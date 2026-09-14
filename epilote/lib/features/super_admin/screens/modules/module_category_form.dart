part of '../modules_screen.dart';

// Formulaire de catégorie.

class _CategoryFormModal extends ConsumerStatefulWidget {
  const _CategoryFormModal({this.editing});
  final ModuleCategory? editing;
  @override
  ConsumerState<_CategoryFormModal> createState() => _CategoryFormModalState();
}

class _CategoryFormModalState extends ConsumerState<_CategoryFormModal> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _slugCtrl  = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');

  String _emoji = '🗂️';
  bool   _saving = false;
  bool   _slugTouched = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.editing;
    if (c != null) {
      _nameCtrl.text  = c.name;
      _slugCtrl.text  = c.slug;
      _orderCtrl.text = '${c.displayOrder}';
      _emoji          = c.emoji;
      _slugTouched    = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final payload = {
        'name':          _nameCtrl.text.trim(),
        'slug':          _slugCtrl.text.trim().isEmpty
            ? _slugify(_nameCtrl.text) : _slugCtrl.text.trim(),
        'icon':          _emoji,
        'display_order': int.tryParse(_orderCtrl.text.trim()) ?? 0,
        'updated_at':    DateTime.now().toIso8601String(),
      };
      if (_isEditing) {
        await client.from('module_categories').update(payload).eq('id', widget.editing!.id);
      } else {
        await client.from('module_categories').insert(payload);
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 640),
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
            icon: _isEditing ? Icons.edit_rounded : Icons.create_new_folder_rounded,
            title: _isEditing ? 'Modifier la catégorie' : 'Nouvelle catégorie',
            subtitle: _isEditing
                ? 'Mise à jour des informations'
                : 'Organisez les modules par thème',
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
                    label: 'Nom de la catégorie *',
                    icon: Icons.folder_rounded,
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
                  _FormField(
                    controller: _orderCtrl,
                    label: 'Ordre d\'affichage',
                    icon: Icons.sort_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ]),
              ),
            ),
          ),
          _FormFooter(
            saving: _saving,
            saveLabel: _isEditing ? 'Enregistrer' : 'Créer la catégorie',
            onSave: _save,
          ),
        ]),
      ),
    );
  }
}

// ─── Sélecteur d'emoji ────────────────────────────────────────────────────────
