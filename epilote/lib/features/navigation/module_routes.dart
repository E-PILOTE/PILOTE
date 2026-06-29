import 'package:flutter/material.dart';

import '../../core/constants/routes.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Source unique de vérité : slug de module ↔ route ↔ icône.
//  Consommé par la sidebar dynamique (app_shell) ET le garde de routes
//  (app_router). Les slugs proviennent du catalogue live (table `modules`).
// ════════════════════════════════════════════════════════════════════════════

/// Modules dotés d'un écran/route dédié. Les autres tombent sur `/user/m/:slug`
/// (placeholder « en cours de développement ») tant qu'ils ne sont pas bâtis.
const Map<String, String> _moduleRoutes = {
  'eleves':           Routes.eleves,
  'inscriptions':     Routes.inscriptions,
  'transferts':       Routes.transferts,
  'documents':        Routes.documents,
  'annuaire':         Routes.annuaire,
  'niveaux':          Routes.structure,
  'classes':          Routes.classes,
  'matieres':         Routes.matieres,
  'programmes':       Routes.programmes,
  'emploi-du-temps':  Routes.emploiDuTemps,
  'cahier-textes':    Routes.cahierTextes,
  'notes':            Routes.notes,
  'bulletins':        Routes.bulletins,
  'conseils':         Routes.conseils,
  'presences-eleves': Routes.presences,
  'discipline':       Routes.discipline,
  'orientation':      Routes.orientation,
  'infirmerie':       Routes.infirmerie,
  'cantine':          Routes.cantine,
  'bibliotheque':     Routes.bibliotheque,
  'frais-scolarite':  Routes.fraisScolarite,
  'paiements-eleves': Routes.paiements,
  'depenses':         Routes.depenses,
  'budget':           Routes.budget,
  'personnel':        Routes.personnel,
  'presences-personnel': Routes.presencesPersonnel,
  'conges':           Routes.conges,
  'paie':             Routes.paie,
};

/// Préfixe de l'hôte générique (sans le paramètre `:slug`).
const String moduleHostPrefix = '/user/m/';

/// Route de navigation pour un module donné (dédiée si elle existe, sinon hôte).
String moduleRoute(String slug) => _moduleRoutes[slug] ?? '$moduleHostPrefix$slug';

/// Slug du module correspondant à une location `/user/*` (pour le garde de
/// routes). `null` si la location n'est pas une route de module.
String? moduleSlugForLocation(String location) {
  for (final e in _moduleRoutes.entries) {
    // Route exacte (`/user/classes`) OU sous-chemin de détail
    // (`/user/classes/:id`) → même module, donc même verrou 3.
    if (location == e.value || location.startsWith('${e.value}/')) return e.key;
  }
  if (location.startsWith(moduleHostPrefix)) {
    return location.substring(moduleHostPrefix.length);
  }
  return null;
}

/// Icône Material par slug (le catalogue stocke des emojis, peu adaptés à une
/// sidebar Material — on mappe vers des icônes cohérentes, défaut neutre).
IconData moduleIcon(String slug) => switch (slug) {
      // Scolarité
      'eleves'            => Icons.people_rounded,
      'inscriptions'      => Icons.how_to_reg_rounded,
      'transferts'        => Icons.swap_horiz_rounded,
      'documents'         => Icons.folder_rounded,
      'annuaire'          => Icons.contacts_rounded,
      // Enseignement
      'classes'           => Icons.class_rounded,
      'niveaux'           => Icons.stairs_rounded,
      'matieres'          => Icons.menu_book_rounded,
      'programmes'        => Icons.article_rounded,
      'emploi-du-temps'   => Icons.calendar_view_week_rounded,
      'cahier-textes'     => Icons.history_edu_rounded,
      // Évaluation
      'notes'             => Icons.grade_rounded,
      'bulletins'         => Icons.assignment_rounded,
      'conseils'          => Icons.groups_rounded,
      // Vie scolaire
      'presences-eleves'  => Icons.fact_check_rounded,
      'discipline'        => Icons.gavel_rounded,
      'orientation'       => Icons.explore_rounded,
      'infirmerie'        => Icons.local_hospital_rounded,
      'cantine'           => Icons.restaurant_rounded,
      'bibliotheque'      => Icons.local_library_rounded,
      // Finance
      'frais-scolarite'   => Icons.request_quote_rounded,
      'paiements-eleves'  => Icons.payments_rounded,
      'depenses'          => Icons.trending_down_rounded,
      'budget'            => Icons.account_balance_wallet_rounded,
      // RH
      'personnel'         => Icons.badge_rounded,
      'presences-personnel' => Icons.schedule_rounded,
      'conges'            => Icons.beach_access_rounded,
      'paie'              => Icons.payments_rounded,
      _                   => Icons.widgets_rounded,
    };
