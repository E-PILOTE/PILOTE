import 'package:flutter/material.dart';

import '../admin_ui.dart' show kNavyDark, kAccent;
import '../../constants/routes.dart';
import '../../../data/models/profile_model.dart';
import 'nav_models.dart';
import 'nav_tile.dart';
import 'sidebar_footer.dart';
import 'sidebar_header.dart';

/// Sidebar complète : en-tête + sections défilantes + sections épinglées (bas)
/// + footer. Purement présentationnelle : reçoit des [NavSection] déjà
/// construites et notifie la navigation via [onNavigate].
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
    final scrolling = [for (final s in sections) if (!s.pinned) s];
    final pinned = [for (final s in sections) if (s.pinned) s];

    return Container(
      color: kNavyDark,
      child: Column(
        children: [
          SidebarHeader(expanded: expanded),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                for (final s in scrolling) ..._buildSection(s, active),
              ],
            ),
          ),
          if (pinned.isNotEmpty)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in pinned) ..._buildSection(s, active),
              ],
            ),
          SidebarFooter(expanded: expanded, profile: profile),
        ],
      ),
    );
  }

  List<Widget> _buildSection(NavSection section, String? active) => [
        if (section.title.isNotEmpty) _SectionHeader(section.title, expanded),
        for (final e in section.entries)
          if (e.isInfo)
            _InfoRow(entry: e, expanded: expanded)
          else
            NavTile(
              entry: e,
              isActive: e.route == active,
              expanded: expanded,
              badge: _badgeFor(e.route),
              onTap: () => onNavigate(e.route),
            ),
      ];

  int _badgeFor(String route) {
    final isMsg =
        route == Routes.adminMessagerie || route == Routes.messagerie;
    return isMsg ? messageBadge : 0;
  }
}

// ─── En-tête de section ─────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, this.expanded);
  final String label;
  final bool expanded;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 5),
      child: Row(
        children: [
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
