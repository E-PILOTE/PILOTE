import 'dart:io';

import 'package:epilote/features/admin_groupe/providers/student_results_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  TROIS MOTEURS DE MOYENNE, UN SEUL COEFFICIENT
//
//  ── LE DÉFAUT, TROUVÉ LE 2026-09-09 ────────────────────────────────────────
//  La moyenne générale d'un élève se calcule à TROIS endroits :
//
//    • le BULLETIN, hors ligne — `evaluation/providers/bulletins_provider.dart`
//      C'est le document que reçoit la famille ;
//    • le DOSSIER RÉSEAU, en ligne — `student_results_provider.dart`
//      C'est ce que lit le ministère ;
//    • le PALMARÈS — `get_passage_merit()`, en base.
//
//  Le bulletin lisait `COALESCE(cs.coefficient, subj.coefficient)` : le
//  coefficient EFFECTIF, celui que la classe a posé. Les deux autres lisaient
//  `subjects.coefficient` : le coefficient PAR DÉFAUT.
//
//  Or `subjects.coefficient` n'est qu'un défaut proposé — `subject_model.dart`
//  le dit noir sur blanc — et l'écran qui pose le coefficient d'une classe
//  existe et écrit vraiment (`class_subjects_provider.dart:188`). Une
//  Terminale C ne pondère pas les mathématiques comme une Terminale A.
//
//  ── POURQUOI PERSONNE NE L'AVAIT VU ────────────────────────────────────────
//  Vérifié en production le 2026-09-09 :
//    select count(*) filter (where cs.coefficient is distinct from s.coefficient)
//    from class_subjects cs join subjects s on s.id = cs.subject_id;
//    → 0 divergent sur 4 564 lignes.
//
//  Aucune classe n'avait encore surchargé un coefficient : les trois moteurs
//  tombaient d'accord PAR ACCIDENT. À la première surcharge, le bulletin de la
//  famille et le palmarès du ministère auraient annoncé deux moyennes
//  différentes pour le même élève, le même trimestre.
//
//  ── CE QUE CE TEST GARDE ───────────────────────────────────────────────────
//  1. Le COMPORTEMENT du moteur réseau : le coefficient de la classe prime,
//     et la matière que la classe n'a pas pondérée garde son défaut.
//  2. La RÈGLE, dans les trois sources à la fois. Elle ne vit pas dans un
//     fichier commun — un moteur est en Dart hors ligne, un autre en Dart en
//     ligne, le troisième en SQL — donc rien d'autre qu'un test ne peut les
//     tenir ensemble.
// ════════════════════════════════════════════════════════════════════════════

Map<String, dynamic> _ev({
  required String subject,
  int subjectCoef = 1,
  required List<Map<String, dynamic>> grades,
}) =>
    {
      'subject_id': subject,
      'coefficient': 1,
      'max_score': 20,
      'subjects': {'name': subject, 'coefficient': subjectCoef},
      'grades': grades,
    };

Map<String, dynamic> _g(String student, num score) =>
    {'student_id': student, 'score': score, 'is_absent': false};

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('Le coefficient de la CLASSE prime sur celui de la matière', () {
    // Maths 20/20, Sport 10/20. Coefficients par défaut : 1 et 1 → 15/20.
    // La classe pondère les maths à 3                       → (60+10)/4 = 17,5.
    final rows = [
      _ev(subject: 'maths', grades: [_g('e1', 20)]),
      _ev(subject: 'sport', grades: [_g('e1', 10)]),
    ];

    test('sans surcharge, le défaut de la matière s\'applique', () {
      final r = computeResults(rows, 'e1');
      expect(r.overall, closeTo(15, 0.001));
    });

    test('avec surcharge, c\'est le coefficient de la classe qui pèse', () {
      final r = computeResults(rows, 'e1',
          coefficientsDeLaClasse: const {'maths': 3});
      expect(r.overall, closeTo(17.5, 0.001),
          reason: 'Le coefficient posé sur `class_subjects` doit primer : '
              'c\'est celui que le bulletin de la famille applique déjà.');
    });

    test('une matière non pondérée par la classe garde son défaut', () {
      // Seule la matière `maths` est surchargée ; `sport` garde 1.
      final r = computeResults(rows, 'e1',
          coefficientsDeLaClasse: const {'maths': 3});
      final sport = r.subjects.firstWhere((s) => s.subject == 'sport');
      expect(sport.coefficient, 1,
          reason: 'Une matière absente de `class_subjects` ne doit ni '
              'disparaître de la moyenne, ni tomber à zéro.');
    });

    test('la moyenne de la CLASSE suit la même pondération', () {
      final deux = [
        _ev(subject: 'maths', grades: [_g('e1', 20), _g('e2', 10)]),
        _ev(subject: 'sport', grades: [_g('e1', 10), _g('e2', 20)]),
      ];
      final r = computeResults(deux, 'e1',
          coefficientsDeLaClasse: const {'maths': 3});
      // Classe : maths (20+10)/2 = 15 · sport (10+20)/2 = 15 → 15 quel que
      // soit le coefficient. Ce qui compte est qu'elle ne soit pas nulle.
      expect(r.classOverall, closeTo(15, 0.001));
    });
  });

  group('Les trois moteurs expriment la même règle', () {
    test('le BULLETIN lit le coefficient effectif', () {
      final src =
          _lire('lib/features/evaluation/providers/bulletins_provider.dart');
      expect(
        src.contains('COALESCE(cs.coefficient, subj.coefficient)'),
        isTrue,
        reason: 'Le bulletin est le document que reçoit la famille : c\'est '
            'lui qui fait autorité. S\'il cesse de lire `class_subjects`, ce '
            'sont les deux autres moteurs qu\'il faut suivre, pas l\'inverse.',
      );
    });

    test('le DOSSIER RÉSEAU lit `class_subjects`', () {
      final src = _lire(
          'lib/features/admin_groupe/providers/student_results_provider.dart');
      expect(src.contains("from('class_subjects')"), isTrue,
          reason: 'Sans cette lecture, le dossier consulté par le ministère '
              'retombe sur le coefficient PAR DÉFAUT de la matière.');
      expect(src.contains('coefficientsDeLaClasse'), isTrue);
    });

    test('le PALMARÈS lit `class_subjects` (migration 0205)', () {
      final f = File(
          '../database/migrations/0205_le_palmares_lisait_le_coefficient_par_defaut.sql');
      expect(f.existsSync(), isTrue,
          reason: 'La migration qui corrige `get_passage_merit` a disparu du '
              'dépôt. Les deux moitiés de cette correction — client et base — '
              'doivent voyager ensemble.');
      final sql = f.readAsStringSync();
      expect(sql.contains('coalesce(cs.coefficient, sub.coefficient)'), isTrue);
      expect(sql.contains('left join class_subjects cs'), isTrue,
          reason: 'La jointure doit rester un LEFT JOIN : en INNER, les notes '
              'd\'une matière que la classe n\'a pas pondérée DISPARAÎTRAIENT '
              'de la moyenne — ce serait changer le résultat, pas le corriger.');
    });
  });
}
