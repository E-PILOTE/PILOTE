import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../providers/audit_data.dart';

/// Onglet « Alertes » : anomalies détectées sur les 30 derniers jours.
class AuditAlertsTab extends StatelessWidget {
  const AuditAlertsTab({super.key, required this.alerts, required this.isLoading});
  final List<AuditAlert> alerts;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: kNavy));
    }
    if (alerts.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.check_circle_rounded,
        title: 'Aucune anomalie détectée',
        message:
            "Le journal ne présente aucun comportement suspect sur les 30 derniers jours. Les alertes s'affichent automatiquement en cas d'anomalie.",
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: alerts.length,
      separatorBuilder: (_, si) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _AlertCard(alert: alerts[i]),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final AuditAlert alert;

  @override
  Widget build(BuildContext context) {
    final (bg, border, iconColor, labelBg, label) = switch (alert.level) {
      AuditAlertLevel.critical => (
          kRed.withValues(alpha: 0.06),
          kRed.withValues(alpha: 0.3),
          kRed,
          kRed,
          'CRITIQUE',
        ),
      AuditAlertLevel.warning => (
          kAccent.withValues(alpha: 0.08),
          kAccent.withValues(alpha: 0.35),
          kAccent,
          kAccent,
          'ATTENTION',
        ),
      AuditAlertLevel.info => (
          kNavy.withValues(alpha: 0.05),
          kNavy.withValues(alpha: 0.2),
          kNavy,
          kNavy,
          'INFO',
        ),
    };

    final icon = switch (alert.level) {
      AuditAlertLevel.critical => Icons.warning_rounded,
      AuditAlertLevel.warning => Icons.trending_up_rounded,
      AuditAlertLevel.info => Icons.info_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(alert.title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: iconColor)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: labelBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(alert.description,
                    style: TextStyle(
                        fontSize: 13, color: kTextPrimary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
