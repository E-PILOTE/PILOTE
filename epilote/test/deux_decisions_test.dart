import 'dart:io';

import 'package:epilote/core/utils/decisions.dart';
import 'package:epilote/features/evaluation/providers/conseils_provider.dart'
    show awardFor, councilAwards, suggestedAward;
import 'package:epilote/features/evaluation/providers/passage_provider.dart'
    show passageVerdicts, verdictFor;
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DEUX DÉCISIONS, DEUX COLONNES — ET PLUS AUCUN MOYEN DE LES ÉCHANGER
//
//  ── LE DÉFAUT, TEL QU'IL SE PRÉSENTE ──────────────────────────────────────
//  `bulletins.decision` porte la DISTINCTION du conseil de classe. Le VERDICT
//  annuel de passage vit ailleurs, dans `class_enrollments.promotion_decision`.
//  Les deux colonnes étaient du texte libre. Les intervertir ne levait rien :
//
//    • un « passe » dans `bulletins.decision` → `awardFor()` rend `null`, le
//      bulletin s'imprime sans distinction, les compteurs du module Conseils
//      restent à zéro. La saisie « a marché ».
//    • une « felicitations » dans `promotion_decision` → l'élève n'est ni
//      passant ni redoublant : il sort des deux listes de fin d'année, et sa
//      réinscription avec lui.
//
//  Aucun des deux ne produit un message. C'est la famille exacte des « zéros
//  menteurs » : un échec qui se lit comme un état normal.
//
//  ── LES TROIS VERROUS QUE CE FICHIER TIENT ────────────────────────────────
//  1. Le Dart REFUSE, avant la file de synchro (`decisions.dart`).
//  2. Les listes d'affichage n'inventent pas de code hors vocabulaire.
//  3. La base refuse aussi — migration 0206, miroir exact du Dart.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — lancer depuis `epilote/`.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('Les deux vocabulaires ne se recouvrent jamais', () {
    test('aucun code commun', () {
      expect(kDistinctionsConseil.intersection(kVerdictsPassage), isEmpty,
          reason: 'Un code partagé rendrait toute vérification inutile : on ne '
              'saurait plus dans quelle colonne il devait aller.');
    });

    test('chacun garde ses membres', () {
      expect(kDistinctionsConseil, hasLength(6));
      expect(kVerdictsPassage, {'passe', 'redouble', 'reoriente'});
    });
  });

  group('🩸 Le Dart refuse AVANT la base', () {
    test('l’absence de distinction reste légitime', () {
      expect(distinctionConseilValide(null), isNull);
      expect(distinctionConseilValide(''), isNull);
      expect(verdictPassageValide(null), isNull);
      expect(verdictPassageValide(''), isNull);
    });

    test('chaque vocabulaire accepte les siens', () {
      for (final c in kDistinctionsConseil) {
        expect(distinctionConseilValide(c), c);
      }
      for (final v in kVerdictsPassage) {
        expect(verdictPassageValide(v), v);
      }
    });

    test('un verdict de passage est REFUSÉ sur un bulletin', () {
      for (final v in kVerdictsPassage) {
        expect(() => distinctionConseilValide(v), throwsArgumentError,
            reason: '« $v » écrit dans `bulletins.decision` s’enregistrait '
                'sans un mot, et le bulletin sortait sans distinction.');
      }
    });

    test('une distinction est REFUSÉE sur un verdict annuel', () {
      for (final d in kDistinctionsConseil) {
        expect(() => verdictPassageValide(d), throwsArgumentError,
            reason: '« $d » dans `promotion_decision` faisait disparaître '
                'l’élève des listes de fin d’année.');
      }
    });

    test('le message dit OÙ la valeur devait aller', () {
      // Sans cette phrase, l'erreur dit seulement « valeur invalide » — et la
      // personne qui la lit doit rouvrir le schéma pour comprendre.
      try {
        distinctionConseilValide('passe');
        fail('aurait dû lever');
      } on ArgumentError catch (e) {
        expect('${e.message}', contains('promotion_decision'));
      }
      try {
        verdictPassageValide('blame');
        fail('aurait dû lever');
      } on ArgumentError catch (e) {
        expect('${e.message}', contains('bulletins.decision'));
      }
    });

    test('une valeur libre est refusée des deux côtés', () {
      // Le cas réel : « Admis en classe supérieure », saisi de bonne foi.
      expect(() => distinctionConseilValide('Admis en classe supérieure'),
          throwsArgumentError);
      expect(() => verdictPassageValide('Admis en classe supérieure'),
          throwsArgumentError);
    });
  });

  group('Les listes d’affichage restent alignées sur l’autorité', () {
    test('les distinctions affichées sont exactement le vocabulaire', () {
      expect(councilAwards.map((a) => a.code).toSet(), kDistinctionsConseil,
          reason: 'Ajouter une distinction à l’écran sans l’ajouter à '
              '`decisions.dart` la ferait lever à l’enregistrement.');
    });

    test('les verdicts affichés sont exactement le vocabulaire', () {
      expect(passageVerdicts.map((v) => v.code).toSet(), kVerdictsPassage);
    });

    test('la distinction proposée par la moyenne reste dans le vocabulaire',
        () {
      for (var n = 0; n <= 200; n++) {
        final s = suggestedAward(n / 10);
        if (s != null) expect(kDistinctionsConseil, contains(s));
      }
      expect(suggestedAward(null), isNull);
    });

    test('chaque lecture ignore le vocabulaire de l’autre — le défaut d’origine',
        () {
      for (final v in kVerdictsPassage) {
        expect(awardFor(v), isNull);
      }
      for (final d in kDistinctionsConseil) {
        expect(verdictFor(d), isNull);
      }
    });
  });

  group('Les cinq points d’écriture passent par le garde', () {
    test('les deux écritures du conseil sont gardées', () {
      final src =
          _lire('lib/features/evaluation/providers/conseils_provider.dart');
      expect('distinctionConseilValide('.allMatches(src).length,
          greaterThanOrEqualTo(2),
          reason: 'Il y a deux `UPDATE bulletins SET decision` : la saisie '
              'unitaire et le pré-remplissage en masse.');
    });

    test('les trois écritures de passage sont gardées', () {
      final passage =
          _lire('lib/features/evaluation/providers/passage_provider.dart');
      final cloture = _lire(
          'lib/features/evaluation/providers/cloture_examen_provider.dart');
      expect(passage.contains('verdictPassageValide(decision)'), isTrue);
      expect('verdictPassageValide('.allMatches(cloture).length, 2,
          reason: 'La clôture écrit deux fois : la décision de masse et la '
              'sortie diplômée figée à « passe ».');
    });
  });

  group('La base dit la même chose que le Dart', () {
    String migration() => _lire(
        '../database/migrations/0206_les_deux_decisions_ne_se_confondent_plus.sql');

    test('la contrainte des bulletins liste les six distinctions', () {
      final sql = migration();
      expect(sql.contains('bulletins_decision_check'), isTrue);
      for (final c in kDistinctionsConseil) {
        expect(sql.contains("'$c'"), isTrue,
            reason: '« $c » manque à la contrainte : la base accepterait une '
                'valeur que le Dart produit.');
      }
    });

    test('la contrainte du passage liste les trois verdicts', () {
      final sql = migration();
      expect(sql.contains('class_enrollments_promotion_decision_check'), isTrue);
      for (final v in kVerdictsPassage) {
        expect(sql.contains("'$v'"), isTrue);
      }
    });

    test('les deux contraintes laissent passer NULL', () {
      // La plupart des bulletins n'ont aucune distinction, et la majorité des
      // inscriptions n'ont pas encore de verdict. Une contrainte NOT NULL ici
      // aurait bloqué toute la remontée du parc.
      final sql = migration();
      expect(sql.contains('decision IS NULL'), isTrue);
      expect(sql.contains('promotion_decision IS NULL'), isTrue);
    });

    test('la migration explique pourquoi une violation ne peut pas venir du '
        'client', () {
      // `23514` est FATAL côté PowerSync : le lot entier serait jeté. La seule
      // raison pour laquelle cette contrainte est sûre, c'est que le Dart lève
      // avant. Si cette phrase disparaît, quelqu'un ajoutera une contrainte
      // sans garde côté client.
      expect(migration().contains('23514'), isTrue);
    });
  });
}
