part of 'messagerie_staff.dart';

// ─── Composer un nouveau message (annuaire local + multi-destinataires) ─────────

class _ComposeDialog extends ConsumerStatefulWidget {
  const _ComposeDialog({required this.onSent});

  /// Rappelé avec l'id du premier destinataire pour ouvrir la conversation.
  final ValueChanged<String> onSent;

  @override
  ConsumerState<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends ConsumerState<_ComposeDialog> {
  final _selected = <String, RecipientOption>{};
  final _search   = TextEditingController();
  final _subject  = TextEditingController();
  final _body     = TextEditingController();
  String _query   = '';
  bool _sending   = false;
  bool _uploading = false;
  final List<MessageAttachment> _pending = [];
  String? _error;

  /// Joint des fichiers (upload Storage → nécessite internet).
  Future<void> _attach() async {
    final ctx = ref.read(communicationContextProvider);
    final me  = ref.read(authNotifierProvider).valueOrNull;
    // Plateforme : le dossier Storage = groupe du destinataire (option = groupe),
    // pour que l'admin du groupe puisse lire la pièce jointe (RLS scopée groupe).
    if (ctx.isPlatform && _selected.isEmpty) {
      setState(() =>
          _error = "Choisissez d'abord un destinataire avant de joindre un fichier.");
      return;
    }
    final groupForUpload = ctx.isPlatform
        ? _selected.values.first.value
        : (me?.groupId ?? '');
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final added = await pickAndUploadAttachments(
        client: ref.read(supabaseClientProvider),
        groupId: groupForUpload,
        bucket: 'message-attachments',
      );
      if (mounted) setState(() => _pending.addAll(added));
    } on AttachmentUploadException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = ref.read(authNotifierProvider).valueOrNull;
    if (me == null) return;
    if (_selected.isEmpty) {
      setState(() => _error = 'Choisissez au moins un destinataire.');
      return;
    }
    if (_body.text.trim().isEmpty && _pending.isEmpty) {
      setState(() => _error = 'Le message ne peut pas être vide.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final subject = _subject.text.trim().isEmpty
          ? '(Sans objet)'
          : _subject.text.trim();
      // Multi-destinataires = une ligne par destinataire (fan-out scope-aware :
      // local PowerSync pour l'école, Supabase pour admin ; super_admin résout
      // le groupe choisi vers son admin).
      String? firstOther;
      for (final opt in _selected.values) {
        final resolved =
            await resolveScopedRecipient(ref, opt, me.groupId ?? '');
        if (resolved == null) continue;
        firstOther ??= resolved.recipientId;
        await sendMessageScoped(
          ref,
          senderId:    me.id,
          recipientId: resolved.recipientId,
          groupId:     resolved.groupId,
          subject:     subject,
          body:        _body.text,
          attachments: List.of(_pending),
        );
      }
      if (firstOther == null) {
        setState(() => _error = 'Aucun destinataire valide (groupe sans admin ?).');
        return;
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSent(firstOther);
      }
    } catch (e) {
      // Échec d'envoi le plus courant : session expirée → l'insert viole la RLS
      // (auth.uid() ne correspond plus). On l'explique au lieu de planter.
      if (mounted) {
        setState(() => _error = _friendlySendError(e));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Traduit une erreur d'envoi technique en message lisible.
  static String _friendlySendError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('row-level security') || s.contains('42501')) {
      return 'Votre session a expiré. Déconnectez-vous puis reconnectez-vous '
          'pour envoyer ce message.';
    }
    return "Échec de l'envoi : $e";
  }

  @override
  Widget build(BuildContext context) {
    final ctx      = ref.watch(communicationContextProvider);
    final dirAsync = ref.watch(scopedRecipientsProvider);
    final dir      = dirAsync.valueOrNull ?? const <RecipientOption>[];
    final q        = _query.trim().toLowerCase();
    final results  = q.isEmpty
        ? dir
        : dir
            .where((o) =>
                o.label.toLowerCase().contains(q) ||
                (o.subtitle ?? '').toLowerCase().contains(q))
            .toList();
    final targetWord = ctx.isPlatform
        ? 'groupes scolaires'
        : ctx.isGroup
            ? 'membres de votre groupe'
            : 'collègues de votre école';

    return AdminFormDialog(
      icon: Icons.edit_outlined,
      title: 'Nouveau message',
      subtitle: 'Vers un ou plusieurs $targetWord',
      width: 520,
      saving: _sending,
      submitLabel: _selected.length > 1
          ? 'Envoyer (${_selected.length})'
          : 'Envoyer',
      submitIcon: Icons.send_rounded,
      onSubmit: _send,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminFormSectionLabel('Destinataires'),
          const SizedBox(height: 8),
          if (_selected.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in _selected.values)
                  InputChip(
                    avatar: _Avatar(name: o.label, radius: 11),
                    label: Text(o.label,
                        style: const TextStyle(fontSize: 11.5)),
                    onDeleted: () =>
                        setState(() => _selected.remove(o.value)),
                    deleteIconColor: kTextMuted,
                    backgroundColor: kSurface,
                    side: BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 13),
            decoration: adminFilledInput('Rechercher un collègue…',
                icon: Icons.search_rounded),
          ),
          const SizedBox(height: 8),
          Container(
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: dir.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Annuaire indisponible (synchronisation en attente).',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: kTextMuted),
                      ),
                    ),
                  )
                : results.isEmpty
                    ? Center(
                        child: Text('Aucun collègue ne correspond.',
                            style: TextStyle(
                                fontSize: 12, color: kTextMuted)),
                      )
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: kBorder),
                        itemBuilder: (_, i) =>
                            _DirectoryTile(
                          option: results[i],
                          selected:
                              _selected.containsKey(results[i].value),
                          onTap: () => setState(() {
                            final o = results[i];
                            _selected.containsKey(o.value)
                                ? _selected.remove(o.value)
                                : _selected[o.value] = o;
                            _error = null;
                          }),
                        ),
                      ),
          ),
          const SizedBox(height: 14),
          const AdminFormSectionLabel('Message'),
          const SizedBox(height: 8),
          TextField(
            controller: _subject,
            style: const TextStyle(fontSize: 13),
            decoration: adminInputDecoration('Objet (optionnel)',
                icon: Icons.subject_rounded),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontSize: 13),
            decoration: adminInputDecoration('Votre message…'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _uploading ? null : _attach,
              icon: _uploading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.attach_file_rounded, size: 16),
              label: const Text('Joindre des fichiers'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: kBorder),
                textStyle: const TextStyle(fontSize: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Images, documents, audio, vidéo — internet requis',
                  style: TextStyle(fontSize: 10.5, color: kTextMuted)),
            ),
          ]),
          CommAttachmentEditList(
            items: _pending,
            onRemove: (i) => setState(() => _pending.removeAt(i)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AdminErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}

// ─── Ligne de l'annuaire (avatar initiales + nom + rôle) ────────────────────────

class _DirectoryTile extends StatelessWidget {
  const _DirectoryTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final RecipientOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? kNavy.withValues(alpha: 0.06) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          _Avatar(name: option.label, radius: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary)),
                if (option.subtitle != null &&
                    option.subtitle!.isNotEmpty)
                  Text(_roleLabel(option.subtitle),
                      style: TextStyle(
                          fontSize: 10.5, color: kTextMuted)),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: selected ? kGreen : kBorder,
          ),
        ]),
      ),
    );
  }
}
