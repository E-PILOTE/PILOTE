import 'dart:io';

import 'package:epilote/core/constants/socle_natif.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  AUCUNE ENTRÉE DE MENU EN DOUBLE
//
//  ── LE DÉFAUT QUE CE GARDE EMPÊCHE DE REVENIR ─────────────────────────────
//  La barre de l'admin de groupe a porté, des semaines durant, DEUX entrées
//  pour le même objet : « Circulaires émises » sous TUTELLE et « Circulaires »
//  sous COMMUNICATION, à huit lignes d'écart. Personne ne l'avait vu en
//  relisant le code — les deux entrées vivaient dans deux sections distantes
//  de deux cents lignes, chacune parfaitement justifiée là où elle était.
//
//  ⚠️ Ce garde lit le CODE SOURCE, section par section, ET la déclaration du
//  socle natif. Il ne rend pas la sidebar : il compte ce que le dépôt déclare.
//  C'est suffisant, parce que le doublon naît toujours à l'écriture — jamais à
//  l'exécution.
//
//  ⚠️ Depuis que les entrées natives viennent de `socle_natif.dart`, la moitié
//  d'une barre n'est plus écrite dans `nav_config.dart`. Compter les seules
//  lignes littérales laisserait passer le cas qui a créé le défaut : une
//  entrée réécrite à la main À CÔTÉ de la même entrée héritée du socle. Les
//  deux sources sont donc réunies avant comptage, et les `Routes.xxx` sont
//  résolus en chemins pour être comparables aux routes du socle.
//
//  ⚠️ Et il ne regarde que les ENTRÉES CONSTRUITES (`route:` / `label:`), pas
//  les identifiants cités dans les commentaires. Deux sondes de ce dépôt sont
//  déjà tombées parce qu'elles attrapaient la prose qui expliquait justement
//  le retrait d'une entrée.
// ════════════════════════════════════════════════════════════════════════════

/// Les trois espaces, et où commence chacun dans `nav_config.dart`.
const _espaces = <String, String>{
  'super_admin': 'List<NavSection> _superAdminSections()',
  'admin_groupe': 'List<NavSection> _adminGroupeSections(',
  'personnel': 'List<NavSection> _staffSections(',
};

/// L'espace du socle dont chaque barre hérite ses entrées natives.
///
/// Le `super_admin` n'en a pas : ses entrées de même nom sont des outils de
/// PLATEFORME (« Paramètres plateforme », « Tickets support »), et sa barre
/// n'est jamais construite depuis la base.
const _socles = <String, EspaceNav?>{
  'super_admin': null,
  'admin_groupe': EspaceNav.groupe,
  'personnel': EspaceNav.etablissement,
};

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Le corps de la fonction qui construit l'espace [nom].
String _corpsDe(String src, String nom) {
  final debut = src.indexOf(_espaces[nom]!);
  expect(debut, greaterThan(0), reason: 'Espace « $nom » introuvable.');
  // Jusqu'au début de l'espace suivant, ou la fin du fichier.
  var fin = src.length;
  for (final marqueur in _espaces.values) {
    final i = src.indexOf(marqueur, debut + 1);
    if (i > debut && i < fin) fin = i;
  }
  return src.substring(debut, fin);
}

/// `Routes.adminEcoles` → `/admin/ecoles`, pour comparer avec le socle qui,
/// lui, porte déjà les chemins.
Map<String, String> _cheminsDesRoutes() {
  final src = _lire('lib/core/constants/routes.dart');
  final m = {
    for (final x in RegExp(r"static const String (\w+)\s*=\s*'([^']*)'")
        .allMatches(src))
      'Routes.${x.group(1)}': x.group(2)!,
  };
  expect(m, isNotEmpty, reason: 'Aucune route lue : sonde creuse.');
  return m;
}

List<String> _occurrences(String corps, RegExp motif) =>
    [for (final m in motif.allMatches(corps)) m.group(1)!];

List<String> _doublons(List<String> valeurs) {
  final vus = <String>{};
  final doubles = <String>[];
  for (final v in valeurs) {
    if (!vus.add(v) && !doubles.contains(v)) doubles.add(v);
  }
  return doubles;
}

/// ⚠️ TOUT CE QUI PEUT ÉCHOUER VIT DANS UN TEST.
/// `_lire`, `_corpsDe` et `_cheminsDesRoutes` appellent `fail`/`expect` : les
/// appeler à la racine de `main()` lève `OutsideTestException` au CHARGEMENT
/// du fichier — le suite entière ne se charge plus, et le rapport ne dit pas
/// pourquoi.
const _nav = 'lib/core/widgets/app_shell/nav_config.dart';

void main() {
  // `route: Routes.adminEcoles,` — l'entrée construite, pas le commentaire.
  final motifRoute = RegExp(r'route:\s*(Routes\.\w+)');
  // `label: 'Mes Écoles',`
  final motifLabel = RegExp(r"label:\s*'([^']+)'");

  for (final espace in _espaces.keys) {
    final socle = _socles[espace];

    test('$espace : aucune ROUTE en double dans la barre', () {
      final corps = _corpsDe(_lire(_nav), espace);
      final chemins = _cheminsDesRoutes();
      final routes = <String>[
        for (final id in _occurrences(corps, motifRoute))
          chemins[id] ?? fail('Route inconnue de routes.dart : $id'),
        if (socle != null)
          for (final e in kSocleNatif)
            if (e.places[socle] != null) e.places[socle]!.route,
      ];
      expect(routes, isNotEmpty, reason: 'Sonde creuse : aucune route lue.');
      expect(_doublons(routes), isEmpty,
          reason: 'Deux entrées mènent au même écran dans l’espace $espace. '
              'Une barre latérale qui propose deux fois la même destination '
              'fait douter l’utilisateur d’avoir compris la différence.');
    });

    test('$espace : aucun LIBELLÉ en double dans la barre', () {
      // Deux libellés identiques sur deux routes différentes est pire qu'un
      // doublon de route : l'utilisateur croit à une répétition, clique au
      // hasard, et atterrit ailleurs qu'il ne pensait.
      final labels = <String>[
        ..._occurrences(_corpsDe(_lire(_nav), espace), motifLabel),
        if (socle != null)
          for (final e in kSocleNatif)
            if (e.places[socle] != null) e.libelle,
      ];
      expect(labels, isNotEmpty);
      expect(_doublons(labels), isEmpty,
          reason: 'Deux entrées portent le même nom dans l’espace $espace.');
    });
  }

  _plurielCompose();

  test('le mot « Circulaire » a bien quitté toutes les barres', () {
    // Il en restait deux, dans deux sections distantes de deux cents lignes.
    expect(RegExp(r"label:\s*'Circulaires").hasMatch(_lire(_nav)), isFalse);
    expect(kSocleNatif.any((e) => e.libelle.startsWith('Circulaire')), isFalse);
  });
}

// ════════════════════════════════════════════════════════════════════════════
//  LE PLURIEL D'UN NOM COMPOSÉ
//
//  Vu à l'écran le 2026-09-03 : « 5 groupe scolaires ». `ListResultHeader`
//  collait un `s` au groupe nominal ENTIER — « école » → « écoles » marche,
//  « groupe scolaire » → « groupe scolaires » non. Tout nom composé, tout mot
//  en -al ou -ail tombe dans le même trou.
// ════════════════════════════════════════════════════════════════════════════
void _plurielCompose() {
  test('un nom composé reçoit un pluriel explicite', () {
    final src = _lire('lib/core/widgets/list_chrome.dart');
    expect(src.contains('final String? nounPlural'), isTrue,
        reason: 'Sans échappatoire, « groupe scolaire » redevient '
            '« groupe scolaires ».');

    final ecran =
        _lire('lib/features/tutelle/screens/tutelle_reseau_screen.dart');
    final i = ecran.indexOf("noun: 'groupe scolaire'");
    expect(i, greaterThan(0));
    expect(ecran.substring(i, i + 120).contains("nounPlural: 'groupes scolaires'"),
        isTrue,
        reason: 'Le seul appel du dépôt à nom composé doit donner son pluriel.');
  });
}
