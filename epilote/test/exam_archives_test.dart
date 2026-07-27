import 'package:epilote/features/admin_groupe/providers/exam_archives_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// ARCHIVES DES PUBLICATIONS DE LA DEC.
///
/// Ce qui est gardé ici n'est pas de l'affichage : c'est la frontière entre
/// deux familles de chiffres qu'on ne doit jamais fondre.
///  • OFFICIEL   — relevé sur la publication de la DEC, fait autorité.
///  • PLATEFORME — dérivé des saisies des écoles, inséparable de sa couverture.
void main() {
  group('Taux officiel — il porte sur les PRÉSENTS', () {
    test('reproduit le taux réellement publié (BAC T&P 2025)', () {
      // 7 681 admis sur 15 843 présents, pour 16 070 inscrits → 48,48 %.
      // Calculer sur les inscrits donnerait 47,80 % : un autre chiffre, faux.
      final r = officialPassRate(present: 15843, admitted: 7681);
      expect(r!.toStringAsFixed(2), '48.48');
    });

    test('un pourcentage publié sans effectifs fait foi tel quel', () {
      // Le classement départemental du Bac général ne donne QUE des %.
      expect(officialPassRate(storedRate: 92.10), 92.10);
    });

    test('les effectifs l\'emportent sur un taux stocké contradictoire', () {
      expect(officialPassRate(present: 200, admitted: 100, storedRate: 75),
          50,
          reason: 'la publication chiffrée prime sur un pourcentage recopié');
    });

    test('aucun chiffre exploitable → aucun taux inventé', () {
      expect(officialPassRate(), isNull);
      expect(officialPassRate(present: 0, admitted: 0), isNull,
          reason: 'diviser par zéro présent ne donne pas 0 %');
    });

    test('les absents se déduisent des inscrits, jamais du taux', () {
      const f = OfficialFigure(
        id: 'x',
        sessionId: 's',
        scope: PubScope.national,
        registered: 16070,
        present: 15843,
        admitted: 7681,
      );
      expect(f.absent, 227);
      expect(f.hasCounts, isTrue);
      expect(f.hasSource, isFalse, reason: 'aucune pièce jointe ici');
    });
  });

  group('Chiffres de la plateforme — jamais sans couverture', () {
    test('une école n\'ayant saisi que ses admis n\'est PAS à 100 %', () {
      // 3 résultats saisis sur 40 candidats : le taux brut dirait 100 %.
      final t = tallyOf([
        ...List.filled(3, 'admis'),
        ...List.filled(37, null),
      ]);
      expect(t.passRate, 100);
      expect(t.coverage.toStringAsFixed(1), '7.5');
      expect(t.isReliable, isFalse,
          reason: 'c\'est la couverture qui interdit d\'afficher ce taux');
    });

    test('les absents sortent du dénominateur', () {
      final t = tallyOf(['admis', 'admis', 'ajourne', 'absent']);
      expect(t.present, 3);
      expect(t.passRate!.toStringAsFixed(2), '66.67');
      expect(t.absent, 1);
    });

    test('une fraude a composé : présente, jamais admise', () {
      final t = tallyOf(['admis', 'fraude']);
      expect(t.present, 2);
      expect(t.passRate, 50,
          reason: 'l\'exclure du dénominateur gonflerait le taux à 100 %');
    });

    test('« en attente » n\'est pas un échec', () {
      final t = tallyOf(['admis', 'en_attente', 'en_attente']);
      expect(t.known, 1);
      expect(t.present, 1);
      expect(t.passRate, 100);
      expect(t.coverage.toStringAsFixed(1), '33.3');
    });

    test('personne n\'ayant composé → aucun taux, pas 0 %', () {
      final t = tallyOf(['absent', 'absent']);
      expect(t.passRate, isNull,
          reason: '0 % dirait « tous recalés » là où nul n\'a composé');
    });

    test('une session complète et fournie est jugée fiable', () {
      final t = tallyOf([...List.filled(18, 'admis'), ...List.filled(6, 'ajourne')]);
      expect(t.coverage, 100);
      expect(t.isReliable, isTrue);
    });

    test('un effectif minuscule reste non fiable même à 100 % de couverture', () {
      final t = tallyOf(['admis', 'ajourne']);
      expect(t.coverage, 100);
      expect(t.isReliable, isFalse,
          reason: '2 candidats ne fondent pas un taux de réussite');
    });

    test('aucun candidat → couverture nulle, sans division par zéro', () {
      final t = tallyOf(const []);
      expect(t.coverage, 0);
      expect(t.passRate, isNull);
    });
  });

  group('Périmètre d\'une publication', () {
    test('le périmètre est toujours lisible sur la pièce archivée', () {
      ExamPublication p(PubScope s, {String? dep, String? school, String? code}) =>
          ExamPublication(
            id: 'p',
            sessionId: 's',
            scope: s,
            title: 'Liste des admis',
            fileName: 'f.pdf',
            filePath: 'x',
            receivedAt: DateTime(2026),
            department: dep,
            schoolName: school,
            decSchoolCode: code,
          );

      expect(p(PubScope.national).scopeLabel, 'National');
      expect(p(PubScope.departement, dep: 'Bouenza').scopeLabel, 'Bouenza');
      expect(p(PubScope.etablissement, school: 'CEG Kinkala').scopeLabel,
          'CEG Kinkala');
      // École pas encore rattachée : le code DEC porté par le document doit
      // suffire à identifier la pièce.
      expect(p(PubScope.etablissement, code: 'AAB').scopeLabel, 'AAB');
    });

    test('un code de périmètre inconnu retombe sur « national », sans planter',
        () {
      expect(PubScope.from('centre_examen'), PubScope.national);
      expect(PubScope.from(null), PubScope.national);
    });
  });
}
