import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « MON PROFIL » — UNE PAGE, TROIS ESPACES, ET RIEN DE DÉCORATIF
//
//  ── CE QUI EXISTAIT (2026-09-04) ──────────────────────────────────────────
//  Trois écrans « Mon profil » qui avaient divergé :
//   • super_admin  — 742 lignes. Sa carte « Sécurité » affichait trois états
//     qui étaient des CONSTANTES dans le widget, dont « Alertes de connexion
//     par e-mail : activé » alors que rien, nulle part, n'envoie d'alerte. Et
//     un champ « Mot de passe actuel » que le code de changement ne LISAIT
//     JAMAIS : la garde était un décor.
//   • admin_groupe — 267 lignes : prénom, nom, téléphone.
//   • personnel    — le plus complet, et le seul offline-first.
//  Aucun des trois ne permettait de déposer sa PHOTO, alors que `avatar_url`
//  s'affiche dans l'annuaire, la messagerie, le fil d'annonces et le sélecteur
//  d'agent : colonne lue partout, écrite nulle part par l'intéressé.
//
//  ── CE QUE CE FICHIER GARDE ───────────────────────────────────────────────
//  Que la page reste UNE, que sa carte Sécurité ne réaffirme pas de protection
//  inexistante, que le mot de passe se change en PROUVANT l'ancien, et que la
//  photo emprunte le chemin qui ne casse pas la synchro.
// ════════════════════════════════════════════════════════════════════════════

const _module = 'lib/features/profil';
const _routeur = 'lib/core/router/app_router.dart';
const _dialogueMdp = 'lib/core/widgets/password_change_dialog.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Le code, SANS ses commentaires.
///
/// ⚠️ Indispensable dans ce dépôt : les en-têtes expliquent longuement le
/// défaut qu'ils corrigent, en le CITANT. Une sonde d'absence naïve se piège
/// alors sur l'explication qui la justifie — c'est arrivé trois fois.
String _sansCommentaires(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

List<File> _pieces() => Directory(_module)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  group('Une seule page pour les trois espaces', () {
    test('les trois routes mènent au même écran', () {
      final src = _lire(_routeur);
      expect('const MonProfilScreen()'.allMatches(src).length, 3,
          reason: 'Un espace a repris un écran de profil à lui : les trois '
              'divergeront de nouveau.');
    });

    test('les trois anciens écrans ont bien disparu', () {
      // Les laisser en place, même non routés, invite à les rouvrir « juste
      // pour ce petit changement ».
      for (final mort in const [
        'lib/features/super_admin/screens/profile_screen.dart',
        'lib/features/admin_groupe/screens/admin_profile_screen.dart',
        'lib/features/user/screens/user_profile_screen.dart',
        'lib/features/admin_groupe/providers/admin_profile_provider.dart',
      ]) {
        expect(File(mort).existsSync(), isFalse,
            reason: '$mort est revenu — la duplication avec.');
      }
    });

    test('chaque pièce du module tient sous 500 lignes', () {
      final trop = <String>[];
      for (final f in _pieces()) {
        final n = _lire(f.path).split('\n').length;
        if (n > 500) trop.add('${f.uri.pathSegments.last} : $n');
      }
      expect(trop, isEmpty);
    });
  });

  group('La carte Sécurité ne dit que ce que l’application FAIT', () {
    test('⚠️ plus aucune protection affirmée en dur', () {
      // Les trois lignes de l'ancienne carte étaient des constantes. La
      // deuxième était fausse : aucune alerte de connexion n'est envoyée.
      for (final f in _pieces()) {
        final code = _sansCommentaires(_lire(f.path));
        for (final mensonge in const [
          'Authentification à deux facteurs',
          'Alertes de connexion',
          'Session sécurisée',
        ]) {
          expect(code.contains(mensonge), isFalse,
              reason: '${f.path} réaffiche « $mensonge » : une page de '
                  'sécurité qui annonce une protection inexistante est pire '
                  'qu’une page vide — on s’y fie.');
        }
      }
    });

    test('le mot de passe et les sessions se refusent sur un poste partagé', () {
      // La session Supabase appartient au compte APPAREIL. Sur un poste où un
      // collègue a pris la main par code PIN, « changer mon mot de passe »
      // changerait celui de quelqu'un d'autre.
      final src = _lire('$_module/screens/profil_securite.dart');
      expect(src.contains('moi.estLeCompteAppareil'), isTrue);
      expect(src.contains('(!estMoi || !enLigne)'), isTrue,
          reason: 'Le bouton n’est plus gardé : il agirait sur le compte d’un '
              'autre, ou échouerait hors ligne sans le dire.');
    });
  });

  group('Changer son mot de passe exige de prouver l’ancien', () {
    test('⚠️ la vérification a lieu AVANT le changement', () {
      // Supabase n'exige pas l'ancien mot de passe pour `updateUser` : c'est à
      // l'application de le demander. Sans cela, un poste laissé déverrouillé
      // une minute suffit à verrouiller le propriétaire dehors.
      final src = _lire(_dialogueMdp);
      final verif = src.indexOf('signInWithPassword(email:');
      final applique = src.indexOf('updateUser(UserAttributes(password:');
      expect(verif, greaterThan(0),
          reason: 'Plus aucune vérification de l’ancien mot de passe.');
      expect(applique, greaterThan(verif),
          reason: 'Le changement est appliqué avant la vérification.');
    });

    test('le champ « actuel » est LU, pas décoré', () {
      // C'est exactement le défaut de l'ancien écran super_admin : le champ
      // existait, le code ne s'en servait pas.
      final src = _lire(_dialogueMdp);
      expect(src.contains('password: _actuel.text'), isTrue);
      expect(src.contains('_actuel.text.isEmpty'), isTrue,
          reason: 'Un champ vide passerait la garde.');
    });
  });

  group('Ma photo emprunte le chemin qui ne casse pas la synchro', () {
    const service = '$_module/services/mon_avatar_service.dart';

    test('⚠️ le personnel DEMANDE, il n’écrit pas la fiche', () {
      // Un `UPDATE profiles` local touchant `avatar_url` revient en 42501 dès
      // que la ligne n'est pas celle du compte appareil — code fatal pour le
      // connecteur : le lot ENTIER est abandonné, notes et paiements compris.
      final src = _lire(service);
      expect(src.contains('deposerDemandePhotoAgent('), isTrue);
      expect(src.contains('profil.isSchoolStaff'), isTrue,
          reason: 'La bifurcation a disparu : les deux espaces écriraient par '
              'le même chemin, et l’un des deux est refusé.');
      expect(_sansCommentaires(src).contains('UPDATE profiles'), isFalse);
    });

    test('les octets partent en file, jamais en direct', () {
      // Sans cela, une école sans réseau ne peut pas déposer de photo — et la
      // reprise « plus tard », au Congo, veut souvent dire jamais.
      final src = _lire(service);
      expect(src.contains('queueAvatarUpload('), isTrue);
      expect(_sansCommentaires(src).contains('uploadBinary('), isFalse);
    });

    test('sans rattachement, la demande est refusée AVANT d’être écrite', () {
      // Une demande sans groupe ni école n'appartient à aucun périmètre : elle
      // ne se synchroniserait pas et dormirait sur le poste sans rien dire.
      final src = _lire(service);
      expect(src.contains('EchecPhotoProfil'), isTrue);
      expect(src.contains('groupe.isEmpty || ecole == null'), isTrue);
    });
  });

  group('La fiche d’un collègue ne s’écrit pas depuis « Mon profil »', () {
    test('⚠️ le formulaire se verrouille, et dit pourquoi', () {
      final src = _lire('$_module/screens/profil_infos.dart');
      expect(src.contains('moi.peutModifierSaFiche'), isTrue,
          reason: 'Le formulaire écrit de nouveau sans garde : la remontée '
              'reviendrait en 42501 et emporterait le lot.');
      expect(src.contains('enabled: actif'), isTrue);
      expect(src.contains('_AvertissementPosteBanalise'), isTrue,
          reason: 'Un champ grisé sans explication passe pour une panne.');
    });

    test('l’e-mail reste en lecture seule, et son rôle est nommé', () {
      // Confondre l'adresse de CONTACT et l'identifiant de session a déjà fait
      // échouer une connexion, sur l'écran des abonnements.
      final src = _lire('$_module/screens/profil_infos.dart');
      expect(src.contains("'Compte de connexion'"), isTrue);
      expect(src.contains('_emailLectureSeule'), isTrue);
    });
  });
}
