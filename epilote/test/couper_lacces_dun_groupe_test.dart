import 'dart:io';

import 'package:epilote/features/admin_groupe/providers/acces_groupe_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  COUPER L'ACCÈS D'UN GROUPE — le levier, et ses limites
//
//  ── LA DÉCISION ───────────────────────────────────────────────────────────
//  J'avais objecté qu'une licence suspendue ne devait couper personne (C4 du
//  0160). Le fondateur a maintenu : « je voudrais quand même un moyen
//  d'annuler une licence et d'empêcher le ministère d'accéder à la plateforme,
//  au cas où les modalités de paiement ne seraient pas respectées ». Sa
//  décision, et elle se défend — sans levier, un marché de quarante millions
//  ne se recouvre qu'au tribunal.
//
//  ── ⚠️ CE QUE CE FICHIER GARDE, ET QUI N'EST PAS ÉVIDENT ──────────────────
//  Le levier existe, mais il reste SÉPARÉ du cycle de vie de la licence. Si
//  quelqu'un les relie un jour — par simplicité, de bonne foi — chaque
//  suspension comptable deviendrait une coupure d'État, et plus personne
//  n'oserait suspendre quoi que ce soit. Deux gestes, deux décisions : c'est
//  ce qui rend le second utilisable.
//
//  Et il ne coupe QUE le ministère. Couper un enseignant de Kinkala parce
//  qu'un mandat ministériel traîne au Trésor punirait une école pour la dette
//  d'une autre administration.
// ════════════════════════════════════════════════════════════════════════════

const _migration =
    '../database/migrations/0187_AVANT_LE_BUILD_couper_lacces_dun_groupe.sql';
const _migrationLicence =
    '../database/migrations/0186_AVANT_LE_BUILD_activer_suspendre_une_licence.sql';
const _shell = 'lib/core/widgets/app_shell.dart';
const _page = 'lib/core/widgets/acces_suspendu_page.dart';
const _detail =
    'lib/features/super_admin/screens/economie/licence_detail.dart';
const _provider =
    'lib/features/super_admin/providers/economie_provider.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('Le levier est réel, côté serveur', () {
    test('il passe par le point de contrôle UNIQUE de la tutelle', () {
      // ⚠️ `auth_peut_superviser()` commande les quatre RPC qui portent tout
      // ce qu'une licence achète : la vue sur le réseau, ses écoles, ses
      // destinataires et l'envoi de circulaires. Une seule fonction à
      // modifier, et rien à oublier ailleurs.
      final sql = _lire(_migration);
      expect(
          sql.contains(
              'CREATE OR REPLACE FUNCTION public.auth_peut_superviser'),
          isTrue,
          reason: 'La coupure ne passe plus par le point de contrôle : elle '
              'devient purement décorative côté serveur.');
      expect(sql.contains('AND NOT COALESCE('), isTrue);
      expect(sql.contains('g.acces_suspendu'), isTrue);
    });

    test('couper exige un motif, rétablir n’exige rien', () {
      // ⚠️ L'asymétrie est délibérée : on ne met JAMAIS de friction sur le
      // geste qui rouvre. Le risque d'un accès rétabli trop vite est nul ;
      // celui d'un accès qui reste fermé faute d'avoir su remplir un champ ne
      // l'est pas.
      final sql = _lire(_migration);
      final couper = sql.substring(sql.indexOf('suspendre_acces_groupe'),
          sql.indexOf('retablir_acces_groupe'));
      final retablir = sql.substring(sql.indexOf('retablir_acces_groupe'));
      expect(couper.contains('Motif obligatoire'), isTrue);
      expect(retablir.contains('Motif obligatoire'), isFalse);
    });

    test('les deux gestes sont réservés à la plateforme', () {
      final sql = _lire(_migration);
      expect('IF NOT is_super_admin() THEN'.allMatches(sql).length, 2);
      expect(sql.contains('REVOKE ALL ON FUNCTION'), isTrue);
    });
  });

  group('⚠️ Le levier reste SÉPARÉ de la licence', () {
    test('changer un statut de licence ne touche pas l’accès', () {
      // Le jour où quelqu'un ajoute cet UPDATE, ce test tombe — et c'est le
      // but. Une suspension comptable ne doit jamais fermer un ministère.
      final sql = _lire(_migrationLicence);
      final corps = sql.substring(sql.indexOf('licence_changer_statut'));
      expect(corps.contains('acces_suspendu'), isFalse,
          reason: 'Le statut de la licence commande maintenant l’accès : '
              'chaque suspension comptable devient une coupure d’État.');
    });

    test('couper l’accès ne touche pas la licence', () {
      // La réciproque : couper pour impayé ne doit pas résilier le marché.
      // Le marché survit à la coupure, sinon on ne peut plus le recouvrer.
      final sql = _lire(_migration);
      expect(sql.contains('UPDATE public.tutelle_licences'), isFalse);
      expect(sql.contains('licence_statut'), isFalse);
    });

    test('l’écran le dit avant de couper', () {
      final src = _lire(_detail);
      expect(
          src.contains('Ces gestes ne touchent PAS l’accès du ministère'),
          isTrue);
      expect(src.contains('Couper l’accès du ministère'), isTrue);
    });
  });

  group('Ce que la coupure ne touche pas', () {
    test('les écoles du réseau gardent leur accès', () {
      // Elles appartiennent à d'AUTRES groupes, qui ont payé, eux.
      final sql = _lire(_migration);
      // ⚠️ Deux apostrophes DANS la chaîne cherchée : le fichier est du SQL,
      // où `''` est l'échappement d'une apostrophe. La sonde doit chercher le
      // texte tel qu'il est ÉCRIT, pas tel qu'il se lira.
      expect(sql.contains("N''affecte ni les ecoles du reseau"), isTrue);
      expect(_lire(_page).contains('Vos établissements continuent de travailler'),
          isTrue);
    });

    test('rien n’est effacé', () {
      final sql = _lire(_migration);
      expect(sql.contains('DELETE FROM'), isFalse,
          reason: 'La coupure efface des données : ce n’est plus une porte '
              'fermée, c’est une destruction.');
      expect(_lire(_page).contains('Vos données sont intactes'), isTrue);
    });

    test('seul l’admin du groupe voit la page de blocage', () {
      final src = _lire(_shell);
      expect(src.contains('profile?.role == AppConstants.roleAdminGroupe'),
          isTrue);
      expect(src.contains('AccesSuspenduPage(acces: accesCoupe)'), isTrue);
    });
  });

  group('⚠️ Fail-soft dans le bon sens', () {
    test('l’état inconnu laisse l’accès OUVERT', () {
      // Se tromper dans ce sens laisse travailler un groupe qui aurait dû être
      // bloqué le temps d'un incident réseau. Se tromper dans l'autre ferme le
      // ministère de l'Éducation nationale parce qu'une requête a expiré — et
      // personne, ce jour-là, ne saura pourquoi. La vraie serrure est de toute
      // façon côté serveur.
      expect(AccesGroupe.ouvert.suspendu, isFalse);
      expect(AccesGroupe.ouvert.motif, isNull);
      final src = _lire('lib/features/admin_groupe/providers/'
          'acces_groupe_provider.dart');
      expect(src.contains('return AccesGroupe.ouvert;'), isTrue);
      expect(src.contains('} catch (_) {'), isTrue,
          reason: 'Une erreur de lecture ne retombe plus sur « ouvert » : un '
              'incident réseau peut fermer un ministère.');
    });

    test('la page de blocage DIT le motif et la sortie', () {
      // Une porte fermée sans explication est un appel téléphonique garanti —
      // et, avec un ministère, une réunion.
      final src = _lire(_page);
      expect(src.contains('acces.motif'), isTrue);
      expect(src.contains('Comment rétablir'), isTrue);
      expect(src.contains('Vérifier à nouveau'), isTrue);
    });
  });

  group('Le geste est branché côté fondateur', () {
    test('l’écran appelle les deux RPC, jamais un update direct', () {
      final src = _lire(_provider);
      expect(src.contains("rpc('suspendre_acces_groupe'"), isTrue);
      expect(src.contains("rpc('retablir_acces_groupe'"), isTrue);
    });

    test('la coupure se voit dans la liste sans ouvrir la fiche', () {
      // C'est le seul état qui doit sauter aux yeux : un ministère coupé ne
      // doit pas se découvrir en cliquant.
      final src =
          _lire('lib/features/super_admin/screens/economie_screen.dart');
      expect(src.contains('if (l.accesSuspendu)'), isTrue);
    });
  });
}
