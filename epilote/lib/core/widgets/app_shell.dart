import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/super_admin/providers/super_dashboard_provider.dart';
import '../../features/super_admin/providers/school_groups_provider.dart';
import '../../features/super_admin/providers/administrators_provider.dart';
import '../../features/super_admin/providers/modules_provider.dart';
import '../../features/communication/providers/notifications_provider.dart';
import '../../features/communication/providers/message_unread_provider.dart';
import '../../features/communication/widgets/notifications_drawer.dart';
import '../../features/communication/providers/messages_provider.dart';
import '../../features/admin_groupe/providers/admin_dashboard_provider.dart';
import '../../features/admin_groupe/providers/admin_nav_provider.dart';
import '../../features/user/providers/user_profile_provider.dart';
import 'admin_ui.dart' show kSurface;
import 'pending_uploads_banner.dart';
import 'sync_failure_banner.dart';
import 'subscription_banner.dart';
import '../../licensing/presentation/license_banner.dart';
import 'app_shell/app_header.dart';
import 'app_shell/app_shell_theme.dart';
import 'app_shell/app_sidebar.dart';
import 'app_shell/nav_config.dart';
import 'app_shell/nav_models.dart';
import 'app_shell/resize_handle.dart';
import 'app_shell/shell_providers.dart';
import 'year_selector.dart';

// API publique de niveau shell (providers + visionneuse de contenu) : conservée
// ici pour que les ~43 importeurs de `app_shell.dart` continuent de fonctionner.
export 'app_shell/shell_providers.dart'
    show
        sidebarExpandedProvider,
        contentOverlayProvider,
        showContentOverlay,
        closeContentOverlay;

/// Coquille applicative : sidebar (redimensionnable) + header + zone de contenu,
/// avec une visionneuse confinée qui préserve la sidebar.
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

  double _sidebarWidth = kSidebarExpandedWidth;
  Duration _widthAnim = Duration.zero;
  bool get _expanded => _sidebarWidth > kSidebarCollapseThreshold;

  void _toggleSidebar() {
    setState(() {
      _widthAnim = const Duration(milliseconds: 200);
      _sidebarWidth =
          _expanded ? kSidebarCollapsedWidth : kSidebarExpandedWidth;
    });
  }

  void _onSidebarDrag(double delta) {
    setState(() {
      _widthAnim = Duration.zero; // suivi instantané du curseur
      _sidebarWidth = (_sidebarWidth + delta)
          .clamp(kSidebarCollapsedWidth, kSidebarMaxWidth);
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
    final profile = ref.watch(authNotifierProvider).valueOrNull;
    final isStaff = profile != null &&
        profile.role != AppConstants.roleSuperAdmin &&
        profile.role != AppConstants.roleAdminGroupe;
    // Sur poste partagé, la sidebar suit l'AGENT ACTIF (rôle + profil d'accès),
    // pas l'utilisateur qui a authentifié l'appareil.
    final activeProfile = isStaff
        ? (ref.watch(myProfileRowProvider).valueOrNull ?? profile)
        : profile;
    final sections = profile == null
        ? const <NavSection>[]
        : buildNavSections(ref, activeProfile!);
    final currentLoc = GoRouterState.of(context).matchedLocation;

    // Referme automatiquement la visionneuse de contenu au changement de route.
    final contentOverlay = ref.watch(contentOverlayProvider);
    if (currentLoc != _lastLoc) {
      _lastLoc = currentLoc;
      if (contentOverlay != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(contentOverlayProvider.notifier).state = null;
        });
      }
    }

    final msgUnread = profile != null
        ? (ref.watch(unreadMessagesCountProvider).valueOrNull ?? 0)
        : 0;

    return Scaffold(
      backgroundColor: kSurface,
      endDrawer: profile != null ? const NotificationsDrawer() : null,
      body: Row(
        children: [
          AnimatedContainer(
            duration: _widthAnim,
            curve: Curves.easeOut,
            width: _sidebarWidth,
            child: AppSidebar(
              sections: sections,
              expanded: expanded,
              currentLocation: currentLoc,
              messageBadge: msgUnread,
              profile: activeProfile,
              onNavigate: (route) => context.go(route),
            ),
          ),
          SidebarResizeHandle(onDrag: _onSidebarDrag),
          Expanded(
            child: Column(
              children: [
                AppHeader(
                  title: widget.title,
                  profile: activeProfile,
                  isStaff: isStaff,
                  sidebarExpanded: expanded,
                  actions: widget.actions,
                  onToggleSidebar: _toggleSidebar,
                ),
                if (isStaff) const ReadOnlyYearBanner(),
                if (isStaff) const SyncFailureBanner(),
                if (isStaff) const PendingUploadsBanner(),
                if (isStaff) const LicenseBanner(),
                if (profile?.role == AppConstants.roleAdminGroupe)
                  const SubscriptionBanner(),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: widget.child),
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
}
