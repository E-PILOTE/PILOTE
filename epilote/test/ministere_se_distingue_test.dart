import 'dart:io';

import 'package:epilote/core/constants/tutelle.dart';
import 'package:epilote/core/widgets/badge_ministere.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN MINISTÈRE NE SE LIT PAS COMME UN GROUPE SCOLAIRE
//
//  ── LE DÉFAUT ─────────────────────────────────────────────────────────────
//  Les deux ministères vivent dans `school_groups` avec les cinq groupes
//  privés — commodité de modèle : eux aussi exploitent des écoles. Mais cette
//  commodité remontait telle quelle à l'écran. Dans la liste, le MEPSA portait
//  la même carte, la même icône et une pastille « MEPSA » de la même forme que
//  « Privé » ou « Premium ». Sa fiche annonçait « Type : Public » — exact, et
//  indiscernable d'une école publique ordinaire. Dans les notifications, une
//  alerte de la tutelle portait une icône « école » et la raison sociale brute
//  enregistrée.
//
//  Or ils diffèrent par NATURE, pas par sigle : un ministère n'a pas de
//  clients, il a un réseau ; il n'est pas agréé, il agrée. Il y en a deux au
//  Congo, et il n'y en aura pas un troisième.
//
//  ── CE QUE CE FICHIER GARDE ───────────────────────────────────────────────
//  Le vocabulaire (déclaré UNE fois — le libellé de la tutelle avait déjà été
//  écrit trois fois avant d'être centralisé), et le fait que les écrans le
//  lisent au lieu de le réécrire.
// ════════════════════════════════════════════════════════════════════════════

const _liste = 'lib/features/super_admin/screens/school_groups_screen.dart';
const _timeline = 'lib/features/communication/widgets/notification_timeline.dart';
const _reglages =
    'lib/features/admin_groupe/screens/admin_settings_screen.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('Le vocabulaire', () {
    test('la nature se dit avant le nom', () {
      expect(natureGroupe(estTutelle: true), 'Ministère de tutelle');
      expect(natureGroupe(estTutelle: false), 'Groupe scolaire');
    });

    test('le nom d’usage remplace la raison sociale enregistrée', () {
      // La base porte « MEPSA — Ministère Enseign. Primaire » d'un côté et
      // « Ministère de l'Enseignement Technique et Professionnel » de l'autre :
      // deux saisies, deux longueurs, aucune cohérence à l'écran.
      expect(nomUsageMinistere('mepsa'), 'Ministère MEPSA');
      expect(nomUsageMinistere('metp'), 'Ministère METP');
    });

    test('hors ministère connu, on n’invente rien', () {
      // « Ministère » tout court désignerait n'importe lequel des deux.
      expect(nomUsageMinistere(null), isNull);
      expect(nomUsageMinistere('mepsaa'), isNull);
    });

    test('un groupe ordinaire garde son nom', () {
      expect(
        nomAffichableGroupe(
            nom: 'Réseau Saint-Pierre', estMinistere: false, tutelle: 'mepsa'),
        'Réseau Saint-Pierre',
      );
      expect(
        nomAffichableGroupe(
            nom: 'MEPSA — Ministère Enseign. Primaire',
            estMinistere: true,
            tutelle: 'mepsa'),
        'Ministère MEPSA',
      );
    });

    test('un ministère sans tutelle lisible garde son nom plutôt que rien', () {
      // Fail-soft : mieux vaut la raison sociale brute qu'une ligne vide.
      expect(
        nomAffichableGroupe(nom: 'X', estMinistere: true, tutelle: null),
        'X',
      );
    });

    test('l’icône d’un ministère n’est pas celle d’un groupe', () {
      // ⚠️ `_typeIcon('public')` rendait déjà `account_balance` : un groupe
      // public ordinaire et un ministère portaient la MÊME icône.
      expect(
          iconeGroupe(
              estMinistere: true, siGroupe: Icons.business_rounded),
          Icons.account_balance_rounded);
      expect(
          iconeGroupe(
              estMinistere: false, siGroupe: Icons.business_rounded),
          Icons.business_rounded);
    });
  });

  group('La pastille', () {
    testWidgets('ne s’affiche PAS sur un groupe ordinaire', (tester) async {
      // C'est un marqueur d'exception : lu sur chaque ligne, il ne dirait plus
      // rien.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BadgeMinistere(estMinistere: false, tutelle: 'mepsa'),
        ),
      ));
      expect(find.textContaining('MINISTÈRE'), findsNothing);
    });

    testWidgets('dit le sigle, pour ne pas confondre les deux', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BadgeMinistere(estMinistere: true, tutelle: 'metp'),
        ),
      ));
      expect(find.text('MINISTÈRE · METP'), findsOneWidget);
    });

    testWidgets('en mode compact, le sigle cède la place', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BadgeMinistere(
              estMinistere: true, tutelle: 'metp', compact: true),
        ),
      ));
      expect(find.text('MINISTÈRE'), findsOneWidget);
    });
  });

  group('Les écrans lisent le vocabulaire', () {
    test('la liste des groupes porte la pastille', () {
      final src = _lire(_liste);
      expect(src.contains('BadgeMinistere('), isTrue,
          reason: 'Le ministère est redevenu un groupe comme les autres dans '
              'la liste.');
      expect(src.contains('natureGroupe(estTutelle:'), isTrue,
          reason: 'La fiche a perdu sa ligne « Nature » : elle annoncerait de '
              'nouveau « Type : Public » en première information.');
    });

    test('le ministère le lit sur SON PROPRE écran', () {
      // ⚠️ VU À L'ÉCRAN, build 3.4.4, compte MEPSA. Sa fiche de groupe
      // annonçait « Public · Institutionnel · Actif · @mepsa » — quatre
      // pastilles exactes, et pas une qui dise qu'on regarde un ministère de
      // tutelle. C'est l'écran de l'intéressé : s'il ne le dit pas là, il ne
      // le dit nulle part.
      final src = _lire(_reglages);
      expect(src.contains('BadgeMinistere('), isTrue,
          reason: 'La fiche du ministère est redevenue celle d’un groupe '
              'public ordinaire.');
      expect(src.contains('natureGroupe(estTutelle: true)'), isTrue,
          reason: 'La ligne « Ministère de tutelle » a disparu sous le nom.');
    });

    test('les notifications distinguent la tutelle', () {
      final src = _lire(_timeline);
      expect(src.contains('groupEstMinistere'), isTrue,
          reason: 'Une alerte de la tutelle se relit comme une alerte de '
              'groupe scolaire : même icône, même graisse.');
      expect(src.contains('nomAffichableGroupe('), isTrue,
          reason: 'La ligne réaffiche la raison sociale brute.');
    });
  });
}
