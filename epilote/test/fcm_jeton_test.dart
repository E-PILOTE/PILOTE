import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE JETON PUSH NE VOYAGE PAS (2026-08-28)
//
//  ── L'ÉTAT MESURÉ DE FCM ──────────────────────────────────────────────────
//  Le cahier des charges, règle n°3, promet : « Directeur valide avant
//  publication → notification push FCM ». La validation EST appliquée depuis le
//  2026-08-27. La notification push, elle, n'existe pas :
//
//    • `firebase_core` / `firebase_messaging` sont COMMENTÉS dans pubspec.yaml ;
//    • `profiles.fcm_token` : 0 jeton sur 344 profils ;
//    • `notifications.fcm_message_id` : 0 sur 121 notifications.
//
//  ⚠️ Et le fait que personne n'avait relevé : sur ces 344 profils, il y a
//  ZÉRO parent et ZÉRO élève. Le rôle existe dans l'enum, `/user/espace-parent`
//  est un écran « bientôt disponible », et la plateforme compte 2 tuteurs en
//  tout. Les familles que la règle veut prévenir n'ont pas de compte : FCM
//  n'est pas la pièce manquante, l'espace famille l'est.
//
//  ── CE QUI RESTE VRAI QUAND FCM ARRIVERA ──────────────────────────────────
//  Un jeton push est une CLÉ D'APPAREIL : qui l'a peut faire sonner le
//  téléphone de son collègue. Les sync-rules l'excluent donc explicitement de
//  la projection `directory` — SEULE colonne de `profiles` à en être retirée,
//  et le commentaire du fichier le dit : « jeton push, seule donnée vraiment
//  sensible ».
//
//  Ce test verrouille cette exclusion. Le jour où quelqu'un remplacera la
//  longue liste de colonnes par un `SELECT *` — geste naturel, et qui a déjà
//  été tenté ailleurs — chaque appareil de l'école recevrait le jeton de tous
//  ses collègues.
// ════════════════════════════════════════════════════════════════════════════

const _kRegles = '../powersync/config/sync-rules.yaml';
const _kSchema = 'lib/services/powersync/powersync_schema.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync();
}

void main() {
  group('Le jeton push ne descend sur aucun appareil', () {
    final regles = _lire(_kRegles);

    test('aucune projection de `profiles` ne le contient', () {
      // On isole chaque requête qui lit `profiles`, sans franchir le `SELECT`
      // d'une autre requête — sinon on ramasserait tout le fichier, commentaire
      // d'exclusion compris, et le garde se déclencherait sur sa propre raison
      // d'être.
      for (final m in RegExp(r'SELECT((?:(?!SELECT)[\s\S])*?)FROM profiles')
          .allMatches(regles)) {
        final colonnes = m.group(1)!;
        expect(colonnes.contains('fcm_token'), isFalse,
            reason: 'Une sync-rule projette `fcm_token` : chaque appareil de '
                'l\'école recevrait le jeton push de tous ses collègues.\n'
                'Requête : SELECT${colonnes.trim()} FROM profiles');
      }
    });

    test('aucun `SELECT *` sur `profiles`', () {
      // Le raccourci qui ferait tout basculer d'un coup.
      expect(RegExp(r'SELECT\s+\*\s+FROM profiles').hasMatch(regles), isFalse,
          reason: '`SELECT *` embarquerait `fcm_token` sans que personne ne '
              'l\'ait décidé. La liste explicite est le garde-fou.');
    });

    test('la raison de l\'exclusion est écrite dans les règles', () {
      expect(regles.contains('fcm_token'), isTrue,
          reason: 'Le fichier doit NOMMER la colonne exclue, sinon la '
              'prochaine personne qui rallonge la liste l\'ajoutera sans y '
              'penser.');
      expect(regles.contains('jeton push'), isTrue);
    });
  });

  group('Le schéma local dit pourquoi la colonne y est', () {
    final schema = _lire(_kSchema);

    test('`fcm_token` est déclarée en écriture seule, et le dit', () {
      expect(schema.contains("Column.text('fcm_token')"), isTrue,
          reason: 'Elle doit exister localement pour que l\'appareil écrive LE '
              'SIEN et le fasse remonter.');
      expect(schema.contains('ÉCRITURE SEULE'), isTrue,
          reason: 'Sans cette note, un développeur lisant le seul Dart croit '
              'la colonne synchronisée et bâtit une fonctionnalité qui lira '
              'toujours NULL.');
    });
  });
}
