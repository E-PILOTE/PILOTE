part of 'programmes_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE création / édition d'un programme + fiche détail (contenu complet).
// ════════════════════════════════════════════════════════════════════════════
class _ProgrammeForm extends ConsumerStatefulWidget {
  const _ProgrammeForm({this.existing});
  final ProgrammeRow? existing;
  @override
  ConsumerState<_ProgrammeForm> createState() => _ProgrammeFormState();
}

class _ProgrammeFormState extends ConsumerState<_ProgrammeForm> {
  late String? _subjectId = widget.existing?.subjectId;
  late String? _levelId = widget.existing?.levelId;
  late String? _trimesterId = widget.existing?.trimesterId;
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _content =
      TextEditingController(text: widget.existing?.content ?? '');
  late bool _isOfficial = widget.existing?.isOfficial ?? false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (_subjectId == null || _levelId == null || title.isEmpty) {
      _snack('Matière, niveau et titre sont obligatoires.', kRed);
      return;
    }
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    final schoolId = profile?.schoolId;
    final yearId = ref.read(activeYearIdProvider);
    if (groupId == null || schoolId == null || schoolId.isEmpty) {
      _snack('École introuvable.', kRed);
      return;
    }
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () async {
        if (_isEdit) {
          await updateProgramme(
            id: widget.existing!.id,
            levelId: _levelId!,
            subjectId: _subjectId!,
            trimesterId: _trimesterId,
            title: title,
            content: _content.text,
            isOfficial: _isOfficial,
          );
        } else {
          await createProgramme(
            groupId: groupId,
            schoolId: schoolId,
            levelId: _levelId!,
            subjectId: _subjectId!,
            academicYearId: yearId,
            trimesterId: _trimesterId,
            title: title,
            content: _content.text,
            isOfficial: _isOfficial,
            createdBy: profile?.id,
          );
        }
      },
      success: _isEdit ? 'Programme mis à jour' : 'Programme créé',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    final structure =
        ref.watch(academicStructureProvider).valueOrNull ?? AcademicStructure.empty;
    final trimesters =
        ref.watch(trimesterOptionsProvider).valueOrNull ?? const [];

    final levelItems = <(String, String)>[
      for (final c in structure.cycles)
        for (final l in c.levels) (l.id, '${c.name} · ${l.code}'),
    ];
    final hasSubject = subjects.any((s) => s.id == _subjectId);
    final hasLevel = levelItems.any((e) => e.$1 == _levelId);
    final hasTri =
        _trimesterId == null || trimesters.any((t) => t.id == _trimesterId);

    return AdminFormDialog(
      icon: _isEdit ? Icons.edit_outlined : Icons.add_rounded,
      title: _isEdit ? 'Modifier le programme' : 'Nouveau programme',
      subtitle: 'Syllabus d\'une matière à un niveau (par trimestre)',
      width: 560,
      saving: _saving,
      submitLabel: _isEdit ? 'Enregistrer' : 'Créer',
      submitIcon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
      onSubmit: _saving ? null : _save,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _Field(
              label: 'Matière *',
              child: DropdownButtonFormField<String>(
                initialValue: hasSubject ? _subjectId : null,
                isExpanded: true,
                style: TextStyle(fontSize: 13.5, color: kTextPrimary),
                icon: Icon(Icons.expand_more_rounded,
                    size: 18, color: kTextMuted),
                decoration: adminFilledInput('Choisir'),
                items: [
                  for (final s in subjects)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _subjectId = v),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Field(
              label: 'Niveau *',
              child: DropdownButtonFormField<String>(
                initialValue: hasLevel ? _levelId : null,
                isExpanded: true,
                style: TextStyle(fontSize: 13.5, color: kTextPrimary),
                icon: Icon(Icons.expand_more_rounded,
                    size: 18, color: kTextMuted),
                decoration: adminFilledInput('Choisir'),
                items: [
                  for (final e in levelItems)
                    DropdownMenuItem(value: e.$1, child: Text(e.$2)),
                ],
                onChanged: (v) => setState(() => _levelId = v),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _Field(
          label: 'Trimestre',
          child: DropdownButtonFormField<String?>(
            initialValue: hasTri ? _trimesterId : null,
            isExpanded: true,
            style: TextStyle(fontSize: 13.5, color: kTextPrimary),
            icon: Icon(Icons.expand_more_rounded,
                size: 18, color: kTextMuted),
            decoration: adminFilledInput('Toute l\'année'),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Toute l\'année')),
              for (final t in trimesters)
                DropdownMenuItem(value: t.id, child: Text(t.label)),
            ],
            onChanged: (v) => setState(() => _trimesterId = v),
          ),
        ),
        const SizedBox(height: 14),
        _Field(
          label: 'Titre *',
          child: TextField(
            controller: _title,
            style: const TextStyle(fontSize: 13.5),
            decoration: adminFilledInput('Ex. Programme de Mathématiques – 6e',
                icon: Icons.title_rounded),
          ),
        ),
        const SizedBox(height: 14),
        _Field(
          label: 'Contenu / progression',
          child: TextField(
            controller: _content,
            minLines: 4,
            maxLines: 10,
            style: const TextStyle(fontSize: 13.5, height: 1.4),
            decoration: adminFilledInput(
                'Chapitres, objectifs, compétences, progression…'),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: kGreen,
            value: _isOfficial,
            onChanged: (v) => setState(() => _isOfficial = v),
            title: Text('Programme officiel',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
            subtitle: Text(
                'Curriculum officiel adopté (sinon : programme propre à l\'école)',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

// ─── Fiche détail (contenu complet) ──────────────────────────────────────────
class _ProgrammeDetail extends StatelessWidget {
  const _ProgrammeDetail({required this.row, this.onEdit});
  final ProgrammeRow row;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final col = _cyc(row.cycleCode);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.article_rounded, color: col, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        AdminBadge(row.subjectName, color: col),
                        AdminBadge(row.levelLabel, color: kNavy),
                        AdminBadge(row.trimesterLabelOrAll, color: kTextMuted),
                        if (row.isOfficial)
                          AdminBadge('Officiel', color: kGreen)
                        else if (row.isShared)
                          AdminBadge('Partagé (groupe)', color: kNavy),
                      ]),
                    ]),
              ),
              IconButton(
                tooltip: 'Fermer',
                icon: Icon(Icons.close_rounded, color: kTextMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: row.hasContent
                  ? Text(row.content!.trim(),
                      style: TextStyle(
                          fontSize: 13.5, color: kTextPrimary, height: 1.5))
                  : Text('Aucun contenu détaillé pour ce programme.',
                      style: TextStyle(
                          fontSize: 13, color: kTextMuted, fontStyle: FontStyle.italic)),
            ),
          ),
          if (onEdit != null)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration:
                  BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
              child: Row(children: [
                const Spacer(),
                AdminPrimaryButton(
                  label: 'Modifier',
                  icon: Icons.edit_outlined,
                  color: kNavy,
                  onTap: onEdit!,
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
