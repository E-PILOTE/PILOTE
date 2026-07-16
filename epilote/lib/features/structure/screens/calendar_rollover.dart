part of 'school_calendar_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PRÉPARER MES CLASSES — côté école. L'année est définie par le groupe ; ici
//  la direction recopie ses classes d'une année précédente vers l'année cible
//  (sans les inscriptions), pour préparer la rentrée.
// ════════════════════════════════════════════════════════════════════════════

class _PrepClassesDialog extends ConsumerStatefulWidget {
  const _PrepClassesDialog({required this.targetYear, required this.years});
  final AcademicYearModel targetYear;
  final List<AcademicYearModel> years;

  @override
  ConsumerState<_PrepClassesDialog> createState() => _PrepClassesDialogState();
}

class _PrepClassesDialogState extends ConsumerState<_PrepClassesDialog> {
  String? _sourceId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Source par défaut = l'année la plus récente AVANT la cible.
    final others = widget.years
        .where((y) => y.id != widget.targetYear.id)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    AcademicYearModel? def;
    for (final y in others) {
      if (y.startDate.isBefore(widget.targetYear.startDate)) {
        def = y;
        break;
      }
    }
    def ??= others.isNotEmpty ? others.first : null;
    _sourceId = def?.id;
  }

  Future<void> _submit() async {
    final p = ref.read(authNotifierProvider).valueOrNull;
    if (_sourceId == null || p?.schoolId == null) {
      _calToast(context, 'Choisissez une année source');
      return;
    }
    setState(() => _saving = true);
    var created = 0;
    final ok = await runModuleWrite(
      context,
      () async {
        created = await copySchoolClassesToYear(
          sourceYearId: _sourceId!,
          targetYearId: widget.targetYear.id,
          schoolId: p!.schoolId!,
          groupId: p.groupId ?? '',
        );
      },
      success: 'Classes préparées',
    );
    if (ok && mounted) {
      ref.read(_selectedYearProvider.notifier).state = widget.targetYear.id;
      Navigator.pop(context);
      _calToast(context, '$created classe(s) préparée(s)', ok: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final others =
        widget.years.where((y) => y.id != widget.targetYear.id).toList();
    final srcCounts = _sourceId == null
        ? null
        : ref.watch(yearContentCountProvider(_sourceId!)).valueOrNull;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AdminDialogHeader(
            title: 'Préparer mes classes',
            icon: Icons.move_up_rounded,
            subtitle: 'Vers ${widget.targetYear.label}',
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (others.isEmpty)
                const AdminErrorBanner(
                    message: 'Aucune année antérieure à recopier.')
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _sourceId,
                  isExpanded: true,
                  decoration: adminInputDecoration('Recopier les classes de',
                      icon: Icons.history_rounded),
                  items: others
                      .map((y) => DropdownMenuItem(
                            value: y.id,
                            child: Text(y.label, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _sourceId = v),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: kNavy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: kNavy),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        srcCounts != null
                            ? '${srcCounts.classes} classe(s) seront recréées '
                                '(sans les inscriptions). Les doublons sont ignorés.'
                            : 'Les classes sont recréées sans les inscriptions. '
                                'Les doublons sont ignorés.',
                        style: TextStyle(
                            fontSize: 11.5, color: kTextMuted, height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
          AdminDialogFooter(
            saving: _saving,
            submitLabel: 'Préparer',
            submitIcon: Icons.move_up_rounded,
            submitColor: kGreen,
            onCancel: () => Navigator.pop(context),
            onSubmit: others.isEmpty ? () => Navigator.pop(context) : _submit,
          ),
        ]),
      ),
    );
  }
}
