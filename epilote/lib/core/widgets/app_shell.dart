import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/routes.dart';
import '../../data/models/profile_model.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/active_agent_provider.dart';
import '../../features/super_admin/providers/super_dashboard_provider.dart';
import '../../features/super_admin/providers/school_groups_provider.dart';
import '../../features/super_admin/providers/administrators_provider.dart';
import '../../features/super_admin/providers/modules_provider.dart';
import '../../features/communication/providers/notifications_provider.dart';
import '../../features/communication/providers/message_unread_provider.dart';
import '../../features/communication/widgets/notifications_drawer.dart';
import '../../features/communication/widgets/notification_bell.dart';
import '../../features/communication/providers/messages_provider.dart';
import '../../features/admin_groupe/providers/admin_dashboard_provider.dart';
import '../../features/admin_groupe/providers/admin_nav_provider.dart';
import '../../features/navigation/module_routes.dart';
import '../../features/navigation/providers/module_navigation_provider.dart';
import '../../features/navigation/providers/permissions_provider.dart';
import '../../features/user/providers/user_profile_provider.dart';
import '../../services/powersync/powersync_service.dart';
import 'year_selector.dart';

// ─── Design tokens ────────────────────────────────────────────────────────
const Color _kNavyDeep = Color(0xFF091828);
const Color _kNavyDark = Color(0xFF0F2340);
const Color _kNavy = Color(0xFF1E3A5F);
const Color _kGreen = Color(0xFF009A44);
const Color _kAccent = Color(0xFFFBBC04);
const Color _kWhite = Colors.white;
const Color _kSurface = Color(0xFFF0F4F8);
const Color _kTextPrimary = Color(0xFF0F172A);
const Color _kTextMuted = Color(0xFF64748B);

const double _kSidebarExpanded = 268;
const double _kSidebarCollapsed = 64;
const double _kHeaderHeight = 68;

// ─── Sidebar state ────────────────────────────────────────────────────────
final sidebarExpandedProvider = StateProvider<bool>((_) => true);

// ─── Theme mode ───────────────────────────────────────────────────────────
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.light);

// ─── Visionneuse confinée au contenu ───────────────────────────────────────
// Une visionneuse (image / PDF) rendue ICI plutôt que via le Navigator racine
// occupe uniquement la zone de contenu → la sidebar reste visible ET cliquable.
final contentOverlayProvider = StateProvider<Widget?>((_) => null);

/// Affiche [child] par-dessus le contenu (sidebar préservée). [close] est passé
/// au builder pour refermer. Lisible depuis n'importe quel BuildContext.
void showContentOverlay(
    BuildContext context, Widget Function(VoidCallback close) builder) {
  final container = ProviderScope.containerOf(context, listen: false);
  void close() {
    if (container.read(contentOverlayProvider) != null) {
      container.read(contentOverlayProvider.notifier).state = null;
    }
  }

  container.read(contentOverlayProvider.notifier).state = builder(close);
}

void closeContentOverlay(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(contentOverlayProvider.notifier).state = null;
}

// ─── Nav item model ───────────────────────────────────────────────────────
class _NavItem {
  const _NavItem({
    this.icon,
    this.label = '',
    this.route = '',
    this.badge = 0,
    this.isDivider = false,
    this.isSection = false,
    this.sectionLabel = '',
    this.isInfo = false,
    this.isLoadingTile = false,
  });
  final IconData? icon;
  final String label;
  final String route;
  final int badge;
  final bool isDivider;
  final bool isSection;
  final String sectionLabel;

  /// Tuile non cliquable d'information (ex. « aucun module », « synchro… »).
  final bool isInfo;

  /// Tuile d'information affichant un petit spinner (état de chargement).
  final bool isLoadingTile;

  // ignore: unused_field — conservé pour usage futur (dividers ad-hoc)
  static const divider = _NavItem(isDivider: true);
  static _NavItem section(String label) =>
      _NavItem(isSection: true, sectionLabel: label);
  static _NavItem info(String label, {bool loading = false}) =>
      _NavItem(label: label, isInfo: true, isLoadingTile: loading);
}

// ─── Navigation par rôle ──────────────────────────────────────────────────
List<_NavItem> _navItemsFor(ProfileModel profile) {
  switch (profile.role) {
    case AppConstants.roleSuperAdmin:
      return [
        const _NavItem(
          icon: Icons.dashboard_rounded,
          label: 'Tableau de bord',
          route: Routes.superDashboard,
        ),
        _NavItem.section('GROUPES & ABONNEMENTS'),
        const _NavItem(
          icon: Icons.school_rounded,
          label: 'Groupes Scolaires',
          route: Routes.superGroupes,
        ),
        const _NavItem(
          icon: Icons.admin_panel_settings_rounded,
          label: 'Administrateurs',
          route: Routes.superAdministrateurs,
        ),
        const _NavItem(
          icon: Icons.inventory_2_rounded,
          label: "Plans d'abonnement",
          route: Routes.superPlans,
        ),
        const _NavItem(
          icon: Icons.receipt_long_rounded,
          label: 'Abonnements',
          route: Routes.superAbonnements,
        ),
        const _NavItem(
          icon: Icons.description_rounded,
          label: 'Factures',
          route: Routes.superFactures,
        ),
        const _NavItem(
          icon: Icons.receipt_rounded,
          label: 'Reçus de paiement',
          route: Routes.superRecus,
        ),
        const _NavItem(
          icon: Icons.payment_rounded,
          label: 'Modes de paiement',
          route: Routes.superPaiements,
        ),
        _NavItem.section('PLATEFORME'),
        const _NavItem(
          icon: Icons.extension_rounded,
          label: 'Catégories & Modules',
          route: Routes.superModules,
        ),
        const _NavItem(
          icon: Icons.psychology_rounded,
          label: 'Intelligence Artificielle',
          route: Routes.superIa,
        ),
        // Communication = tissu natif de la plateforme (jamais vendu, non
        // désactivable). Items directs (pas de déroulant) → cohérent avec
        // l'espace admin_groupe.
        _NavItem.section('COMMUNICATION'),
        const _NavItem(
          icon: Icons.campaign_rounded,
          label: 'Annonces & Agenda',
          route: Routes.superAnnonces,
        ),
        const _NavItem(
          icon: Icons.mail_rounded,
          label: 'Messages',
          route: Routes.superMessagesInbox,
        ),
        const _NavItem(
          icon: Icons.confirmation_num_rounded,
          label: 'Tickets support',
          route: Routes.superTickets,
        ),
        _NavItem.section('RAPPORTS & SYSTÈME'),
        const _NavItem(
          icon: Icons.list_alt_rounded,
          label: "Journal d'audit",
          route: Routes.superAudit,
        ),
        const _NavItem(
          icon: Icons.bar_chart_rounded,
          label: 'Rapports & Statistiques',
          route: Routes.superRapports,
        ),
        const _NavItem(
          icon: Icons.settings_rounded,
          label: 'Paramètres plateforme',
          route: Routes.superParametres,
        ),
      ];

    case AppConstants.roleAdminGroupe:
      return [
        const _NavItem(
          icon: Icons.dashboard_rounded,
          label: 'Tableau de bord',
          route: Routes.adminDashboard,
        ),
        _NavItem.section('GESTION'),
        // Ordre workflow : on crée les écoles, puis les profils, puis on assigne les utilisateurs
        const _NavItem(
          icon: Icons.school_rounded,
          label: 'Mes Écoles',
          route: Routes.adminEcoles,
        ),
        const _NavItem(
          icon: Icons.event_note_rounded,
          label: 'Années scolaires',
          route: Routes.adminAnnees,
        ),
        const _NavItem(
          icon: Icons.lock_rounded,
          label: "Profils d'accès",
          route: Routes.adminProfils,
        ),
        const _NavItem(
          icon: Icons.people_rounded,
          label: 'Utilisateurs',
          route: Routes.adminUtilisateurs,
        ),
        _NavItem.section('PILOTAGE'),
        const _NavItem(
          icon: Icons.bar_chart_rounded,
          label: 'Rapports',
          route: Routes.adminRapports,
        ),
        const _NavItem(
          icon: Icons.credit_card_rounded,
          label: 'Abonnement',
          route: Routes.adminAbonnement,
        ),
        // Communication = tissu natif de la plateforme (jamais vendu, non désactivable)
        _NavItem.section('COMMUNICATION'),
        const _NavItem(
          icon: Icons.campaign_rounded,
          label: 'Annonces & Agenda',
          route: Routes.adminAnnonces,
        ),
        const _NavItem(
          icon: Icons.forum_rounded,
          label: 'Messagerie',
          route: Routes.adminMessagerie,
        ),
        _NavItem.section('SYSTÈME'),
        const _NavItem(
          icon: Icons.confirmation_num_rounded,
          label: 'Tickets',
          route: Routes.adminSupport,
        ),
        const _NavItem(
          icon: Icons.menu_book_rounded,
          label: "Journal d'audit",
          route: Routes.adminAudit,
        ),
        const _NavItem(
          icon: Icons.settings_rounded,
          label: 'Paramètres',
          route: Routes.adminParametres,
        ),
      ];

    default:
      // Personnel école / parent / élève → sidebar dynamique (voir _staffNavItems).
      // Repli statique minimal si les providers ne sont pas encore prêts.
      return const [
        _NavItem(
          icon: Icons.dashboard_rounded,
          label: 'Tableau de bord',
          route: Routes.userDashboard,
        ),
      ];
  }
}

/// Sidebar du personnel scolaire — dynamique, construite depuis le catalogue
/// (verrou 2 : plan) ∩ les permissions du membre (verrou 3 : `can_read`).
/// La section COMMUNICATION reste native (tissu plateforme, hors catalogue).
List<_NavItem> _staffNavItems(WidgetRef ref, ProfileModel profile) {
  final isEleve = profile.role == AppConstants.roleEleve;
  final isParent = profile.role == AppConstants.roleParent;

  final groupedAsync = ref.watch(modulesGroupedByCategoryProvider);
  final permsAsync = ref.watch(myPermissionsProvider);
  final grouped = groupedAsync.valueOrNull ?? const {};
  final perms = permsAsync.valueOrNull ?? const {};
  // Distinguer « en cours de synchro » de « réellement aucun module » : sans
  // ça, un personnel voit une sidebar vide pendant la 1ʳᵉ synchro PowerSync et
  // croit que rien ne marche.
  final modulesSyncing =
      (groupedAsync.isLoading && !groupedAsync.hasValue) ||
      (permsAsync.isLoading && !permsAsync.hasValue);
  final modulesError = groupedAsync.hasError || permsAsync.hasError;

  final items = <_NavItem>[
    const _NavItem(
      icon: Icons.dashboard_rounded,
      label: 'Tableau de bord',
      route: Routes.userDashboard,
    ),
  ];

  // Calendrier scolaire = config NATIVE réservée à la direction (années /
  // trimestres / séquences). Hors catalogue : ce n'est pas un module vendable.
  if (AppConstants.directionRoles.contains(profile.role)) {
    items.add(_NavItem.section('ÉTABLISSEMENT'));
    items.add(
      const _NavItem(
        icon: Icons.event_note_rounded,
        label: 'Calendrier scolaire',
        route: Routes.calendrier,
      ),
    );
    // Journal d'audit = outil natif de direction (consultation online).
    items.add(
      const _NavItem(
        icon: Icons.fact_check_outlined,
        label: "Journal d'audit",
        route: Routes.userAudit,
      ),
    );
  }

  // Modules accordés, regroupés par catégorie (ordre = display_order du SQL).
  var moduleCount = 0;
  for (final entry in grouped.entries) {
    final cat = entry.key;
    final visible = entry.value
        .where((m) => perms[m.slug]?.canRead ?? false)
        .toList();
    if (visible.isEmpty) continue;
    items.add(_NavItem.section(cat.name.toUpperCase()));
    for (final m in visible) {
      moduleCount++;
      items.add(
        _NavItem(
          icon: moduleIcon(m.slug),
          label: m.name,
          route: moduleRoute(m.slug),
        ),
      );
    }
  }

  // Aucun module rendu : afficher un état explicite (jamais une zone vide muette)
  // sauf pour élève/parent dont l'essentiel passe par Communication / Espace.
  if (moduleCount == 0 && !isEleve && !isParent) {
    items.add(_NavItem.section('MES MODULES'));
    items.add(
      modulesSyncing
          ? _NavItem.info('Synchronisation…', loading: true)
          : modulesError
          ? _NavItem.info('Erreur de synchronisation')
          : _NavItem.info('Aucun module attribué'),
    );
  }

  // Communication = tissu natif (jamais vendu, non désactivable).
  // Les notifications NE sont PAS une page : cloche + drawer dans le header,
  // structure identique pour tous les rôles (super_admin → personnel école).
  items.add(_NavItem.section('COMMUNICATION'));
  items.add(
    const _NavItem(
      icon: Icons.campaign_rounded,
      label: 'Annonces & Agenda',
      route: Routes.annonces,
    ),
  );
  if (!isEleve) {
    // Sauvegarde mineurs : les élèves n'ont pas la messagerie privée.
    items.add(
      const _NavItem(
        icon: Icons.forum_rounded,
        label: 'Messagerie',
        route: Routes.messagerie,
      ),
    );
  }
  if (isParent) {
    items.add(
      const _NavItem(
        icon: Icons.family_restroom_rounded,
        label: 'Espace Parent',
        route: Routes.espaceParent,
      ),
    );
  }

  items.add(_NavItem.section('SYSTÈME'));
  if (!isEleve && !isParent) {
    // Demandes au support plateforme : réservé au personnel de l'école.
    items.add(
      const _NavItem(
        icon: Icons.confirmation_num_rounded,
        label: 'Tickets',
        route: Routes.userSupport,
      ),
    );
  }
  items.add(
    const _NavItem(
      icon: Icons.settings_rounded,
      label: 'Paramètres',
      route: Routes.userParametres,
    ),
  );
  return items;
}

// ─── AppShell ─────────────────────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.title,
    this.actions,
  });
  final Widget child;
  final String title;
  final List<Widget>? actions;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Dernière route connue → referme la visionneuse de contenu au changement.
  String? _lastLoc;

  // ── Sidebar width (drag-resizable) ───────────────────────────────────────
  double _sidebarWidth = _kSidebarExpanded;
  bool get _expanded => _sidebarWidth > 120;

  void _toggleSidebar() {
    final wasExpanded = _expanded;
    setState(() {
      _sidebarWidth = wasExpanded ? _kSidebarCollapsed : _kSidebarExpanded;
    });
  }

  void _onSidebarDrag(double delta) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + delta).clamp(_kSidebarCollapsed, 340.0);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final role = ref.read(authNotifierProvider).valueOrNull?.role;
      if (role == AppConstants.roleSuperAdmin) {
        ref.read(superDashboardProvider);
        ref.read(schoolGroupsProvider);
        ref.read(administratorsProvider);
        ref.read(modulesProvider);
        ref.read(notificationsProvider);
        ref.read(messagesProvider);
      } else if (role == AppConstants.roleAdminGroupe) {
        ref.read(adminDashboardProvider);
        ref.read(adminModulesCatalogProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded;
    final authState = ref.watch(authNotifierProvider);
    final profile = authState.valueOrNull;
    final syncStatus = ref.watch(syncStatusProvider);
    final isStaff =
        profile != null &&
        profile.role != AppConstants.roleSuperAdmin &&
        profile.role != AppConstants.roleAdminGroupe;
    // Sur poste partagé, la sidebar suit l'AGENT ACTIF (rôle + profil d'accès),
    // pas l'utilisateur qui a authentifié l'appareil.
    final activeProfile = isStaff
        ? (ref.watch(myProfileRowProvider).valueOrNull ?? profile)
        : profile;
    final navItems = profile == null
        ? <_NavItem>[]
        : (isStaff ? _staffNavItems(ref, activeProfile!) : _navItemsFor(profile));
    final currentLoc = GoRouterState.of(context).matchedLocation;

    // Visionneuse confinée au contenu (sidebar préservée). On la referme
    // automatiquement si l'utilisateur change de page via la sidebar.
    final contentOverlay = ref.watch(contentOverlayProvider);
    if (currentLoc != _lastLoc) {
      _lastLoc = currentLoc;
      if (contentOverlay != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(contentOverlayProvider.notifier).state = null;
          }
        });
      }
    }

    // Entrée dynamique « Modules du groupe » (admin_groupe only)
    if (profile?.role == AppConstants.roleAdminGroupe) {
      final catalog = ref.watch(adminModulesCatalogProvider).valueOrNull;
      if (catalog != null && catalog.categories.isNotEmpty) {
        navItems.add(_NavItem.section('MODULES'));
        navItems.add(
          const _NavItem(
            icon: Icons.apps_rounded,
            label: 'Modules du groupe',
            route: Routes.adminModules,
          ),
        );
      }
    }

    // Séparer les items SYSTÈME (pinned bas) du reste (scrollable)
    final mainItems = <_NavItem>[];
    final sysItems = <_NavItem>[];
    bool inSystem = false;
    for (final item in navItems) {
      final isSystemSection =
          item.isSection && item.sectionLabel.contains('SYSTÈME');
      if (isSystemSection) {
        inSystem = true;
        sysItems.add(item);
      } else if (item.isSection && inSystem) {
        inSystem = false;
        mainItems.add(item);
      } else if (inSystem) {
        sysItems.add(item);
      } else {
        mainItems.add(item);
      }
    }

    // Centre de notifications (cloche + drawer) : identique pour TOUS les rôles.
    final canNotif = profile != null;

    // Badge messagerie déplacé du header vers la sidebar (signal conservé)
    final msgUnread = profile != null
        ? (ref.watch(unreadMessagesCountProvider).valueOrNull ?? 0)
        : 0;

    return Scaffold(
      backgroundColor: _kSurface,
      endDrawer: canNotif ? const NotificationsDrawer() : null,
      body: Row(
        children: [
          // ── Sidebar ────────────────────────────────────────────────────
          SizedBox(
            width: _sidebarWidth,
            child: Container(
              color: _kNavyDark,
              child: Column(
                children: [
                  _SidebarHeader(expanded: expanded),
                  // Items principaux (scrollables)
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: mainItems
                          .map(
                            (item) => _buildNavItem(
                              item,
                              expanded,
                              currentLoc,
                              msgUnread,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  // Items SYSTÈME (pinned juste au-dessus du footer)
                  if (sysItems.isNotEmpty)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: sysItems
                          .map(
                            (item) => _buildNavItem(
                              item,
                              expanded,
                              currentLoc,
                              msgUnread,
                            ),
                          )
                          .toList(),
                    ),
                  _SidebarFooter(
                    expanded: expanded,
                    profile: activeProfile,
                    syncStatus: syncStatus,
                  ),
                ],
              ),
            ),
          ),

          // ── Drag handle ────────────────────────────────────────────────
          _SidebarResizeHandle(onDrag: _onSidebarDrag),

          // ── Contenu principal ──────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _AppHeader(
                  title: widget.title,
                  profile: activeProfile,
                  isStaff: isStaff,
                  sidebarExpanded: expanded,
                  actions: widget.actions,
                  onToggleSidebar: _toggleSidebar,
                ),
                if (isStaff) const ReadOnlyYearBanner(),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: widget.child),
                      // Visionneuse image/PDF confinée (sidebar préservée).
                      if (contentOverlay != null)
                        Positioned.fill(child: contentOverlay),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    _NavItem item,
    bool expanded,
    String currentLoc,
    int msgUnread,
  ) {
    // ── Séparateur fin ─────────────────────────────────────────────────
    if (item.isDivider) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 14 : 10,
          vertical: 4,
        ),
        child: Divider(height: 1, color: _kWhite.withValues(alpha: 0.10)),
      );
    }

    // ── Label de section ───────────────────────────────────────────────
    if (item.isSection) {
      if (!expanded) {
        // En mode réduit : juste une petite ligne de séparation
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Divider(height: 1, color: _kWhite.withValues(alpha: 0.08)),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 5),
        child: Row(
          children: [
            Text(
              item.sectionLabel,
              style: TextStyle(
                color: _kWhite.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Divider(height: 1, color: _kWhite.withValues(alpha: 0.10)),
            ),
          ],
        ),
      );
    }

    // ── Tuile d'information non cliquable (synchro / aucun module) ──────
    if (item.isInfo) {
      if (!expanded) {
        return item.isLoadingTile
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kAccent,
                    ),
                  ),
                ),
              )
            : const SizedBox(height: 8);
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 14, 6),
        child: Row(
          children: [
            if (item.isLoadingTile)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kAccent,
                ),
              )
            else
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: _kWhite.withValues(alpha: 0.4),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: _kWhite.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Badge messagerie dynamique (signal déplacé du header)
    final isMsg =
        item.route == Routes.adminMessagerie || item.route == Routes.messagerie;
    final effItem = (isMsg && msgUnread > 0)
        ? _NavItem(
            icon: item.icon,
            label: item.label,
            route: item.route,
            badge: msgUnread,
          )
        : item;

    final isActive = currentLoc.startsWith(item.route) && item.route != '/';

    return _NavTile(
      item: effItem,
      isActive: isActive,
      expanded: expanded,
      onTap: () => context.go(item.route),
    );
  }
}

// ─── Sidebar Header — juste le bouton toggle ─────────────────────────────
class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kHeaderHeight,
      padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 10),
      decoration: BoxDecoration(
        color: _kNavyDeep,
        border: Border(
          bottom: BorderSide(color: _kWhite.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/logo.svg',
            width: expanded ? 42 : 36,
            height: expanded ? 42 : 36,
          ),
          if (expanded) ...[
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'E-PILOTE CONGO',
                    style: TextStyle(
                      color: _kWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'Gestion scolaire',
                    style: TextStyle(
                      color: _kGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Sidebar Drag Handle ──────────────────────────────────────────────────
class _SidebarResizeHandle extends StatefulWidget {
  const _SidebarResizeHandle({required this.onDrag});
  final ValueChanged<double> onDrag;

  @override
  State<_SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<_SidebarResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 5,
          color: _hovered
              ? _kGreen.withValues(alpha: 0.55)
              : _kNavyDark.withValues(alpha: 0.40),
        ),
      ),
    );
  }
}

// ─── Nav Tile ─────────────────────────────────────────────────────────────
class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.isActive,
    required this.expanded,
    required this.onTap,
  });
  final _NavItem item;
  final bool isActive;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isActive = widget.isActive;
    final expanded = widget.expanded;

    return Tooltip(
      message: expanded ? '' : item.label,
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            margin: EdgeInsets.symmetric(
              horizontal: expanded ? 6 : 4,
              vertical: 1,
            ),
            padding: const EdgeInsets.only(left: 10, right: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? _kNavy
                  : _hovered
                  ? _kWhite.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: isActive ? _kGreen : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      item.icon ?? Icons.circle_outlined,
                      size: 19,
                      color: isActive
                          ? _kWhite
                          : _kWhite.withValues(alpha: 0.6),
                    ),
                    if (item.badge > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${item.badge}',
                            style: const TextStyle(
                              color: _kWhite,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isActive
                            ? _kWhite
                            : _kWhite.withValues(alpha: 0.80),
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar Footer ───────────────────────────────────────────────────────
class _SidebarFooter extends ConsumerWidget {
  const _SidebarFooter({
    required this.expanded,
    required this.profile,
    required this.syncStatus,
  });
  final bool expanded;
  final ProfileModel? profile;
  final AsyncValue<dynamic> syncStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Offline-first : « synchronisé » dès qu'une synchro a réussi (lastSyncedAt),
    // pas seulement quand la connexion live est active.
    final syncUi = ref.watch(syncIndicatorProvider);
    final isSynced = syncUi == SyncUiState.synced;
    final isStaff =
        profile != null &&
        profile!.role != AppConstants.roleSuperAdmin &&
        profile!.role != AppConstants.roleAdminGroupe;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _kWhite.withValues(alpha: 0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sync status (personnel scolaire uniquement)
          if (isStaff) ...[
            if (expanded)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _kWhite.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isSynced ? _kGreen : _kAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isSynced ? 'Synchronisé' : 'Hors ligne',
                      style: TextStyle(
                        color: _kWhite.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSynced ? _kGreen : _kAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],

          // Bouton déconnexion
          Tooltip(
            message: expanded ? '' : 'Déconnexion',
            child: InkWell(
              onTap: () async {
                // Vraie déconnexion appareil : on oublie l'agent sélectionné.
                ref.read(selectedAgentIdProvider.notifier).state = null;
                await ref.read(authNotifierProvider.notifier).signOut();
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 12 : 8,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisAlignment: expanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      size: 15,
                      color: Color(0xFFFF6B6B),
                    ),
                    if (expanded) ...[
                      const SizedBox(width: 9),
                      const Text(
                        'Déconnexion',
                        style: TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── App Header ───────────────────────────────────────────────────────────
class _AppHeader extends ConsumerWidget {
  const _AppHeader({
    required this.title,
    required this.profile,
    required this.isStaff,
    required this.sidebarExpanded,
    required this.onToggleSidebar,
    this.actions,
  });
  final String title;
  final ProfileModel? profile;
  final bool isStaff;
  final bool sidebarExpanded;
  final VoidCallback onToggleSidebar;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final displayName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : currentUser?.email ?? 'Utilisateur';
    final initials = _initials(displayName);
    final roleLabel = _roleLabel(profile?.role);
    final avatarColor = _avatarColor(profile?.role);
    // Cloche de notifications : présente pour tous les rôles connectés.
    final showComm = profile != null;
    final profileRoute = switch (profile?.role) {
      AppConstants.roleSuperAdmin => Routes.superProfil,
      AppConstants.roleAdminGroupe => Routes.adminProfil,
      _ => Routes.userProfil,
    };
    final settingsRoute = switch (profile?.role) {
      AppConstants.roleSuperAdmin => Routes.superParametres,
      AppConstants.roleAdminGroupe => Routes.adminParametres,
      _ => Routes.userParametres,
    };

    return Container(
      height: _kHeaderHeight,
      decoration: BoxDecoration(
        color: _kWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              sidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
              color: _kNavy,
              size: 22,
            ),
            onPressed: onToggleSidebar,
            tooltip: sidebarExpanded
                ? 'Réduire la navigation'
                : 'Ouvrir la navigation',
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: _kTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (isStaff) ...[const YearSelector(), const SizedBox(width: 10)],
          ...?actions,
          if (showComm) ...[
            Builder(
              builder: (context) => NotificationBell(
                onSeeAll: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Consumer(
            builder: (context, ref, _) {
              final themeMode = ref.watch(themeModeProvider);
              final isDark = themeMode == ThemeMode.dark;
              return Tooltip(
                message: isDark ? 'Mode clair' : 'Mode sombre',
                child: IconButton(
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_outlined,
                    color: _kTextMuted,
                    size: 22,
                  ),
                  onPressed: () {
                    ref.read(themeModeProvider.notifier).state = isDark
                        ? ThemeMode.light
                        : ThemeMode.dark;
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Mon compte',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                ref.read(selectedAgentIdProvider.notifier).state = null;
                await ref.read(authNotifierProvider.notifier).signOut();
              } else if (value == 'profile') {
                context.go(profileRoute);
              } else if (value == 'settings') {
                context.go(settingsRoute);
              } else if (value == 'switch_agent') {
                context.go(Routes.userAgents);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _kTextPrimary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      roleLabel,
                      style: const TextStyle(color: _kTextMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: _kNavy),
                    SizedBox(width: 10),
                    Text('Mon profil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18, color: _kNavy),
                    SizedBox(width: 10),
                    Text('Paramètres'),
                  ],
                ),
              ),
              // Poste partagé : bascule d'agent (personnel scolaire uniquement).
              if (profile != null &&
                  profile!.role != AppConstants.roleSuperAdmin &&
                  profile!.role != AppConstants.roleAdminGroupe)
                const PopupMenuItem(
                  value: 'switch_agent',
                  child: Row(
                    children: [
                      Icon(Icons.switch_account_outlined,
                          size: 18, color: _kNavy),
                      SizedBox(width: 10),
                      Text('Changer d’agent'),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Déconnexion', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarColor,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: _kWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (profile != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _shortName(displayName),
                          style: const TextStyle(
                            color: _kTextPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          roleLabel,
                          style: const TextStyle(
                            color: _kTextMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: _kTextMuted, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _shortName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0]} ${parts[1][0]}.';
    return name;
  }

  String _roleLabel(String? role) {
    switch (role) {
      case AppConstants.roleSuperAdmin:
        return 'Super Administrateur';
      case AppConstants.roleAdminGroupe:
        return 'Admin Groupe';
      case AppConstants.roleDirecteur:
        return 'Directeur';
      case AppConstants.roleProviseur:
        return 'Proviseur';
      case AppConstants.roleEnseignant:
        return 'Enseignant';
      case AppConstants.roleCpe:
        return 'CPE';
      case AppConstants.roleComptable:
        return 'Comptable';
      case AppConstants.roleSecretaire:
        return 'Secrétaire';
      case AppConstants.roleSurveillant:
        return 'Surveillant';
      case AppConstants.roleParent:
        return 'Parent';
      case AppConstants.roleEleve:
        return 'Élève';
      case AppConstants.roleInfirmier:
        return 'Infirmier';
      case AppConstants.roleResponsableCantine:
        return 'Resp. Cantine';
      default:
        return 'Utilisateur';
    }
  }

  Color _avatarColor(String? role) {
    switch (role) {
      case AppConstants.roleSuperAdmin:
        return _kNavy;
      case AppConstants.roleAdminGroupe:
        return _kGreen;
      default:
        return const Color(0xFF7C3AED);
    }
  }
}
