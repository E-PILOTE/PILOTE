import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../providers/audit_data.dart';

/// Rangée de 6 KPIs (événements, créations, modifs, suppressions, utilisateurs
/// actifs, dernier événement). Identique aux deux périmètres.
class AuditKpiGrid extends StatelessWidget {
  const AuditKpiGrid({super.key, required this.facets});
  final AuditFacets facets;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      AdminStatCard(
        label: 'Événements',
        value: '${facets.total}',
        icon: Icons.list_alt_rounded,
        color: kNavy,
        subtitle: _breakdown(facets),
      ),
      AdminStatCard(
        label: 'Créations',
        value: '${facets.creations}',
        icon: Icons.add_circle_rounded,
        color: kGreen,
      ),
      AdminStatCard(
        label: 'Modifications',
        value: '${facets.modifications}',
        icon: Icons.edit_rounded,
        color: kAccent,
      ),
      AdminStatCard(
        label: 'Suppressions',
        value: '${facets.suppressions}',
        icon: Icons.delete_rounded,
        color: kRed,
      ),
      AdminStatCard(
        label: 'Utilisateurs actifs',
        value: '${facets.activeUsers}',
        icon: Icons.group_rounded,
        color: kNavy,
      ),
      AdminStatCard(
        label: 'Dernier événement',
        value: _lastValue(facets.lastEventAt),
        icon: Icons.schedule_rounded,
        color: kNavy,
        subtitle:
            facets.lastEventAt != null ? _fullDate(facets.lastEventAt!) : null,
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      const gap = 14.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: cards.map((c) => SizedBox(width: w, child: c)).toList(),
      );
    });
  }

  static String _breakdown(AuditFacets f) {
    if (f.total == 0) return 'Aucune activité';
    return '${f.creations} créa · ${f.modifications} modif · ${f.suppressions} suppr';
  }

  static String _lastValue(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  static String _fullDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      'à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class AuditKpiSkeleton extends StatelessWidget {
  const AuditKpiSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      const gap = 14.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: List.generate(
            6,
            (_) => SizedBox(
                  width: w,
                  height: 110,
                  child: Container(
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                    ),
                  ),
                )),
      );
    });
  }
}

/// Bandeau rouge affiché hors onglet quand au moins une alerte critique existe.
class AuditCriticalAlertBanner extends StatelessWidget {
  const AuditCriticalAlertBanner({super.key, required this.alerts});
  final List<AuditAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: kRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alerts.first.title,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: kRed),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Voir les alertes →',
            style: TextStyle(
                fontSize: 12,
                color: kRed.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
