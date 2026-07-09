import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_ui.dart'
    show kNavy, kGreen, kBorder, kTextPrimary, kTextMuted;
import '../year_selector.dart';
import '../../constants/app_constants.dart';
import '../../constants/routes.dart';
import '../../../data/models/module_model.dart';
import '../../../data/models/profile_model.dart';
import '../../../features/auth/providers/active_agent_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/communication/widgets/notification_bell.dart';
import '../../../features/navigation/module_routes.dart';
import '../../../features/navigation/providers/module_navigation_provider.dart';
import '../../../features/navigation/providers/permissions_provider.dart';
import 'app_shell_theme.dart';
import 'shell_providers.dart';

/// Barre supérieure de l'AppShell : toggle sidebar, titre, sélecteur d'année
/// (personnel), cloche de notifications, bascule de thème, menu compte.
class AppHeader extends ConsumerWidget {
  const AppHeader({
    super.key,
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
    final roleLabel = roleDisplayLabel(profile?.role);
    final showComm = profile != null;

    return Container(
      height: kShellHeaderHeight,
      decoration: BoxDecoration(
        color: Colors.white,
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
              color: kNavy,
              size: 22,
            ),
            onPressed: onToggleSidebar,
            tooltip:
                sidebarExpanded ? 'Réduire la navigation' : 'Ouvrir la navigation',
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: kTextPrimary,
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
          const _ThemeToggle(),
          // Lanceur d'applications (« Accès rapide ») — personnel scolaire
          // uniquement (jamais super admin / admin groupe, qui ont leur nav).
          if (isStaff) ...[
            const SizedBox(width: 2),
            const _ModuleLauncher(),
          ],
          const SizedBox(width: 4),
          _AccountMenu(
            profile: profile,
            displayName: displayName,
            roleLabel: roleLabel,
          ),
        ],
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Tooltip(
      message: isDark ? 'Mode clair' : 'Mode sombre',
      child: IconButton(
        icon: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
          color: kTextMuted,
          size: 22,
        ),
        onPressed: () => ref.read(themeModeProvider.notifier).state =
            isDark ? ThemeMode.light : ThemeMode.dark,
      ),
    );
  }
}

// ─── Lanceur d'applications (« Accès rapide ») ────────────────────────────────
// Popover ancré au header (pattern « app switcher » Notion/Linear/Google).
// Grille de modules groupée par catégorie, filtrée `can_read` (verrou 3),
// ouverture/fermeture fluides via MenuAnchor, responsive (largeur clampée).
const List<Color> _launcherPalette = [
  kNavy,
  kGreen,
  Color(0xFF0EA5E9),
  Color(0xFF7C3AED),
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFF0891B2),
  Color(0xFFDB2777),
];

class _LauncherSection {
  const _LauncherSection(this.title, this.modules, this.color);
  final String title;
  final List<ModuleModel> modules;
  final Color color;
}

class _ModuleLauncher extends ConsumerStatefulWidget {
  const _ModuleLauncher();
  @override
  ConsumerState<_ModuleLauncher> createState() => _ModuleLauncherState();
}

class _ModuleLauncherState extends ConsumerState<_ModuleLauncher> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final grouped =
        ref.watch(modulesGroupedByCategoryProvider).valueOrNull ?? const {};
    final perms = ref.watch(myPermissionsProvider).valueOrNull ?? const {};

    final sections = <_LauncherSection>[];
    var total = 0;
    var ci = 0;
    for (final entry in grouped.entries) {
      final visible =
          entry.value.where((m) => perms[m.slug]?.canRead ?? false).toList();
      if (visible.isEmpty) continue;
      sections.add(_LauncherSection(
          entry.key.name, visible, _launcherPalette[ci % _launcherPalette.length]));
      total += visible.length;
      ci++;
    }
    // Rien à lancer (pas de module accordé, ou 1ʳᵉ synchro) → pas de bouton.
    if (sections.isEmpty) return const SizedBox.shrink();

    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.white),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        elevation: const WidgetStatePropertyAll(12),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      builder: (context, controller, _) => Tooltip(
        message: 'Accès rapide',
        child: IconButton(
          icon: const Icon(Icons.grid_view_rounded, color: kTextMuted, size: 22),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
      menuChildren: [
        _LauncherPanel(
          sections: sections,
          total: total,
          onPick: (slug) {
            // Fermer le menu PUIS router dans la frame suivante. Fermer
            // l'overlay et appeler context.go() dans la même frame crée une
            // course : la navigation peut être avalée par la fermeture du
            // menu (tap sans effet, intermittent). On diffère d'une frame
            // pour garantir l'ouverture du module à chaque clic.
            final route = moduleRoute(slug);
            _menu.close();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.go(route);
            });
          },
        ),
      ],
    );
  }
}

class _LauncherPanel extends StatelessWidget {
  const _LauncherPanel({
    required this.sections,
    required this.total,
    required this.onPick,
  });
  final List<_LauncherSection> sections;
  final int total;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final panelW = math.min(400.0, screenW - 24);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      builder: (context, s, child) => Transform.scale(
        scale: s,
        alignment: Alignment.topRight,
        child: Opacity(
            opacity: ((s - 0.96) / 0.04).clamp(0.0, 1.0), child: child),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: panelW,
          minWidth: math.min(320.0, panelW),
          maxHeight: 540,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(children: [
                const Icon(Icons.grid_view_rounded, size: 18, color: kNavy),
                const SizedBox(width: 9),
                const Text('Accès rapide',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                const Spacer(),
                Text('$total module${total > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: kTextMuted)),
              ]),
            ),
            const Divider(height: 1, color: kBorder),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _LauncherSectionView(section: sections[i], onPick: onPick),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LauncherSectionView extends StatelessWidget {
  const _LauncherSectionView({required this.section, required this.onPick});
  final _LauncherSection section;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 7,
          height: 7,
          decoration:
              BoxDecoration(color: section.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(section.title.toUpperCase(),
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: kTextMuted)),
      ]),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final m in section.modules)
            _LauncherTile(module: m, color: section.color, onPick: onPick),
        ],
      ),
    ]);
  }
}

class _LauncherTile extends StatelessWidget {
  const _LauncherTile(
      {required this.module, required this.color, required this.onPick});
  final ModuleModel module;
  final Color color;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onPick(module.slug),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(moduleIcon(module.slug), size: 21, color: color),
                ),
                const SizedBox(height: 8),
                Text(
                  module.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({
    required this.profile,
    required this.displayName,
    required this.roleLabel,
  });
  final ProfileModel? profile;
  final String displayName;
  final String roleLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = _initials(displayName);
    final avatarColor = _avatarColor(profile?.role);

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

    return PopupMenuButton<String>(
      tooltip: 'Mon compte',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        switch (value) {
          case 'logout':
            ref.read(selectedAgentIdProvider.notifier).state = null;
            await ref.read(authNotifierProvider.notifier).signOut();
          case 'profile':
            if (context.mounted) context.go(profileRoute);
          case 'settings':
            if (context.mounted) context.go(settingsRoute);
          case 'switch_agent':
            // Réaffiche le sélecteur de profils. En poste partagé, oublier
            // l'agent suffit ; en poste personnel, forcer explicitement.
            ref.read(selectedAgentIdProvider.notifier).state = null;
            ref.read(forceAgentPickerProvider.notifier).state = true;
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
                  color: kTextPrimary,
                  fontSize: 13,
                ),
              ),
              Text(
                roleLabel,
                style: const TextStyle(color: kTextMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: Row(children: [
            Icon(Icons.person_outline, size: 18, color: kNavy),
            SizedBox(width: 10),
            Text('Mon profil'),
          ]),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(children: [
            Icon(Icons.settings_outlined, size: 18, color: kNavy),
            SizedBox(width: 10),
            Text('Paramètres'),
          ]),
        ),
        // Poste partagé : reverrouiller l'appareil (personnel scolaire, hors
        // parent/élève — même public que le verrou).
        if (agentLockApplies(profile?.role))
          const PopupMenuItem(
            value: 'switch_agent',
            child: Row(children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: kNavy),
              SizedBox(width: 10),
              Text('Changer d’utilisateur'),
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
                color: Colors.white,
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
                      color: kTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    roleLabel,
                    style: const TextStyle(color: kTextMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, color: kTextMuted, size: 20),
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

  Color _avatarColor(String? role) => switch (role) {
        AppConstants.roleSuperAdmin => kNavy,
        AppConstants.roleAdminGroupe => kGreen,
        _ => const Color(0xFF7C3AED),
      };
}

/// Libellé lisible d'un rôle (partagé header / autres écrans si besoin).
String roleDisplayLabel(String? role) => switch (role) {
      AppConstants.roleSuperAdmin => 'Super Administrateur',
      AppConstants.roleAdminGroupe => 'Admin Groupe',
      AppConstants.roleDirecteur => 'Directeur',
      AppConstants.roleProviseur => 'Proviseur',
      AppConstants.roleEnseignant => 'Enseignant',
      AppConstants.roleCpe => 'CPE',
      AppConstants.roleComptable => 'Comptable',
      AppConstants.roleSecretaire => 'Secrétaire',
      AppConstants.roleSurveillant => 'Surveillant',
      AppConstants.roleParent => 'Parent',
      AppConstants.roleEleve => 'Élève',
      AppConstants.roleInfirmier => 'Infirmier',
      AppConstants.roleResponsableCantine => 'Resp. Cantine',
      _ => 'Utilisateur',
    };
