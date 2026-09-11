import 'dart:io';

import 'package:epilote/core/services/fiche_detail_pdf.dart';
import 'package:epilote/core/widgets/fiche_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FICHE DE DÉTAIL TIENT LA CHARGE — et s'imprime
//
//  ── CE QUE CE FICHIER GARDE ───────────────────────────────────────────────
//  « Ça va se remplir demain, il y a quinze départements, beaucoup de choses
//    vont y arriver. Donc prépare tout afin que ça soit flexible. »
//
//  Une promesse de souplesse ne se vérifie pas à l'œil sur douze lignes : elle
//  se vérifie sur trois cents, et seulement là. Ces tests construisent donc
//  des fiches DE TAILLE RÉELLE et vérifient les trois choses qui cassent en
//  premier :
//   1. l'écran ne construit pas la liste entière (sinon l'ouverture rame et
//      finit par jeter) ;
//   2. rien n'est tronqué en silence ;
//   3. le PDF SORT — une section trop longue fait boucler `MultiPage` jusqu'à
//      `TooManyPagesException`, c'est-à-dire aucun document du tout, le jour
//      précis où le réseau devient intéressant.
// ════════════════════════════════════════════════════════════════════════════

FicheDetail _ficheDe(int n, {void Function(BuildContext)? onTap}) => FicheDetail(
      titre: 'Établissements couverts',
      sousTitre: 'Réseau supervisé',
      icone: Icons.school_rounded,
      couleur: const Color(0xFF1E3A5F),
      total: '$n',
      totalLabel: 'Établissements',
      nomFichier: 'Test_Fiche',
      chiffres: const [('départements', '15')],
      sections: [
        SectionFiche(
          titre: 'Par établissement',
          enTetes: const ['Établissement', 'Classes', 'Élèves'],
          flex: const [5, 2, 2],
          lignes: [
            for (var i = 0; i < n; i++)
              LigneFiche(
                titre: 'École numéro $i',
                sousTitre: 'Département ${i % 15}',
                colonnes: ['${i % 30}'],
                valeur: '${1000 - i}',
                onTap: onTap,
              ),
          ],
          note: 'Total : $n établissement(s).',
        ),
      ],
      notes: const ['Effectifs agrégés.'],
    );

Future<void> _ouvrir(WidgetTester tester, FicheDetail f) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => ouvrirFicheDetail(ctx, f),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  // `OfficialPdfKit.loadFonts()` lit les polices embarquées via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Le modèle', () {
    test('le filtre réduit les lignes ET se dit', () {
      // ⚠️ `filtre` non vide ⇒ le PDF portera l'avertissement « vue filtrée ».
      // Une liste partielle qui ne s'annonce pas est le plus court chemin vers
      // un chiffre faux dans un état ministériel.
      final f = _ficheDe(300);
      expect(f.nbLignes, 300);
      expect(f.filtre, isEmpty);

      final vue = f.filtree('numéro 42');
      expect(vue.filtre, 'numéro 42');
      expect(vue.nbLignes, 1);
      // La fiche d'origine n'est pas touchée : on imprime une VUE, on ne
      // détruit pas la source.
      expect(f.nbLignes, 300);
    });

    test('la recherche porte aussi sur les colonnes et le sous-titre', () {
      final f = _ficheDe(60);
      expect(f.filtree('Département 3').nbLignes, 4);
    });

    test('un en-tête oublié se répare au lieu de faire échouer le document',
        () {
      // `OfficialPdfKit.table` lève dès que headers et rows divergent. Un
      // oubli d'en-tête ne doit PAS coûter le document entier : un intitulé
      // générique vaut mieux qu'un PDF qui n'existe pas.
      const s = SectionFiche(
        titre: 'Sans en-têtes',
        lignes: [
          LigneFiche(titre: 'A', valeur: '1', colonnes: ['x', 'y']),
        ],
      );
      expect(s.enTetesEffectifs.length, 4);
      expect(s.flexEffectif.length, 4);
    });
  });

  group('L’écran', () {
    testWidgets('300 lignes : la liste est virtualisée, rien n’est tronqué',
        (tester) async {
      final f = _ficheDe(300);
      await _ouvrir(tester, f);

      // Le haut de la liste est là…
      expect(find.text('École numéro 0'), findsOneWidget);
      // …et le bas ne l'est PAS : c'est la preuve que `ListView.builder` ne
      // construit que le visible. Si ce test tombe parce que la 250e ligne
      // existe, la modale reconstruit tout — et une école de plus est une
      // école de plus à construire avant le premier pixel.
      expect(find.text('École numéro 250'), findsNothing);

      // Le compte annoncé, lui, porte bien sur la TOTALITÉ.
      expect(find.textContaining('300 lignes'), findsOneWidget);
    });

    testWidgets('la recherche filtre, et le pied annonce l’impression filtrée',
        (tester) async {
      await _ouvrir(tester, _ficheDe(300));
      await tester.enterText(find.byType(TextField), 'numéro 137');
      await tester.pumpAndSettle();

      expect(find.text('École numéro 137'), findsOneWidget);
      expect(find.text('École numéro 0'), findsNothing);
      expect(find.textContaining('1 sur 300'), findsOneWidget);
      expect(find.textContaining('l’impression suivra ce filtre'),
          findsOneWidget);
    });

    testWidgets('sous le seuil, pas de champ de recherche', (tester) async {
      // Un champ de recherche sur six lignes est du bruit.
      await _ouvrir(tester, _ficheDe(6));
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('une ligne cliquable descend d’un cran', (tester) async {
      var ouvertures = 0;
      await _ouvrir(tester, _ficheDe(20, onTap: (_) => ouvertures++));
      // La première ligne : dans une fenêtre de test de 600 px de haut, la
      // liste n'en construit que quelques-unes — c'est précisément ce que le
      // test précédent vérifie.
      await tester.tap(find.text('École numéro 0'));
      await tester.pumpAndSettle();
      expect(ouvertures, 1);
    });

    testWidgets('chaque fiche porte son bouton d’impression', (tester) async {
      await _ouvrir(tester, _ficheDe(20));
      expect(find.widgetWithText(OutlinedButton, 'Imprimer'), findsOneWidget);
    });
  });

  group('Le document', () {
    test('300 lignes s’impriment vraiment — et le fichier s’ouvre', () async {
      // ⚠️ LE test qui compte. Sans `tableSection`, cette taille ne produit
      // PAS un document tronqué : elle ne produit aucun document.
      final octets = await FicheDetailPdf.build(_ficheDe(300));
      expect(String.fromCharCodes(octets.take(4)), '%PDF');
      expect(octets.length, greaterThan(4000));

      final dossier = Directory('build/apercu')..createSync(recursive: true);
      final f = File('${dossier.path}/fiche_detail_300_lignes.pdf')
        ..writeAsBytesSync(octets);
      // ignore: avoid_print
      print('Fiche écrite : ${f.absolute.path} (${octets.length} octets)');
    });

    test('un document filtré porte l’avertissement', () async {
      final octets = await FicheDetailPdf.build(_ficheDe(300).filtree('42'));
      expect(String.fromCharCodes(octets.take(4)), '%PDF');
      // Le texte est compressé dans le flux : on vérifie la source du widget,
      // pas les octets — la sonde de contenu vit dans le test de source.
      expect(octets.length, greaterThan(2000));
    });

    test('une fiche vide sort quand même un document', () async {
      // Un réseau qui n'a encore rien ne doit pas casser l'impression : c'est
      // l'état du premier jour de chaque nouveau ministère.
      const vide = FicheDetail(
        titre: 'Rien',
        icone: Icons.info_outline,
        couleur: Color(0xFF1E3A5F),
        total: '0',
        totalLabel: 'Établissements',
        nomFichier: 'Vide',
        sections: [
          SectionFiche(titre: 'Par établissement', lignes: []),
        ],
      );
      final octets = await FicheDetailPdf.build(vide);
      expect(String.fromCharCodes(octets.take(4)), '%PDF');
    });
  });
}
