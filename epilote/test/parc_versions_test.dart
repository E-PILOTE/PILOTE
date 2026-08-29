import 'dart:io';

import 'package:epilote/features/super_admin/providers/parc_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RELEVÉ DU PARC
//
//  ── CE QU'IL SERT À EMPÊCHER ───────────────────────────────────────────────
//  La migration 0146 supprime une colonne que les postes en retard envoient
//  encore. PostgREST répond alors 42703, que `_fatalResponseCodes` ne traite
//  PAS comme fatal : le connecteur rejoue le lot indéfiniment. Ce poste cesse
//  d'envoyer quoi que ce soit, pour toujours, sans un mot à l'écran.
//
//  Ce relevé existe pour dire NON tant qu'on n'est pas sûr. Un garde qui dirait
//  « probablement oui » serait pire que pas de garde : il donnerait à la
//  supposition l'autorité d'une mesure.
//
//  ── LE PIÈGE QUE CES TESTS TIENNENT ────────────────────────────────────────
//  Les builds antérieurs au relevé NE SAVENT PAS se signaler. Le jour de sa
//  mise en service, la table est vide — et un calcul naïf (« 0 en retard sur 0
//  connus = 100 % ») annoncerait une couverture parfaite alors qu'on ne sait
//  RIEN de personne. C'est exactement l'erreur qui déclencherait 0146.
// ════════════════════════════════════════════════════════════════════════════

CouvertureParc c({
  int aJour = 0,
  int enRetard = 0,
  int jamaisSignale = 0,
  int? total,
  int? plusAncien,
  int seuil = kBuildSansFirebase,
}) =>
    CouvertureParc(
      aJour: aJour,
      enRetard: enRetard,
      jamaisSignale: jamaisSignale,
      totalProfils: total ?? (aJour + enRetard + jamaisSignale),
      plusAncien: plusAncien,
      seuil: seuil,
    );

void main() {
  group('La certitude se refuse au moindre doute', () {
    test('tout le monde a signalé, tout le monde est à jour → OUI', () {
      expect(c(aJour: 344).certitude, isTrue);
    });

    test('un seul poste en retard → NON', () {
      expect(c(aJour: 343, enRetard: 1).certitude, isFalse);
    });

    test('un seul poste muet → NON, même si tous les autres sont à jour', () {
      expect(c(aJour: 343, jamaisSignale: 1).certitude, isFalse,
          reason: 'Un poste qui n’a rien dit tourne peut-être sur une version '
              'antérieure au relevé — précisément celle qui casse.');
    });

    test('⚠️ LE JOUR DE LA MISE EN SERVICE : table vide → NON', () {
      // 344 profils, aucun signalement. Un calcul naïf dirait « 0 en retard,
      // donc 100 % à jour ». C'est l'erreur qui déclencherait 0146.
      final vide = c(jamaisSignale: 344);
      expect(vide.certitude, isFalse);
      expect(vide.connus, 0);
      expect(vide.partConnue, 0);
    });

    test('une plateforme sans aucun profil ne déclare pas la victoire', () {
      expect(c(total: 0).certitude, isFalse,
          reason: '« Aucun poste en retard » sur zéro poste n’est pas une '
              'garantie, c’est une absence de population.');
    });
  });

  group('Les chiffres se recomposent, personne n’est perdu', () {
    test('à jour + en retard + muets = total', () {
      final x = c(aJour: 300, enRetard: 12, jamaisSignale: 32);
      expect(x.totalProfils, 344);
      expect(x.aJour + x.enRetard + x.jamaisSignale, x.totalProfils);
    });

    test('« connus » ne compte QUE ceux qui ont parlé', () {
      final x = c(aJour: 300, enRetard: 12, jamaisSignale: 32);
      expect(x.connus, 312);
    });

    test('la part connue est un taux de CONNAISSANCE, pas de mise à jour', () {
      final x = c(aJour: 100, enRetard: 200, jamaisSignale: 44);
      expect(x.partConnue, closeTo(87.2, 0.1),
          reason: 'Deux tiers du parc sont en retard, et pourtant on en '
              'connaît 87 % : ce sont deux questions différentes, et les '
              'confondre ferait lire un échec comme un succès.');
    });

    test('aucun profil : pas de division par zéro', () {
      expect(c(total: 0).partConnue, 0);
    });
  });

  group('Le seuil est celui que le parc peut atteindre', () {
    test('c’est le build 24, ni 21 ni 23', () {
      expect(kBuildSansFirebase, 24,
          reason: 'Les colonnes ont quitté le schéma local au build 21, mais '
              '21, 22 et 23 n’ont JAMAIS été distribués — le parc passe de 20 '
              'à 24. Et 24 est aussi le premier build qui sait se signaler : '
              'aucun poste antérieur ne peut apparaître dans la table.');
    });
  });

  group('Le serveur décide du périmètre, jamais le client', () {
    test('la RPC ne reçoit ni profil, ni groupe, ni école', () {
      final src = File(
        'lib/features/updates/providers/update_provider.dart',
      ).readAsStringSync();
      final i = src.indexOf("rpc('signaler_version'");
      expect(i, greaterThan(-1));
      final appel = src.substring(i, src.indexOf('}', i));
      for (final interdit in [
        'profile_id',
        'group_id',
        'school_id',
        'auth.uid',
      ]) {
        expect(appel.contains(interdit), isFalse,
            reason: 'Le client enverrait « $interdit » : il pourrait alors '
                'écrire pour autrui, ou mentir sur son périmètre. Ces valeurs '
                'se dérivent de la session, côté serveur.');
      }
      expect(appel.contains('p_version'), isTrue);
      expect(appel.contains('p_build'), isTrue);
      expect(appel.contains('p_platform'), isTrue);
    });

    test('le signalement n’est pas attendu et ne peut pas casser la '
        'vérification de mise à jour', () {
      final src = File(
        'lib/features/updates/providers/update_provider.dart',
      ).readAsStringSync();
      expect(src.contains('unawaited(_signalerVersion('), isTrue,
          reason: 'Attendre le relevé retarderait d’un aller-retour la seule '
              'chose qui compte : savoir qu’un correctif existe.');
      final i = src.indexOf('Future<void> _signalerVersion');
      expect(src.substring(i).contains('catch (_)'), isTrue,
          reason: 'Un relevé d’exploitation ne justifie jamais d’empêcher '
              'quelqu’un de travailler.');
    });
  });

  group('La table reste hors de PowerSync', () {
    test('`app_installations` n’est ni dans le schéma local ni dans les '
        'sync-rules', () {
      final schema = File(
        'lib/services/powersync/powersync_schema.dart',
      ).readAsStringSync();
      final regles = File('../powersync/config/sync-rules.yaml').readAsStringSync();
      expect(schema.contains('app_installations'), isFalse,
          reason: 'Ce n’est pas une donnée de travail : personne ne la lit '
              'hors ligne, et elle n’a rien à faire dans les buckets d’une '
              'école.');
      expect(regles.contains('app_installations'), isFalse);
    });
  });
}
