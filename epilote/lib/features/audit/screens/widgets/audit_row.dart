import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../providers/audit_data.dart';

/// Couleur + icône d'une action (partagé ligne ↔ modal détail).
(Color, IconData) auditActionStyle(String action) =>
    switch (action.toUpperCase()) {
      'INSERT' => (kGreen, Icons.add_rounded),
      'UPDATE' => (kAccent, Icons.edit_rounded),
      'DELETE' => (kRed, Icons.delete_outline_rounded),
      _ => (kTextMuted, Icons.bolt_rounded),
    };

/// Une ligne du journal (action · entité · acteur · école? · IP? · date).
/// La colonne « École » ne s'affiche que si l'entrée porte un nom d'école —
/// donc jamais en périmètre école (non hydraté), automatiquement.
class AuditRow extends StatelessWidget {
  const AuditRow({super.key, required this.e, required this.onTap});
  final AuditEntry e;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = auditActionStyle(e.action);
    final severity = e.severity;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicateur de sévérité (barre colorée à gauche)
            Container(
              width: 3,
              height: 42,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: switch (severity) {
                  AuditSeverity.high => kRed,
                  AuditSeverity.medium => kAccent,
                  AuditSeverity.low => Colors.transparent,
                },
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(e.actionLabel,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: color)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('· ${e.entityLabel}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                    ),
                    if (severity == AuditSeverity.high) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: kRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('SENSIBLE',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: kRed,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.person_outline_rounded,
                        size: 13, color: kTextMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('${e.userName} · ${e.roleLbl}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: kTextMuted)),
                    ),
                    if (e.schoolName != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.school_outlined, size: 13, color: kTextMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(e.schoolName!,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: kTextMuted)),
                      ),
                    ],
                    if (e.ipAddress != null && e.ipAddress!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.lan_outlined, size: 12, color: kTextMuted),
                      const SizedBox(width: 3),
                      Text(e.ipAddress!,
                          style: TextStyle(
                              fontSize: 11,
                              color: kTextMuted,
                              fontFamily: 'monospace')),
                    ],
                  ]),
                  if (e.action.toUpperCase() == 'UPDATE' &&
                      e.newFields.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: e.newFields.take(5).map((field) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: kBorder),
                            ),
                            child: Text(field,
                                style: TextStyle(
                                    fontSize: 10.5, color: kTextMuted)),
                          )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_timeLabel(e.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right_rounded, size: 16, color: kTextMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
