import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_ui.dart' show kNavyDark, kAccent;
import '../../constants/routes.dart';
import '../../../data/models/profile_model.dart';
import '../../../features/navigation/module_routes.dart';
import '../../../licensing/presentation/license_providers.dart';
import 'nav_models.dart';
import 'nav_tile.dart';
import 'shell_providers.dart';
import 'sidebar_footer.dart';
import 'sidebar_header.dart';

/// Sidebar complète : en-tête + sections défilantes + sections épinglées (bas)
/// + footer. Reçoit des [NavSection] déjà construites et notifie la navigation
/// via [onNavigate]. Les sections titrées non épinglées sont repliables.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.sections,
    required this.expanded,
    required this.currentLocation,
    required this.messageBadge,
    required this.profile,
    required this.onNavigate,
  });

  final List<NavSection> sections;
  final bool expanded;
  final String currentLocation;
  final int messageBadge;
  final ProfileModel? profile;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final active = activeNavRoute(currentLocation, navRoutes(sections));
    final top = [for (final s in sections) if (s.pinnedTop) s];
    final scrolling = [
      for (final s in sections)
        if (!s.pinned && !s.pinnedTop) s
    ];
    final pinned = [for (final s in sections) if (s.pinned) s];

    Widget sectionView(NavSection s) => _NavSectionView(
          section: s,
          expanded: expanded,
          activeRoute: active,
          messageBadge: messageBadge,
          onNavigate: onNavigate,
        );

    return Container(
      color: kNavyDark,
      child: Column(
        children: [
          SidebarHeader(expanded: expanded),
          if (top.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [for (final s in top) sectionView(s)],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [for (final s in scrolling) sectionView(s)],
            ),
          ),
          if (pinned.isNotEmpty)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final s in pinned) sectionView(s)],
            ),
          SidebarFooter(expanded: expanded, profile: profile),
        ],
      ),
    );
  }
}

/// Rendu d'une section : en-tête (repliable si titrée + non épinglée) + entrées.
class _NavSectionView extends ConsumerWidget {
  const _NavSectionView({
    required this.section,
    required this.expanded,
    required this.activeRoute,
    required this.messageBadge,
    required this.onNavigate,
  });

  final NavSection section;
  final bool expanded;
  final String? activeRoute;
  final int messageBadge;
  final ValueChanged<String> onNavigate;

  bool get _containsActive =>
      activeRoute != null && section.entries.any((e) => e.route == activeRoute);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTitle = section.title.isNotEmpty;
    // Repliable seulement si titrée, non épinglée, et sidebar en mode étendu.
    final collapsible = hasTitle && !section.pinned && expanded;

    // Hard-lock d'abonnement (ADR-0009) : les entrées de MODULE deviennent des
    // clics morts (grisées + cadenas). Fail-soft : non-enforcé / grâce / lecture
    // seule / plan public → false. Les entrées hors catalogue (Dashboard, Profil,
    // Paramètres, natives) ne sont jamais verrouillées (moduleSlugForLocation == null).
    final hardLocked = ref
            .watch(entitlementProvider)
            .valueOrNull
            ?.isHardLockedAt(DateTime.now().toUtc()) ??
        false;

    // La section de la page courante est toujours dépliée (on ne cache jamais
    // où l'on se trouve). Idem en mode icônes : pas de repli.
    final collapsed = collapsible &&
        !_containsActive &&
        ref.watch(collapsedNavSectionsProvider).contains(section.title);

    final entries = [
      for (final e in section.entries)
        if (e.isInfo)
          _InfoRow(entry: e, expanded: expanded)
        else
          NavTile(
            entry: e,
            isActive: e.route == activeRoute,
            expanded: expanded,
            badge: _badgeFor(e.route),
            locked: hardLocked && moduleSlugForLocation(e.route) != null,
            onTap: () => onNavigate(e.route),
          ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasTitle)
          _SectionHeader(
            label: section.title,
            expanded: expanded,
            collapsible: collapsible,
            collapsed: collapsed,
            onToggle: collapsible
                ? () {
                    final notifier =
                        ref.read(collapsedNavSectionsProvider.notifier);
                    final next = {...notifier.state};
                    next.contains(section.title)
                        ? next.remove(section.title)
                        : next.add(section.title);
                    notifier.state = next;
                  }
                : null,
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: collapsed
              ? const SizedBox(width: double.infinity)
              : Column(mainAxisSize: MainAxisSize.min, children: entries),
        ),
      ],
    );
  }

  int _badgeFor(String route) {
    final isMsg =
        route == Routes.adminMessagerie || route == Routes.messagerie;
    return isMsg ? messageBadge : 0;
  }
}

// ─── En-tête de section (avec chevron de repli si applicable) ───────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.expanded,
    required this.collapsible,
    required this.collapsed,
    required this.onToggle,
  });

  final String label;
  final bool expanded;
  final bool collapsible;
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final white = Colors.white;
    if (!expanded) {
      // Mode réduit : fine ligne de séparation entre groupes.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Divider(height: 1, color: white.withValues(alpha: 0.08)),
      );
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 5),
      child: Row(
        children: [
          if (collapsible) ...[
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0, // ▸ replié / ▾ déplié
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: white.withValues(alpha: 0.40),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: white.withValues(alpha: 0.38),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(height: 1, color: white.withValues(alpha: 0.10)),
          ),
        ],
      ),
    );

    if (!collapsible) return header;
    return _HoverableHeader(onTap: onToggle!, child: header);
  }
}

/// En-tête cliquable avec retour de survol (curseur + léger fond).
class _HoverableHeader extends StatefulWidget {
  const _HoverableHeader({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_HoverableHeader> createState() => _HoverableHeaderState();
}

class _HoverableHeaderState extends State<_HoverableHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: _hovered
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── Ligne d'information non cliquable (synchro / aucun module) ─────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.entry, required this.expanded});
  final NavEntry entry;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final white = Colors.white;
    if (!expanded) {
      return entry.loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kAccent,
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
          if (entry.loading)
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
            )
          else
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: white.withValues(alpha: 0.4),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.label,
              style: TextStyle(
                color: white.withValues(alpha: 0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
