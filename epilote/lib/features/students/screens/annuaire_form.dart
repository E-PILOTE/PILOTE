part of 'annuaire_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE TUTEUR — ajout / édition d'un contact famille (offline-first).
//  Téléphone principal obligatoire. Validation locale avant écriture.
// ════════════════════════════════════════════════════════════════════════════
class _TutorForm extends ConsumerStatefulWidget {
  const _TutorForm({required this.studentId, this.tutor});
  final String studentId;
  final StudentTutorModel? tutor;
  @override
  ConsumerState<_TutorForm> createState() => _TutorFormState();
}

class _TutorFormState extends ConsumerState<_TutorForm> {
  late final TextEditingController _first, _last, _phone1, _phone2, _email,
      _prof, _addr;
  String _rel = 'pere';
  bool _primary = false, _emergency = false;
  bool _saving = false;

  bool get _isEdit => widget.tutor != null;

  @override
  void initState() {
    super.initState();
    final t = widget.tutor;
    _first = TextEditingController(text: t?.firstName ?? '');
    _last = TextEditingController(text: t?.lastName ?? '');
    _phone1 = TextEditingController(text: t?.phonePrimary ?? '');
    _phone2 = TextEditingController(text: t?.phoneSecondary ?? '');
    _email = TextEditingController(text: t?.email ?? '');
    _prof = TextEditingController(text: t?.profession ?? '');
    _addr = TextEditingController(text: t?.address ?? '');
    _rel = t?.relationship ?? 'pere';
    _primary = t?.isPrimaryContact ?? false;
    _emergency = t?.isEmergencyContact ?? false;
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _phone1, _phone2, _email, _prof, _addr]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  Future<void> _save() async {
    final first = _first.text.trim();
    final last = _last.text.trim();
    final phone = _phone1.text.trim();
    if (first.isEmpty || last.isEmpty) {
      _snack('Nom et prénom obligatoires', kAccent);
      return;
    }
    if (phone.isEmpty) {
      _snack('Téléphone principal obligatoire', kAccent);
      return;
    }
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () async {
        if (_isEdit) {
          await updateTutor(
            tutorId: widget.tutor!.id,
            firstName: first,
            lastName: last,
            relationship: _rel,
            phonePrimary: phone,
            phoneSecondary: _phone2.text.trim(),
            email: _email.text.trim(),
            profession: _prof.text.trim(),
            address: _addr.text.trim(),
            isPrimaryContact: _primary,
            isEmergencyContact: _emergency,
          );
        } else {
          final groupId =
              ref.read(authNotifierProvider).valueOrNull?.groupId ?? '';
          await addTutor(
            studentId: widget.studentId,
            groupId: groupId,
            firstName: first,
            lastName: last,
            relationship: _rel,
            phonePrimary: phone,
            phoneSecondary: _phone2.text.trim(),
            email: _email.text.trim(),
            profession: _prof.text.trim(),
            address: _addr.text.trim(),
            isPrimaryContact: _primary,
            isEmergencyContact: _emergency,
          );
        }
      },
      success: _isEdit ? 'Contact mis à jour' : 'Contact ajouté',
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
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 660),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder))),
            child: Row(children: [
              Icon(_isEdit ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
                  size: 18, color: kNavy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_isEdit ? 'Modifier le contact' : 'Nouveau contact',
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ),
              IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(children: [
                  Expanded(child: _Field('Prénom', _first)),
                  const SizedBox(width: 12),
                  Expanded(child: _Field('Nom', _last)),
                ]),
                const SizedBox(height: 14),
                const _Lbl('Lien de parenté'),
                _RelDropdown(value: _rel, onChanged: (v) => setState(() => _rel = v)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: _Field('Téléphone principal *', _phone1,
                          keyboard: TextInputType.phone)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _Field('Téléphone secondaire', _phone2,
                          keyboard: TextInputType.phone)),
                ]),
                const SizedBox(height: 14),
                _Field('E-mail', _email, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _Field('Profession', _prof),
                const SizedBox(height: 14),
                _Field('Adresse', _addr),
                const SizedBox(height: 8),
                _CheckTile(
                  label: 'Contact principal',
                  sub: 'Premier joint en cas de besoin',
                  value: _primary,
                  onChanged: (v) => setState(() => _primary = v),
                ),
                _CheckTile(
                  label: 'Contact d\'urgence',
                  sub: 'À appeler en priorité en cas d\'urgence',
                  value: _emergency,
                  onChanged: (v) => setState(() => _emergency = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _saving ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kNavy),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isEdit ? 'Enregistrer' : 'Ajouter'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Lbl extends StatelessWidget {
  const _Lbl(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
      );
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.controller, {this.keyboard});
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Lbl(label),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 13.5),
            decoration: adminFilledInput(label.replaceAll(' *', '')),
          ),
        ],
      );
}

class _RelDropdown extends StatelessWidget {
  const _RelDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    const items = [
      ('pere', 'Père'),
      ('mere', 'Mère'),
      ('tuteur', 'Tuteur légal'),
      ('autre', 'Autre'),
    ];
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      style: const TextStyle(fontSize: 13.5, color: kTextPrimary),
      icon: const Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
      decoration: adminFilledInput('Lien', icon: Icons.family_restroom_rounded),
      items: [
        for (final e in items) DropdownMenuItem(value: e.$1, child: Text(e.$2)),
      ],
      onChanged: (v) => onChanged(v ?? 'pere'),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });
  final String label, sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: kNavy,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary)),
                    Text(sub,
                        style:
                            const TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ]),
            ),
          ]),
        ),
      );
}
