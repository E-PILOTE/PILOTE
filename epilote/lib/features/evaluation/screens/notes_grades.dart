part of 'notes_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FEUILLE DE SAISIE DES NOTES — un tiroir bas listant les élèves de la classe ;
//  pour chacun : une note sur le barème (max_score) OU « absent », + une
//  appréciation facultative. Enregistrement offline immédiat (upsertGrade) à
//  chaque modification. En tête : avancement + moyenne /20 en direct. Lecture
//  seule si l'évaluation est publiée ou l'année verrouillée.
// ════════════════════════════════════════════════════════════════════════════
class _GradeSheet extends ConsumerStatefulWidget {
  const _GradeSheet({required this.evaluation, required this.canEdit});
  final Evaluation evaluation;
  final bool canEdit;
  @override
  ConsumerState<_GradeSheet> createState() => _GradeSheetState();
}

class _GradeSheetState extends ConsumerState<_GradeSheet> {
  final _ctrls = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(GradeRow r) {
    final c = _ctrls.putIfAbsent(
        r.enrollmentId,
        () => TextEditingController(
            text: r.score == null ? '' : _fmt(r.score!)));
    final f = _focus.putIfAbsent(r.enrollmentId, () => FocusNode());
    // Resynchronise depuis la base seulement si l'utilisateur n'édite pas.
    if (!f.hasFocus) {
      final want = r.score == null ? '' : _fmt(r.score!);
      if (c.text != want) c.text = want;
    }
    return c;
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _save(GradeRow r, {double? score, bool? absent, String? appr}) async {
    final p = ref.read(authNotifierProvider).valueOrNull;
    final isAbsent = absent ?? r.isAbsent;
    await upsertGrade(
      groupId: p?.groupId ?? '',
      schoolId: p?.schoolId ?? '',
      evaluationId: widget.evaluation.id,
      studentId: r.studentId,
      enrollmentId: r.enrollmentId,
      createdBy: p?.id ?? '',
      score: isAbsent ? null : score,
      isAbsent: isAbsent,
      appreciation: appr ?? r.appreciation,
      existingGradeId: r.gradeId,
    );
  }

  void _onScoreSubmit(GradeRow r, String raw) {
    final max = widget.evaluation.maxScore;
    final txt = raw.trim().replaceAll(',', '.');
    if (txt.isEmpty) {
      _save(r, score: null, absent: false);
      return;
    }
    final v = double.tryParse(txt);
    if (v == null || v < 0 || v > max) {
      // Valeur invalide → on remet l'ancienne et signale.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Note invalide (0 à ${_fmt(max)})'),
          backgroundColor: kRed));
      _ctrls[r.enrollmentId]?.text = r.score == null ? '' : _fmt(r.score!);
      return;
    }
    _save(r, score: v, absent: false);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.evaluation;
    final async = ref.watch(
        evalGradesProvider((classId: e.classId, evalId: e.id)));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: kBorder, borderRadius: BorderRadius.circular(2)),
          ),
          _header(e, async.valueOrNull ?? const []),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur : $err')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: AdminEmptyState(
                        icon: Icons.group_off_outlined,
                        title: 'Aucun élève',
                        message:
                            'Cette classe n\'a pas d\'élève actif inscrit.',
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

  Widget _header(Evaluation e, List<GradeRow> rows) {
    final graded =
        rows.where((r) => r.hasGrade && (r.score != null || r.isAbsent)).length;
    final scored = rows.where((r) => !r.isAbsent && r.score != null);
    final avg = scored.isEmpty
        ? null
        : scored.map((r) => r.score!).reduce((a, b) => a + b) /
            scored.length /
            e.maxScore *
            20;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                const SizedBox(height: 2),
                Text(
                    '${e.subjectName ?? ''} · ${e.className ?? ''} · '
                    '/${e.maxScore.toStringAsFixed(0)} · '
                    '$graded/${rows.length} saisies'
                    '${avg != null ? ' · moy. ${avg.toStringAsFixed(2)}/20' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ]),
        ),
        if (!widget.canEdit)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: kTextMuted.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: kTextMuted),
              const SizedBox(width: 5),
              Text('Lecture seule',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted)),
            ]),
          ),
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 20)),
      ]),
    );
  }

  Widget _row(GradeRow r, int index) {
    final e = widget.evaluation;
    final norm = (!r.isAbsent && r.score != null)
        ? r.score! / e.maxScore * 20
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: r.isAbsent ? kRed.withValues(alpha: 0.04) : kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        SizedBox(
          width: 24,
          child: Text('$index',
              style: TextStyle(fontSize: 11, color: kTextMuted)),
        ),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                if ((r.matricule ?? '').isNotEmpty)
                  Text(r.matricule!,
                      style:
                          TextStyle(fontSize: 10.5, color: kTextMuted)),
              ]),
        ),
        if (norm != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _normColor(norm).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${norm.toStringAsFixed(1)}/20',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _normColor(norm))),
          ),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 78,
          child: TextField(
            controller: _ctrl(r),
            focusNode: _focus[r.enrollmentId],
            enabled: widget.canEdit && !r.isAbsent,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              filled: true,
              fillColor: kSurface,
              suffixText: '/${e.maxScore.toStringAsFixed(0)}',
              suffixStyle: TextStyle(fontSize: 10, color: kTextMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (v) => _onScoreSubmit(r, v),
            onTapOutside: (_) {
              final c = _ctrls[r.enrollmentId];
              if (c != null) _onScoreSubmit(r, c.text);
              _focus[r.enrollmentId]?.unfocus();
            },
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Absent',
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: widget.canEdit
                ? () => _save(r, absent: !r.isAbsent, score: null)
                : null,
            icon: Icon(
              r.isAbsent
                  ? Icons.person_off_rounded
                  : Icons.person_off_outlined,
              size: 19,
              color: r.isAbsent ? kRed : kTextMuted,
            ),
          ),
        ),
      ]),
    );
  }

  Color _normColor(double n) => n >= 14
      ? kGreen
      : n >= 10
          ? const Color(0xFF0EA5E9)
          : const Color(0xFFF59E0B);
}
