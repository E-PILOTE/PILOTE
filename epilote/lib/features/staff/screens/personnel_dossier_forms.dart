part of 'personnel_dossier_sheet.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRES du dossier RH — Parcours professionnel & Diplôme. Modals ajustés
//  au contenu (shrinkWrap). Écritures offline via runModuleWrite.
// ════════════════════════════════════════════════════════════════════════════

void showCareerForm(BuildContext context,
    {required String profileId, CareerEntry? entry}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CareerForm(profileId: profileId, entry: entry),
  );
}

void showDiplomaForm(BuildContext context,
    {required String profileId, Diploma? diploma}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DiplomaForm(profileId: profileId, diploma: diploma),
  );
}

// ─── Parcours professionnel ──────────────────────────────────────────────────
class _CareerForm extends ConsumerStatefulWidget {
  const _CareerForm({required this.profileId, this.entry});
  final String profileId;
  final CareerEntry? entry;
  @override
  ConsumerState<_CareerForm> createState() => _CareerFormState();
}

class _CareerFormState extends ConsumerState<_CareerForm> {
  final _position = TextEditingController();
  final _org = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _start, _end;
  bool _current = false;
  bool _saving = false;

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) {
      _position.text = e.position;
      _org.text = e.organization ?? '';
      _notes.text = e.notes ?? '';
      _start = DateTime.tryParse(e.startDate ?? '');
      _end = DateTime.tryParse(e.endDate ?? '');
      _current = e.isCurrent;
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _org.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final base = start ? (_start ?? DateTime.now()) : (_end ?? DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => start ? _start = d : _end = d);
  }

  Future<void> _save() async {
    if (_position.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Le poste est requis'), backgroundColor: kRed));
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => saveCareerEntry(
        id: widget.entry?.id,
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        profileId: widget.profileId,
        position: _position.text.trim(),
        organization: _org.text.trim().isEmpty ? null : _org.text.trim(),
        startDate: _start?.toIso8601String().substring(0, 10),
        endDate: _current ? null : _end?.toIso8601String().substring(0, 10),
        isCurrent: _current,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
      success: _isEdit ? 'Poste modifié' : 'Poste ajouté',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          vsFormHeader(context, _isEdit ? 'Modifier le poste' : 'Nouveau poste',
              Icons.timeline_rounded),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                TextField(
                  controller: _position,
                  decoration: adminFilledInput('Poste occupé',
                      icon: Icons.work_outline_rounded),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _org,
                  decoration: adminFilledInput('Établissement / structure',
                      icon: Icons.business_outlined),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _DateField('Début', _start, () => _pick(true))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _current
                        ? const _DisabledField('Poste actuel')
                        : _DateField('Fin', _end, () => _pick(false)),
                  ),
                ]),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _current,
                  activeThumbColor: kGreen,
                  title: const Text('Poste actuel',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  onChanged: (v) => setState(() => _current = v),
                ),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: adminFilledInput('Notes (facultatif)',
                      icon: Icons.notes_rounded),
                ),
              ],
            ),
          ),
          vsFormActions(context, _saving, _save, _isEdit),
        ]),
      ),
    );
  }
}

// ─── Diplôme ─────────────────────────────────────────────────────────────────
class _DiplomaForm extends ConsumerStatefulWidget {
  const _DiplomaForm({required this.profileId, this.diploma});
  final String profileId;
  final Diploma? diploma;
  @override
  ConsumerState<_DiplomaForm> createState() => _DiplomaFormState();
}

class _DiplomaFormState extends ConsumerState<_DiplomaForm> {
  final _title = TextEditingController();
  final _field = TextEditingController();
  final _institution = TextEditingController();
  final _year = TextEditingController();
  String? _level;
  bool _saving = false;

  bool get _isEdit => widget.diploma != null;

  @override
  void initState() {
    super.initState();
    final d = widget.diploma;
    if (d != null) {
      _title.text = d.title;
      _field.text = d.field ?? '';
      _institution.text = d.institution ?? '';
      _year.text = d.yearObtained?.toString() ?? '';
      _level = kDiplomaLevels.contains(d.level) ? d.level : null;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _field.dispose();
    _institution.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('L\'intitulé est requis'), backgroundColor: kRed));
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => saveDiploma(
        id: widget.diploma?.id,
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        profileId: widget.profileId,
        title: _title.text.trim(),
        level: _level,
        field: _field.text.trim().isEmpty ? null : _field.text.trim(),
        institution: _institution.text.trim().isEmpty
            ? null
            : _institution.text.trim(),
        yearObtained: int.tryParse(_year.text.trim()),
      ),
      success: _isEdit ? 'Diplôme modifié' : 'Diplôme ajouté',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          vsFormHeader(context, _isEdit ? 'Modifier le diplôme' : 'Nouveau diplôme',
              Icons.school_rounded),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                TextField(
                  controller: _title,
                  decoration: adminFilledInput('Intitulé du diplôme',
                      icon: Icons.workspace_premium_outlined),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _level,
                      isExpanded: true,
                      decoration: adminFilledInput('Niveau',
                          icon: Icons.stairs_outlined),
                      items: [
                        for (final l in kDiplomaLevels)
                          DropdownMenuItem(value: l, child: Text(l)),
                      ],
                      onChanged: (v) => setState(() => _level = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      decoration: adminFilledInput('Année',
                          icon: Icons.event_outlined),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _field,
                  decoration: adminFilledInput('Filière / spécialité',
                      icon: Icons.category_outlined),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _institution,
                  decoration: adminFilledInput('Établissement de délivrance',
                      icon: Icons.account_balance_outlined),
                ),
              ],
            ),
          ),
          vsFormActions(context, _saving, _save, _isEdit),
        ]),
      ),
    );
  }
}

// ─── Petits champs date ──────────────────────────────────────────────────────
class _DateField extends StatelessWidget {
  const _DateField(this.label, this.value, this.onTap);
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final txt = value == null
        ? '—'
        : '${value!.day.toString().padLeft(2, '0')}/'
            '${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: adminFilledInput(label, icon: Icons.calendar_today_rounded),
        child: Text(txt,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _DisabledField extends StatelessWidget {
  const _DisabledField(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: adminFilledInput(label, icon: Icons.lock_clock_outlined),
        child: Text('—',
            style: TextStyle(fontSize: 13.5, color: kTextMuted)),
      );
}

// ─── Briques partagées ───────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.onAdd,
  });
  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(icon, size: 18, color: kNavy),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w800, color: kNavy)),
        const Spacer(),
        if (onAdd != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onAdd,
            icon: Icon(Icons.add_circle_rounded, color: kNavy),
            tooltip: 'Ajouter',
          ),
      ]),
      const SizedBox(height: 6),
      child,
    ]);
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.child, this.onEdit, this.onDelete});
  final Widget child;
  final VoidCallback? onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 11, 6, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: child),
        if (onEdit != null || onDelete != null)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 18, color: kTextMuted),
            onSelected: (v) => v == 'edit' ? onEdit?.call() : onDelete?.call(),
            itemBuilder: (_) => [
              if (onEdit != null)
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
              if (onDelete != null)
                PopupMenuItem(
                    value: 'delete',
                    child: Text('Supprimer', style: TextStyle(color: kRed))),
            ],
          ),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(text,
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
}

Future<void> _confirmDelete(
    BuildContext context, String title, Future<void> Function() action) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kRed),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await runModuleWrite(context, action, success: 'Supprimé');
}
