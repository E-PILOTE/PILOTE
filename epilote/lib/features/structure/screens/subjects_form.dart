part of 'subjects_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CRÉER / MODIFIER UNE MATIÈRE
// ════════════════════════════════════════════════════════════════════════════

class _SubjectForm extends ConsumerStatefulWidget {
  const _SubjectForm({this.existing});
  final SubjectModel? existing;
  @override
  ConsumerState<_SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends ConsumerState<_SubjectForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late int _coef = widget.existing?.coefficient ?? 1;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Le nom de la matière est obligatoire.', kRed);
      return;
    }
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    final schoolId = profile?.schoolId;
    if (groupId == null || schoolId == null || schoolId.isEmpty) {
      _snack('École introuvable.', kRed);
      return;
    }
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () async {
        if (_isEdit) {
          await updateSubject(
              id: widget.existing!.id, name: name, coefficient: _coef);
        } else {
          await createSubject(
              groupId: groupId,
              schoolId: schoolId,
              name: name,
              coefficient: _coef);
        }
      },
      success: _isEdit ? 'Matière mise à jour' : 'Matière créée',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: _isEdit ? Icons.edit_outlined : Icons.add_rounded,
      title: _isEdit ? 'Modifier la matière' : 'Nouvelle matière',
      subtitle: 'Identité réutilisable · le coefficient s\'ajuste par classe',
      width: 480,
      saving: _saving,
      submitLabel: _isEdit ? 'Enregistrer' : 'Créer',
      submitIcon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
      onSubmit: _saving ? null : _save,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Nom de la matière *',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          autofocus: true,
          style: const TextStyle(fontSize: 13.5),
          decoration: adminFilledInput('Ex. Mathématiques',
              icon: Icons.menu_book_outlined),
        ),
        const SizedBox(height: 16),
        Text('Coefficient par défaut',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 8),
        Row(children: [
          _StepBtn(
              icon: Icons.remove_rounded,
              onTap: () => setState(() => _coef = (_coef - 1).clamp(1, 20))),
          Expanded(
            child: Center(
              child: Text('$_coef',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: kNavy)),
            ),
          ),
          _StepBtn(
              icon: Icons.add_rounded,
              onTap: () => setState(() => _coef = (_coef + 1).clamp(1, 20))),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
              'Une même matière peut être enseignée dans plusieurs niveaux et '
              'cycles, avec un coefficient différent par classe (ex. Maths coef. '
              '4 en Tle C, coef. 2 en Tle A). Affectez-la aux classes depuis son '
              'détail.',
              style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.35)),
        ),
      ]),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder)),
            child: Icon(icon, size: 20, color: kNavy),
          ),
        ),
      );
}
