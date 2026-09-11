import 'dart:io';

import 'package:epilote/services/powersync/powersync_schema.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE TABLE QUI GROSSIT SANS INDEX DEVIENT LENTE SANS RIEN DIRE
//
//  ── CE QUE POWERSYNC FAIT VRAIMENT ─────────────────────────────────────────
//  Le SQLite local ne range pas les colonnes : chaque ligne est un blob JSON
//  dans `ps_data__<table>.data`, et la « table » que le code interroge est une
//  VUE dont chaque colonne vaut `json_extract(data, '$.colonne')`.
//
//  Donc `WHERE class_id = ?` sans index, c'est un balayage complet AVEC un
//  décodage JSON par ligne. Aucune erreur, aucun avertissement : juste une
//  page qui met une seconde, puis deux, puis dix, à mesure que l'année
//  avance. C'est le pire profil de défaut pour un produit livré par vagues —
//  il ne se voit pas à la recette, il se voit au troisième trimestre.
//
//  ── LA MESURE QUI A DÉCLENCHÉ CE GARDE (2026-09-09) ────────────────────────
//  Base de production, 44 écoles sur les 1 000+ visées :
//    • `grades`                  501 012 lignes (38 544 pour la seule école
//                                la plus chargée) ;
//    • `bulletin_subject_lines`  178 419 ;
//    • `attendance_entries`       28 316 ;
//    • `class_enrollments`        10 364.
//  Le schéma local déclarait **zéro** index sur 89 tables.
//
//  ── CE QUE CE TEST GARDE ───────────────────────────────────────────────────
//  1. Le contrat technique : toute colonne indexée existe dans sa table —
//     sinon `IndexedColumn.toJson` lève un StateError AU DÉMARRAGE de
//     l'application, pas ici. Un schéma qui ne se construit pas, c'est une
//     app qui ne s'ouvre pas.
//  2. La liste des tables de VOLUME : celles dont le nombre de lignes croît
//     avec les élèves, les jours de classe ou les années. Aucune ne doit
//     repartir sans index. Ajouter une table de volume sans l'indexer fait
//     échouer ce test — c'est-à-dire au moment où l'on peut encore y penser.
// ════════════════════════════════════════════════════════════════════════════

/// Les tables dont le volume croît avec l'usage, et ce qu'on attend d'elles.
///
/// La valeur est la colonne de filtre la plus chaude : celle par laquelle
/// les écrans entrent dans la table. Elle doit être la PREMIÈRE colonne d'au
/// moins un index — un index composite ne sert que si l'on attaque par sa
/// tête.
const Map<String, String> _tablesDeVolume = {
  'grades': 'evaluation_id',
  'competence_grades': 'evaluation_id',
  'bulletins': 'student_id',
  'bulletin_subject_lines': 'bulletin_id',
  'evaluations': 'class_id',
  'attendance_records': 'class_id',
  'attendance_entries': 'attendance_record_id',
  'canteen_records': 'student_id',
  'class_enrollments': 'class_id',
  'students': 'school_id',
  'student_payments': 'student_id',
  'student_documents': 'student_id',
  'student_tutors': 'student_id',
  'issued_documents': 'student_id',
  'timetable_slots': 'class_id',
  'lesson_entries': 'class_id',
  'exam_candidates': 'session_id',
  'messages': 'conversation_id',
  'notifications': 'recipient_id',
  'payroll': 'school_id',
  'staff_attendance': 'school_id',
  'library_loans': 'borrower_id',
  'discipline_incidents': 'student_id',
  'infirmary_visits': 'student_id',
};

void main() {
  final tables = {for (final t in schema.tables) t.name: t};

  group('Le schéma local est indexé', () {
    test('toute colonne indexée est déclarée dans sa table', () {
      final fautes = <String>[];
      for (final t in schema.tables) {
        final colonnes = {for (final c in t.columns) c.name};
        for (final idx in t.indexes) {
          for (final ic in idx.columns) {
            if (!colonnes.contains(ic.column)) {
              fautes.add('${t.name}.${idx.name} → « ${ic.column} » absente');
            }
          }
        }
      }
      expect(
        fautes,
        isEmpty,
        reason: 'Ces index visent des colonnes non déclarées :\n  '
            '${fautes.join('\n  ')}\n\n'
            'PowerSync résout la colonne avec `firstWhere` à la '
            "CONSTRUCTION du schéma : l'application lèverait un StateError au "
            'démarrage, avant même son premier écran.',
      );
    });

    test('le schéma se construit vraiment (pas seulement à la lecture)', () {
      // `toJson()` est le chemin que PowerSync emprunte pour créer les index.
      // C'est lui, et pas la simple lecture des champs, qui déclenche le
      // `firstWhere` — donc c'est lui qu'il faut exercer.
      expect(() => schema.toJson(), returnsNormally);
    });

    test('aucune table de volume ne repart sans index', () {
      final nues = <String>[];
      for (final nom in _tablesDeVolume.keys) {
        final t = tables[nom];
        if (t == null) continue; // table renommée : un autre garde le dira
        if (t.indexes.isEmpty) nues.add(nom);
      }
      expect(
        nues,
        isEmpty,
        reason: 'Ces tables grossissent avec les élèves ou les jours de '
            'classe et n\'ont aucun index local : ${nues.join(', ')}.\n'
            'Sans index, chaque filtre les balaie en entier avec un décodage '
            'JSON par ligne.',
      );
    });

    test('la colonne de filtre la plus chaude attaque bien un index', () {
      final manques = <String>[];
      _tablesDeVolume.forEach((nom, chaude) {
        final t = tables[nom];
        if (t == null) return;
        final tetes = {
          for (final i in t.indexes)
            if (i.columns.isNotEmpty) i.columns.first.column,
        };
        if (!tetes.contains(chaude)) manques.add('$nom (attendu « $chaude »)');
      });
      expect(
        manques,
        isEmpty,
        reason: 'Un index composite ne sert que si on l\'attaque par sa tête. '
            'Ces tables ont des index, mais aucun ne commence par leur '
            'colonne de filtre principale : ${manques.join(', ')}.',
      );
    });

    test('deux index de la même table ne portent pas le même nom', () {
      final collisions = <String>[];
      for (final t in schema.tables) {
        final vus = <String>{};
        for (final i in t.indexes) {
          if (!vus.add(i.name)) collisions.add('${t.name}.${i.name}');
        }
      }
      expect(collisions, isEmpty,
          reason: 'Noms d\'index dupliqués : ${collisions.join(', ')}. '
              'Le nom SQLite réel est `ps_data__<table>__<nom>` : deux '
              'homonymes dans la même table entrent en conflit à la création.');
    });
  });

  group('Le fichier de schéma reste lisible par les autres gardes', () {
    test('chaque `indexes:` suit immédiatement la liste des colonnes', () {
      // `colonnes_synchronisees_test` et `registre_documents_test` découpent ce
      // fichier au texte. La forme `  ], indexes: [` … `  ]),` est celle qu'ils
      // savent lire ; une autre les rendrait verts-mais-aveugles.
      final src = File('lib/services/powersync/powersync_schema.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      final ouvertures = RegExp(r'\n  \], indexes: \[\n').allMatches(src).length;
      final declarations = RegExp(r'indexes:\s*\[').allMatches(src).length;
      expect(ouvertures, declarations,
          reason: 'Un `indexes:` est écrit autrement que sur la forme '
              '`  ], indexes: [` : les gardes qui lisent ce fichier au texte '
              'ne le verraient plus.');
      expect(ouvertures, greaterThan(20),
          reason: 'La lecture du fichier a échoué : le test passerait à vide.');
    });
  });
}
