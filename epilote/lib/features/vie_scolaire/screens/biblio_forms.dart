part of 'bibliotheque_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE OUVRAGE — titre, auteur, ISBN, catégorie, exemplaires, cote.
// ════════════════════════════════════════════════════════════════════════════
class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm({this.item});
  final LibraryItem? item;
  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _isbn = TextEditingController();
  final _category = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _location = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      _title.text = it.title;
      _author.text = it.author ?? '';
      _isbn.text = it.isbn ?? '';
      _category.text = it.category ?? '';
      _qty.text = '${it.quantity}';
      _location.text = it.location ?? '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _isbn.dispose();
    _category.dispose();
    _qty.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = int.tryParse(_qty.text.trim());
    if (_title.text.trim().isEmpty || qty == null || qty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Titre et nombre d\'exemplaires (≥1) requis'),
          backgroundColor: kRed));
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => saveItem(
        id: widget.item?.id,
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        title: _title.text.trim(),
        author: _author.text.trim().isEmpty ? null : _author.text.trim(),
        isbn: _isbn.text.trim().isEmpty ? null : _isbn.text.trim(),
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        quantity: qty,
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      ),
      success: _isEdit ? 'Ouvrage modifié' : 'Ouvrage ajouté',
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
          vsFormHeader(context, _isEdit ? 'Modifier l\'ouvrage' : 'Nouvel ouvrage',
              Icons.menu_book_rounded),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                TextField(
                  controller: _title,
                  decoration:
                      adminFilledInput('Titre', icon: Icons.title_rounded),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _author,
                  decoration:
                      adminFilledInput('Auteur', icon: Icons.person_rounded),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _category,
                      decoration: adminFilledInput('Catégorie',
                          icon: Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      decoration: adminFilledInput('Exempl.',
                          icon: Icons.tag_rounded),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _isbn,
                      decoration:
                          adminFilledInput('ISBN', icon: Icons.qr_code_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _location,
                      decoration: adminFilledInput('Cote',
                          icon: Icons.shelves),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          vsFormActions(context, _saving, _save, _isEdit),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE PRÊT — ouvrage (disponible), emprunteur, dates emprunt/retour.
// ════════════════════════════════════════════════════════════════════════════
class _LoanForm extends ConsumerStatefulWidget {
  const _LoanForm();
  @override
  ConsumerState<_LoanForm> createState() => _LoanFormState();
}

class _LoanFormState extends ConsumerState<_LoanForm> {
  String? _itemId;
  String? _borrowerId;
  DateTime _borrow = DateTime.now();
  DateTime _due = DateTime.now().add(const Duration(days: 14));
  bool _saving = false;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _key(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _save() async {
    if (_itemId == null || _borrowerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choisissez un ouvrage et un emprunteur'),
          backgroundColor: kRed));
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    setState(() => _saving = true);
    String? error;
    final ok = await runModuleWrite(
      context,
      () async {
        error = await createLoan(
          groupId: p?.groupId ?? '',
          schoolId: p?.schoolId ?? '',
          itemId: _itemId!,
          borrowerId: _borrowerId!,
          borrowDate: _key(_borrow),
          dueDate: _key(_due),
        );
        if (error != null) throw Exception(error);
      },
      success: 'Prêt enregistré',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
    final available = [for (final it in items) if (it.available > 0) it];
    final students = ref.watch(vsStudentsProvider).valueOrNull ?? const [];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          vsFormHeader(context, 'Nouveau prêt', Icons.book_rounded),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _itemId,
                  isExpanded: true,
                  decoration: adminFilledInput('Ouvrage',
                      icon: Icons.menu_book_rounded),
                  items: [
                    for (final it in available)
                      DropdownMenuItem(
                          value: it.id,
                          child: Text('${it.title} (${it.available} dispo)',
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _itemId = v),
                ),
                if (available.isEmpty) ...[
                  const SizedBox(height: 6),
                  const Text('Aucun exemplaire disponible au catalogue.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFFF59E0B))),
                ],
                const SizedBox(height: 14),
                VsStudentField(
                  students: students,
                  selectedId: _borrowerId,
                  onSelect: (id) => setState(() => _borrowerId = id),
                  label: 'Emprunteur',
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _dateField('Emprunt', _borrow, () async {
                    final d = await _pick(_borrow);
                    if (d != null) setState(() => _borrow = d);
                  })),
                  const SizedBox(width: 12),
                  Expanded(child: _dateField('Retour prévu', _due, () async {
                    final d = await _pick(_due);
                    if (d != null) setState(() => _due = d);
                  })),
                ]),
              ],
            ),
          ),
          vsFormActions(context, _saving, _save, false),
        ]),
      ),
    );
  }

  Future<DateTime?> _pick(DateTime init) => showDatePicker(
        context: context,
        initialDate: init,
        firstDate: DateTime(init.year - 1),
        lastDate: DateTime(init.year + 1),
      );

  Widget _dateField(String label, DateTime d, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration:
              adminFilledInput(label, icon: Icons.calendar_today_rounded),
          child: Text(_fmt(d),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      );
}
