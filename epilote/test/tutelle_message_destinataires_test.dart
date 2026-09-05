import 'package:epilote/features/tutelle/providers/tutelle_destinataires_provider.dart';
import 'package:epilote/features/tutelle/providers/tutelle_reseau_provider.dart';
import 'package:epilote/features/tutelle/widgets/tutelle_message_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHOISIR À QUI LA TUTELLE ÉCRIT
//
//  Un ministère coche l'administrateur du groupe, ou les chefs des
//  établissements qu'il vise, ou les deux. La coupure entre les deux blocs a
//  un sens juridique : d'un côté la PERSONNE MORALE qu'on agrée, de l'autre
//  les CHEFS qui dirigent chacun une école. Écrire au premier n'est pas écrire
//  aux seconds, et l'écran ne doit pas laisser croire l'inverse.
// ════════════════════════════════════════════════════════════════════════════

const _groupe = TutelleGroupe(
  id: 'PRI',
  nom: 'Réseau Scolaire Saint-Pierre',
  secteur: 'prive',
  nbEcoles: 3,
  nbEcolesActives: 3,
  nbEleves: 0,
  nbFilles: 0,
  nbPersonnel: 0,
  nbClasses: 0,
  nbEcolesAgreees: 0,
);

// Le réseau réel du groupe, tel que la RPC le rend (mesuré le 2026-09-03).
const _reels = [
  DestinataireTutelle(
      userId: 'admin', nom: 'Anicet Mouko', fonction: 'Administrateur du groupe'),
  DestinataireTutelle(
      userId: 'd1',
      nom: 'Jean-Claude Bouity',
      fonction: 'Directeur',
      schoolId: 's1',
      ecole: 'Collège Saint-Pierre'),
  DestinataireTutelle(
      userId: 'd2',
      nom: 'Norbert Mouko',
      fonction: 'Directeur',
      schoolId: 's2',
      ecole: 'École Primaire Saint-Pierre'),
  DestinataireTutelle(
      userId: 'd3',
      nom: 'Firmin Ekondi',
      fonction: 'Proviseur',
      schoolId: 's3',
      ecole: 'Lycée Catholique Saint-Pierre'),
];

void main() {
  Future<void> ouvrir(WidgetTester tester,
      {List<DestinataireTutelle> liste = _reels}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        destinatairesTutelleProvider.overrideWith((ref, arg) async => liste),
      ],
      child: const MaterialApp(
        home: Scaffold(body: TutelleMessageDialog(groupe: _groupe)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('deux blocs : la personne morale, puis les établissements',
      (tester) async {
    await ouvrir(tester);
    final groupe = tester.getTopLeft(find.text('LE GROUPE SCOLAIRE')).dy;
    final ecoles = tester.getTopLeft(find.text('LES ÉTABLISSEMENTS')).dy;
    expect(groupe, lessThan(ecoles),
        reason: 'Écrire à la personne morale est le geste ordinaire ; '
            'atteindre chaque chef est une décision.');
    expect(find.text('Anicet Mouko'), findsOneWidget);
    expect(find.text('Firmin Ekondi'), findsOneWidget);
  });

  testWidgets('chaque chef porte SON école — sinon on ne les distingue pas',
      (tester) async {
    await ouvrir(tester);
    expect(find.text('Directeur · Collège Saint-Pierre'), findsOneWidget);
    expect(find.text('Proviseur · Lycée Catholique Saint-Pierre'),
        findsOneWidget);
    expect(find.text('Administrateur du groupe'), findsOneWidget);
  });

  testWidgets('le GROUPE est coché d’office, les écoles ne le sont pas',
      (tester) async {
    await ouvrir(tester);
    final cases = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .map((c) => c.value)
        .toList();
    expect(cases, [true, false, false, false],
        reason: 'Une décision se prend en cochant, pas en oubliant de '
            'décocher.');
    // Le bouton reflète le compte : un seul destinataire.
    expect(find.text('Envoyer'), findsOneWidget);
  });

  testWidgets('« Tout cocher » ne touche QUE les établissements',
      (tester) async {
    await ouvrir(tester);
    await tester.tap(find.text('Tout cocher'));
    await tester.pump();

    final cases = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .map((c) => c.value)
        .toList();
    expect(cases, [true, true, true, true]);
    expect(find.text('Envoyer (4)'), findsOneWidget,
        reason: 'Le compte doit être DIT : sans lui, on croit avoir coché ce '
            'qu’on n’a pas coché.');
    expect(find.text('Tout décocher'), findsOneWidget);
  });

  testWidgets('décocher tout le monde retire le bouton d’envoi',
      (tester) async {
    await ouvrir(tester);
    // Seul l'administrateur est coché au départ.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    // ⚠️ `recipient_id` est NOT NULL : un envoi à vide échouerait en base et
    // l'agent croirait à une panne de réseau.
    expect(find.text('Envoyer'), findsNothing);
  });

  testWidgets('un groupe sans personne le DIT, au lieu d’une liste vide',
      (tester) async {
    await ouvrir(tester, liste: const []);
    expect(find.textContaining('personne ne peut recevoir'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('un groupe sans chef d’établissement le dit aussi',
      (tester) async {
    await ouvrir(tester, liste: const [_adminSeul]);
    expect(find.textContaining('Aucun chef d’établissement enregistré'),
        findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });
}

const _adminSeul = DestinataireTutelle(
    userId: 'admin', nom: 'Anicet Mouko', fonction: 'Administrateur du groupe');
