import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/examens/providers/exam_registration_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Inscription aux examens — logique pure.
//
//  L'âge est le point sensible : il conditionne la recevabilité d'un dossier
//  (24 ans bacs · 20 BET/CAP · 21 autres brevets), et un calcul faux exclut ou
//  laisse passer à tort. Il reste CONSULTATIF : ces tests vérifient qu'on
//  AVERTIT correctement, jamais qu'on interdit.
// ════════════════════════════════════════════════════════════════════════════

ExamStudentRow _student({
  String id = 's1',
  DateTime? dob,
  String? candidateId,
}) =>
    ExamStudentRow(
      studentId: id,
      fullName: 'Élève $id',
      matricule: 'M-$id',
      dateOfBirth: dob,
      candidateId: candidateId,
      dossierStatus: candidateId == null ? null : 'incomplet',
      candidateNumber: null,
    );

ClassRegistration _reg({
  required List<ExamStudentRow> students,
  int? maxAge,
  DateTime? ageReference,
  String? sessionId = 'sess-1',
  String? sessionStatus = 'open',
  DateTime? closesAt,
}) =>
    ClassRegistration(
      sessionId: sessionId,
      examShortName: 'BET',
      yearLabel: '2025-2026',
      maxAge: maxAge,
      ageReference: ageReference,
      registrationClosesAt: closesAt ?? DateTime(2026, 2, 14),
      sessionStatus: sessionStatus,
      requiredDocuments: const [],
      students: students,
    );

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  //  LA FENÊTRE D'INSCRIPTION SE DIT, ELLE NE S'IMPOSE PAS (2026-08-28)
  //
  //  `registration_closes_at` était LU, AFFICHÉ au milieu d'un sous-titre, et
  //  jamais signalé. Une école pouvait inscrire en mars des candidats pour une
  //  session close en février : elle ne l'apprenait qu'au rejet de la
  //  transmission, des semaines plus tard.
  //
  //  On avertit sans interdire — même raison que l'âge (piège n°2) : la DEC
  //  prolonge, accorde des dérogations, et l'horloge d'un poste hors ligne peut
  //  avoir dérivé. Et la base ne l'exige pas non plus : aucun déclencheur sur
  //  `exam_candidates`.
  // ══════════════════════════════════════════════════════════════════════════
  group('ClassRegistration.inscriptionsCloses', () {
    final demain = DateTime.now().add(const Duration(days: 30));
    final hier = DateTime.now().subtract(const Duration(days: 30));

    test('une session ouverte dont la date court n\'alerte pas', () {
      expect(
          _reg(students: const [], sessionStatus: 'open', closesAt: demain)
              .inscriptionsCloses,
          isFalse);
    });

    test('la date passée suffit, même si la session se dit ouverte', () {
      expect(
          _reg(students: const [], sessionStatus: 'open', closesAt: hier)
              .inscriptionsCloses,
          isTrue);
    });

    test('le statut suffit, même sans date', () {
      for (final st in ['closed', 'running']) {
        expect(
            _reg(students: const [], sessionStatus: st, closesAt: demain)
                .inscriptionsCloses,
            isTrue,
            reason: 'Une session « $st » n\'accepte plus de dépôt.');
      }
    });

    test('sans date ni statut connus, on n\'invente pas une clôture', () {
      // « Je ne sais pas » ne se traite pas comme « c'est fermé » : ici,
      // l'avertissement serait faux et ferait douter d'une inscription valide.
      final r = const ClassRegistration(
        sessionId: 'sess-1',
        examShortName: 'BET',
        yearLabel: '2025-2026',
        maxAge: null,
        ageReference: null,
        registrationClosesAt: null,
        sessionStatus: null,
        requiredDocuments: [],
        students: [],
      );
      expect(r.inscriptionsCloses, isFalse);
    });
  });

  group('ExamStudentRow.ageAt', () {
    // Épreuves écrites du BET : 23 juin 2026.
    final ref = DateTime(2026, 6, 23);

    test('anniversaire déjà passé à la date de référence', () {
      expect(_student(dob: DateTime(2006, 1, 10)).ageAt(ref), 20);
    });

    test('anniversaire PAS encore passé : un an de moins', () {
      // Né en décembre : au 23 juin il n'a pas encore eu ses 20 ans.
      expect(_student(dob: DateTime(2006, 12, 10)).ageAt(ref), 19);
    });

    test('anniversaire le jour même : l\'âge est atteint', () {
      // Cas limite classique : ne doit PAS retirer une année.
      expect(_student(dob: DateTime(2006, 6, 23)).ageAt(ref), 20);
    });

    test('anniversaire le lendemain : pas encore atteint', () {
      expect(_student(dob: DateTime(2006, 6, 24)).ageAt(ref), 19);
    });

    test('sans date de naissance -> null (jamais 0, qui ferait « nourrisson »)',
        () {
      expect(_student(dob: null).ageAt(ref), isNull);
    });

    test('sans date de référence -> null', () {
      expect(_student(dob: DateTime(2006, 1, 10)).ageAt(null), isNull);
    });
  });

  group('ClassRegistration.overAge', () {
    final ref = DateTime(2026, 6, 23);

    test('signale ceux qui dépassent strictement l\'âge maximal', () {
      final reg = _reg(
        maxAge: 20,
        ageReference: ref,
        students: [
          _student(id: 'ok', dob: DateTime(2007, 1, 1)),    // 19 ans
          _student(id: 'pile', dob: DateTime(2006, 1, 1)),  // 20 ans -> admis
          _student(id: 'trop', dob: DateTime(2004, 1, 1)),  // 22 ans -> signalé
        ],
      );
      expect(reg.overAge.map((s) => s.studentId), ['trop']);
    });

    test('l\'âge exactement égal au maximum n\'est PAS un dépassement', () {
      final reg = _reg(
        maxAge: 20,
        ageReference: ref,
        students: [_student(dob: DateTime(2006, 1, 1))],
      );
      expect(reg.overAge, isEmpty);
    });

    test('aucun maximum -> aucun signalement (CEPE, BEPC : pas de limite connue)',
        () {
      final reg = _reg(
        maxAge: null,
        ageReference: ref,
        students: [_student(dob: DateTime(1990, 1, 1))],
      );
      expect(reg.overAge, isEmpty);
    });

    test('date de naissance manquante -> jamais signalé « trop âgé »', () {
      // On ne peut pas conclure : signaler serait une accusation infondée.
      final reg = _reg(
        maxAge: 20,
        ageReference: ref,
        students: [_student(dob: null)],
      );
      expect(reg.overAge, isEmpty);
    });
  });

  group('ClassRegistration — partitions', () {
    test('sépare inscrits et restants', () {
      final reg = _reg(students: [
        _student(id: 'a'),
        _student(id: 'b', candidateId: 'c-b'),
        _student(id: 'c'),
      ]);
      expect(reg.pending.map((s) => s.studentId), ['a', 'c']);
      expect(reg.registered.map((s) => s.studentId), ['b']);
    });

    test('hasSession est faux sans session -> l\'UI doit bloquer l\'inscription',
        () {
      expect(_reg(students: const [], sessionId: null).hasSession, isFalse);
      expect(_reg(students: const []).hasSession, isTrue);
    });
  });
}
