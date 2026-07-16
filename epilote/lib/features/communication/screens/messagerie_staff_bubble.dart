part of 'messagerie_staff.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Bulle de message WhatsApp : citation (réponse), pièces jointes, texte (avec
//  surlignage de recherche), réactions emoji, « modifié », heure + coches, et
//  menu contextuel complet (Réagir / Répondre / Transférer / Modifier / Copier /
//  Supprimer). + barre de contexte de composition (réponse / édition).
// ════════════════════════════════════════════════════════════════════════════

/// Émojis de réaction rapides (rangée en tête du menu contextuel).
const _kQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.msg,
    required this.mine,
    required this.myId,
    this.showSender = false,
    this.quoted,
    this.highlight = '',
    this.groupReadBy,
    this.groupReadTotal,
    required this.onReact,
    required this.onReply,
    required this.onForward,
    this.onInfo,
    this.onEdit,
    this.onDelete,
  });

  final MessageModel msg;
  final bool mine;
  final String myId;

  /// Affiche le nom de l'expéditeur au-dessus (bulles entrantes de groupe).
  final bool showSender;

  /// Message cité (réponse) — null si ce n'est pas une réponse.
  final MessageModel? quoted;

  /// Terme de recherche à surligner dans le corps.
  final String highlight;

  /// Accusé de lecture de groupe (mes messages) : lu par N membres sur M.
  /// null = message 1-à-1 ou message reçu (la coche utilise alors `isRead`).
  final int? groupReadBy;
  final int? groupReadTotal;

  final ValueChanged<String> onReact;
  final VoidCallback onReply;
  final VoidCallback onForward;

  /// Infos de lecture « Lu par N/M » (mes messages de groupe) — null sinon.
  final VoidCallback? onInfo;

  /// Édition (mes messages texte) — null = indisponible.
  final VoidCallback? onEdit;

  /// Suppression (mes messages) — null = indisponible.
  final VoidCallback? onDelete;

  Future<void> _showMenu(BuildContext context, Offset pos) async {
    final hasText = msg.body.trim().isNotEmpty;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
          pos & const Size(40, 40), Offset.zero & overlay.size),
      items: [
        // Rangée d'émojis de réaction rapide. `value` null : un tap hors émoji
        // (padding) renvoie null (ignoré) ; chaque émoji pop sa propre valeur.
        PopupMenuItem<String>(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in _kQuickReactions)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.pop(context, 'react:$e'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 6),
        const PopupMenuItem(
          value: 'reply',
          height: 40,
          child: _MenuRow(
              icon: Icons.reply_rounded, label: 'Répondre'),
        ),
        const PopupMenuItem(
          value: 'forward',
          height: 40,
          child: _MenuRow(
              icon: Icons.shortcut_rounded, label: 'Transférer'),
        ),
        if (onInfo != null)
          const PopupMenuItem(
            value: 'info',
            height: 40,
            child: _MenuRow(
                icon: Icons.done_all_rounded, label: 'Infos de lecture'),
          ),
        if (hasText)
          const PopupMenuItem(
            value: 'copy',
            height: 40,
            child: _MenuRow(icon: Icons.copy_rounded, label: 'Copier'),
          ),
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            height: 40,
            child: _MenuRow(icon: Icons.edit_outlined, label: 'Modifier'),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            height: 40,
            child: _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: 'Supprimer',
                danger: true),
          ),
      ],
    );
    if (choice == null) return;
    if (choice.startsWith('react:')) {
      onReact(choice.substring(6));
    } else if (choice == 'reply') {
      onReply();
    } else if (choice == 'forward') {
      onForward();
    } else if (choice == 'info') {
      onInfo?.call();
    } else if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: msg.body));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Message copié'), duration: Duration(seconds: 1)));
      }
    } else if (choice == 'edit') {
      onEdit?.call();
    } else if (choice == 'delete') {
      onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt    = DateTime.tryParse(msg.insertedAt)?.toLocal();
    final clock = dt == null ? '' : _fmtClock.format(dt);
    final senderColor = roleColor(msg.senderRole);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPressStart: (d) => _showMenu(context, d.globalPosition),
            onSecondaryTapDown: (d) => _showMenu(context, d.globalPosition),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              margin: EdgeInsets.only(
                  bottom: 2, left: mine ? 50 : 0, right: mine ? 0 : 50),
              padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
              decoration: BoxDecoration(
                color: mine ? _waOutgoing : _waIncoming,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(mine ? 8 : 0),
                  topRight: Radius.circular(mine ? 0 : 8),
                  bottomLeft: const Radius.circular(8),
                  bottomRight: const Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 1.5,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSender && !mine && msg.senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 2),
                      child: Text(msg.senderName,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: senderColor)),
                    ),
                  // Citation (réponse).
                  if (quoted != null) _QuotedPreview(quoted: quoted!, mine: mine),
                  // Pièces jointes.
                  if (msg.attachments.isNotEmpty)
                    CommAttachmentView(
                        items: msg.attachments, thumbSize: 210, mine: mine),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 1, 2, 0),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        if (msg.body.isNotEmpty)
                          _highlightedBody(msg.body, highlight),
                        const SizedBox(width: 8),
                        if (msg.isEdited)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Text('modifié',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    color: _waTime)),
                          ),
                        _MetaStamp(
                            clock: clock,
                            mine: mine,
                            isRead: msg.isRead,
                            readAt: msg.readAt,
                            groupReadBy: groupReadBy,
                            groupReadTotal: groupReadTotal),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Réactions sous la bulle.
          if (msg.reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                  bottom: 6, left: mine ? 50 : 4, right: mine ? 4 : 50),
              child: _ReactionChips(
                reactions: msg.reactions,
                myId: myId,
                onTap: onReact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _highlightedBody(String text, String query) {
    const base = TextStyle(fontSize: 14.2, height: 1.32, color: _waText);
    final q = query.trim();
    if (q.isEmpty) return Text(text, style: base);
    final lower = text.toLowerCase();
    final ql = q.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (i < text.length) {
      final hit = lower.indexOf(ql, i);
      if (hit < 0) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (hit > i) spans.add(TextSpan(text: text.substring(i, hit)));
      spans.add(TextSpan(
          text: text.substring(hit, hit + q.length),
          style: const TextStyle(
              backgroundColor: Color(0xFFFFE08A),
              fontWeight: FontWeight.w700)));
      i = hit + q.length;
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.icon, required this.label, this.danger = false});
  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = danger ? kRed : kTextMuted;
    return Row(children: [
      Icon(icon, size: 17, color: c),
      const SizedBox(width: 10),
      Text(label,
          style: TextStyle(fontSize: 13, color: danger ? kRed : kTextPrimary)),
    ]);
  }
}

/// Aperçu cité (réponse) — barre colorée + nom + extrait.
class _QuotedPreview extends StatelessWidget {
  const _QuotedPreview({required this.quoted, required this.mine});
  final MessageModel quoted;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final name = quoted.senderName.isNotEmpty ? quoted.senderName : 'Message';
    final preview = quoted.body.trim().isNotEmpty
        ? quoted.body.trim()
        : (quoted.attachments.isNotEmpty ? 'Pièce jointe' : '…');
    final accent = roleColor(quoted.senderRole);
    return Container(
      margin: const EdgeInsets.only(bottom: 4, top: 1),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: accent)),
          Text(preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _waTime)),
        ],
      ),
    );
  }
}

/// Pastilles de réactions (emoji + compteur) — surlignées si j'ai réagi.
class _ReactionChips extends StatelessWidget {
  const _ReactionChips(
      {required this.reactions, required this.myId, required this.onTap});
  final Map<String, List<String>> reactions;
  final String myId;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final e in reactions.entries)
          GestureDetector(
            onTap: () => onTap(e.key),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: e.value.contains(myId)
                    ? kNavy.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: e.value.contains(myId) ? kNavy : kBorder,
                    width: e.value.contains(myId) ? 1.2 : 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(e.key, style: const TextStyle(fontSize: 12.5)),
                if (e.value.length > 1) ...[
                  const SizedBox(width: 3),
                  Text('${e.value.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kTextMuted)),
                ],
              ]),
            ),
          ),
      ],
    );
  }
}

/// Horodatage + coches « ✓/✓✓ » (bleu si lu) — collé en bas à droite des bulles.
/// Pour un message de groupe émis par moi, [groupReadTotal] est renseigné : la
/// coche passe au bleu quand TOUS les autres membres ont lu, et un petit
/// compteur « N/M » est affiché tant que la lecture n'est pas complète.
class _MetaStamp extends StatelessWidget {
  const _MetaStamp(
      {required this.clock,
      required this.mine,
      required this.isRead,
      required this.readAt,
      this.groupReadBy,
      this.groupReadTotal});
  final String  clock;
  final bool    mine, isRead;
  final String? readAt;
  final int?    groupReadBy;
  final int?    groupReadTotal;

  @override
  Widget build(BuildContext context) {
    // ── Cas groupe (mes messages) : accusé par membre ──────────────────────────
    if (mine && groupReadTotal != null) {
      final total = groupReadTotal!;
      final by    = groupReadBy ?? 0;
      final allRead = total > 0 && by >= total;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Text(clock, style: const TextStyle(fontSize: 11, color: _waTime)),
        if (total > 0 && by > 0 && !allRead) ...[
          const SizedBox(width: 4),
          Text('$by/$total',
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: _waTime)),
        ],
        const SizedBox(width: 3),
        Tooltip(
          message: total == 0
              ? 'Envoyé'
              : (allRead ? 'Lu par tous' : 'Lu par $by/$total'),
          child: Icon(
            by > 0 ? Icons.done_all_rounded : Icons.done_rounded,
            size: 15,
            color: allRead ? _waTickRead : _waTime,
          ),
        ),
      ]);
    }
    // ── Cas 1-à-1 ──────────────────────────────────────────────────────────────
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(clock, style: const TextStyle(fontSize: 11, color: _waTime)),
      if (mine) ...[
        const SizedBox(width: 3),
        Tooltip(
          message: isRead ? _readLabel(readAt) : 'Envoyé',
          child: Icon(
            isRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: 15,
            color: isRead ? _waTickRead : _waTime,
          ),
        ),
      ],
    ]);
  }

  static String _readLabel(String? readAt) {
    final dt = readAt == null ? null : DateTime.tryParse(readAt)?.toLocal();
    return dt == null ? 'Lu' : 'Lu le ${_fmtFull.format(dt)}';
  }
}

// ─── Barre de contexte de composition (réponse / édition) ─────────────────────
class _ComposeContextBar extends StatelessWidget {
  const _ComposeContextBar({
    required this.editing,
    required this.title,
    required this.preview,
    required this.onCancel,
  });
  final bool editing;
  final String title;
  final String preview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
            left: BorderSide(color: Color(0xFF00A884), width: 3)),
      ),
      child: Row(children: [
        Icon(editing ? Icons.edit_outlined : Icons.reply_rounded,
            size: 16, color: const Color(0xFF00A884)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00A884))),
              if (preview.trim().isNotEmpty)
                Text(preview.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onCancel,
          icon: Icon(Icons.close_rounded, size: 18, color: kTextMuted),
        ),
      ]),
    );
  }
}
