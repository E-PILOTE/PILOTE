import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_ui.dart' show kNavy, kGreen, kTextPrimary, kTextMuted;
import '../year_selector.dart';
import '../../constants/app_constants.dart';
import '../../constants/routes.dart';
import '../../../data/models/profile_model.dart';
import '../../../features/auth/providers/active_agent_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/communication/widgets/notification_bell.dart';
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
            // Poste partagé : reverrouille → AgentLockGate réaffiche l'écran-verrou.
            ref.read(selectedAgentIdProvider.notifier).state = null;
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
