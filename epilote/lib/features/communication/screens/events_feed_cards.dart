import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/events_provider.dart';
import '../widgets/comm_attachments.dart';
import '../widgets/staff_feed_ui.dart';

// ─── Carte événement (pastille date + métadonnées, tap = détail) ─────────────
class StaffEventCard extends StatelessWidget {
  const StaffEventCard({super.key,
    required this.event,
    required this.onTap,
    this.manageable = false,
    this.onEdit,
    this.onDelete,
  });
  final EventModel event;
  final VoidCallback onTap;

  /// Événement de MON école et je suis direction → modifier / supprimer.
  final bool manageable;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final d = event.date;
    final accent = event.isPast ? kTextMuted : kGreen;

    return AdminCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text(d != null ? '${d.day}' : '—',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: accent)),
              Text(d != null ? kMoisCourtFr[d.month - 1].toUpperCase() : '',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600, color: accent)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary)),
                  ),
                  if (event.isPast) ...[
                    const SizedBox(width: 8),
                    AdminBadge('Passé', color: kTextMuted),
                  ],
                  if (manageable)
                    PopupMenuButton<String>(
                      tooltip: 'Gérer',
                      icon: Icon(Icons.more_vert_rounded,
                          size: 18, color: kTextMuted),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      onSelected: (v) => v == 'edit'
                          ? onEdit?.call()
                          : onDelete?.call(),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'edit',
                            child: Text('Modifier',
                                style: TextStyle(fontSize: 12.5))),
                        PopupMenuItem(
                            value: 'delete',
                            child: Text('Supprimer',
                                style: TextStyle(
                                    fontSize: 12.5, color: kRed))),
                      ],
                    ),
                ]),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: kTextMuted, height: 1.4)),
                ],
                const SizedBox(height: 8),
                Wrap(spacing: 14, runSpacing: 4, children: [
                  if (event.startTime != null)
                    _meta(Icons.schedule_rounded,
                        '${event.startTime}${event.endTime != null ? ' – ${event.endTime}' : ''}'),
                  if ((event.location ?? '').isNotEmpty)
                    _meta(Icons.place_rounded, event.location!),
                  if (event.attachments.isNotEmpty)
                    _meta(Icons.attach_file_rounded,
                        '${event.attachments.length} pièce${event.attachments.length > 1 ? 's' : ''} jointe${event.attachments.length > 1 ? 's' : ''}'),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: kTextMuted),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ],
      );
}

// ─── Modal détail événement ───────────────────────────────────────────────────
class StaffEventDetailDialog extends StatelessWidget {
  const StaffEventDetailDialog({super.key,required this.event});
  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final d = event.date;
    final end = event.endDate != null ? DateTime.tryParse(event.endDate!) : null;
    final aColor = audienceColor(event.targetAudience);
    final horaires = event.startTime != null
        ? '${event.startTime}${event.endTime != null ? ' – ${event.endTime}' : ''}'
        : null;

    return StaffDetailDialog(
      icon: Icons.event_rounded,
      title: event.title,
      subtitle: fmtDateFullFr(d),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            AdminBadge(event.isPast ? 'Passé' : 'À venir',
                color: event.isPast ? kTextMuted : kGreen,
                icon: event.isPast
                    ? Icons.history_rounded
                    : Icons.event_available_rounded),
            AdminBadge(
                kAudienceLabels[event.targetAudience] ?? event.targetAudience,
                color: aColor,
                icon: Icons.groups_rounded),
            if (event.schoolId == null)
              AdminBadge('Tout le réseau',
                  color: kNavy, icon: Icons.hub_rounded)
            else
              AdminBadge('Mon école',
                  color: kGreen, icon: Icons.school_rounded),
          ]),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            SelectableText(
              event.description,
              style: TextStyle(
                  fontSize: 13.5, color: kTextPrimary, height: 1.6),
            ),
          ],
          // Pièces jointes : affiche, programme PDF, photos…
          if (event.attachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            const AdminModalSectionTitle('Pièces jointes'),
            CommAttachmentView(items: event.attachments, thumbSize: 170),
          ],
          const SizedBox(height: 20),
          const AdminModalSectionTitle('Informations pratiques'),
          const SizedBox(height: 8),
          AdminDetailCard([
            AdminDetailRow(Icons.event_rounded, 'Date', fmtDateFullFr(d)),
            if (end != null)
              AdminDetailRow(Icons.event_repeat_rounded, 'Fin',
                  fmtDateFullFr(end)),
            if (horaires != null)
              AdminDetailRow(Icons.schedule_rounded, 'Horaires', horaires),
            AdminDetailRow(Icons.place_rounded, 'Lieu',
                (event.location ?? '').isNotEmpty ? event.location! : '—',
                last: true),
          ]),
        ],
      ),
    );
  }
}

