import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/admin_groupe/providers/exam_sessions_admin_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SESSIONS D'EXAMEN — administration du calendrier national.
//
//  Le trou comblé : les 12 sessions 2025-2026 avaient été semées par une
//  MIGRATION. À l'ouverture de 2026-2027, personne n'aurait pu en créer une
//  sans écrire du SQL.
//
//  Ces tests verrouillent les deux garde-fous de l'écran : on ne supprime pas
//  une session qui porte des candidatures (ce serait détruire le travail des
//  écoles), et une session sans date d'épreuve est signalée sans être traitée
//  comme une erreur (l'arrêté ouvre souvent les inscriptions avant de publier
//  le calendrier — cas réel de CAP et CQP).
// ════════════════════════════════════════════════════════════════════════════

ExamSessionAdminRow _session({
  String status = 'open',
  DateTime? writtenFrom,
  int candidateCount = 0,
}) =>
    ExamSessionAdminRow(
      id: 's1',
      examId: 'e1',
      examCode: 'BET',
      examShortName: 'BET',
      tutelle: 'metp',
      yearLabel: '2025-2026',
      status: status,
      registrationOpensAt: DateTime(2025, 12, 8),
      registrationClosesAt: DateTime(2026, 2, 14),
      writtenFrom: writtenFrom,
      writtenTo: null,
      practicalFrom: null,
      practicalTo: null,
      maxAge: 20,
      candidateCount: candidateCount,
      notes: null,
    );

void main() {
  group('Suppression — protéger le travail des écoles', () {
    test('une session vierge est supprimable', () {
      expect(_session(candidateCount: 0).isDeletable, isTrue);
    });

    test('une session avec UNE seule candidature ne l\'est plus', () {
      // Supprimer emporterait les candidatures : le travail d'une école
      // entière disparaîtrait à la prochaine synchronisation.
      expect(_session(candidateCount: 1).isDeletable, isFalse);
      expect(_session(candidateCount: 6867).isDeletable, isFalse);
    });
  });

  group('Dates manquantes — un manque, pas une faute', () {
    test('sans date d\'écrits -> signalée incomplète', () {
      // Cas réel : CAP et CQP 2025-2026 ont une fenêtre d'inscription connue
      // mais aucune date d'épreuve publiée.
      expect(_session(writtenFrom: null).missingDates, isTrue);
    });

    test('avec date d\'écrits -> complète', () {
      expect(_session(writtenFrom: DateTime(2026, 6, 23)).missingDates, isFalse);
    });
  });

  group('Statut de session', () {
    test('seule « open » est ouverte aux inscriptions', () {
      expect(_session(status: 'open').isOpen, isTrue);
      for (final s in ['draft', 'closed', 'running', 'published', 'cancelled']) {
        expect(_session(status: s).isOpen, isFalse, reason: s);
      }
    });
  });

  group('year_label — pourquoi du texte libre', () {
    test('une session porte une année en TEXTE, pas une FK', () {
      // Une session est NATIONALE ; les `academic_years` sont propres à chaque
      // tenant. Les lier aurait rendu le calendrier national dépendant du
      // paramétrage d'une école — et deux écoles en désaccord auraient produit
      // deux calendriers.
      final s = _session();
      expect(s.yearLabel, isA<String>());
      expect(s.yearLabel, '2025-2026');
    });
  });
}
