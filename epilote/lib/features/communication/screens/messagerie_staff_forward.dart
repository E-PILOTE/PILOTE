part of 'messagerie_staff.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Transfert d'un message vers une autre conversation : personnes (annuaire
//  scope-aware) OU groupes existants. Réutilise sendMessageScoped /
//  sendGroupMessageScoped avec le corps + pièces jointes du message source.
// ════════════════════════════════════════════════════════════════════════════

class ForwardMessageDialog extends ConsumerStatefulWidget {
  const ForwardMessageDialog({super.key, required this.source});
  final MessageModel source;

  @override
  ConsumerState<ForwardMessageDialog> createState() =>
      _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends ConsumerState<ForwardMessageDialog> {
  String _query = '';
  bool _busy = false;

  Future<void> _toPerson(RecipientOption opt) async {
    final me = ref.read(authNotifierProvider).valueOrNull;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      final resolved = await resolveScopedRecipient(ref, opt, me.groupId ?? '');
      if (resolved == null) {
        _snack('Destinataire indisponible (groupe sans admin).', error: true);
        return;
      }
      await sendMessageScoped(
        ref,
        senderId:    me.id,
        recipientId: resolved.recipientId,
        groupId:     resolved.groupId,
        subject:     'Transféré',
        body:        widget.source.body,
        attachments: widget.source.attachments,
      );
      _done(opt.label);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toGroup(GroupConversation g) async {
    final me = ref.read(authNotifierProvider).valueOrNull;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await sendGroupMessageScoped(
        ref,
        conversationId: g.id,
        groupId:        g.groupId,
        body:           widget.source.body,
        attachments:    widget.source.attachments,
      );
      _done(g.displayTitle(me.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _done(String target) {
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Transféré à $target'), backgroundColor: kGreen));
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: error ? kRed : kGreen));
  }

  @override
  Widget build(BuildContext context) {
    final me     = ref.watch(authNotifierProvider).valueOrNull;
    final people = ref.watch(scopedRecipientsProvider).valueOrNull ?? const [];
    final groups =
        ref.watch(groupConversationsProvider).valueOrNull ?? const [];
    final q = _query.trim().toLowerCase();
    final fp = q.isEmpty
        ? people
        : people
            .where((o) =>
                o.label.toLowerCase().contains(q) ||
                (o.subtitle ?? '').toLowerCase().contains(q))
            .toList();
    final fg = q.isEmpty
        ? groups
        : groups
            .where((g) =>
                g.displayTitle(me?.id ?? '').toLowerCase().contains(q))
            .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.shortcut_rounded, size: 19, color: kNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Transférer à…',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _busy ? null : () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: kTextMuted),
            ),
          ]),
          const SizedBox(height: 4),
          // Aperçu du message transféré.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Text(
                widget.source.body.trim().isNotEmpty
                    ? widget.source.body.trim()
                    : (widget.source.attachments.isNotEmpty
                        ? '${widget.source.attachments.length} pièce(s) jointe(s)'
                        : '(vide)'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
          ),
          const SizedBox(height: 10),
          TextField(
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _query = v),
            decoration: adminFilledInput('Rechercher…',
                icon: Icons.search_rounded),
          ),
          const SizedBox(height: 8),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (fg.isNotEmpty) ...[
                  const _ForwardSection('Groupes'),
                  for (final g in fg)
                    _ForwardTile(
                      icon: Icons.groups_rounded,
                      title: g.displayTitle(me?.id ?? ''),
                      subtitle: '${g.memberCount} membres',
                      onTap: _busy ? null : () => _toGroup(g),
                    ),
                ],
                if (fp.isNotEmpty) ...[
                  const _ForwardSection('Personnes'),
                  for (final o in fp)
                    _ForwardTile(
                      icon: Icons.person_rounded,
                      title: o.label,
                      subtitle: _roleLabel(o.subtitle),
                      onTap: _busy ? null : () => _toPerson(o),
                    ),
                ],
                if (fg.isEmpty && fp.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Aucune destination',
                          style:
                              TextStyle(color: kTextMuted, fontSize: 12.5)),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ForwardSection extends StatelessWidget {
  const _ForwardSection(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: kTextMuted)),
        ),
      );
}

class _ForwardTile extends StatelessWidget {
  const _ForwardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          child: Row(children: [
            CircleAvatar(
                radius: 16,
                backgroundColor: kNavy.withValues(alpha: 0.10),
                child: Icon(icon, size: 17, color: kNavy)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 11, color: kTextMuted)),
                ],
              ),
            ),
            Icon(Icons.send_rounded, size: 16, color: kNavy),
          ]),
        ),
      );
}
