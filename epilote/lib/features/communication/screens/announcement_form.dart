part of 'announcements_screen.dart';

// ─── Helpers formulaire ──────────────────────────────────────────────────────

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.5));
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.label, required this.sub,
      required this.value, required this.onChanged});
  final IconData icon;
  final String label, sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: value ? _kGreen : _kMuted),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(sub, style: const TextStyle(color: _kMuted, fontSize: 11)),
      ])),
      Switch(value: value, activeThumbColor: _kGreen, onChanged: onChanged),
    ]),
  );
}

// ─── Modal Formulaire (créer / éditer) — scope-aware ────────────────────────────

class _AnnFormModal extends ConsumerStatefulWidget {
  const _AnnFormModal({this.editing});
  final AnnouncementDetail? editing;
  @override
  ConsumerState<_AnnFormModal> createState() => _AnnFormModalState();
}

class _AnnFormModalState extends ConsumerState<_AnnFormModal> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();

  String  _audience  = 'all';
  String? _groupId;
  bool    _isPinned  = false;
  bool    _isPublished = false;
  DateTime? _expiresAt;
  bool    _saving    = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.editing;
    if (a != null) {
      _titleCtrl.text   = a.title;
      _contentCtrl.text = a.content;
      _audience         = a.targetAudience;
      _groupId          = a.groupId;
      _isPinned         = a.isPinned;
      _isPublished      = a.isPublished;
      _expiresAt        = a.expiresAt;
    } else {
      // admin_groupe : groupe verrouillé sur le sien.
      final ctx = ref.read(communicationContextProvider);
      if (ctx.isGroup) _groupId = ctx.groupId;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ctx = ref.read(communicationContextProvider);
    if (ctx.isGroup) _groupId = ctx.groupId;
    if (_groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez sélectionner un groupe scolaire.'),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user   = client.auth.currentUser;
      final payload = {
        'group_id':        _groupId,
        'title':           _titleCtrl.text.trim(),
        'content':         _contentCtrl.text.trim(),
        'target_audience': _audience,
        'is_pinned':       _isPinned,
        'is_published':    _isPublished,
        'published_at':    _isPublished ? DateTime.now().toIso8601String() : null,
        'expires_at':      _expiresAt?.toIso8601String(),
        'updated_at':      DateTime.now().toIso8601String(),
      };

      if (_isEditing) {
        await client.from('announcements').update(payload).eq('id', widget.editing!.id);
      } else {
        await client.from('announcements').insert({
          ...payload,
          'created_by': user?.id ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      ref.invalidate(announcementsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'), backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx    = ref.watch(communicationContextProvider);
    final groups = ref.watch(announcementsProvider).valueOrNull?.groups ?? const [];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: _kBg, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1A2F5A), _kNavy]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(_isEditing ? Icons.edit_rounded : Icons.add_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isEditing ? 'Modifier l\'annonce' : 'Nouvelle annonce',
                    style: const TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w800)),
                Text(_isEditing ? 'Mise à jour du contenu' : 'Créer et diffuser une annonce',
                    style: const TextStyle(color: _kMuted, fontSize: 11)),
              ]),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8), mouseCursor: SystemMouseCursors.click,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: _kSurface,
                      borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
                  child: const Icon(Icons.close_rounded, size: 15, color: _kMuted),
                ),
              ),
            ]),
          ),
          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Groupe cible — masqué pour admin_groupe (verrouillé sur son groupe)
                  if (ctx.isPlatform) ...[
                    const _FormSectionTitle('Groupe scolaire *'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: _kSurface,
                          border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _groupId,
                          isExpanded: true,
                          icon: const Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                          style: const TextStyle(color: _kText, fontSize: 13),
                          hint: const Text('Sélectionner un groupe', style: TextStyle(color: _kMuted)),
                          items: groups.map((g) => DropdownMenuItem<String?>(
                            value: g.id,
                            child: Row(children: [
                              const Icon(Icons.business_rounded, size: 14, color: _kNavy),
                              const SizedBox(width: 8),
                              Flexible(child: Text(g.name, overflow: TextOverflow.ellipsis)),
                            ]),
                          )).toList(),
                          onChanged: (v) => setState(() => _groupId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Titre
                  TextFormField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontSize: 13, color: _kText),
                    decoration: InputDecoration(
                      labelText: 'Titre *',
                      prefixIcon: const Icon(Icons.campaign_rounded, size: 16, color: _kMuted),
                      filled: true, fillColor: _kSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kNavy, width: 1.5)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  // Contenu
                  TextFormField(
                    controller: _contentCtrl,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 13, color: _kText),
                    decoration: InputDecoration(
                      labelText: 'Contenu *',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 60),
                        child: Icon(Icons.notes_rounded, size: 16, color: _kMuted),
                      ),
                      filled: true, fillColor: _kSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kNavy, width: 1.5)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  // Audience
                  const _FormSectionTitle('Audience cible'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: _kSurface,
                        border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _audience, isExpanded: true,
                        icon: const Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                        style: const TextStyle(color: _kText, fontSize: 13),
                        items: _audienceLabels.entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Row(children: [
                            Icon(_audienceIcon(e.key), size: 14, color: _audienceColor(e.key)),
                            const SizedBox(width: 8),
                            Text(e.value),
                          ]),
                        )).toList(),
                        onChanged: (v) => setState(() => _audience = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Expiration
                  const _FormSectionTitle('Date d\'expiration (optionnel)'),
                  const SizedBox(height: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _pickExpiry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(color: _kSurface,
                            border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.event_rounded, size: 16, color: _kMuted),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            _expiresAt != null ? _fmtDate(_expiresAt) : 'Aucune expiration',
                            style: TextStyle(fontSize: 13,
                                color: _expiresAt != null ? _kText : _kMuted),
                          )),
                          if (_expiresAt != null)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => setState(() => _expiresAt = null),
                                child: const Icon(Icons.close_rounded, size: 14, color: _kMuted),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Toggles
                  const _FormSectionTitle('Options de diffusion'),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    icon: Icons.push_pin_rounded, label: 'Épinglez l\'annonce',
                    sub: 'Affichée en tête de liste', value: _isPinned,
                    onChanged: (v) => setState(() => _isPinned = v),
                  ),
                  _SwitchRow(
                    icon: Icons.publish_rounded, label: 'Publier immédiatement',
                    sub: 'Visible par les destinataires dès maintenant', value: _isPublished,
                    onChanged: (v) => setState(() => _isPublished = v),
                  ),
                ]),
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            decoration: const BoxDecoration(
              color: _kSurface,
              border: Border(top: BorderSide(color: _kBorder)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context), borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Annuler', style: TextStyle(color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: _saving ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
                child: InkWell(
                  onTap: _saving ? null : _save, borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _saving ? _kNavy.withValues(alpha: 0.5) : _kNavy,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _saving ? [] : [BoxShadow(
                        color: _kNavy.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_saving)
                        const SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.save_rounded, color: Colors.white, size: 15),
                      const SizedBox(width: 8),
                      Text(_saving ? 'Enregistrement…' : (_isEditing ? 'Enregistrer' : 'Créer l\'annonce'),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
