part of 'messages_screen.dart';

// ─── Panneau de lecture ───────────────────────────────────────────────────────
class _MessageReader extends ConsumerStatefulWidget {
  const _MessageReader({required this.msg});
  final MessageModel msg;

  @override
  ConsumerState<_MessageReader> createState() => _MessageReaderState();
}

class _MessageReaderState extends ConsumerState<_MessageReader> {
  bool _showReply = false;

  Future<void> _toggleArchive() async {
    final client = ref.read(supabaseClientProvider);
    if (widget.msg.isArchived) {
      await unarchiveMessage(client, widget.msg.id);
    } else {
      await archiveMessage(client, widget.msg.id);
    }
    ref.read(_selectedProv.notifier).state = null;
    ref.invalidate(messagesProvider);
  }

  Future<void> _markUnread() async {
    await markMessageUnread(ref.read(supabaseClientProvider), widget.msg.id);
    ref.read(_selectedProv.notifier).state = null;
    ref.invalidate(messagesProvider);
  }

  void _forward() {
    final body = '\n\n──────────\nMessage transféré :\n${widget.msg.body}';
    showDialog<void>(
      context: context,
      builder: (_) => _ComposeDialog(
        onSent: () => ref.invalidate(messagesProvider),
        initialSubject: 'TR: ${baseSubject(widget.msg.subject)}',
        initialBody: body,
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer ce message ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await deleteMessage(ref.read(supabaseClientProvider), widget.msg.id);
    ref.read(_selectedProv.notifier).state = null;
    ref.invalidate(messagesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id ?? '';
    final all = ref.watch(messagesProvider).valueOrNull?.messages ?? [widget.msg];
    final thread = threadOf(all, widget.msg);
    final dt = widget.msg.insertedAt.isNotEmpty
        ? DateTime.tryParse(widget.msg.insertedAt)
        : null;
    final dateStr = dt != null ? _fmtFull.format(dt.toLocal()) : '—';
    final counterpart = widget.msg.counterpart(myId);

    return Container(
      color: const Color(0xFFFAFBFC),
      child: Column(
        children: [
          Container(
            color: _kCard,
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(baseSubject(widget.msg.subject),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800, color: _kText)),
                    ),
                    _ActionBtn(
                      icon: Icons.reply_rounded,
                      label: 'Répondre',
                      color: _kNavy,
                      onTap: () => setState(() => _showReply = !_showReply),
                    ),
                    const SizedBox(width: 4),
                    _ActionBtn(
                      icon: Icons.forward_rounded,
                      label: 'Transférer',
                      color: _kNavy,
                      onTap: _forward,
                    ),
                    const SizedBox(width: 4),
                    if (widget.msg.isRead)
                      _ActionBtn(
                        icon: Icons.mark_email_unread_rounded,
                        label: 'Marquer non lu',
                        color: _kSub,
                        onTap: _markUnread,
                      ),
                    if (widget.msg.isRead) const SizedBox(width: 4),
                    _ActionBtn(
                      icon: widget.msg.isArchived
                          ? Icons.unarchive_rounded
                          : Icons.archive_rounded,
                      label: widget.msg.isArchived ? 'Désarchiver' : 'Archiver',
                      color: _kSub,
                      onTap: _toggleArchive,
                    ),
                    const SizedBox(width: 4),
                    _ActionBtn(
                      icon: Icons.delete_outline_rounded,
                      label: 'Supprimer',
                      color: _kRed,
                      onTap: _delete,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: _kSub,
                      onPressed: () => ref.read(_selectedProv.notifier).state = null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 16, runSpacing: 4, children: [
                  _MetaItem(icon: Icons.person_rounded, label: counterpart),
                  _MetaItem(icon: Icons.corporate_fare_rounded, label: widget.msg.groupName),
                  _MetaItem(icon: Icons.schedule_rounded, label: dateStr),
                  if (thread.length > 1)
                    _MetaItem(
                        icon: Icons.forum_rounded,
                        label: '${thread.length} messages'),
                  if (!widget.msg.isRead)
                    const _Pill(text: 'Non lu', color: _kNavy),
                  if (widget.msg.isArchived)
                    const _Pill(text: 'Archivé', color: _kSub),
                ]),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...thread.map((m) => _Bubble(msg: m, mine: m.senderId == myId)),
                  if (_showReply) ...[
                    const SizedBox(height: 20),
                    _ReplyForm(
                      msg: widget.msg,
                      onCancel: () => setState(() => _showReply = false),
                      onSent: () {
                        setState(() => _showReply = false);
                        ref.invalidate(messagesProvider);
                      },
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (!_showReply)
            Container(
              color: _kCard,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showReply = true),
                  icon: const Icon(Icons.reply_rounded, size: 14),
                  label: const Text('Répondre'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kNavy,
                    side: const BorderSide(color: _kNavy),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _toggleArchive,
                  icon: Icon(
                    widget.msg.isArchived
                        ? Icons.unarchive_rounded
                        : Icons.archive_rounded,
                    size: 14,
                  ),
                  label: Text(widget.msg.isArchived ? 'Désarchiver' : 'Archiver'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kSub,
                    side: const BorderSide(color: _kBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

// ─── Bulle de conversation ────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.mine});
  final MessageModel msg;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final dt = msg.insertedAt.isNotEmpty ? DateTime.tryParse(msg.insertedAt) : null;
    final dateStr = dt != null ? _fmtFull.format(dt.toLocal()) : '';
    final who = mine ? 'Moi' : msg.senderName;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: mine ? _kNavy.withValues(alpha: 0.07) : _kCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(mine ? 12 : 2),
            bottomRight: Radius.circular(mine ? 2 : 12),
          ),
          border: Border.all(color: mine ? _kNavy.withValues(alpha: 0.2) : _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(who,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: mine ? _kNavy : _kText)),
              const SizedBox(width: 8),
              Text(dateStr, style: const TextStyle(fontSize: 10, color: _kSub)),
            ]),
            const SizedBox(height: 6),
            SelectableText(msg.body,
                style: const TextStyle(fontSize: 14, color: _kText, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(icon, size: 18),
          color: color,
          onPressed: onTap,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _kSub),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: _kSub)),
        ],
      );
}

// ─── Formulaire de réponse ────────────────────────────────────────────────────
class _ReplyForm extends ConsumerStatefulWidget {
  const _ReplyForm({required this.msg, required this.onCancel, required this.onSent});
  final MessageModel msg;
  final VoidCallback onCancel;
  final VoidCallback onSent;

  @override
  ConsumerState<_ReplyForm> createState() => _ReplyFormState();
}

class _ReplyFormState extends ConsumerState<_ReplyForm> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(supabaseClientProvider).auth.currentUser?.id ?? '';
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kNavy.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F4F8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              const Icon(Icons.reply_rounded, size: 14, color: _kNavy),
              const SizedBox(width: 6),
              Text('Répondre à ${widget.msg.counterpart(myId)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                color: _kSub,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onCancel,
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _ctrl,
              maxLines: 5,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Écrivez votre réponse…',
                hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kNavy)),
                filled: true,
                fillColor: _kBg,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  style: TextButton.styleFrom(foregroundColor: _kSub),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Envoyer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    final client = ref.read(supabaseClientProvider);
    final myId = client.auth.currentUser?.id ?? '';
    // Répondre à l'interlocuteur (l'autre partie de la conversation).
    final replyTo =
        widget.msg.senderId == myId ? widget.msg.recipientId : widget.msg.senderId;
    if (replyTo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible de répondre : interlocuteur inconnu'),
          backgroundColor: _kRed));
      return;
    }
    setState(() => _sending = true);
    try {
      await sendMessage(
        client: client,
        senderId: myId,
        recipientId: replyTo,
        groupId: widget.msg.groupId,
        subject: 'RE: ${widget.msg.subject}',
        body: _ctrl.text.trim(),
        parentId: widget.msg.id,
      );
      _ctrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Réponse envoyée !'), backgroundColor: _kGreen));
        widget.onSent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: _kRed));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
