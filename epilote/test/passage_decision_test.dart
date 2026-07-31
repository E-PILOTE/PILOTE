import 'package:epilote/features/evaluation/providers/passage_provider.dart';
import 'package:epilote/services/powersync/powersync_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA DÉCISION DE PASSAGE — ce qui ne doit jamais dériver.
//
//  Deux invariants, pour deux raisons différentes :
//
//  1. LA BARRE EST À 10/20. C'est la même que `mentionFor` et que `get_mention()`
//     en base. Ce barème avait DÉJÀ dérivé de deux points côté bulletins : un
//     8/20 ressortait « Passable ». Sur une décision de passage, la même dérive
//     ferait redoubler — ou passer — des enfants à tort.
//
//  2. LE TYPE LOCAL SUIT LE TYPE SERVEUR. `promotion_average` est un `numeric`
//     en base : déclaré autrement, PowerSync abandonnerait la transaction
//     entière (22P02) et TOUTE la délibération d'une classe disparaîtrait sans
//     message. Même famille de panne que `student_payments.amount_xaf`.
// ════════════════════════════════════════════════════════════════════════════
void main() {
  group('verdict proposé', () {
    test('la barre de passage est à 10/20, pas 8', () {
      expect(suggestedVerdict(10.0), 'passe');
      expect(suggestedVerdict(9.99), 'redouble');
      expect(suggestedVerdict(8.0), 'redouble');
      expect(suggestedVerdict(19.5), 'passe');
      expect(suggestedVerdict(0), 'redouble');
    });

    test('aucune note ne propose rien — on ne délibère pas dans le vide', () {
      expect(suggestedVerdict(null), isNull);
    });

    test('« réorienté » n\'est jamais proposé automatiquement', () {
      for (var a = 0.0; a <= 20.0; a += 0.5) {
        expect(suggestedVerdict(a), isNot('reoriente'));
      }
    });
  });

  group('catalogue des verdicts', () {
    test('les trois codes attendus par la contrainte SQL, et eux seuls', () {
      expect(
        passageVerdicts.map((v) => v.code).toList(),
        ['passe', 'redouble', 'reoriente'],
      );
    });

    test('un code inconnu ne rend pas un verdict par défaut', () {
      expect(verdictFor(null), isNull);
      expect(verdictFor(''), isNull);
      expect(verdictFor('admis'), isNull);
    });
  });

  group('schéma PowerSync local', () {
    Column columnOf(String table, String name) => schema.tables
        .firstWhere((t) => t.name == table)
        .columns
        .firstWhere((c) => c.name == name);

    test('les colonnes de décision existent côté local', () {
      for (final c in [
        'promotion_decision',
        'promotion_average',
        'promotion_target_class_id',
        'promotion_decided_at',
        'promotion_decided_by',
      ]) {
        expect(
          () => columnOf('class_enrollments', c),
          returnsNormally,
          reason: 'Sans $c dans le schéma local, la décision reste sur '
              'l\'appareil et ne remonte jamais.',
        );
      }
    });

    test('promotion_average est « real » face au numeric du serveur', () {
      expect(columnOf('class_enrollments', 'promotion_average').type,
          ColumnType.real);
    });

    test('les identifiants et horodatages restent du texte', () {
      for (final c in [
        'promotion_decision',
        'promotion_target_class_id',
        'promotion_decided_at',
        'promotion_decided_by',
      ]) {
        expect(columnOf('class_enrollments', c).type, ColumnType.text);
      }
    });
  });
}
