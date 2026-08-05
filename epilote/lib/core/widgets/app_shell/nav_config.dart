import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../constants/routes.dart';
import '../../../data/models/profile_model.dart';
import '../../../features/admin_groupe/providers/admin_nav_provider.dart';
import '../../../features/navigation/module_routes.dart';
import '../../../features/navigation/providers/module_navigation_provider.dart';
import '../../../features/navigation/providers/permissions_provider.dart';
import 'nav_models.dart';

/// Construit les sections de navigation pour le profil donné.
///
/// - `super_admin` / `admin_groupe` : sections déclaratives statiques (admin
///   reçoit l'entrée dynamique « Modules du groupe » selon son catalogue).
/// - Personnel scolaire : sections dynamiques (catalogue ∩ permissions).
List<NavSection> buildNavSections(WidgetRef ref, ProfileModel profile) {
  switch (profile.role) {
    case AppConstants.roleSuperAdmin:
      return _superAdminSections();
    case AppConstants.roleAdminGroupe:
      return _adminGroupeSections(ref);
    default:
      return _staffSections(ref, profile);
  }
}

// ─── super_admin (INTOUCHÉ — ordre & libellés à l'identique) ────────────────
List<NavSection> _superAdminSections() => const [
      NavSection(title: '', entries: [
        NavEntry.item(
          icon: Icons.dashboard_rounded,
          label: 'Tableau de bord',
          route: Routes.superDashboard,
        ),
      ]),
      NavSection(title: 'GROUPES & ABONNEMENTS', entries: [
        NavEntry.item(
          icon: Icons.school_rounded,
          label: 'Groupes Scolaires',
          route: Routes.superGroupes,
        ),
        NavEntry.item(
          icon: Icons.admin_panel_settings_rounded,
          label: 'Administrateurs',
          route: Routes.superAdministrateurs,
        ),
        NavEntry.item(
          icon: Icons.inventory_2_rounded,
          label: "Plans d'abonnement",
          route: Routes.superPlans,
        ),
        NavEntry.item(
          icon: Icons.receipt_long_rounded,
          label: 'Abonnements',
          route: Routes.superAbonnements,
        ),
        NavEntry.item(
          icon: Icons.description_rounded,
          label: 'Factures',
          route: Routes.superFactures,
        ),
        NavEntry.item(
          icon: Icons.receipt_rounded,
          label: 'Reçus de paiement',
          route: Routes.superRecus,
        ),
        NavEntry.item(
          icon: Icons.payment_rounded,
          label: 'Modes de paiement',
          route: Routes.superPaiements,
        ),
      ]),
      NavSection(title: 'PLATEFORME', entries: [
        NavEntry.item(
          icon: Icons.extension_rounded,
          label: 'Catégories & Modules',
          route: Routes.superModules,
        ),
        NavEntry.item(
          icon: Icons.psychology_rounded,
          label: 'Intelligence Artificielle',
          route: Routes.superIa,
        ),
        // Sans cette page, une correction ne peut atteindre le parc que par
        // un accès direct à la base de production.
        NavEntry.item(
          icon: Icons.system_update_rounded,
          label: "Versions de l'application",
          route: Routes.superVersions,
        ),
      ]),
      NavSection(title: 'COMMUNICATION', entries: [
        NavEntry.item(
          icon: Icons.campaign_rounded,
          label: 'Annonces & Agenda',
          route: Routes.superAnnonces,
        ),
        NavEntry.item(
          icon: Icons.mail_rounded,
          label: 'Messages',
          route: Routes.superMessagesInbox,
        ),
        NavEntry.item(
          icon: Icons.confirmation_num_rounded,
          label: 'Tickets support',
          route: Routes.superTickets,
        ),
        NavEntry.item(
          icon: Icons.desktop_windows_rounded,
          label: 'Messages d’accueil des postes',
          route: Routes.superMessagesAccueil,
        ),
        NavEntry.item(
          icon: Icons.handshake_rounded,
          label: 'Partenaires des postes',
          route: Routes.superPartenaires,
        ),
      ]),
      NavSection(title: 'RAPPORTS & SYSTÈME', pinned: true, entries: [
        NavEntry.item(
          icon: Icons.list_alt_rounded,
          label: "Journal d'audit",
          route: Routes.superAudit,
        ),
        NavEntry.item(
          icon: Icons.bar_chart_rounded,
          label: 'Rapports & Statistiques',
          route: Routes.superRapports,
        ),
        NavEntry.item(
          icon: Icons.settings_rounded,
          label: 'Paramètres plateforme',
          route: Routes.superParametres,
        ),
      ]),
    ];

// ─── admin_groupe ───────────────────────────────────────────────────────────
List<NavSection> _adminGroupeSections(WidgetRef ref) {
  // Entrée « Modules du groupe » : ref-aware (plus de mutation pendant build()).
  // Affichée seulement si le catalogue du groupe est chargé et non vide.
  final catalog = ref.watch(adminModulesCatalogProvider).valueOrNull;
  final hasModules = catalog != null && catalog.categories.isNotEmpty;

  return [
    const NavSection(title: '', pinnedTop: true, entries: [
      NavEntry.item(
        icon: Icons.dashboard_rounded,
        label: 'Tableau de bord',
        route: Routes.adminDashboard,
      ),
    ]),
    // Ordre workflow : créer les écoles → les profils → assigner les utilisateurs.
    const NavSection(title: 'GESTION', entries: [
      NavEntry.item(
        icon: Icons.school_rounded,
        label: 'Mes Écoles',
        route: Routes.adminEcoles,
      ),
      NavEntry.item(
        icon: Icons.event_note_rounded,
        label: 'Années scolaires',
        route: Routes.adminAnnees,
      ),
      // Juste après l'année : un tarif s'attache à une année, et sans tarif
      // publié aucune école du réseau ne peut encaisser.
      NavEntry.item(
        icon: Icons.request_quote_rounded,
        label: 'Frais & tarifs',
        route: Routes.adminFrais,
      ),
      NavEntry.item(
        icon: Icons.lock_rounded,
        label: "Profils d'accès",
        route: Routes.adminProfils,
      ),
      NavEntry.item(
        icon: Icons.people_rounded,
        label: 'Utilisateurs',
        route: Routes.adminUtilisateurs,
      ),
      // Retrouver UN élève dans tout le réseau : la question qu'un cabinet
      // reçoit sans arrêt, et à laquelle rien ne répondait au niveau groupe.
      NavEntry.item(
        icon: Icons.school_rounded,
        label: 'Élèves du réseau',
        route: Routes.adminEleves,
      ),
    ]),
    NavSection(title: 'PILOTAGE', entries: [
      // Cœur du METP : la couverture des examens nationaux sur tout le réseau.
      const NavEntry.item(
        icon: Icons.workspace_premium_rounded,
        label: 'Examens nationaux',
        route: Routes.adminExamens,
      ),
      // AMONT de la campagne — c'est le ministère qui connaît les examens et
      // reçoit les arrêtés, pas l'opérateur de la plateforme. Le référentiel
      // d'abord (un examen se déclare et se branche à des classes), le
      // calendrier ensuite : sans session ouverte, aucune école n'inscrit.
      const NavEntry.item(
        icon: Icons.rule_rounded,
        label: 'Référentiel des examens',
        route: Routes.adminReferentiel,
      ),
      const NavEntry.item(
        icon: Icons.event_note_rounded,
        label: "Sessions d'examen",
        route: Routes.adminSessions,
      ),
      // Le RETOUR de la DEC : résultats proclamés et pièces archivées. Suit
      // immédiatement l'envoi — c'est le second temps du même cycle, mais pas
      // la même page : l'un suit la campagne en cours, l'autre l'histoire.
      const NavEntry.item(
        icon: Icons.verified_rounded,
        label: 'Résultats & archives',
        route: Routes.adminResultats,
      ),
      // Les meilleurs lauréats du réseau : la matière première d'une commission
      // de bourses. Adossé aux examens, donc juste après eux.
      const NavEntry.item(
        icon: Icons.emoji_events_rounded,
        label: 'Meilleurs élèves',
        route: Routes.adminPalmares,
      ),
      const NavEntry.item(
        icon: Icons.bar_chart_rounded,
        label: 'Rapports',
        route: Routes.adminRapports,
      ),
      // « Modules du groupe » remis à une place LOGIQUE (pilotage), au lieu de
      // l'ancien rattachement après la section SYSTÈME.
      if (hasModules)
        const NavEntry.item(
          icon: Icons.apps_rounded,
          label: 'Modules du groupe',
          route: Routes.adminModules,
        ),
      const NavEntry.item(
        icon: Icons.credit_card_rounded,
        label: 'Abonnement',
        route: Routes.adminAbonnement,
      ),
    ]),
    // Communication = tissu natif de la plateforme (jamais vendu, non
    // désactivable) → épinglée comme Système : bloc-repère permanent en bas.
    const NavSection(title: 'COMMUNICATION', pinned: true, entries: [
      NavEntry.item(
        icon: Icons.campaign_rounded,
        label: 'Annonces & Agenda',
        route: Routes.adminAnnonces,
      ),
      NavEntry.item(
        icon: Icons.forum_rounded,
        label: 'Messagerie',
        route: Routes.adminMessagerie,
      ),
    ]),
    const NavSection(title: 'SYSTÈME', pinned: true, entries: [
      NavEntry.item(
        icon: Icons.confirmation_num_rounded,
        label: 'Tickets',
        route: Routes.adminSupport,
      ),
      NavEntry.item(
        icon: Icons.menu_book_rounded,
        label: "Journal d'audit",
        route: Routes.adminAudit,
      ),
      NavEntry.item(
        icon: Icons.settings_rounded,
        label: 'Paramètres',
        route: Routes.adminParametres,
      ),
    ]),
  ];
}

// ─── Personnel scolaire (dynamique) ─────────────────────────────────────────
/// Sidebar du personnel : catalogue (verrou 2 : plan) ∩ permissions du membre
/// (verrou 3 : `can_read`). La section COMMUNICATION reste native (hors
/// catalogue), comme pour tous les autres rôles.
List<NavSection> _staffSections(WidgetRef ref, ProfileModel profile) {
  final isEleve = profile.role == AppConstants.roleEleve;
  final isParent = profile.role == AppConstants.roleParent;

  final groupedAsync = ref.watch(modulesGroupedByCategoryProvider);
  final permsAsync = ref.watch(myPermissionsProvider);
  final grouped = groupedAsync.valueOrNull ?? const {};
  final perms = permsAsync.valueOrNull ?? const {};
  // Distinguer « en cours de synchro » de « réellement aucun module » : sinon le
  // personnel voit une sidebar vide pendant la 1ʳᵉ synchro PowerSync.
  final modulesSyncing = (groupedAsync.isLoading && !groupedAsync.hasValue) ||
      (permsAsync.isLoading && !permsAsync.hasValue);
  final modulesError = groupedAsync.hasError || permsAsync.hasError;

  final sections = <NavSection>[
    const NavSection(title: '', pinnedTop: true, entries: [
      NavEntry.item(
        icon: Icons.dashboard_rounded,
        label: 'Tableau de bord',
        route: Routes.userDashboard,
      ),
    ]),
  ];

  // Calendrier scolaire + Journal d'audit = configs NATIVES réservées à la
  // direction (hors catalogue : non vendables).
  if (AppConstants.directionRoles.contains(profile.role)) {
    sections.add(const NavSection(title: 'ÉTABLISSEMENT', entries: [
      NavEntry.item(
        icon: Icons.event_note_rounded,
        label: 'Calendrier scolaire',
        route: Routes.calendrier,
      ),
      NavEntry.item(
        icon: Icons.fact_check_outlined,
        label: "Journal d'audit",
        route: Routes.userAudit,
      ),
    ]));
  }

  // Modules accordés, regroupés par catégorie (ordre = display_order du SQL).
  var moduleCount = 0;
  for (final entry in grouped.entries) {
    final visible =
        entry.value.where((m) => perms[m.slug]?.canRead ?? false).toList();
    if (visible.isEmpty) continue;
    sections.add(NavSection(
      title: entry.key.name.toUpperCase(),
      entries: [
        for (final m in visible)
          NavEntry.item(
            icon: moduleIcon(m.slug),
            label: m.name,
            route: moduleRoute(m.slug),
          ),
      ],
    ));
    moduleCount += visible.length;
  }

  // Aucun module : état explicite (jamais une zone vide muette), sauf
  // élève/parent dont l'essentiel passe par Communication / Espace.
  if (moduleCount == 0 && !isEleve && !isParent) {
    sections.add(NavSection(title: 'MES MODULES', entries: [
      modulesSyncing
          ? const NavEntry.info('Synchronisation…', loading: true)
          : modulesError
              ? const NavEntry.info('Erreur de synchronisation')
              : const NavEntry.info('Aucun module attribué'),
    ]));
  }

  // Communication = tissu natif (jamais vendu, non désactivable).
  final commEntries = <NavEntry>[
    const NavEntry.item(
      icon: Icons.campaign_rounded,
      label: 'Annonces & Agenda',
      route: Routes.annonces,
    ),
    // Sauvegarde mineurs : les élèves n'ont pas la messagerie privée.
    if (!isEleve)
      const NavEntry.item(
        icon: Icons.forum_rounded,
        label: 'Messagerie',
        route: Routes.messagerie,
      ),
    if (isParent)
      const NavEntry.item(
        icon: Icons.family_restroom_rounded,
        label: 'Espace Parent',
        route: Routes.espaceParent,
      ),
  ];
  // Communication = tissu natif → épinglée comme Système (bloc-repère bas).
  sections
      .add(NavSection(title: 'COMMUNICATION', pinned: true, entries: commEntries));

  // Système (épinglé en bas).
  final sysEntries = <NavEntry>[
    // Demandes au support plateforme : réservé au personnel de l'école.
    if (!isEleve && !isParent)
      const NavEntry.item(
        icon: Icons.confirmation_num_rounded,
        label: 'Tickets',
        route: Routes.userSupport,
      ),
    const NavEntry.item(
      icon: Icons.settings_rounded,
      label: 'Paramètres',
      route: Routes.userParametres,
    ),
  ];
  sections.add(NavSection(title: 'SYSTÈME', pinned: true, entries: sysEntries));

  return sections;
}
