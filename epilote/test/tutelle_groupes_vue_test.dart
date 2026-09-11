import 'package:epilote/features/tutelle/providers/tutelle_reseau_provider.dart';
import 'package:epilote/features/tutelle/widgets/tutelle_groupes_vue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE LA PAGE MONTRE VRAIMENT — vérifié sur l'arbre de widgets
//
//  ── POURQUOI CE TEST EXISTE ───────────────────────────────────────────────
//  Le défaut corrigé le 2026-09-02 ne se voyait dans AUCUN test : les filtres
//  étaient justes, les bilans étaient justes, les documents se généraient. Ce
//  qui était faux, c'était ce que l'écran AFFICHAIT — un titre promettant « les
//  écoles que vous ne gérez pas » au-dessus d'une carte unique : celle du
//  ministère qui regardait la page. Il a fallu ouvrir l'application pour le
//  voir.
//
//  Ces tests rendent la vue et lisent ce qui s'y trouve. Ils ne remplacent pas
//  un coup d'œil, mais ils attrapent les régressions qu'un coup d'œil attrape.
// ════════════════════════════════════════════════════════════════════════════

TutelleGroupe _groupe({
  required String id,
  required String nom,
  String secteur = 'prive',
  int nbEcoles = 2,
  String? departement = 'Brazzaville',
}) =>
    TutelleGroupe(
      id: id,
      nom: nom,
      secteur: secteur,
      departement: departement,
      nbEcoles: nbEcoles,
      nbEcolesActives: nbEcoles,
      nbEleves: 0,
      nbFilles: 0,
      nbPersonnel: 0,
      nbClasses: 0,
      nbEcolesAgreees: 0,
    );

TutelleEcole _ecole({
  required String id,
  required String groupId,
  String secteur = 'prive',
  int eleves = 120,
}) =>
    TutelleEcole(
      id: id,
      groupId: groupId,
      groupeNom: 'G',
      nom: 'École $id',
      secteur: secteur,
      departement: 'Brazzaville',
      nbEleves: eleves,
      nbFilles: 60,
      nbPersonnel: 10,
      nbClasses: 5,
    );

void main() {
  final groupes = [
    _groupe(id: 'PUB', nom: 'Groupe Scolaire EDEC', secteur: 'public'),
    _groupe(id: 'PRI', nom: 'Réseau Scolaire Saint-Pierre', nbEcoles: 3),
  ];
  final ecoles = [
    _ecole(id: '1', groupId: 'PUB', secteur: 'public'),
    _ecole(id: '2', groupId: 'PUB', secteur: 'public'),
    _ecole(id: '3', groupId: 'PRI'),
    _ecole(id: '4', groupId: 'PRI'),
    _ecole(id: '5', groupId: 'PRI'),
  ];

  Widget host({
    List<TutelleGroupe>? g,
    List<TutelleEcole>? e,
    void Function(TutelleGroupe)? onEcrire,
    void Function(TutelleGroupe)? onVoirEcoles,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TutelleGroupesVue(
              groupes: g ?? groupes,
              ecoles: e ?? ecoles,
              onOuvrirFiche: (_, _) {},
              onVoirEcoles: onVoirEcoles ?? (_) {},
              onEcrire: onEcrire ?? (_) {},
            ),
          ),
        ),
      );

  testWidgets('le pan PRIVÉ est rendu AVANT le pan public', (tester) async {
    await tester.pumpWidget(host());

    final prive = tester.getTopLeft(find.text('Réseau privé sous tutelle')).dy;
    final public = tester.getTopLeft(find.text('Réseau public')).dy;
    expect(prive, lessThan(public),
        reason: 'Le ministère administre déjà son public. Ce que cette page '
            'lui apprend, ce sont les opérateurs privés qu’il agrée sans les '
            'posséder — ils ouvrent la vue.');
  });

  testWidgets('chaque pan dit ce qu’il recouvre', (tester) async {
    await tester.pumpWidget(host());
    expect(find.textContaining('Le ministère les supervise ; il ne les gère'),
        findsOneWidget);
    expect(find.textContaining('tous groupes confondus'), findsOneWidget);
  });

  testWidgets('les trois actions d’une tutelle, et pas une de plus',
      (tester) async {
    await tester.pumpWidget(host());

    // Consulter, ouvrir ses écoles, écrire. Aucune action de GESTION : la
    // politique `groups_select` interdit à un ministère jusqu'à la lecture
    // directe d'un groupe tiers — un bouton « Modifier » échouerait en 42501,
    // et un UPDATE échouerait en silence.
    expect(find.text('Fiche'), findsNWidgets(2));
    expect(find.text('Ses écoles'), findsNWidgets(2));
    expect(find.text('Écrire'), findsNWidgets(2));
    for (final interdit in ['Modifier', 'Supprimer', 'Désactiver', 'Ajouter']) {
      expect(find.text(interdit), findsNothing,
          reason: '« $interdit » n’est pas un droit de la tutelle.');
    }
  });

  testWidgets('« Écrire » remonte LE groupe cliqué', (tester) async {
    // Le ciblage part dans `cible_group_ids` et la base l'applique : se
    // tromper de groupe ici enverrait la circulaire au mauvais opérateur.
    TutelleGroupe? recu;
    await tester.pumpWidget(host(onEcrire: (g) => recu = g));

    await tester.tap(find.text('Écrire').first);
    await tester.pump();
    expect(recu?.nom, 'Réseau Scolaire Saint-Pierre',
        reason: 'Le premier « Écrire » est celui du pan privé, rendu en tête.');
  });

  testWidgets('une vue filtrée dit « sur N » au lieu de mentir',
      (tester) async {
    // Saint-Pierre tient 3 écoles ; on n'en montre qu'une.
    await tester.pumpWidget(host(
      g: [groupes[1]],
      e: [ecoles[2]],
    ));
    expect(find.text('sur 3'), findsOneWidget,
        reason: 'Sans ce rappel, une vue filtrée annonce « 1 école » pour un '
            'opérateur qui en tient trois.');
  });

  testWidgets('une vue complète n’affiche pas le rappel « sur N »',
      (tester) async {
    await tester.pumpWidget(host());
    expect(find.textContaining('sur '), findsNothing);
  });

  testWidgets('un groupe hors sélection ne produit pas de carte vide',
      (tester) async {
    await tester.pumpWidget(host(e: [ecoles[0], ecoles[1]]));
    expect(find.text('Groupe Scolaire EDEC'), findsOneWidget);
    expect(find.text('Réseau Scolaire Saint-Pierre'), findsNothing,
        reason: 'Une carte à zéro école ferait croire à un groupe vide alors '
            'qu’il est seulement hors filtre.');
    expect(find.text('Réseau privé sous tutelle'), findsNothing);
  });

  testWidgets('aucun groupe retenu → un état vide qui le DIT', (tester) async {
    await tester.pumpWidget(host(e: const []));
    expect(find.text('Aucun groupe ne correspond'), findsOneWidget);
  });
}
