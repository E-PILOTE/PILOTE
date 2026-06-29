part of 'emploi_du_temps_screen.dart';

// ─── Drawer latéral de détail d'un créneau ───────────────────────────────────
class _SlotDrawer extends StatelessWidget {
  const _SlotDrawer({
    required this.slot,
    required this.conflict,
    this.onEdit,
    this.onDelete,
    this.onViewClass,
  });
  final TimetableSlot slot;
  final bool conflict;
  final VoidCallback? onEdit, onDelete, onViewClass;

  @override
  Widget build(BuildContext context) {
    final color = _subjectColor(slot.subjectId);
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: 380,
        height: double.infinity,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // En-tête coloré matière.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 14, 18),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                border: const Border(bottom: BorderSide(color: kBorder))),
            child: Row(children: [
              Container(width: 4, height: 38, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.subjectName ?? 'Matière',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: color)),
                      const SizedBox(height: 2),
                      Text('${frDays[slot.dayOfWeek]} · ${slot.timeLabel}',
                          style: const TextStyle(
                              fontSize: 12.5, color: kTextMuted)),
                    ]),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                if (conflict) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                    decoration: BoxDecoration(
                      color: kRed.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kRed.withValues(alpha: 0.35)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: kRed),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Ce créneau est en conflit',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: kRed)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],
                AdminDetailCard([
                  AdminDetailRow(Icons.groups_2_rounded, 'Classe',
                      slot.className ?? '—'),
                  AdminDetailRow(Icons.person_outline_rounded, 'Enseignant',
                      slot.teacherName ?? '—'),
                  AdminDetailRow(Icons.place_outlined, 'Salle',
                      (slot.room ?? '').trim().isEmpty ? '—' : slot.room!.trim()),
                  AdminDetailRow(Icons.schedule_rounded, 'Horaire',
                      slot.timeLabel, last: true),
                ]),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null || onViewClass != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration:
                  const BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
              child: Column(children: [
                if (onViewClass != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onViewClass,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Voir la classe'),
                    ),
                  ),
                if (onEdit != null || onDelete != null) ...[
                  if (onViewClass != null) const SizedBox(height: 10),
                  Row(children: [
                    if (onDelete != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDelete,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: kRed,
                              side: BorderSide(
                                  color: kRed.withValues(alpha: 0.4))),
                          icon:
                              const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Supprimer'),
                        ),
                      ),
                    if (onDelete != null && onEdit != null)
                      const SizedBox(width: 10),
                    if (onEdit != null)
                      Expanded(
                        child: AdminPrimaryButton(
                          label: 'Modifier',
                          icon: Icons.edit_rounded,
                          onTap: onEdit!,
                        ),
                      ),
                  ]),
                ],
              ]),
            ),
        ]),
      ),
    );
  }
}
