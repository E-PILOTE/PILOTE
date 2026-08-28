import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN SEUL FOURNISSEUR : SUPABASE (2026-08-29)
//
//  ── LA DÉCISION ───────────────────────────────────────────────────────────
//  La plateforme n'a qu'un fournisseur de service : Supabase. Firebase n'entre
//  pas. Le cahier des charges, règle n°3, promettait « notification push FCM » ;
//  cette promesse est REMPLACÉE, pas ajournée.
//
//  ── POURQUOI CE N'EST PAS UN RENONCEMENT ──────────────────────────────────
//  `firebase_messaging` ne couvre qu'Android et iOS. Les écoles sont sur des
//  postes Windows partagés — secrétariat, surveillance, direction s'y
//  succèdent. FCM n'aurait donc JAMAIS sonné là où le travail se fait.
//
//  Le canal réel existe déjà et couvre les quatre cibles : la table
//  `notifications`, alimentée par les déclencheurs `notify_on_announcement` et
//  `notify_on_message`, synchronisée par PowerSync, lue par la cloche de
//  l'en-tête. Elle a une propriété que le push n'a pas : elle arrive AUSSI
//  quand le poste était éteint ou hors ligne au moment de l'événement, parce
//  qu'elle est stockée et non diffusée.
//
//  ── CE QUE CE GARDE TIENT ─────────────────────────────────────────────────
//  1. Aucune dépendance Firebase ne revient dans le projet.
//  2. `profiles.fcm_token` a quitté le schéma local — donc plus aucun poste
//     n'envoie cette colonne. C'est le préalable au DROP (migration 0146) :
//     un client qui écrirait vers une colonne disparue produirait un 42703,
//     que `_fatalResponseCodes` ne traite PAS comme fatal — le connecteur
//     rejouerait le lot indéfiniment et la synchro du poste serait bloquée.
//  3. Les sync-rules ne projettent toujours pas le jeton : tant que la colonne
//     existe en base, un `SELECT *` sur `profiles` distribuerait à chaque
//     poste de l'école la clé d'appareil de tous ses collègues.
//  4. Le personnel scolaire lit ses notifications EN LOCAL. Router la cloche
//     sur Supabase la rendrait vide dès la première coupure de réseau.
// ════════════════════════════════════════════════════════════════════════════

const _kRegles = '../powersync/config/sync-rules.yaml';
const _kSchema = 'lib/services/powersync/powersync_schema.dart';
const _kPubspec = 'pubspec.yaml';
const _kProvider =
    'lib/features/communication/providers/notifications_provider.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync();
}

/// Toutes les lignes non commentées d'un fichier YAML/Dart.
Iterable<String> _lignesActives(String source) => source
    .split('\n')
    .map((l) => l.trim())
    .where((l) => !l.startsWith('#') && !l.startsWith('//'));

void main() {
  group("Firebase n'entre pas dans le projet", () {
    test('aucune dépendance Firebase dans pubspec.yaml', () {
      for (final l in _lignesActives(_lire(_kPubspec))) {
        expect(l.toLowerCase().contains('firebase'), isFalse,
            reason: 'Un seul fournisseur : Supabase. Ligne fautive : $l');
      }
    });

    test('aucun import Firebase dans le code', () {
      final fautes = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        for (final l in f.readAsStringSync().split('\n')) {
          if (l.trimLeft().startsWith('import ') &&
              l.toLowerCase().contains('firebase')) {
            fautes.add('${f.path} → ${l.trim()}');
          }
        }
      }
      expect(fautes, isEmpty, reason: fautes.join('\n'));
    });
  });

  group('Le jeton push a quitté les postes', () {
    test('`fcm_token` ne figure plus dans le schéma local', () {
      for (final l in _lignesActives(_lire(_kSchema))) {
        expect(l.contains("Column.text('fcm_token')"), isFalse,
            reason: "Tant qu'un poste déclare cette colonne, il la renvoie "
                'dans ses upserts `profiles` — et le DROP de la migration 0146 '
                'provoquerait alors un 42703 en boucle, synchro bloquée.');
      }
    });

    test("aucun code Dart ne lit ni ne l'écrit", () {
      final fautes = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        for (final l in _lignesActives(f.readAsStringSync())) {
          if (l.contains('fcm_token') || l.contains('fcmToken')) {
            fautes.add('${f.path} → $l');
          }
        }
      }
      expect(fautes, isEmpty,
          reason: "Le jeton n'a plus de producteur : le lire, c'est lire NULL "
              "et bâtir dessus.\n${fautes.join('\n')}");
    });

    test("les sync-rules ne le projettent pas tant qu'il existe en base",
        () {
      final regles = _lire(_kRegles);
      // On isole chaque requête qui lit `profiles`, sans franchir le `SELECT`
      // d'une autre requête — sinon on ramasserait le commentaire d'exclusion,
      // et le garde se déclencherait sur sa propre raison d'être.
      for (final m in RegExp(r'SELECT((?:(?!SELECT)[\s\S])*?)FROM profiles')
          .allMatches(regles)) {
        expect(m.group(1)!.contains('fcm_token'), isFalse,
            reason: 'Une sync-rule projette `fcm_token` : chaque poste de '
                "l'école recevrait la clé d'appareil de tous ses collègues.");
      }
      expect(RegExp(r'SELECT\s+\*\s+FROM profiles').hasMatch(regles), isFalse,
          reason: '`SELECT *` embarquerait `fcm_token` sans que personne ne '
              "l'ait décidé. La liste explicite est le garde-fou.");
    });
  });

  group('La cloche est le canal, et elle fonctionne hors ligne', () {
    test('`notifications` est bien une table synchronisée', () {
      expect(_lire(_kSchema).contains("Table('notifications'"), isTrue,
          reason: 'Sans synchronisation, la cloche serait vide dès la '
              "première coupure — c'est-à-dire la plupart du temps.");
    });

    test('le personnel scolaire lit en local, pas chez Supabase', () {
      final src = _lire(_kProvider);
      expect(src.contains('if (ctx.isSchool) return _notificationsOffline(ref)'),
          isTrue,
          reason: 'Le chemin école doit court-circuiter Supabase AVANT toute '
              'requête en ligne.');
      // Le `SELECT` local doit être scopé au destinataire : la table descend
      // déjà filtrée, mais un poste partagé enchaîne plusieurs agents.
      expect(src.contains('FROM notifications WHERE recipient_id = ?'), isTrue,
          reason: "Sur un poste partagé, l'agent suivant verrait la cloche du "
              'précédent.');
    });
  });
}
