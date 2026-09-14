part of 'subject_detail_dialog.dart';

// ─── Ligne « classe » : coefficient effectif, professeur, effectif ──────────

class _AssignmentRow extends ConsumerWidget {
  const _AssignmentRow({
    required this.subject,
    required this.a,
    required this.last,
    required this.canEdit,
  });
  final SubjectModel subject;
  final SubjectAssignment a;
  final bool last, canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: _cyc(a.cycleCode).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(Icons.meeting_room_outlined,
              size: 18, color: _cyc(a.cycleCode)),
        ),
        const SizedBox(width: 11),
        // Classe + prof + effectif.
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.className,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.person_outline_rounded,
                  size: 13, color: a.hasTeacher ? kNavy : kTextMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(a.teacherLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: a.hasTeacher ? kNavy : kTextMuted)),
              ),
              const SizedBox(width: 10),
              Icon(Icons.groups_2_outlined, size: 13, color: kTextMuted),
              const SizedBox(width: 4),
              Text('${a.studentCount}',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              if (a.weeklyHours != null) ...[
                const SizedBox(width: 10),
                Icon(Icons.schedule_outlined, size: 13, color: kTextMuted),
                const SizedBox(width: 4),
                Text('${a.weeklyHours}h',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        // Coefficient effectif.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: (a.hasOverride ? const Color(0xFFF59E0B) : kGreen)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text('Coef. ${a.effectiveCoef}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: a.hasOverride ? const Color(0xFFB45309) : kGreen)),
        ),
        if (canEdit)
          PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: Icon(Icons.more_vert_rounded,
                size: 18, color: kTextMuted),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            onSelected: (v) async {
              switch (v) {
                case 'coef':
                  await showDialog<void>(
                    context: context,
                    builder: (_) =>
                        _AssignmentEditDialog(subject: subject, a: a),
                  );
                case 'teacher':
                  await showDialog<void>(
                    context: context,
                    builder: (_) => _TeacherPickerDialog(subject: subject, a: a),
                  );
                case 'remove':
                  if (!context.mounted) return;
                  await runModuleWrite(context, () => removeAssignment(a.id),
                      success: 'Retirée du programme de ${a.className}');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'coef',
                  child: Row(children: [
                    Icon(Icons.tune_rounded, size: 17, color: kNavy),
                    const SizedBox(width: 10),
                    const Text('Coefficient / horaire'),
                  ])),
              PopupMenuItem(
                  value: 'teacher',
                  child: Row(children: [
                    Icon(Icons.person_add_alt_1_outlined,
                        size: 17, color: kNavy),
                    const SizedBox(width: 10),
                    const Text('Professeur'),
                  ])),
              PopupMenuItem(
                  value: 'remove',
                  child: Row(children: [
                    Icon(Icons.link_off_rounded, size: 17, color: kRed),
                    const SizedBox(width: 10),
                    const Text('Retirer de la classe'),
                  ])),
            ],
          ),
      ]),
    );
  }
}
