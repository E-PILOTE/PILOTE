import 'dart:io';

import 'package:epilote/features/auth/providers/active_agent_provider.dart';
import 'package:epilote/features/profil/providers/mon_code_pin_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHANGER SON CODE PIN — ce que l'écran doit continuer de garantir
//
//  ── CE QUI MANQUAIT (2026-09-04) ──────────────────────────────────────────
//  Le code PIN se posait à l'enrôlement, sur l'écran-verrou, et ne se changeait
//  plus JAMAIS. C'est pourtant le secret le plus exposé du produit : quatre
//  chiffres composés devant un guichet, sur une machine partagée. Le mot de
//  passe, lui, avait sa carte depuis toujours.
//
//  ── LES DEUX RÉGRESSIONS QUE CE FICHIER ATTEND ────────────────────────────
//  1. « Puisqu'on est déjà déverrouillé, pourquoi redemander l'ancien code ? »
//     Parce qu'un poste partagé reste ouvert entre deux services : sans cette
//     vérification, il suffit de passer derrière un collègue pour lui poser un
//     code qu'il ignore — on ne lui vole rien, on le met dehors de sa propre
//     machine, et il n'a plus de recours avant le retour du réseau.
//  2. « Cette boîte de dialogue n'a pas besoin du compteur d'échecs. »
//     Si, exactement : sinon elle devient le chemin doux pour essayer les dix
//     mille combinaisons que l'écran-verrou refuse.
// ════════════════════════════════════════════════════════════════════════════

const _dialogue =
    'lib/features/profil/widgets/changer_code_pin_dialog.dart';
const _carte = 'lib/features/profil/widgets/profil_code_pin.dart';
const _etat = 'lib/features/profil/providers/mon_code_pin_provider.dart';
const _pad = 'lib/features/auth/screens/widgets/agent_pin_pad.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Le code SANS ses commentaires : les en-têtes de ce projet citent justement
/// les formes interdites pour les expliquer. Une sonde qui lirait les
/// commentaires se croirait satisfaite par une explication.
String _sansCommentaires(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('L’ancien code est exigé', () {
    test('le dialogue vérifie le code actuel avant d’en poser un nouveau', () {
      final src = _sansCommentaires(_lire(_dialogue));
      expect(src.contains('verifyPin(widget.profilId, _actuel.text)'), isTrue,
          reason: 'Sans vérification, on verrouille un collègue hors de sa '
              'propre machine.');

      final verif = src.indexOf('verifyPin(');
      final pose = src.indexOf('setPin(');
      expect(verif, greaterThan(-1));
      expect(pose, greaterThan(verif),
          reason: 'Le nouveau code serait posé AVANT que l’ancien soit vérifié.');
    });

    test('l’exigence tombe uniquement quand il n’y a rien à vérifier', () {
      // Premier code sur ce poste, ou code invalidé par un reset serveur : il
      // n'existe pas d'ancien code à opposer. Toute autre exemption serait un
      // contournement.
      final src = _sansCommentaires(_lire(_dialogue));
      expect(src.contains('if (!widget.aPoser) {'), isTrue,
          reason: 'La seule porte de sortie doit rester « aucun code posé ».');
    });

    test('un nouveau code identique à l’ancien est refusé', () {
      final src = _sansCommentaires(_lire(_dialogue));
      expect(src.contains('nouveau == _actuel.text'), isTrue,
          reason: 'Se croire protégé sans que rien n’ait changé est pire que '
              'ne pas avoir agi.');
    });
  });

  group('La pause anti-force-brute est celle de l’écran-verrou', () {
    test('le dialogue compte les échecs et relit la pause en cours', () {
      final src = _sansCommentaires(_lire(_dialogue));
      expect(src.contains('recordFail(widget.profilId)'), isTrue,
          reason: 'Un échec non compté ouvre dix mille essais gratuits.');
      expect(src.contains('lockedUntil(widget.profilId)'), isTrue,
          reason: 'La pause posée par l’écran-verrou doit s’appliquer ici.');
    });

    test('la validation refuse de partir pendant la pause', () {
      final src = _sansCommentaires(_lire(_dialogue));
      expect(src.contains('if (_envoi || _enPause) return;'), isTrue,
          reason: 'Une pause affichée mais non appliquée ne protège de rien.');
    });
  });

  group('Une seule longueur de code dans tout le produit', () {
    test('le dialogue et l’écran-verrou lisent la même constante', () {
      expect(_sansCommentaires(_lire(_dialogue)).contains('kAgentPinLength'),
          isTrue);
      expect(_sansCommentaires(_lire(_pad)).contains('kAgentPinLength'), isTrue,
          reason: 'Deux longueurs séparées finiraient par se contredire : un '
              'code posé ici que l’écran-verrou refuse de reconnaître.');
      expect(kAgentPinLength, 4);
    });
  });

  group('Qui a le droit de changer ce code', () {
    test('la carte ne se refuse PAS à l’agent qui n’est pas le compte du poste',
        () {
      // C'est l'asymétrie du fichier : mot de passe et fermeture des sessions
      // sont refusés quand la session appartient à quelqu'un d'autre ; le code
      // PIN est ouvert exactement dans ce cas-là, puisqu'il appartient à
      // l'agent au clavier. Le gater reviendrait à réserver le changement de
      // code à la direction, qui a enrôlé l'appareil.
      final src = _sansCommentaires(_lire(_carte));
      expect(src.contains('estLeCompteAppareil'), isFalse,
          reason: 'Le code PIN n’est pas le mot de passe du compte.');
      expect(src.contains('peutModifierSaFiche'), isFalse,
          reason: 'Cette garde protège la synchro, pas un secret local.');
    });

    test('la carte ne s’affiche qu’aux rôles que le verrou concerne', () {
      final src = _sansCommentaires(_lire(_etat));
      expect(src.contains('agentLockApplies(cible.role)'), isTrue,
          reason: 'Proposer un code à un super_admin ou à un parent ajoute une '
              'case à remplir, pas de la sécurité.');
      expect(agentLockApplies('super_admin'), isFalse);
      expect(agentLockApplies('admin_groupe'), isFalse);
      expect(agentLockApplies('parent'), isFalse);
      expect(agentLockApplies('secretaire'), isTrue);
    });

    test('un reset demandé par un administrateur invalide le code local', () {
      final src = _sansCommentaires(_lire(_etat));
      expect(src.contains('pinResetInvalidates('), isTrue,
          reason: 'Sinon l’agent compose un code que l’écran-verrou refuse '
              'sans lui dire pourquoi.');
      final avant = DateTime(2026, 9, 1);
      final apres = DateTime(2026, 9, 4);
      expect(pinResetInvalidates(apres, avant), isTrue);
      expect(pinResetInvalidates(avant, apres), isFalse);
    });

    test('l’annonce du reset dépend d’un code réellement posé ici', () {
      // Annoncer « votre ancien code ne fonctionne plus » à qui n'en a jamais
      // posé sur ce poste lui ferait chercher un code qu'il n'a jamais eu.
      final src = _sansCommentaires(_lire(_etat));
      expect(src.contains('existe && pinResetInvalidates('), isTrue);

      const jamaisPose = EtatCodePin(sApplique: true);
      expect(jamaisPose.resetDemande, isFalse);
      expect(jamaisPose.aPoser, isTrue,
          reason: 'Sans code local, il y a bien un code à POSER.');
    });
  });

  group('L’écran dit que le code ne vaut que sur ce poste', () {
    test('la portée locale est écrite, pas sous-entendue', () {
      // Un code qui se propagerait devrait passer par le réseau — et le verrou
      // cesserait de fonctionner le jour où le réseau manque, c'est-à-dire
      // celui où l'on en a besoin. La conséquence surprend : elle se dit.
      final visible =
          _sansCommentaires(_lire(_dialogue)) + _sansCommentaires(_lire(_carte));
      expect(visible.contains('CE poste'), isTrue,
          reason: 'Sans cette phrase, on croit avoir changé son code partout.');
    });
  });

  group('Le service porte réellement le changement', () {
    const svc = AgentPinService();
    const moi = 'agent-au-clavier';

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('poser, vérifier, changer : l’ancien code ne rouvre plus rien',
        () async {
      await svc.setPin(moi, '1234');
      expect(await svc.verifyPin(moi, '1234'), isTrue);

      // Le geste exact du dialogue : on vérifie l'ancien, puis on pose l'autre.
      expect(await svc.verifyPin(moi, '1234'), isTrue);
      await svc.setPin(moi, '5678');

      expect(await svc.verifyPin(moi, '5678'), isTrue);
      expect(await svc.verifyPin(moi, '1234'), isFalse,
          reason: 'Un ancien code encore valable rendrait le changement vain.');
    });

    test('un changement réussi efface les échecs et la pause', () async {
      await svc.setPin(moi, '1234');
      for (var i = 0; i < 6; i++) {
        await svc.recordFail(moi);
      }
      expect(await svc.lockedUntil(moi), isNotNull);

      await svc.setPin(moi, '5678');
      expect(await svc.failCount(moi), 0);
      expect(await svc.lockedUntil(moi), isNull,
          reason: 'Rester en pause après avoir prouvé qui l’on est punirait '
              'l’agent légitime.');
    });

    test('le code d’un collègue n’est pas touché', () async {
      await svc.setPin('moi', '1234');
      await svc.setPin('elle', '4321');
      await svc.setPin('moi', '5678');
      expect(await svc.verifyPin('elle', '4321'), isTrue);
    });
  });
}
