import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUI TIENT LA MIGRATION 0146 — ET CE QUI POURRAIT LA CASSER
//
//  `0146` retire `profiles.fcm_token` et `notifications.fcm_message_id`, deux
//  colonnes mortes (0 valeur sur 344 profils et 122 notifications). Elle est
//  SUSPENDUE depuis le 2026-08-29 pour une raison précise : un poste resté sur
//  un vieux build qui ENVERRAIT la colonne retirée prendrait un `42703`, rejoué
//  à l'infini — et cesserait silencieusement de remonter quoi que ce soit.
//
//  ── CE QUE LA MESURE DU 2026-09-01 A ÉTABLI ────────────────────────────────
//  Le danger suppose qu'un poste ENVOIE la colonne. Or il ne le peut pas :
//
//   1. le connecteur envoie, pour un `patch`, UNIQUEMENT `op.opData` —
//      c'est-à-dire les colonnes réellement écrites localement ;
//   2. seul un `put` (insertion) transmettrait la ligne entière ;
//   3. il n'existe AUCUNE insertion locale sur `profiles` ni sur
//      `notifications` ;
//   4. et ni `fcm_token` ni `fcm_message_id` n'est écrite nulle part.
//
//  ⚠️ CE TEST NE DIT PAS QUE 0146 PEUT ÊTRE APPLIQUÉE. Il garde les quatre
//  faits sur lesquels ce raisonnement repose. Si l'un tombe — quelqu'un ajoute
//  un `INSERT INTO profiles` hors ligne — la conclusion tombe avec lui, et il
//  vaut mieux que ce soit un test qui le dise qu'un parc qui se bloque.
//
//  ⚠️ Et il ne dit rien du parc : `app_installations` ne remonte que depuis le
//  2026-08-29 (migration 0150), alors que les 10 sessions jamais ouvertes
//  datent toutes d'AVANT. L'absence de vieux poste dans cette table n'est donc
//  pas une preuve d'absence.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) {
  final f = File(chemin);
  expect(f.existsSync(), isTrue, reason: 'Sonde aveugle : $chemin introuvable.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Toutes les lignes de `lib/`, hors commentaires.
Iterable<(String, int, String)> _lignesDeCode() sync* {
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final lignes = f.readAsLinesSync();
    for (var i = 0; i < lignes.length; i++) {
      final t = lignes[i].trimLeft();
      if (t.startsWith('//') || t.startsWith('*') || t.startsWith('///')) continue;
      yield (f.path, i + 1, lignes[i]);
    }
  }
}

void main() {
  group('Une colonne retirée ne peut pas être envoyée par un vieux poste', () {
    test('le connecteur n\'envoie que les colonnes écrites (`op.opData`)', () {
      // C'est le pivot du raisonnement : si le connecteur envoyait la ligne
      // locale entière sur un `patch`, un vieux build transmettrait ses
      // colonnes mortes et 0146 le bloquerait.
      final src = _lire('lib/services/powersync/powersync_connector.dart');
      expect(src.contains('table\n                .update(_decodeJsonbColumns(op.table, op.opData!))') ||
             src.contains('.update(_decodeJsonbColumns(op.table, op.opData!))'),
          isTrue,
          reason: 'Le chemin `patch` n\'envoie plus `op.opData` seul. Si la '
              'ligne locale entière part désormais, un poste ancien enverra '
              'ses colonnes mortes — et 0146 le bloquera en silence.');
    });

    test('aucune INSERTION locale sur `profiles` ni sur `notifications`', () {
      // Une insertion produit un `put`, qui transmet TOUTE la ligne locale —
      // y compris les colonnes que ce build déclare et que le serveur n'a plus.
      final fautes = <String>[];
      for (final (chemin, n, l) in _lignesDeCode()) {
        if (RegExp(r'INSERT\s+INTO\s+(profiles|notifications)\b').hasMatch(l)) {
          fautes.add('$chemin:$n → ${l.trim()}');
        }
      }
      expect(fautes, isEmpty,
          reason: 'Une insertion locale transmet la LIGNE ENTIÈRE. Elle rend '
              'donc `0146` dangereuse pour tout poste antérieur au 2026-08-29 :'
              '\n${fautes.join('\n')}');
    });

    test('`fcm_token` et `fcm_message_id` ne sont écrites nulle part', () {
      final fautes = <String>[];
      for (final (chemin, n, l) in _lignesDeCode()) {
        for (final col in ['fcm_token', 'fcm_message_id']) {
          if (l.contains(col)) fautes.add('$chemin:$n → ${l.trim()}');
        }
      }
      expect(fautes, isEmpty,
          reason: 'Ces colonnes sont retirées par `0146`. Les écrire — ou même '
              'les déclarer dans le schéma local — rouvre le risque de `42703` :'
              '\n${fautes.join('\n')}');
    });

    test('le schéma local ne déclare NI l\'une NI l\'autre', () {
      // Une colonne déclarée mais jamais écrite ne part pas sur un `patch` ;
      // elle partirait sur un `put`. La garder hors du schéma supprime le cas.
      final schema = _lire('lib/services/powersync/powersync_schema.dart');
      for (final col in ['fcm_token', 'fcm_message_id']) {
        expect(schema.contains("Column.text('$col')"), isFalse,
            reason: '`$col` est de retour dans le schéma local.');
      }
    });
  });
}
