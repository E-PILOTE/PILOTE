import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/user/screens/rapports_parts.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA CARTE D'UN ÉTAT OFFICIEL
//
//  Elle porte trois promesses, et chacune protège le document qui en sort :
//
//  1. elle DIT CE QU'ELLE EXCLUT avant l'aperçu. Une exclusion apprise après
//     signature tue le document : le lecteur croyait tenir un total.
//  2. elle n'offre pas d'imprimer ce qui n'est pas prêt. Un PDF édité sur des
//     données à moitié chargées ne porte aucune trace de son incomplétude.
//  3. elle remonte l'anomalie AVANT l'impression — après, plus personne ne la
//     cherche.
//
//  Aucun de ces trois points n'est vérifiable par un test d'édition PDF : ils
//  vivent dans l'écran, à l'endroit où l'agent décide.
// ════════════════════════════════════════════════════════════════════════════

Future<void> _pump(
  WidgetTester tester, {
  required bool pret,
  String? alerte,
  VoidCallback? onApercu,
  String messageVide = 'Chargement…',
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: RapportCard(
          icone: Icons.groups_rounded,
          couleur: Colors.blue,
          titre: 'État des effectifs',
          resume: '1 800 élève(s) inscrit(s)',
          contient: const [
            'Effectif par classe, filles et garçons',
            'Sous-total par cycle',
          ],
          exclut: 'Les dossiers en attente de validation.',
          alerte: alerte,
          pret: pret,
          messageVide: messageVide,
          onApercu: onApercu,
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('elle annonce ce que le document contient', (tester) async {
    await _pump(tester, pret: true, onApercu: () {});
    expect(find.text('État des effectifs'), findsOneWidget);
    expect(find.text('Effectif par classe, filles et garçons'), findsOneWidget);
    expect(find.text('Sous-total par cycle'), findsOneWidget);
  });

  testWidgets('elle annonce SURTOUT ce qu\'il exclut', (tester) async {
    // ⚠️ Toujours affiché, jamais conditionnel : c'est la seule occasion de le
    // dire. Le papier signé n'en portera aucune trace.
    await _pump(tester, pret: true, onApercu: () {});
    expect(find.textContaining('Non inclus'), findsOneWidget);
    expect(find.textContaining('en attente de validation'), findsOneWidget);
  });

  group('le bouton d\'aperçu', () {
    testWidgets('déclenche l\'aperçu quand les données sont prêtes',
        (tester) async {
      var ouvert = 0;
      await _pump(tester, pret: true, onApercu: () => ouvert++);
      await tester.tap(find.text('Aperçu'));
      await tester.pump();
      expect(ouvert, 1);
    });

    testWidgets('reste inerte tant que les données ne sont pas prêtes',
        (tester) async {
      // ⚠️ Le cas qui produit un document faux : éditer pendant le chargement.
      // Le PDF sortirait avec un effectif partiel et sans rien qui le signale.
      var ouvert = 0;
      await _pump(tester, pret: false, onApercu: () => ouvert++);
      await tester.tap(find.text('Aperçu'), warnIfMissed: false);
      await tester.pump();
      expect(ouvert, 0);

      final bouton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(bouton.onPressed, isNull, reason: 'le bouton doit être désactivé');
    });

    testWidgets('explique POURQUOI il ne se passe rien', (tester) async {
      // Un bouton grisé sans explication se lit comme une panne.
      await _pump(tester,
          pret: false, messageVide: 'Aucun élève inscrit sur l\'année active.');
      expect(find.text('Aucun élève inscrit sur l\'année active.'),
          findsOneWidget);
    });

    testWidgets('aucun message d\'attente quand tout est prêt', (tester) async {
      await _pump(tester, pret: true, onApercu: () {});
      expect(find.text('Chargement…'), findsNothing);
    });
  });

  group('l\'anomalie', () {
    testWidgets('s\'affiche avant l\'impression, pas après', (tester) async {
      await _pump(tester,
          pret: true,
          onApercu: () {},
          alerte: 'À corriger avant transmission : 12 élèves sans sexe '
              'renseigné.');
      expect(find.textContaining('À corriger avant transmission'),
          findsOneWidget);
    });

    testWidgets('n\'encombre pas la carte quand il n\'y en a pas',
        (tester) async {
      // ⚠️ Un avertissement systématique cesse d'être lu — même règle que la
      // note imprimée sur le document.
      await _pump(tester, pret: true, onApercu: () {});
      expect(find.textContaining('À corriger'), findsNothing);
    });

    testWidgets('n\'empêche PAS d\'éditer le document', (tester) async {
      // L'anomalie se signale, elle ne se substitue pas au jugement de l'agent :
      // un état incomplet reste parfois le seul disponible ce jour-là.
      var ouvert = 0;
      await _pump(tester,
          pret: true, onApercu: () => ouvert++, alerte: 'Une anomalie.');
      await tester.tap(find.text('Aperçu'));
      await tester.pump();
      expect(ouvert, 1);
    });
  });

  testWidgets('la carte tient sur un écran étroit sans déborder',
      (tester) async {
    // Les postes des écoles sont des portables 1366×768, souvent en fenêtre
    // réduite. Un débordement ici masquerait la ligne « Non inclus ».
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pump(tester, pret: true, onApercu: () {}, alerte: 'Une anomalie.');
    expect(tester.takeException(), isNull);
  });
}
