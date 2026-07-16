part of 'presences_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FEUILLE D'APPEL — un tiroir : avancement + compteurs en tête, « Tout présent »
//  et « Finaliser » ; une ligne par élève (Présent / Absent / Retard ; heure
//  d'arrivée si retard ; motif si absent/retard). Écriture offline immédiate.
// ════════════════════════════════════════════════════════════════════════════
class _RollSheet extends ConsumerStatefulWidget {
  const _RollSheet({
    required this.args,
    required this.className,
    required this.breadcrumb,
    required this.dateLabel,
    required this.canEdit,
    required this.onChanged,
  });
  final AttendanceArgs args;
  final String className, breadcrumb, dateLabel;
  final bool canEdit;
  final VoidCallback onChanged;
  @override
  ConsumerState<_RollSheet> createState() => _RollSheetState();
}

class _RollSheetState extends ConsumerState<_RollSheet> {
  final _search = TextEditingController();
  String _q = '';
  String? _recordId;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<String?> _ensureRecord() async {
    if (_recordId != null) return _recordId;
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) return null;
    _recordId = await ensureAttendanceRecord(
      groupId: p?.groupId ?? '',
      schoolId: p?.schoolId ?? '',
      academicYearId: yearId,
      classId: widget.args.classId,
      date: widget.args.date,
      period: widget.args.period,
      recordedBy: p?.id ?? '',
    );
    return _recordId;
  }

  Future<void> _setStatus(RollRow r, String status) async {
    if (!widget.canEdit) return;
    final p = ref.read(authNotifierProvider).valueOrNull;
    final rid = await _ensureRecord();
    if (rid == null) return;
    final arrival = status == 'late'
        ? (r.arrivalTime ?? _nowTime())
        : null;
    await setAttendance(
      recordId: rid,
      groupId: p?.groupId ?? '',
      schoolId: p?.schoolId ?? '',
      studentId: r.studentId,
      status: status,
      arrivalTime: arrival,
      justification: r.justification,
      existingEntryId: r.entryId,
    );
    widget.onChanged();
  }

  Future<void> _editJustification(RollRow r) async {
    final ctrl = TextEditingController(text: r.justification ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Motif / justification'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Maladie, rendez-vous, justifié par les parents…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok != true || r.status == null) return;
    final p = ref.read(authNotifierProvider).valueOrNull;
    final rid = await _ensureRecord();
    if (rid == null) return;
    await setAttendance(
      recordId: rid,
      groupId: p?.groupId ?? '',
      schoolId: p?.schoolId ?? '',
      studentId: r.studentId,
      status: r.status!,
      arrivalTime: r.arrivalTime,
      justification: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
      existingEntryId: r.entryId,
    );
    widget.onChanged();
  }

  Future<void> _allPresent(List<RollRow> rows) async {
    setState(() => _busy = true);
    final p = ref.read(authNotifierProvider).valueOrNull;
    final rid = await _ensureRecord();
    if (rid != null && mounted) {
      await runModuleWrite(
        context,
        () => markAllPresent(
          recordId: rid,
          groupId: p?.groupId ?? '',
          schoolId: p?.schoolId ?? '',
          rows: rows,
        ),
        success: 'Élèves restants marqués présents',
      );
      widget.onChanged();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finalize(bool value) async {
    final rid = await _ensureRecord();
    if (rid == null || !mounted) return;
    setState(() => _busy = true);
    await runModuleWrite(context, () => finalizeAttendance(rid, value),
        success: value ? 'Appel finalisé' : 'Appel rouvert');
    widget.onChanged();
    if (mounted) setState(() => _busy = false);
  }

  String _nowTime() {
    final n = TimeOfDay.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(classRollProvider(widget.args));
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
          _header(async.valueOrNull),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (roll) {
                _recordId ??= roll.recordId;
                if (roll.rows.isEmpty) {
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
                final q = _q.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? roll.rows
                    : [
                        for (final r in roll.rows)
                          if (r.studentName.toLowerCase().contains(q) ||
                              (r.matricule ?? '').toLowerCase().contains(q))
                            r,
                      ];
                return Column(children: [
                  // À grande échelle (classes jusqu'à 200 élèves), la recherche
                  // permet de retrouver un élève instantanément (ex. marquer un
                  // absent après « Tout présent »).
                  if (roll.rows.length > 8) _searchField(roll.rows.length),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text('Aucun élève trouvé',
                                style: TextStyle(color: kTextMuted)))
                        : ListView.separated(
                            controller: scroll,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 6),
                            itemBuilder: (_, i) =>
                                _row(filtered[i], i + 1, roll.finalized),
                          ),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _searchField(int total) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: TextField(
          controller: _search,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Rechercher un élève parmi $total…',
            hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
            prefixIcon: Icon(Icons.search_rounded, size: 19, color: kTextMuted),
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _q = '');
                    }),
            filled: true,
            fillColor: kSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  Widget _header(ClassRoll? roll) {
    final rows = roll?.rows ?? const <RollRow>[];
    final present = rows.where((r) => r.status == 'present').length;
    final absent = rows.where((r) => r.status == 'absent').length;
    final late = rows.where((r) => r.status == 'late').length;
    final done = rows.where((r) => r.recorded).length;
    final finalized = roll?.finalized ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.breadcrumb,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kTextMuted,
                          letterSpacing: 0.2)),
                  const SizedBox(height: 1),
                  Text(widget.className,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  Text(
                      '${widget.dateLabel} · $done/${rows.length} pointés · '
                      'P $present · A $absent · R $late',
                      style: TextStyle(fontSize: 12, color: kTextMuted)),
                ]),
          ),
          if (finalized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_rounded, size: 13, color: kGreen),
                const SizedBox(width: 5),
                Text('Finalisé',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: kGreen)),
              ]),
            ),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 20)),
        ]),
        if (widget.canEdit && rows.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            if (done < rows.length)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _allPresent(rows),
                style: OutlinedButton.styleFrom(
                    foregroundColor: kGreen,
                    side: BorderSide(color: kGreen.withValues(alpha: 0.4))),
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('Tout présent'),
              ),
            const Spacer(),
            if (!finalized)
              FilledButton.icon(
                onPressed: _busy || done == 0 ? null : () => _finalize(true),
                style: FilledButton.styleFrom(backgroundColor: kNavy),
                icon: const Icon(Icons.lock_rounded, size: 16),
                label: const Text('Finaliser'),
              )
            else
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _finalize(false),
                style: OutlinedButton.styleFrom(
                    foregroundColor: kAccent,
                    side: BorderSide(color: kAccent.withValues(alpha: 0.4))),
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: const Text('Rouvrir'),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _row(RollRow r, int index, bool finalized) {
    final editable = widget.canEdit && !finalized;
    final showJust = r.status == 'absent' || r.status == 'late';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      decoration: BoxDecoration(
        color: r.status == 'absent'
            ? kRed.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        Row(children: [
          SizedBox(
              width: 22,
              child: Text('$index',
                  style: TextStyle(fontSize: 11, color: kTextMuted))),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  if (r.status == 'late' && r.arrivalTime != null)
                    Text('Arrivé ${r.arrivalTime}',
                        style: const TextStyle(
                            fontSize: 10.5, color: Color(0xFFF59E0B))),
                ]),
          ),
          _statusBtn(r, 'present', 'P', kGreen, editable),
          const SizedBox(width: 5),
          _statusBtn(r, 'absent', 'A', kRed, editable),
          const SizedBox(width: 5),
          _statusBtn(r, 'late', 'R', const Color(0xFFF59E0B), editable),
        ]),
        if (showJust) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: editable ? () => _editJustification(r) : null,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(children: [
                Icon(Icons.edit_note_rounded, size: 15, color: kTextMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      (r.justification ?? '').isEmpty
                          ? 'Ajouter un motif…'
                          : r.justification!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: (r.justification ?? '').isEmpty
                              ? kTextMuted
                              : kTextPrimary)),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _statusBtn(RollRow r, String code, String letter, Color color, bool editable) {
    final sel = r.status == code;
    return InkWell(
      onTap: editable ? () => _setStatus(r, code) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: sel ? color : color.withValues(alpha: 0.30)),
        ),
        child: Center(
          child: Text(letter,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: sel ? Colors.white : color)),
        ),
      ),
    );
  }
}
