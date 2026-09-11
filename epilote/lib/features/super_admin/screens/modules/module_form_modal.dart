part of '../modules_screen.dart';

// Formulaire de module.

class _ModuleFormModal extends ConsumerStatefulWidget {
  const _ModuleFormModal({this.editing});
  final ModuleItem? editing;
  @override
  ConsumerState<_ModuleFormModal> createState() => _ModuleFormModalState();
}

class _ModuleFormModalState extends ConsumerState<_ModuleFormModal> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _slugCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');

  String  _emoji    = '🧩';
  String? _categoryId;
  bool    _isActive = true;
  bool    _saving   = false;
  bool    _slugTouched = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.editing;
    if (m != null) {
      _nameCtrl.text  = m.name;
      _slugCtrl.text  = m.slug;
      _descCtrl.text  = m.description ?? '';
      _orderCtrl.text = '${m.displayOrder}';
      _emoji          = m.emoji;
      _categoryId     = m.categoryId;
      _isActive       = m.isActive;
      _slugTouched    = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez sélectionner une catégorie'),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final payload = {
        'category_id':   _categoryId,
        'name':          _nameCtrl.text.trim(),
        'slug':          _slugCtrl.text.trim().isEmpty
            ? _slugify(_nameCtrl.text) : _slugCtrl.text.trim(),
        'description':   _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'icon':          _emoji,
        'display_order': int.tryParse(_orderCtrl.text.trim()) ?? 0,
        'is_active':     _isActive,
        'updated_at':    DateTime.now().toIso8601String(),
      };
      if (_isEditing) {
        await client.from('modules').update(payload).eq('id', widget.editing!.id);
      } else {
        await client.from('modules').insert(payload);
      }
      ref.invalidate(modulesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e)),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(modulesProvider).valueOrNull;
    final cats = data?.categories ?? const <ModuleCategory>[];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(children: [
          _FormHeader(
            icon: _isEditing ? Icons.edit_rounded : Icons.add_rounded,
            title: _isEditing ? 'Modifier le module' : 'Nouveau module',
            subtitle: _isEditing
                ? 'Mise à jour des informations'
                : 'Ajoutez un module au catalogue',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _EmojiPickerRow(
                    selected: _emoji,
                    onSelect: (e) => setState(() => _emoji = e),
                  ),
                  const SizedBox(height: 18),
                  _FormField(
                    controller: _nameCtrl,
                    label: 'Nom du module *',
                    icon: Icons.extension_rounded,
                    onChanged: (v) => setState(() {
                      if (!_slugTouched) _slugCtrl.text = _slugify(v);
                    }),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _slugCtrl,
                    label: 'Slug (identifiant technique) *',
                    icon: Icons.link_rounded,
                    hint: 'auto-généré depuis le nom',
                    onChanged: (_) => _slugTouched = true,
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Catégorie & Ordre'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      border: Border.all(
                          color: _categoryId == null
                              ? _kRed.withValues(alpha: 0.5) : _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _categoryId,
                        isExpanded: true,
                        hint: Text('Sélectionner une catégorie *',
                            style: TextStyle(color: _kMuted, fontSize: 13)),
                        icon: Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                        style: TextStyle(color: _kText, fontSize: 13),
                        items: cats.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(children: [
                            Text(c.emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                          ]),
                        )).toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _orderCtrl,
                    label: 'Ordre d\'affichage',
                    icon: Icons.sort_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Description (optionnelle)'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Décrivez la fonction de ce module…',
                      hintStyle: TextStyle(color: _kMuted, fontSize: 12.5),
                      filled: true, fillColor: _kSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _kNavy, width: 1.5)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ActiveToggleTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ]),
              ),
            ),
          ),
          _FormFooter(
            saving: _saving,
            saveLabel: _isEditing ? 'Enregistrer' : 'Créer le module',
            onSave: _save,
          ),
        ]),
      ),
    );
  }
}

// ─── Modal Catégorie (création / édition) ─────────────────────────────────────
