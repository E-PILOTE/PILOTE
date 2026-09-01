import 'dart:io';

import 'package:epilote/core/constants/routes.dart';
import 'package:epilote/features/navigation/module_routes.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE PAGE DE L'ÉCOLE QUI N'EST PAS UN MODULE N'A AUCUN VERROU
//
//  ── LE DÉFAUT, TROUVÉ LE 2026-08-29 ────────────────────────────────────────
//  Le garde de routes (`app_router`, verrous 2/3/4) commence par :
//
//      final slug = moduleSlugForLocation(loc);
//      if (slug != null) { ...impayé... ...plan... ...profil d'accès... }
//
//  Tout tient à cette table. Une route absente de `_moduleRoutes` rend `null`,
//  et `null` veut dire « route native » — la catégorie du Tableau de bord, du
//  Profil et des Paramètres, que rien ne doit jamais barrer. Le garde la laisse
//  donc passer SANS verrou : ni impayé, ni plan, ni profil d'accès.
//
//  `/user/passage` y était tombée. C'est l'écran de DÉLIBÉRATION : il écrit
//  `class_enrollments.promotion_decision` — qui passe, qui redouble — puis
//  réinscrit toute une classe dans l'année suivante. L'écriture la plus lourde
//  de conséquence de l'année scolaire était la seule page sans verrou.
//
//  Le droit `conseils.update` gardait le BOUTON d'entrée, au fond de l'écran
//  Conseils de classe. Pas la PAGE. Et un bouton n'est pas un verrou : il ne
//  garde qu'un chemin, celui qu'on a pensé.
//
//  ── POURQUOI LE MAL N'ÉTAIT PAS L'ÉCRITURE ILLÉGITIME ──────────────────────
//  La RLS tenait : `enrollments_update` exige un verbe sur l'un de
//  inscriptions/eleves/conseils/transferts/discipline. Un poste sans ce verbe
//  écrivait donc quand même EN LOCAL, affichait le verdict au conseil réuni,
//  et se le faisait jeter au téléversement (42501, code fatal — le lot entier
//  part avec). Le conseil croit avoir délibéré. Rien n'est parti, et personne
//  ne l'apprend.
//
//  ── CE QUE CE TEST GARDE ───────────────────────────────────────────────────
//  Pas le cas `passage` — le CAS GÉNÉRAL. Toute route `/user/*` déclarée dans
//  `Routes` est soit un module (donc verrouillée), soit inscrite ci-dessous
//  dans la liste des routes natives, à la main, avec sa raison. Ajouter un
//  écran sans y penser fait échouer ce test, ce qui est exactement le moment
//  où il faut y penser.
//
//  Voir migration `0147_AVANT_LE_BUILD_la_deliberation_devient_un_module.sql`,
//  qui crée le module côté base et lui recopie à l'identique les droits de
//  `conseils` — sans donner un droit nouveau à qui que ce soit.
// ════════════════════════════════════════════════════════════════════════════

/// Routes `/user/*` volontairement SANS module, chacune avec sa raison.
///
/// Une entrée ici est une décision, pas un oubli : elle affirme que la page
/// doit rester accessible même à une école en impayé, hors de tout plan, et
/// sans profil d'accès particulier.
const Map<String, String> _routesNativesJustifiees = {
  '/user/dashboard':
      "Point d'entrée du personnel : le barrer n'aurait nulle part où renvoyer.",
  '/user/profil': 'Son propre compte. Ne se vend pas et ne se retire pas.',
  '/user/parametres': 'Réglages du poste (agent actif, base locale, licence).',
  '/user/renouvellement':
      "Le mur d'impayé lui-même. Le verrouiller enfermerait l'école dehors.",
  '/user/rapports':
      'Synthèses de direction, gardées par le rôle et non par un module.',
  '/user/journal-audit':
      'Journal de direction (online). Gardé par le rôle, pas par un module.',
  '/user/calendrier':
      'Configuration de direction (trimestres, périodes) — gardée par le rôle.',
  // Communication : tissu natif, dans le catalogue mais dans AUCUN plan
  // (vérifié en base) — jamais vendue, jamais désactivable.
  '/user/annonces': 'Communication : tissu natif, jamais vendu.',
  '/user/notifications': 'Communication : tissu natif, jamais vendu.',
  '/user/messagerie': 'Communication : tissu natif, jamais vendu.',
  '/user/evenements': 'Communication : tissu natif, jamais vendu.',
  // Une circulaire vient du MINISTÈRE de tutelle. La gater sur un plan
  // reviendrait à couper un établissement de la correspondance officielle
  // de son administration parce qu'il n'a pas payé son logiciel — et
  // l'accusé de lecture qu'on lui réclame deviendrait impossible à donner.
  // Gardée par le RÔLE (direction), au routeur et dans la sidebar.
  '/user/circulaires':
      'Correspondance de la tutelle : tissu natif, jamais vendu.',
  '/user/espace-parent': 'Espace famille — planifié en dernier.',
  '/user/support': 'Ouvrir un ticket au support plateforme.',
  // L'hôte générique n'est pas une page : il PORTE le slug d'un module.
  '/user/m/:slug': 'Gîte des modules accordés mais pas encore bâtis.',
};

/// Toutes les routes `/user/...` déclarées dans `Routes`, lues à la source.
///
/// La lecture du fichier — plutôt qu'une liste recopiée — est ce qui fait que
/// le test parle encore des écrans écrits après lui.
List<(String nom, String chemin)> _routesEcole() {
  final src = File('lib/core/constants/routes.dart').readAsStringSync();
  final re = RegExp(
    r"static\s+const\s+String\s+(\w+)\s*=\s*'(/user/[^']*)'",
  );
  return [
    for (final m in re.allMatches(src)) (m.group(1)!, m.group(2)!),
  ];
}

void main() {
  group("Toute page de l'école est un module, ou une exception assumée", () {
    test('le fichier de routes est bien lu (le test ne se vide pas en silence)',
        () {
      final routes = _routesEcole();
      expect(
        routes.length,
        greaterThan(30),
        reason: 'Moins de 30 routes /user/* : la lecture de routes.dart a '
            'échoué et le test passerait à vide — ce qui est pire que rouge.',
      );
      expect(
        routes.map((r) => r.$2),
        contains(Routes.passage),
        reason: "L'écran de délibération doit figurer dans le relevé.",
      );
    });

    test('aucune route /user/* ne franchit le garde sans verrou ni justification',
        () {
      final sansVerrou = <String>[];
      for (final (nom, chemin) in _routesEcole()) {
        if (_routesNativesJustifiees.containsKey(chemin)) continue;
        if (moduleSlugForLocation(chemin) == null) {
          sansVerrou.add('$nom  ($chemin)');
        }
      }
      expect(
        sansVerrou,
        isEmpty,
        reason: 'Ces routes traversent le garde de `app_router` SANS verrou '
            "d'impayé, de plan ni de profil d'accès :\n  ${sansVerrou.join('\n  ')}"
            '\n\nDeux issues, et une seule est un choix : soit la page reçoit '
            "un module dans `_moduleRoutes` (+ la migration qui l'inscrit au "
            'catalogue, aux plans et aux droits), soit elle rejoint '
            '`_routesNativesJustifiees` AVEC sa raison écrite.',
      );
    });

    test('chaque exception native correspond à une route qui existe vraiment',
        () {
      final chemins = _routesEcole().map((r) => r.$2).toSet();
      final orphelines = _routesNativesJustifiees.keys
          .where((c) => !chemins.contains(c))
          .toList();
      expect(
        orphelines,
        isEmpty,
        reason: 'Exceptions accordées à des routes disparues : '
            "${orphelines.join(', ')}. Une dispense qui survit à son écran "
            'couvrira un jour un écran homonyme qui, lui, aurait besoin du '
            'verrou.',
      );
    });
  });

  group("La délibération de fin d'année est verrouillée", () {
    test('/user/passage est reconnue comme le module `passage`', () {
      expect(moduleSlugForLocation(Routes.passage), 'passage');
    });

    test('le module `passage` mène bien à son écran, pas au gîte générique', () {
      expect(moduleRoute('passage'), Routes.passage);
      expect(moduleRoute('passage').startsWith(moduleHostPrefix), isFalse,
          reason: 'Un module dépourvu de route dédiée tombe sur '
              "`/user/m/:slug`, l'écran « en cours de développement ». La "
              "délibération existe : elle doit mener à l'écran réel.");
    });

    test('un module inconnu tombe toujours sur le gîte générique', () {
      expect(moduleRoute('module-qui-nexiste-pas'),
          '${moduleHostPrefix}module-qui-nexiste-pas');
    });
  });
}
