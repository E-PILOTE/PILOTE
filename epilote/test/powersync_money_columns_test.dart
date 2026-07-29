import 'package:epilote/services/powersync/powersync_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE TYPE LOCAL DOIT SUIVRE LE TYPE SERVEUR — sur l'argent, surtout.
//
//  ── CE QUI S'EST PASSÉ ─────────────────────────────────────────────────────
//  `student_payments.amount_xaf` est un `integer` en base (le franc CFA n'a
//  pas de subdivision). Le schéma LOCAL le déclarait `real`. SQLite stockait
//  donc 10000.0, le connecteur l'envoyait tel quel, et Postgres refusait :
//
//     invalid input syntax for type integer: "10000.0"   (SQLSTATE 22P02)
//
//  PowerSync n'écarte pas la ligne fautive : il ABANDONNE la transaction
//  entière. Chaque paiement encaissé hors ligne était perdu à la synchro —
//  avec toutes les écritures du même lot. Silencieux, et sur de l'argent.
//
//  ── L'INVARIANT ────────────────────────────────────────────────────────────
//  Toute colonne monétaire (suffixe `_xaf`) est un entier côté serveur. Elle
//  doit donc être `Column.integer` côté local. Ce test le verrouille pour
//  toutes les tables, pas seulement celle qui a saigné.
//
//  Les colonnes `real` restantes du schéma (moyennes, scores, latitude…) font
//  face à des `numeric` / `double precision`, qui acceptent un décimal : elles
//  sont légitimes et volontairement hors de cette règle.
// ════════════════════════════════════════════════════════════════════════════
void main() {
  group('schéma PowerSync local', () {
    test('aucune colonne monétaire (_xaf) n\'est déclarée « real »', () {
      final fautives = <String>[];
      for (final table in schema.tables) {
        for (final column in table.columns) {
          if (column.name.endsWith('_xaf') &&
              column.type == ColumnType.real) {
            fautives.add('${table.name}.${column.name}');
          }
        }
      }

      expect(
        fautives,
        isEmpty,
        reason: 'Ces colonnes sont des `integer` en base : déclarées `real`, '
            'elles font échouer la synchro en 22P02 et PowerSync abandonne '
            'toute la transaction — le paiement est perdu sans bruit.',
      );
    });

    test('amount_xaf de student_payments est un entier', () {
      final table =
          schema.tables.firstWhere((t) => t.name == 'student_payments');
      final column =
          table.columns.firstWhere((c) => c.name == 'amount_xaf');
      expect(column.type, ColumnType.integer);
    });
  });
}
