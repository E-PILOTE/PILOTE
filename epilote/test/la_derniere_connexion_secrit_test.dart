import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN CHAMP QUI A L'AIR D'ÊTRE UNE INFORMATION
//
//  ── CE QUI A ÉTÉ VU À L'ÉCRAN (2026-09-04) ────────────────────────────────
//  La page « Mon profil » affichait « Dernière connexion : Jamais » pour un
//  compte ouvert deux heures plus tôt. Relevé en base : **345 profils, ZÉRO
//  `last_login` renseigné**, alors que 13 comptes avaient déjà ouvert une
//  session. La colonne était lue à QUATRE endroits et écrite nulle part.
//
//  Le panneau « Connexions récentes » des paramètres admin_groupe était donc
//  vide depuis toujours — et se lisait comme « personne ne s'est connecté ».
//
//  ── CE QUE CES SONDES GARDENT ─────────────────────────────────────────────
//   1. Que la valeur vienne de `auth.users.last_sign_in_at`, la seule source
//      qui la connaisse, et non d'une écriture applicative à chaque connexion
//      (le personnel scolaire n'écrit jamais en direct vers Supabase).
//   2. Que le déclencheur ne puisse JAMAIS faire échouer une connexion.
//   3. Qu'aucun écran ne se remette à écrire `last_login` lui-même : deux
//      sources pour une date, ce sont deux dates.
// ════════════════════════════════════════════════════════════════════════════

const _mig =
    '../database/migrations/0192_AVANT_LE_BUILD_la_derniere_connexion_ne_sest_jamais_ecrite.sql';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Le SQL SANS ses commentaires : l'en-tête décrit le défaut avec les mêmes
/// mots que le correctif — une sonde naïve s'y piégerait.
String _sql() => _lire(_mig)
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('--'))
    .join('\n');

List<File> _dartsSous(String chemin) => Directory(chemin)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  group('La dernière connexion vient de la seule source qui la connaisse', () {
    test('le déclencheur suit `auth.users.last_sign_in_at`', () {
      final sql = _sql();
      expect(
          sql.contains('AFTER UPDATE OF last_sign_in_at ON auth.users'), isTrue,
          reason: 'La date ne se reflète plus depuis l’authentification : '
              'l’écran redira « Jamais ».');
      expect(sql.contains('set last_login = new.last_sign_in_at'), isTrue);
    });

    test('⚠️ il ne peut PAS faire échouer une connexion', () {
      // Il est posé sur `auth.users`. Une exception ici, et c'est tout le parc
      // qui ne peut plus se connecter — pour une date d'affichage.
      final sql = _sql();
      final i = sql.indexOf('update public.profiles');
      expect(i, greaterThan(0));
      final apres = sql.substring(i);
      expect(apres.contains('exception when others then'), isTrue,
          reason: 'L’écriture n’est plus protégée : une erreur sur `profiles` '
              'ferait échouer la connexion elle-même.');
      expect(apres.indexOf('exception when others then') < apres.indexOf('return new'),
          isTrue);
    });

    test('les connexions déjà survenues sont rattrapées', () {
      // Sans ce rattrapage, treize personnes qui se connectent depuis des mois
      // liraient « Jamais » jusqu'à leur prochaine session.
      final sql = _sql();
      expect(sql.contains('UPDATE public.profiles p'), isTrue);
      expect(sql.contains('FROM auth.users u'), isTrue);
    });

    test('la fonction n’est pas exposée à la clé publique', () {
      final sql = _sql();
      expect(
          RegExp(r'REVOKE EXECUTE ON FUNCTION public\.suivre_derniere_connexion'
                  r'\(\)\s*\n?\s*FROM PUBLIC, anon, authenticated')
              .hasMatch(sql),
          isTrue);
    });
  });

  group('Et rien d’autre ne l’écrit', () {
    test('⚠️ aucun écran ne pose `last_login` lui-même', () {
      // Deux sources pour une date, ce sont deux dates. Le personnel écrit en
      // local (PowerSync) : une écriture de plus partirait dans la file de
      // synchro à chaque démarrage, sans rien apporter.
      final fautes = <String>[];
      for (final f in _dartsSous('lib')) {
        final src = f.readAsStringSync().replaceAll('\r\n', '\n');
        final code = src
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        if (RegExp(r"'last_login'\s*:").hasMatch(code) ||
            RegExp(r'set\s+last_login\s*=', caseSensitive: false)
                .hasMatch(code)) {
          fautes.add(f.path);
        }
      }
      expect(fautes, isEmpty,
          reason: 'Un écran écrit de nouveau `last_login` : la base le fait '
              'déjà depuis `auth.users`.\n\n${fautes.join('\n')}');
    });
  });
}
