import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PUBLIER AU NOM DE L'ÉCOLE EST UN DROIT (2026-08-28)
//
//  Le domaine Communication — 55 fichiers, ~21 800 lignes, le plus gros du
//  produit — vivait entièrement hors du modèle de permissions : aucun module
//  dans `modules`, donc aucun `ModuleScaffold`, aucun `PermissionGate`, aucun
//  `canProvider` nulle part.
//
//  ── LA MOITIÉ QUI GARDAIT DÉJÀ, ET SA LIMITE ──────────────────────────────
//  L'écran n'était pas ouvert à tous : il lisait `AppConstants.directionRoles`
//  = {proviseur, directeur, secretaire}, EN DUR. Une école ne pouvait donc ni
//  confier la publication à quelqu'un d'autre, ni la retirer à un adjoint —
//  seul domaine du produit à décider par le rôle plutôt que par le profil.
//
//  ── LA MOITIÉ QUI NE GARDAIT PAS DU TOUT ──────────────────────────────────
//  La RLS de `announcements` / `events` : `FOR ALL` sur la seule appartenance à
//  l'école. Tout jeton de personnel pouvait publier et supprimer la publication
//  d'un autre, hors de l'écran.
//
//  ── POURQUOI LE GARDE HABITUEL NE MARCHAIT PAS ICI ────────────────────────
//  `canProvider` lit la base LOCALE PowerSync du profil d'accès. `super_admin`
//  et `admin_groupe` ne font pas tourner PowerSync et n'ont pas de profil : il
//  rend TOUJOURS faux pour eux. Or ces écrans sont PARTAGÉS par les trois
//  espaces. Le garde est donc scope-aware : hors école, la route garde déjà.
// ════════════════════════════════════════════════════════════════════════════

const _kDroits = 'lib/features/communication/providers/comm_droits.dart';
const _kAnnonces =
    'lib/features/communication/providers/announcements_provider.dart';
const _kEvents = 'lib/features/communication/providers/events_provider.dart';
const _kFeedA = 'lib/features/communication/screens/announcements_feed.dart';
const _kFeedE = 'lib/features/communication/screens/events_feed.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync();
}

void main() {
  group('Le garde connaît les trois espaces', () {
    test('hors périmètre école, la route garde — pas le profil', () {
      final src = _lire(_kDroits);
      expect(src.contains('if (!ctx.isSchool) return true;'), isTrue,
          reason: '`canProvider` rend toujours faux pour super_admin et '
              'admin_groupe : les garder avec lui leur retirerait la '
              'publication.');
      expect(src.contains('communicationContextProvider'), isTrue);
    });

    test('les trois modules portent leur slug une seule fois', () {
      final src = _lire(_kDroits);
      for (final slug in ['annonces', 'messagerie', 'evenements']) {
        expect(src.contains("'$slug'"), isTrue);
      }
    });
  });

  group('Le garde vit dans l\'écriture, pas seulement dans le bouton', () {
    test('chaque écriture partagée exige son verbe', () {
      // Un écran neuf qui appellerait ces fonctions sans y penser reste gardé.
      // C'est la seule forme de garde qu'on n'oublie pas.
      final ann = _lire(_kAnnonces);
      for (final verbe in ['create', 'update', 'delete']) {
        expect(ann.contains("exigerDroitComm(ref, kSlugAnnonces, '$verbe')"),
            isTrue,
            reason: 'Aucune écriture d\'annonce ne doit passer sans son verbe.');
      }
      final ev = _lire(_kEvents);
      expect(ev.contains("exigerDroitComm(ref, kSlugEvenements, 'delete')"),
          isTrue);
      expect(
          ev.contains(
              "exigerDroitComm(ref, kSlugEvenements, id == null ? 'create' : 'update')"),
          isTrue,
          reason: 'Créer et modifier passent par la MÊME fonction : un profil '
              'doté du seul `update` ne doit pas pouvoir créer.');
    });

    test('le refus dit pourquoi', () {
      // `ErreurMetier` remonte telle quelle à l'écran : la personne apprend
      // qu'elle n'a pas ce droit, au lieu de voir « une erreur inattendue ».
      final src = _lire(_kDroits);
      expect(src.contains('throw ErreurMetier('), isTrue);
      expect(src.contains('Votre profil ne permet pas de publier'), isTrue);
    });
  });

  group('Le droit se lit sur le PROFIL, plus sur le rôle', () {
    test('les deux fils abandonnent `directionRoles`', () {
      for (final chemin in [_kFeedA, _kFeedE]) {
        final src = _lire(chemin);
        expect(src.contains('AppConstants.directionRoles'), isFalse,
            reason: '$chemin décidait par le rôle, en dur : une école ne '
                'pouvait ni déléguer la publication ni la retirer.');
        expect(src.contains('ref.watch(peutPublier'), isTrue);
        expect(src.contains('peutModifier &&'), isTrue,
            reason: 'Modifier la publication d\'autrui suit le même chemin.');
      }
    });
  });

  group('La base bouge AVEC le build, jamais avant', () {
    test('la migration RLS attend explicitement la publication', () {
      final f = File('../database/migrations/'
          '0139_APRES_LE_BUILD_annonces_et_evenements_par_le_verbe.sql');
      expect(f.existsSync(), isTrue,
          reason: 'La moitié base doit être écrite, prête, et datée.');
      final sql = f.readAsStringSync();
      expect(sql.contains('NE PAS APPLIQUER AVANT LA PUBLICATION DU BUILD'),
          isTrue,
          reason: 'Durcir un verbe sans son build produit un 42501 — code '
              'fatal, lot PowerSync entier jeté (DEPLOIEMENT_ORDRE.md).');
      expect(sql.contains('school_id IS NULL'), isTrue,
          reason: 'Les annonces du GROUPE doivent rester lisibles par toutes '
              'ses écoles.');
    });
  });
}
