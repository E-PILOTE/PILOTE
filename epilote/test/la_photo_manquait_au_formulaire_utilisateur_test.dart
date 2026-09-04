import 'dart:io';
import 'dart:typed_data';

import 'package:epilote/features/admin_groupe/screens/users/champ_photo_agent.dart';
import 'package:epilote/features/profil/services/mon_avatar_service.dart'
    show dossierPhoto;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE FORMULAIRE UTILISATEUR NE DEMANDAIT PAS LE VISAGE
//
//  ── CE QUI MANQUAIT (2026-09-05) ──────────────────────────────────────────
//  L'espace admin_groupe crée le personnel des écoles. C'était le SEUL
//  formulaire du produit qui crée une personne sans jamais demander sa photo :
//  les élèves l'ont (inscriptions et fiche élève), la fiche agent de l'espace
//  école l'a, l'écran des administrateurs de plateforme l'avait.
//
//  `avatar_url` n'est pourtant pas un ornement : elle est lue par l'annuaire,
//  la messagerie, le fil d'annonces — et par l'ÉCRAN-VERROU des postes
//  partagés, où l'agent choisit son visage dans une grille avant de travailler.
//  Sans photo, cette grille est une liste d'initiales.
//
//  Et la fonction qui sert l'annuaire du groupe, `get_group_users`, rendait
//  vingt-six colonnes — jusqu'au motif de départ — mais pas celle-là : même la
//  photo DÉJÀ posée par ailleurs restait invisible dans cet espace.
// ════════════════════════════════════════════════════════════════════════════

const _migration =
    '../database/migrations/0193_AVANT_LE_BUILD_lannuaire_du_groupe_ignorait_les_visages.sql';
const _service = 'lib/features/admin_groupe/services/photo_utilisateur_service.dart';
const _provider = 'lib/features/admin_groupe/providers/admin_users_provider.dart';
const _ecran = 'lib/features/admin_groupe/screens/admin_users_screen.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Le code SANS ses commentaires : les en-têtes de ce projet citent les formes
/// interdites pour les expliquer.
String _sansCommentaires(String source) => source
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('--');
    })
    .join('\n');

void main() {
  group('L’annuaire du groupe rend enfin le visage', () {
    test('get_group_users renvoie avatar_url', () {
      final sql = _sansCommentaires(_lire(_migration));
      expect(sql.contains('avatar_url text'), isTrue,
          reason: 'Sans la colonne de retour, la liste et le formulaire ne '
              'peuvent pas voir la photo qui existe en base.');
      expect(sql.contains('p.avatar_url::text'), isTrue);
    });

    test('la garde d’accès est reconduite À L’IDENTIQUE', () {
      // C'est la ligne qui empêche un administrateur de groupe de lire
      // l'annuaire d'un autre client. Un DROP/CREATE qui l'oublierait ouvrirait
      // l'annuaire de tous les clients à tous les clients.
      final sql = _sansCommentaires(_lire(_migration));
      expect(
          sql.contains(
              'is_super_admin() OR (is_admin_groupe() AND p_group_id = auth_group_id())'),
          isTrue);
      expect(sql.contains("RAISE EXCEPTION 'Accès refusé"), isTrue);
    });

    test('les administrateurs restent hors de l’annuaire du personnel', () {
      final sql = _sansCommentaires(_lire(_migration));
      expect(sql.contains("p.role NOT IN ('super_admin', 'admin_groupe')"),
          isTrue);
    });

    test('le droit d’exécution est reposé après le DROP', () {
      final sql = _sansCommentaires(_lire(_migration));
      expect(sql.contains('DROP FUNCTION IF EXISTS public.get_group_users'),
          isTrue);
      expect(
          sql.contains(
              'GRANT EXECUTE ON FUNCTION public.get_group_users(uuid) TO authenticated'),
          isTrue,
          reason: 'Un DROP emporte les droits : sans ce GRANT, l’espace du '
              'groupe perd son annuaire.');
    });
  });

  group('Rien ne part avant la validation du formulaire', () {
    test('l’écran choisit la photo, il ne l’envoie pas', () {
      // À la création, l'identifiant de la personne n'existe pas encore : il
      // n'y a aucun chemin de stockage à calculer. Et un formulaire abandonné
      // ne doit pas laisser de fichier orphelin dans le seau.
      final src = _sansCommentaires(_lire(_ecran));
      expect(src.contains('choisirPhotoPersonne'), isTrue,
          reason: 'Webcam ou fichier — la même porte que les autres écrans.');
      expect(src.contains('queueAvatarUpload'), isFalse);
      expect(src.contains('envoyerPhotoAgent'), isFalse,
          reason: 'L’envoi appartient au service, après l’écriture du compte.');
    });

    test('l’envoi vient après la création, jamais avant', () {
      final src = _sansCommentaires(_lire(_provider));
      final rpc = src.indexOf("rpc('create_school_user'");
      final envoi = src.indexOf('envoyerPhotoAgent(');
      expect(rpc, greaterThan(-1));
      expect(envoi, greaterThan(rpc),
          reason: 'Le chemin de stockage porte l’identifiant de la personne : '
              'il n’existe pas avant l’appel.');
    });
  });

  group('Le compte vaut plus que la photo', () {
    test('un envoi raté ne fait pas passer la création pour un échec', () {
      final src = _sansCommentaires(_lire(_provider));
      expect(src.contains('PhotoNonPosee'), isTrue);

      final ecran = _sansCommentaires(_lire(_ecran));
      expect(ecran.contains('on PhotoNonPosee catch'), isTrue,
          reason: 'Sinon l’administrateur resoumet le formulaire et se heurte '
              'à « adresse déjà utilisée » sans comprendre.');
    });

    test('en modification, une photo qui ne part pas n’écrit rien', () {
      // Là, rien n'est encore enregistré : on peut refuser franchement plutôt
      // que de laisser la fiche à moitié écrite.
      final src = _sansCommentaires(_lire(_provider));
      final envoi = src.indexOf('nouvelleUrl = await envoyerPhotoAgent(');
      final ecriture = src.indexOf("await client.from('profiles').update({");
      expect(envoi, greaterThan(-1));
      expect(ecriture, greaterThan(envoi));
    });
  });

  group('Trois états de photo, et les confondre efface des visages', () {
    test('la colonne n’est écrite que si l’on a voulu la changer', () {
      final src = _sansCommentaires(_lire(_provider));
      expect(
          src.contains(
              "if (nouvelleUrl != null || retirerPhoto) 'avatar_url': nouvelleUrl,"),
          isTrue,
          reason: 'Écrire la colonne à chaque enregistrement effacerait la '
              'photo de quiconque modifie son numéro de téléphone.');
    });
  });

  group('Le personnel se range avec le personnel', () {
    test('dossier « staff », jamais « admins »', () {
      expect(dossierPhoto(estPersonnel: true), 'staff');
      expect(dossierPhoto(estPersonnel: false), 'admins');
      final src = _sansCommentaires(_lire(_service));
      expect(src.contains('dossierPhoto(estPersonnel: true)'), isTrue);
    });
  });

  group('L’annuaire affiche les visages, plus des initiales', () {
    test('les trois pastilles passent par le widget partagé', () {
      final src = _sansCommentaires(_lire(_ecran));
      expect(src.contains('u.initials'), isFalse,
          reason: 'Une pastille d’initiales au-dessus d’une photo existante '
              'donne à croire qu’aucune photo n’a été déposée.');
      expect('PhotoAvatar('.allMatches(src).length, 3);
    });
  });

  group('Le champ photo dit la vérité avant tout envoi', () {
    final octets = Uint8List.fromList(_pngMinimal);

    Future<void> montrer(
      WidgetTester tester, {
      Uint8List? choisis,
      String? url,
      bool retiree = false,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChampPhotoAgent(
            nom: 'Alphonse Mabiala',
            octets: choisis,
            urlExistante: url,
            retiree: retiree,
            actif: true,
            onChoisir: () {},
            onRetirer: () {},
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('rien de choisi → initiales et « Ajouter une photo »',
        (tester) async {
      await montrer(tester);
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('Ajouter une photo'), findsOneWidget);
      expect(find.text('Retirer'), findsNothing,
          reason: 'Retirer quoi ?');
    });

    testWidgets('une photo choisie s’affiche AVANT tout envoi', (tester) async {
      // Sur une connexion congolaise, un écran qui ne montre rien après le clic
      // fait recliquer — et l'on choisit trois fois le même fichier.
      await montrer(tester, choisis: octets);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('AM'), findsNothing);
      expect(find.text('Changer'), findsOneWidget);
      expect(find.text('Retirer'), findsOneWidget);
    });

    testWidgets('un retrait demandé passe devant la photo enregistrée',
        (tester) async {
      // Sinon la photo reste affichée jusqu'à l'enregistrement, et l'on
      // reclique sur « Retirer » en croyant que rien ne s'est passé.
      await montrer(tester,
          url: 'https://exemple.test/photo.jpg', retiree: true);
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('Ajouter une photo'), findsOneWidget);
      expect(find.text('Retirer'), findsNothing);
    });

    testWidgets('ce qu’on vient de choisir passe devant l’enregistré',
        (tester) async {
      await montrer(tester,
          choisis: octets, url: 'https://exemple.test/photo.jpg');
      expect(find.byType(Image), findsOneWidget);
    });
  });
}

/// Le plus petit PNG valide (1×1, transparent) — de quoi faire rendre
/// `Image.memory` sans dépendre d'un fichier sur le disque.
const List<int> _pngMinimal = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];
