import 'dart:io';

import 'package:epilote/core/utils/politique_mot_de_passe.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ecran_reglages_source.dart';
import 'ecran_utilisateurs_source.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE CASE QUI NE FAIT RIEN EST PIRE QU'UNE CASE ABSENTE
//
//  ── CE QUI A ÉTÉ TROUVÉ (2026-09-05) ──────────────────────────────────────
//  L'onglet « Sécurité » des paramètres du groupe proposait SIX réglages :
//  longueur minimale du mot de passe, mot de passe robuste, double
//  authentification, sessions multiples, expiration de session, verrouillage
//  après échecs. Les six s'enregistraient dans `group_settings.security` — et
//  AUCUN code Dart, AUCUNE fonction en base ne les lisait. Vérifié des deux
//  côtés : `grep` sur `lib/`, et `pg_proc.prosrc` sur la base de production.
//
//  Pendant ce temps, les trois endroits qui posent un mot de passe exigeaient
//  six ou huit caractères, en dur, sans jamais regarder le réglage du groupe.
//
//  La pire des six était la double authentification : un administrateur de
//  ministère pouvait l'activer et croire ses comptes protégés par un second
//  facteur qui n'existe nulle part dans le produit.
//
//  ── CE QUE CE FICHIER GARDE ───────────────────────────────────────────────
//  Que les deux règles de mot de passe restent APPLIQUÉES aux trois portes, et
//  que les quatre autres ne reviennent pas sous forme de cases décoratives.
// ════════════════════════════════════════════════════════════════════════════

const _politique = 'lib/core/utils/politique_mot_de_passe.dart';
const _changement = 'lib/core/widgets/password_change_dialog.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

String _sansCommentaires(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('La règle refuse ce qu’elle annonce', () {
    const stricte = PolitiqueMotDePasse(longueurMinimale: 8, exigeRobuste: true);

    test('un mot de passe vide est refusé', () {
      expect(stricte.refus(''), 'Mot de passe requis');
      expect(stricte.refus(null), 'Mot de passe requis');
    });

    test('trop court : on dit COMBIEN il en faut', () {
      // « Mot de passe invalide » n'apprend rien et fait essayer au hasard.
      expect(stricte.refus('Ab1!'), contains('8'));
    });

    test('on nomme ce qui manque, pas « format incorrect »', () {
      expect(stricte.refus('motdepasse1!'), contains('majuscule'));
      expect(stricte.refus('Motdepasse!!'), contains('chiffre'));
      expect(stricte.refus('Motdepasse12'), contains('caractère spécial'));
    });

    test('un mot de passe conforme passe', () {
      expect(stricte.refus('Mabiala2026!'), isNull);
    });

    test('les accents comptent comme des majuscules, pas comme du spécial', () {
      // Un clavier congolais tape « É » sans effort : le refuser comme
      // majuscule obligerait à contourner la règle.
      expect(stricte.refus('École2026!'), isNull);
      expect(stricte.refus('Eleve2026e'), contains('caractère spécial'));
    });

    test('sans exigence de robustesse, seule la longueur compte', () {
      const souple =
          PolitiqueMotDePasse(longueurMinimale: 6, exigeRobuste: false);
      expect(souple.refus('abcdef'), isNull);
      expect(souple.refus('abcde'), contains('6'));
    });

    test('le défaut est plus strict que le « six caractères » d’avant', () {
      expect(PolitiqueMotDePasse.parDefaut.longueurMinimale, 8);
      expect(PolitiqueMotDePasse.parDefaut.exigeRobuste, isTrue);
      expect(PolitiqueMotDePasse.parDefaut.refus('secret'), isNotNull);
    });

    test('l’exigence s’annonce avant la faute', () {
      // Découvrir la règle en se faisant refuser trois fois pousse au mot de
      // passe le plus court qui passe.
      expect(stricte.exigence, contains('8'));
      expect(stricte.exigence, contains('majuscule'));
      const souple =
          PolitiqueMotDePasse(longueurMinimale: 6, exigeRobuste: false);
      expect(souple.exigence, isNot(contains('majuscule')));
    });
  });

  group('Les trois portes appliquent la même règle', () {
    test('création d’un compte et réinitialisation par l’administrateur', () {
      final src = _sansCommentaires(sourceEcranUtilisateurs());
      expect('politiqueMotDePasseProvider'.allMatches(src).length,
          greaterThanOrEqualTo(4),
          reason: 'Chaque champ doit lire la politique pour valider ET pour '
              'annoncer l’exigence.');
      expect(src.contains('if (v.length < 6)'), isFalse,
          reason: 'Six caractères en dur ignorent le réglage du groupe.');
    });

    test('changement de son propre mot de passe', () {
      final src = _sansCommentaires(_lire(_changement));
      expect(src.contains('politiqueMotDePasseProvider'), isTrue);
      expect(src.contains('_pwd.text.length < 8'), isFalse,
          reason: 'Huit caractères en dur ignorent le réglage du groupe.');
      expect(src.contains("Text('8 caractères minimum'"), isFalse,
          reason: 'Le texte affiché doit suivre la politique réelle.');
    });

    test('la règle dit ce qu’elle n’est pas', () {
      // Elle couvre les portes du produit, pas l'API : le jour où cela compte,
      // la même règle devra vivre dans les deux RPC.
      final src = _lire(_politique);
      expect(src.contains('create_school_user'), isTrue);
      expect(src.contains('set_school_user_password'), isTrue);
    });
  });

  group('Les quatre cases mortes ne reviennent pas', () {
    test('plus aucun réglage non appliqué dans l’écran', () {
      final src = _sansCommentaires(sourceEcranReglages());
      for (final mort in [
        'require2fa',
        'allowMultipleSessions',
        'sessionTimeoutMinutes',
        'lockAfterFailedAttempts',
      ]) {
        expect(src.contains(mort), isFalse,
            reason: '« $mort » est de retour à l’écran alors que rien ne '
                'l’applique — ni Dart, ni la base.');
      }
    });

    test('l’écran dit ce que la plateforme protège vraiment', () {
      final src = _sansCommentaires(sourceEcranReglages());
      expect(src.contains('_ProtectionsReelles'), isTrue);
      expect(src.contains('absente: true'), isTrue,
          reason: 'L’absence de second facteur doit être DITE : sans cela, '
              'elle se lit comme un oubli d’affichage.');
    });

    test('les deux règles vivantes restent réglables', () {
      final src = _sansCommentaires(sourceEcranReglages());
      expect(src.contains('minPasswordLength'), isTrue);
      expect(src.contains('requireStrongPassword'), isTrue,
          reason: 'Ces deux-là s’appliquent : elles doivent rester offertes.');
    });
  });
}
