import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/routes.dart';
import '../../data/models/profile_model.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/super_admin/providers/super_dashboard_provider.dart';
import '../../features/super_admin/providers/school_groups_provider.dart';
import '../../features/super_admin/providers/administrators_provider.dart';
import '../../features/super_admin/providers/modules_provider.dart';
import '../../features/super_admin/providers/notifications_provider.dart';
import '../../features/super_admin/providers/messages_provider.dart';
import '../../features/admin_groupe/providers/admin_dashboard_provider.dart';
import '../../features/admin_groupe/providers/admin_nav_provider.dart';
import '../../services/powersync/powersync_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────
const Color _kNavyDeep    = Color(0xFF091828);
const Color _kNavyDark    = Color(0xFF0F2340);
const Color _kNavy        = Color(0xFF1E3A5F);
const Color _kGreen       = Color(0xFF009A44);
const Color _kAccent      = Color(0xFFFBBC04);
const Color _kWhite       = Colors.white;
const Color _kSurface     = Color(0xFFF0F4F8);
const Color _kTextPrimary = Color(0xFF0F172A);
const Color _kTextMuted   = Color(0xFF64748B);

const double _kSidebarExpanded  = 268;
const double _kSidebarCollapsed = 64;
const double _kHeaderHeight     = 68;

// ─── Sidebar state ────────────────────────────────────────────────────────
final sidebarExpandedProvider = StateProvider<bool>((_) => true);

// ─── Theme mode ───────────────────────────────────────────────────────────
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.light);

// ─── Nav item model ───────────────────────────────────────────────────────
class _NavItem {
  const _NavItem({
    this.icon,
    this.label = '',
    this.route = '',
    this.badge = 0,
    this.children = const [],
    this.isDivider = false,
    this.isSection = false,
    this.sectionLabel = '',
  });
  final IconData? icon;
  final String label;
  final String route;
  final int badge;
  final List<_NavItem> children;
  final bool isDivider;
  final bool isSection;
  final String sectionLabel;

  // ignore: unused_field — conservé pour usage futur (dividers ad-hoc)
  static const divider = _NavItem(isDivider: true);
  static _NavItem section(String label) =>
      _NavItem(isSection: true, sectionLabel: label);
}

// ─── Navigation par rôle ──────────────────────────────────────────────────
List<_NavItem> _navItemsFor(ProfileModel profile) {
  switch (profile.role) {
    case AppConstants.roleSuperAdmin:
      return [
        const _NavItem(icon: Icons.dashboard_rounded,             label: 'Tableau de bord',          route: Routes.superDashboard),
        _NavItem.section('GROUPES & ABONNEMENTS'),
        const _NavItem(icon: Icons.school_rounded,                label: 'Groupes Scolaires',         route: Routes.superGroupes),
        const _NavItem(icon: Icons.admin_panel_settings_rounded,  label: 'Administrateurs',           route: Routes.superAdministrateurs),
        const _NavItem(icon: Icons.inventory_2_rounded,           label: "Plans d'abonnement",        route: Routes.superPlans),
        const _NavItem(icon: Icons.receipt_long_rounded,          label: 'Abonnements',               route: Routes.superAbonnements),
        const _NavItem(icon: Icons.description_rounded,           label: 'Factures',                  route: Routes.superFactures),
        const _NavItem(icon: Icons.receipt_rounded,               label: 'Reçus de paiement',         route: Routes.superRecus),
        const _NavItem(icon: Icons.payment_rounded,               label: 'Modes de paiement',         route: Routes.superPaiements),
        _NavItem.section('PLATEFORME'),
        const _NavItem(icon: Icons.extension_rounded,             label: 'Catégories & Modules',      route: Routes.superModules),
        const _NavItem(icon: Icons.forum_rounded, label: 'Messagerie', route: Routes.superMessages, badge: 2, children: [
          _NavItem(icon: Icons.confirmation_num_rounded, label: 'Tickets support',    route: Routes.superTickets),
          _NavItem(icon: Icons.mail_rounded,             label: 'Messages',           route: Routes.superMessagesInbox),
          _NavItem(icon: Icons.campaign_rounded,         label: 'Annonces générales', route: Routes.superAnnonces),
        ]),
        const _NavItem(icon: Icons.notifications_rounded,         label: 'Notifications',             route: Routes.superNotifications, badge: 2),
        const _NavItem(icon: Icons.psychology_rounded,            label: 'Intelligence Artificielle', route: Routes.superIa),
        _NavItem.section('RAPPORTS & SYSTÈME'),
        const _NavItem(icon: Icons.list_alt_rounded,              label: "Journal d'audit",           route: Routes.superAudit),
        const _NavItem(icon: Icons.bar_chart_rounded,             label: 'Rapports & Statistiques',   route: Routes.superRapports),
        const _NavItem(icon: Icons.settings_rounded,              label: 'Paramètres plateforme',     route: Routes.superParametres),
      ];

    case AppConstants.roleAdminGroupe:
      return [
        const _NavItem(icon: Icons.dashboard_rounded,  label: 'Tableau de bord',  route: Routes.adminDashboard),
        _NavItem.section('GESTION'),
        // Ordre workflow : on crée les écoles, puis les profils, puis on assigne les utilisateurs
        const _NavItem(icon: Icons.school_rounded,     label: 'Mes Écoles',        route: Routes.adminEcoles),
        const _NavItem(icon: Icons.lock_rounded,       label: "Profils d'accès",   route: Routes.adminProfils),
        const _NavItem(icon: Icons.people_rounded,     label: 'Utilisateurs',      route: Routes.adminUtilisateurs),
        _NavItem.section('PILOTAGE'),
        const _NavItem(icon: Icons.bar_chart_rounded,  label: 'Rapports',          route: Routes.adminRapports),
        const _NavItem(icon: Icons.credit_card_rounded,label: 'Abonnement',        route: Routes.adminAbonnement),
        // Communication = tissu natif de la plateforme (jamais vendu, non désactivable)
        _NavItem.section('COMMUNICATION'),
        const _NavItem(icon: Icons.notifications_rounded, label: 'Notifications', route: Routes.adminNotifications),
        const _NavItem(icon: Icons.campaign_rounded,      label: 'Annonces',      route: Routes.adminAnnonces),
        const _NavItem(icon: Icons.forum_rounded,         label: 'Messagerie',    route: Routes.adminMessagerie),
        const _NavItem(icon: Icons.event_rounded,         label: 'Événements',    route: Routes.adminEvenements),
        _NavItem.section('SYSTÈME'),
        const _NavItem(icon: Icons.menu_book_rounded,  label: "Journal d'audit",   route: Routes.adminAudit),
        const _NavItem(icon: Icons.settings_rounded,   label: 'Paramètres',        route: Routes.adminParametres),
      ];

    default:
      // Personnel école / parent / élève
      final isEleve  = profile.role == AppConstants.roleEleve;
      final isParent = profile.role == AppConstants.roleParent;
      return [
        const _NavItem(icon: Icons.dashboard_rounded,     label: 'Tableau de bord',   route: Routes.userDashboard),
        _NavItem.section('SCOLARITÉ'),
        const _NavItem(icon: Icons.people_rounded,        label: 'Élèves',            route: Routes.eleves),
        const _NavItem(icon: Icons.class_rounded,         label: 'Classes',           route: Routes.classes),
        const _NavItem(icon: Icons.grade_rounded,         label: 'Notes & Bulletins', route: Routes.notes),
        const _NavItem(icon: Icons.calendar_today_rounded,label: 'Présences',         route: Routes.presences),
        _NavItem.section('GESTION'),
        const _NavItem(icon: Icons.attach_money_rounded,  label: 'Finance',           route: Routes.paiements),
        const _NavItem(icon: Icons.bar_chart_rounded,     label: 'Rapports',          route: Routes.userRapports),
        // Communication = tissu natif de la plateforme (jamais vendu, non désactivable)
        _NavItem.section('COMMUNICATION'),
        const _NavItem(icon: Icons.notifications_rounded, label: 'Notifications', route: Routes.notifications),
        const _NavItem(icon: Icons.campaign_rounded,      label: 'Annonces',      route: Routes.annonces),
        // Sauvegarde mineurs : les élèves n'ont pas la messagerie privée
        if (!isEleve)
          const _NavItem(icon: Icons.forum_rounded,       label: 'Messagerie',    route: Routes.messagerie),
        const _NavItem(icon: Icons.event_rounded,         label: 'Événements',    route: Routes.evenements),
        // Espace Parent : réservé aux comptes parents (désactivable par école — à câbler)
        if (isParent)
          const _NavItem(icon: Icons.family_restroom_rounded, label: 'Espace Parent', route: Routes.espaceParent),
        _NavItem.section('SYSTÈME'),
        const _NavItem(icon: Icons.settings_rounded,      label: 'Paramètres',        route: Routes.userParametres),
      ];
  }
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
  final Set<String> _expandedMenus = {};

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
    final expanded   = _expanded;
    final authState  = ref.watch(authNotifierProvider);
    final profile    = authState.valueOrNull;
    final syncStatus = ref.watch(syncStatusProvider);
    final navItems   = profile != null ? _navItemsFor(profile) : <_NavItem>[];
    final currentLoc = GoRouterState.of(context).matchedLocation;

    // Entrée dynamique « Modules du groupe » (admin_groupe only)
    if (profile?.role == AppConstants.roleAdminGroupe) {
      final catalog = ref.watch(adminModulesCatalogProvider).valueOrNull;
      if (catalog != null && catalog.categories.isNotEmpty) {
        navItems.add(_NavItem.section('MODULES'));
        navItems.add(const _NavItem(
          icon: Icons.apps_rounded,
          label: 'Modules du groupe',
          route: Routes.adminModules,
        ));
      }
    }

    // Séparer les items SYSTÈME (pinned bas) du reste (scrollable)
    final mainItems = <_NavItem>[];
    final sysItems  = <_NavItem>[];
    bool inSystem = false;
    for (final item in navItems) {
      final isSystemSection = item.isSection && item.sectionLabel.contains('SYSTÈME');
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

    return Scaffold(
      backgroundColor: _kSurface,
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
                          .map((item) => _buildNavItem(item, expanded, currentLoc))
                          .toList(),
                    ),
                  ),
                  // Items SYSTÈME (pinned juste au-dessus du footer)
                  if (sysItems.isNotEmpty)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: sysItems
                          .map((item) => _buildNavItem(item, expanded, currentLoc))
                          .toList(),
                    ),
                  _SidebarFooter(
                    expanded: expanded,
                    profile: profile,
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
                  profile: profile,
                  sidebarExpanded: expanded,
                  actions: widget.actions,
                  onToggleSidebar: _toggleSidebar,
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, bool expanded, String currentLoc) {
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
        child: Row(children: [
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
            child: Divider(
              height: 1,
              color: _kWhite.withValues(alpha: 0.10),
            ),
          ),
        ]),
      );
    }

    final isActive    = currentLoc.startsWith(item.route) && item.route != '/';
    final hasChildren = item.children.isNotEmpty;
    final isMenuOpen  = _expandedMenus.contains(item.route);

    return Column(
      children: [
        _NavTile(
          item: item,
          isActive: isActive,
          expanded: expanded,
          trailing: hasChildren
              ? Icon(
                  isMenuOpen ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: _kWhite.withValues(alpha: 0.6),
                )
              : null,
          onTap: () {
            if (hasChildren) {
              setState(() {
                if (isMenuOpen) {
                  _expandedMenus.remove(item.route);
                } else {
                  _expandedMenus.add(item.route);
                }
              });
            } else {
              context.go(item.route);
            }
          },
        ),
        if (hasChildren && isMenuOpen && expanded)
          Column(
            children: item.children
                .map((child) => _NavTile(
                      item: child,
                      isActive: currentLoc == child.route,
                      expanded: expanded,
                      isChild: true,
                      onTap: () => context.go(child.route),
                    ))
                .toList(),
          ),
      ],
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
        border: Border(bottom: BorderSide(color: _kWhite.withValues(alpha: 0.08))),
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
                  Text('E-PILOTE CONGO', style: TextStyle(
                    color: _kWhite,
                    fontSize: 13, fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  )),
                  Text('Gestion scolaire', style: TextStyle(
                    color: _kGreen,
                    fontSize: 10, fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  )),
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
      onExit:  (_) => setState(() => _hovered = false),
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
    this.isChild = false,
    this.trailing,
  });
  final _NavItem item;
  final bool isActive;
  final bool expanded;
  final bool isChild;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item     = widget.item;
    final isActive = widget.isActive;
    final expanded = widget.expanded;

    return Tooltip(
      message: expanded ? '' : item.label,
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            margin: EdgeInsets.symmetric(
              horizontal: expanded ? 6 : 4,
              vertical: 1,
            ),
            padding: EdgeInsets.only(
              left: widget.isChild ? (expanded ? 30 : 8) : 10,
              right: 10,
            ),
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
                        top: -4, right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '${item.badge}',
                            style: const TextStyle(
                              color: _kWhite,
                              fontSize: 9, fontWeight: FontWeight.bold,
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
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ?widget.trailing,
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
    final isSyncing = syncStatus.valueOrNull?.connected ?? false;
    final isStaff   = profile != null &&
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _kWhite.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: isSyncing ? _kGreen : _kAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSyncing ? 'Synchronisé' : 'Hors ligne',
                    style: TextStyle(
                      color: _kWhite.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ]),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: isSyncing ? _kGreen : _kAccent,
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
                    const Icon(Icons.logout_rounded, size: 15, color: Color(0xFFFF6B6B)),
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

// ─── Header Badge Button ─────────────────────────────────────────────────
class _HeaderBadgeButton extends StatelessWidget {
  const _HeaderBadgeButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = 0,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, color: _kTextMuted, size: 22),
          onPressed: onPressed,
          tooltip: tooltip,
        ),
        if (badge > 0)
          Positioned(
            top: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── App Header ───────────────────────────────────────────────────────────
class _AppHeader extends ConsumerWidget {

  const _AppHeader({
    required this.title,
    required this.profile,
    required this.sidebarExpanded,
    required this.onToggleSidebar,
    this.actions,
  });
  final String title;
  final ProfileModel? profile;
  final bool sidebarExpanded;
  final VoidCallback onToggleSidebar;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final displayName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : currentUser?.email ?? 'Utilisateur';
    final initials    = _initials(displayName);
    final roleLabel   = _roleLabel(profile?.role);
    final avatarColor = _avatarColor(profile?.role);
    final isSuper       = profile?.role == AppConstants.roleSuperAdmin;
    final isAdminGroupe = profile?.role == AppConstants.roleAdminGroupe;
    final notifBadge  = isSuper ? ref.watch(notifBadgeProvider) : 0;
    final msgBadge    = isSuper
        ? (ref.watch(messagesProvider).valueOrNull?.unreadCount ?? 0)
        : 0;
    final profileRoute  = profile?.role == AppConstants.roleAdminGroupe
        ? Routes.adminProfil
        : Routes.superProfil;
    final settingsRoute = profile?.role == AppConstants.roleAdminGroupe
        ? Routes.adminParametres
        : Routes.superParametres;

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
            tooltip: sidebarExpanded ? 'Réduire la navigation' : 'Ouvrir la navigation',
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
          ...?actions,
          if (isSuper) ...[
            _HeaderBadgeButton(
              icon: Icons.forum_outlined,
              badge: msgBadge,
              tooltip: 'Messagerie',
              onPressed: () => context.go(Routes.superMessagesInbox),
            ),
            const SizedBox(width: 4),
            _HeaderBadgeButton(
              icon: Icons.notifications_outlined,
              badge: notifBadge,
              tooltip: 'Notifications',
              onPressed: () => context.go(Routes.superNotifications),
            ),
            const SizedBox(width: 4),
          ] else if (isAdminGroupe) ...[
            _HeaderBadgeButton(
              icon: Icons.forum_outlined,
              tooltip: 'Messagerie',
              onPressed: () => context.go(Routes.adminMessagerie),
            ),
            const SizedBox(width: 4),
            _HeaderBadgeButton(
              icon: Icons.notifications_outlined,
              tooltip: 'Notifications',
              onPressed: () => context.go(Routes.adminNotifications),
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
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                    color: _kTextMuted,
                    size: 22,
                  ),
                  onPressed: () {
                    ref.read(themeModeProvider.notifier).state =
                        isDark ? ThemeMode.light : ThemeMode.dark;
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Mon compte',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authNotifierProvider.notifier).signOut();
              } else if (value == 'profile') {
                context.go(profileRoute);
              } else if (value == 'settings') {
                context.go(settingsRoute);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _kTextPrimary,
                          fontSize: 13,
                        )),
                    Text(roleLabel,
                        style: const TextStyle(color: _kTextMuted, fontSize: 11)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'profile',
                child: Row(children: [
                  Icon(Icons.person_outline, size: 18, color: _kNavy),
                  SizedBox(width: 10),
                  Text('Mon profil'),
                ]),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(children: [
                  Icon(Icons.settings_outlined, size: 18, color: _kNavy),
                  SizedBox(width: 10),
                  Text('Paramètres'),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Déconnexion', style: TextStyle(color: Colors.red)),
                ]),
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
                          style: const TextStyle(color: _kTextMuted, fontSize: 10),
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
      case AppConstants.roleSuperAdmin:         return 'Super Administrateur';
      case AppConstants.roleAdminGroupe:        return 'Admin Groupe';
      case AppConstants.roleDirecteur:          return 'Directeur';
      case AppConstants.roleProviseur:          return 'Proviseur';
      case AppConstants.roleEnseignant:         return 'Enseignant';
      case AppConstants.roleCpe:                return 'CPE';
      case AppConstants.roleComptable:          return 'Comptable';
      case AppConstants.roleSecretaire:         return 'Secrétaire';
      case AppConstants.roleSurveillant:        return 'Surveillant';
      case AppConstants.roleParent:             return 'Parent';
      case AppConstants.roleEleve:              return 'Élève';
      case AppConstants.roleInfirmier:          return 'Infirmier';
      case AppConstants.roleResponsableCantine: return 'Resp. Cantine';
      default:                                  return 'Utilisateur';
    }
  }

  Color _avatarColor(String? role) {
    switch (role) {
      case AppConstants.roleSuperAdmin:  return _kNavy;
      case AppConstants.roleAdminGroupe: return _kGreen;
      default:                           return const Color(0xFF7C3AED);
    }
  }
}
