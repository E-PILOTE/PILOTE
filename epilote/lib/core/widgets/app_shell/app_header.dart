import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logout_guard.dart';
import 'package:go_router/go_router.dart';

import '../admin_ui.dart'
    show kNavy, kGreen, kBorder, kTextPrimary, kTextMuted, kCardBg;
import '../year_selector.dart';
import '../../theme/palette.dart';
import '../../theme/theme_provider.dart';
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
    this.onBack,
  });

  final String title;
  final ProfileModel? profile;
  final bool isStaff;
  final bool sidebarExpanded;
  final VoidCallback onToggleSidebar;
  final List<Widget>? actions;

  /// Retour explicite. Optionnel : la plupart des modules sont des destinations
  /// de la barre latérale et n'ont nulle part où revenir.
  final VoidCallback? onBack;

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
        color: kCardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // ⚠️ CETTE BARRE DÉBORDAIT, SUR TOUS LES ÉCRANS DE L'APPLICATION.
      //
      //  Le titre était un `Text` nu suivi d'un `Spacer` : largeur naturelle,
      //  aucune capacité à céder. À droite, un bloc de commandes de largeur
      //  fixe (cloche, thème, lanceur, compte avec nom et rôle). Dès que la
      //  somme dépassait la place disponible — fenêtre étroite, ou simplement
      //  Windows à 150 % d'agrandissement, où 1 650 px physiques ne font plus
      //  que 1 100 px logiques — Flutter peignait la bande jaune « RIGHT
      //  OVERFLOWED BY 12 PIXELS » par-dessus l'avatar. Le défaut n'était pas
      //  propre à un écran : il vivait dans la coquille, donc partout.
      //
      //  Deux cessions, dans cet ordre :
      //   1. le TITRE devient `Expanded` et se tronque — il occupe déjà la
      //      place libre, le rendre flexible ne déplace rien tant qu'il y a de
      //      la marge, et il est le seul élément qui ne porte aucune action ;
      //   2. sous `_kSeuilCompact`, le NOM et le RÔLE à côté de l'avatar
      //      s'effacent. Ce sont deux lignes de texte décoratives : le menu du
      //      compte reste ouvrable par l'avatar, qui porte déjà les initiales.
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < _kSeuilCompact;
          return Row(
            children: [
              IconButton(
                icon: Icon(
                  sidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
                  color: kNavy,
                  size: 22,
                ),
                onPressed: onToggleSidebar,
                tooltip: sidebarExpanded
                    ? 'Réduire la navigation'
                    : 'Ouvrir la navigation',
              ),
              const SizedBox(width: 8),
              if (onBack != null) ...[
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: kNavy, size: 20),
                  onPressed: onBack,
                  tooltip: 'Retour',
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                montrerNom: !compact,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Largeur de barre sous laquelle le nom et le rôle cèdent la place.
///
/// Mesuré, pas choisi : le bloc de droite pèse ~290 px avec le nom (cloche 48,
/// thème 48, compte 186, écarts), ~164 sans lui ; le bouton de navigation et sa
/// marge en prennent 56. À 720, le titre garde donc au moins 370 px — de quoi
/// écrire « Journal d'audit » ou « Années scolaires » en entier.
const double _kSeuilCompact = 720;

/// Icône du thème [id] — également réutilisée par les écrans Paramètres.
IconData themeIcon(EpiloteThemeId id) => switch (id) {
      EpiloteThemeId.clair => Icons.light_mode_rounded,
      EpiloteThemeId.sombre => Icons.dark_mode_rounded,
      EpiloteThemeId.melack => Icons.shield_moon_rounded,
    };

/// Choix du thème — personnel à l'agent au clavier, jamais à l'appareil.
class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeIdProvider);
    return PopupMenuButton<EpiloteThemeId>(
      tooltip: 'Thème',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: Icon(themeIcon(current), color: kTextMuted, size: 22),
      onSelected: (id) => ref.read(themeIdProvider.notifier).set(id),
      itemBuilder: (_) => [
        for (final id in EpiloteThemeId.values)
          PopupMenuItem(
            value: id,
            child: Row(children: [
              Icon(themeIcon(id),
                  size: 18, color: id == current ? kGreen : kTextMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(id.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: id == current
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: kTextPrimary)),
                    Text(id.description,
                        style: TextStyle(fontSize: 10.5, color: kTextMuted)),
                  ],
                ),
              ),
              if (id == current) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_rounded, size: 16, color: kGreen),
              ],
            ]),
          ),
      ],
    );
  }
}

// ─── Lanceur d'applications (« Accès rapide ») ────────────────────────────────
// Popover ancré au header (pattern « app switcher » Notion/Linear/Google).
// Grille de modules groupée par catégorie, filtrée `can_read` (verrou 3),
// ouverture/fermeture fluides via MenuAnchor, responsive (largeur clampée).
List<Color> get _launcherPalette => [
  kNavy,
  kGreen,
  const Color(0xFF0EA5E9),
  const Color(0xFF7C3AED),
  const Color(0xFFEF4444),
  const Color(0xFFF59E0B),
  const Color(0xFF0891B2),
  const Color(0xFFDB2777),
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
        // Fond du popover : suit le thème. `WidgetStatePropertyAll` masquait ce
        // blanc au tri par constructeur englobant du codemod — d'où un lanceur
        // resté blanc en Sombre/Melack.
        backgroundColor: WidgetStatePropertyAll(kCardBg),
        surfaceTintColor: WidgetStatePropertyAll(kCardBg),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        elevation: const WidgetStatePropertyAll(12),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      builder: (context, controller, _) => Tooltip(
        message: 'Accès rapide',
        child: IconButton(
          icon: Icon(Icons.grid_view_rounded, color: kTextMuted, size: 22),
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
                Icon(Icons.grid_view_rounded, size: 18, color: kNavy),
                const SizedBox(width: 9),
                Text('Accès rapide',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                const Spacer(),
                Text('$total module${total > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ]),
            ),
            Divider(height: 1, color: kBorder),
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
            style: TextStyle(
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
                  style: TextStyle(
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
    this.montrerNom = true,
  });
  final ProfileModel? profile;
  final String displayName;
  final String roleLabel;

  /// Barre trop étroite : seul l'avatar reste, initiales comprises.
  final bool montrerNom;

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

    // Désenrôler le poste = le priver d'offline pour TOUTE l'école → direction
    // uniquement sur un poste partagé (cf. `canUnenrollDevice`).
    final mayUnenroll = canUnenrollDevice(
      role: profile?.role,
      mode: ref.watch(deviceModeProvider).mode,
    );

    return PopupMenuButton<String>(
      tooltip: 'Mon compte',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        switch (value) {
          case 'logout':
            // Déconnexion de l'APPAREIL : sur un poste scolaire, elle lui
            // retire son droit de travailler hors-ligne → avertissement fort.
            await guardedSignOut(context, ref,
                sharedDevice: agentLockApplies(profile?.role));
          case 'profile':
            if (context.mounted) context.go(profileRoute);
          case 'settings':
            if (context.mounted) context.go(settingsRoute);
          case 'switch_agent':
            lockDevice(ref);
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
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  fontSize: 13,
                ),
              ),
              Text(
                roleLabel,
                style: TextStyle(color: kTextMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'profile',
          child: Row(children: [
            Icon(Icons.person_outline, size: 18, color: kNavy),
            const SizedBox(width: 10),
            const Text('Mon profil'),
          ]),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(children: [
            Icon(Icons.settings_outlined, size: 18, color: kNavy),
            const SizedBox(width: 10),
            const Text('Paramètres'),
          ]),
        ),
        // Poste partagé : verrouiller = quitter son écran (local, hors-ligne).
        if (agentLockApplies(profile?.role))
          PopupMenuItem(
            value: 'switch_agent',
            child: Row(children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: kNavy),
              const SizedBox(width: 10),
              const Text('Verrouiller / changer d’utilisateur'),
            ]),
          ),
        // Déconnexion de l'APPAREIL : rare, destructrice de l'offline, réservée
        // à la direction sur un poste partagé. Libellée sans ambiguïté.
        if (mayUnenroll) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'logout',
            child: Row(children: [
              const Icon(Icons.link_off_rounded, size: 18, color: Colors.red),
              const SizedBox(width: 10),
              Text(
                agentLockApplies(profile?.role)
                    ? 'Déconnecter ce poste…'
                    : 'Déconnexion',
                style: const TextStyle(color: Colors.red),
              ),
            ]),
          ),
        ],
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
          if (profile != null && montrerNom) ...[
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shortName(displayName),
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    roleLabel,
                    style: TextStyle(color: kTextMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, color: kTextMuted, size: 20),
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
