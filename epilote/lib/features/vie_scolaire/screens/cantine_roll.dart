part of 'cantine_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  POINTAGE REPAS — un tiroir : avancement en tête + « Tout servir » ; une ligne
//  par élève (Servi / Absent). Écriture offline immédiate.
// ════════════════════════════════════════════════════════════════════════════
class _MealSheet extends ConsumerStatefulWidget {
  const _MealSheet({
    required this.args,
    required this.className,
    required this.subtitle,
    required this.canEdit,
    required this.onChanged,
  });
  final MealArgs args;
  final String className, subtitle;
  final bool canEdit;
  final VoidCallback onChanged;
  @override
  ConsumerState<_MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends ConsumerState<_MealSheet> {
  bool _busy = false;

  Future<void> _set(MealRow r, bool present) async {
    if (!widget.canEdit) return;
    final p = ref.read(authNotifierProvider).valueOrNull;
    await setMeal(
      groupId: p?.groupId ?? '',
      schoolId: p?.schoolId ?? '',
      studentId: r.studentId,
      date: widget.args.date,
      meal: widget.args.meal,
      present: present,
      notes: r.notes,
      existingId: r.recordId,
    );
    widget.onChanged();
  }

  Future<void> _allServed(List<MealRow> rows) async {
    final p = ref.read(authNotifierProvider).valueOrNull;
    setState(() => _busy = true);
    await runModuleWrite(
      context,
      () => markAllServed(
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        date: widget.args.date,
        meal: widget.args.meal,
        rows: rows,
      ),
      success: 'Élèves restants marqués servis',
    );
    widget.onChanged();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(classMealProvider(widget.args));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2))),
          _header(async.valueOrNull ?? const []),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: AdminEmptyState(
                        icon: Icons.group_off_outlined,
                        title: 'Aucun élève',
                        message: 'Cette classe n\'a pas d\'élève actif inscrit.',
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _row(rows[i], i + 1),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header(List<MealRow> rows) {
    final served = rows.where((r) => r.present == true).length;
    final absent = rows.where((r) => r.present == false).length;
    final done = rows.where((r) => r.present != null).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.className,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  Text(
                      '${widget.subtitle} · servis $served · absents $absent · '
                      '$done/${rows.length} pointés',
                      style: const TextStyle(fontSize: 12, color: kTextMuted)),
                ]),
          ),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 20)),
        ]),
        if (widget.canEdit && rows.any((r) => r.present == null)) ...[
          const SizedBox(height: 4),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _allServed(rows),
              style: OutlinedButton.styleFrom(
                  foregroundColor: kGreen,
                  side: BorderSide(color: kGreen.withValues(alpha: 0.4))),
              icon: const Icon(Icons.done_all_rounded, size: 16),
              label: const Text('Tout servir'),
            ),
            const Spacer(),
          ]),
        ],
      ]),
    );
  }

  Widget _row(MealRow r, int index) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      decoration: BoxDecoration(
        color: r.present == false ? kAccent.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        SizedBox(
            width: 22,
            child: Text('$index',
                style: const TextStyle(fontSize: 11, color: kTextMuted))),
        Expanded(
          child: Text(r.studentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        _btn(r, true, 'Servi', kGreen),
        const SizedBox(width: 6),
        _btn(r, false, 'Absent', const Color(0xFFF59E0B)),
      ]),
    );
  }

  Widget _btn(MealRow r, bool present, String label, Color color) {
    final sel = r.present == present;
    return InkWell(
      onTap: widget.canEdit ? () => _set(r, present) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? color : color.withValues(alpha: 0.30)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: sel ? Colors.white : color)),
      ),
    );
  }
}
