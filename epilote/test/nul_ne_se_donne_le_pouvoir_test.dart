import 'dart:io';

import 'package:epilote/features/admin_groupe/providers/admin_users_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ACCÈS AU RANG DE SUPER_ADMIN — deux escalades mesurées, deux verrous
//
//  ── CE QUI A ÉTÉ TROUVÉ (2026-09-04) ──────────────────────────────────────
//  Les huit comptes `admin_groupe` — l'administrateur de CHAQUE client, dont
//  les deux ministères — pouvaient, par un simple appel PostgREST :
//    • `update profiles set role = 'super_admin' where id = <soi>` ;
//    • `update profiles set group_id = <un autre client> where id = <soi>`.
//  Les deux ont été exécutés en transaction ANNULÉE sur la base de production :
//  `is_super_admin()` répondait `true`, et l'admin du METP se retrouvait admin
//  du MEPSA.
//
//  ── POURQUOI CE FICHIER EXISTE ────────────────────────────────────────────
//  Le correctif (0188) vit en base, pas dans Dart : aucun test d'application
//  ne peut le rejouer. Ce que ces sondes gardent, c'est ce qui a rendu la
//  faille possible — l'idée qu'un administrateur de groupe « administre son
//  groupe », sa propre ligne comprise. Le jour où quelqu'un simplifiera la
//  garde en revenant à ce raisonnement, ces tests tombent.
//
//  ⚠️ ET SURTOUT : la liste des rôles de l'écran (`kStaffRoles`) est devenue
//  une RÈGLE DE SÉCURITÉ. La base refuse désormais ce qu'elle ne contient pas.
//  Ajouter `admin_groupe` à ce menu rouvrirait la porte côté serveur — le test
//  le dit à celui qui l'ajouterait.
// ════════════════════════════════════════════════════════════════════════════

const _garde =
    '../database/migrations/0188_AVANT_LE_BUILD_nul_ne_se_donne_le_pouvoir.sql';
const _revoke =
    '../database/migrations/0189_AVANT_LE_BUILD_trois_fonctions_ouvertes_a_tous.sql';
const _profilPerso =
    'lib/features/admin_groupe/providers/admin_profile_provider.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync();
}

void main() {
  group('Nul ne se donne le pouvoir', () {
    test('la garde s’applique à SA PROPRE ligne avant tout le reste', () {
      // Le trou était exactement là : le déclencheur rendait la main dès que
      // l'auteur était admin de groupe et la ligne dans son groupe. Sa propre
      // ligne est dans son groupe.
      final sql = _lire(_garde);
      expect(sql.contains('IF NEW.id = v_moi THEN'), isTrue,
          reason: 'Plus de branche « c’est moi » : l’auto-promotion revient.');
      final soi = sql.substring(sql.indexOf('IF NEW.id = v_moi THEN'));
      for (final colonne in [
        'NEW.role',
        'NEW.group_id',
        'NEW.school_id',
        'NEW.is_active',
        'NEW.access_profile_id',
      ]) {
        expect(soi.contains('$colonne              := OLD') ||
            soi.contains('$colonne := OLD') ||
            soi.contains('$colonne          := OLD') ||
            soi.contains('$colonne         := OLD') ||
            soi.contains('$colonne := OLD.'),
            isTrue,
            reason: '$colonne n’est plus figée sur sa propre ligne.');
      }
    });

    test('⚠️ même un super_admin ne se rétrograde pas', () {
      // Il n'y a QU'UN super_admin en base. Une rétrogradation accidentelle
      // ferme la plateforme à tout le monde, sans recours dans l'application.
      final sql = _lire(_garde);
      final avantSuper = sql.indexOf('IF NEW.id = v_moi THEN');
      final branchePlateforme = sql.indexOf('IF v_super THEN');
      expect(avantSuper, greaterThan(0));
      expect(branchePlateforme, greaterThan(avantSuper),
          reason: 'La branche super_admin passe AVANT le gel de sa propre '
              'ligne : le seul super_admin peut de nouveau se rétrograder.');
    });

    test('attribuer super_admin LÈVE, au lieu de geler en silence', () {
      // Toutes les autres violations sont des maladresses possibles ; celle-ci
      // n'en est pas une. Elle doit laisser une trace et échouer bruyamment.
      final sql = _lire(_garde);
      expect(sql.contains("NEW.role = 'super_admin'::user_role"), isTrue);
      expect(sql.contains('RAISE EXCEPTION'), isTrue);
      expect(sql.contains("ERRCODE = '42501'"), isTrue);
    });

    test('la règle vaut aussi à l’INSERT', () {
      // La politique RLS `profiles_insert` laisse un admin de groupe insérer
      // dans son groupe : sans garde à l'insertion, la porte se rouvre par
      // l'autre bout.
      final sql = _lire(_garde);
      expect(sql.contains('BEFORE INSERT OR UPDATE ON public.profiles'), isTrue);
      expect(sql.contains("TG_OP = 'INSERT'"), isTrue);
    });

    test('un admin de groupe ne déplace personne hors de son groupe', () {
      final sql = _lire(_garde);
      final branche = sql.substring(sql.indexOf('v_admin_groupe'));
      expect(branche.contains('NEW.group_id := OLD.group_id'), isTrue,
          reason: 'Un client peut de nouveau transférer un compte chez un '
              'autre client.');
    });
  });

  group('⚠️ Le menu de l’écran est devenu une règle de sécurité', () {
    test('kStaffRoles ne contient ni admin_groupe ni super_admin', () {
      // `roles_administrables_par_groupe()` en base est le miroir de cette
      // liste. Y ajouter un rôle d'administration le rendrait attribuable par
      // un client à lui-même.
      final valeurs = kStaffRoles.map((r) => r.value).toSet();
      expect(valeurs.contains('admin_groupe'), isFalse);
      expect(valeurs.contains('super_admin'), isFalse);
    });

    test('les neuf rôles de l’écran sont ceux que la base accepte', () {
      // La base compose : roles_provisionnables_par_ecole() + directeur +
      // proviseur. Si l'écran gagne un rôle que la base ignore, l'utilisateur
      // enregistre et rien ne change — le pire des retours.
      final sql = _lire(_garde);
      expect(sql.contains('roles_provisionnables_par_ecole()'), isTrue);
      expect(sql.contains("ARRAY['directeur', 'proviseur']::user_role[]"),
          isTrue);
      expect(kStaffRoles.length, 9);
      expect(kStaffRoles.map((r) => r.value),
          containsAll(['directeur', 'proviseur', 'enseignant']));
    });
  });

  group('« Mon profil » n’écrit aucune colonne de pouvoir', () {
    test('il ne touche que le nom et le téléphone', () {
      // C'est ce qui rend le gel de sa propre ligne indolore. Le jour où cet
      // écran voudra écrire autre chose, il faudra passer par une RPC.
      final src = _lire(_profilPerso);
      for (final interdit in [
        "'role'",
        "'group_id'",
        "'school_id'",
        "'is_active'",
        "'access_profile_id'",
      ]) {
        expect(src.contains(interdit), isFalse,
            reason: '« Mon profil » écrit $interdit : la garde 0188 le gèlera '
                'en silence, et l’écran mentira sur ce qu’il a enregistré.');
      }
    });
  });

  group('Trois fonctions qui écrivaient sans demander qui appelle', () {
    test('elles ne sont plus exposées à la clé publique', () {
      // `anon`, c'est la clé écrite en clair dans l'installateur : sans
      // compte, sans mot de passe.
      final sql = _lire(_revoke);
      for (final f in [
        'liberer_charge_agent',
        'emit_subscription_reminders',
        'next_license_version',
      ]) {
        expect(sql.contains('REVOKE EXECUTE ON FUNCTION public.$f'), isTrue,
            reason: '$f est de nouveau appelable par n’importe qui.');
      }
      expect('FROM PUBLIC, anon, authenticated;'.allMatches(sql).length, 3);
    });

    test('aucune n’est appelée par l’application', () {
      // C'est ce qui rend la révocation sans risque : elles servent en interne
      // (muter/radier) ou en service_role (Edge Function license-issuer).
      final lib = Directory('lib');
      final coupables = <String>[];
      for (final f in lib.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final s = f.readAsStringSync();
        for (final nom in [
          'liberer_charge_agent',
          'emit_subscription_reminders',
          'next_license_version',
        ]) {
          if (s.contains("rpc('$nom'")) coupables.add('${f.path} → $nom');
        }
      }
      expect(coupables, isEmpty,
          reason: 'Un écran appelle une fonction dont le droit vient d’être '
              'retiré : il échouera en « permission denied ».');
    });
  });
}
