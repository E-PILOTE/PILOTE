import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/announcement_interactions_provider.dart';
import 'staff_feed_ui.dart';
import 'user_avatar.dart';
import '../../../core/utils/message_erreur.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Fil de commentaires INLINE (jamais de modal) — s'ouvre sous la publication
//  et étire la carte, façon réseau social. Liste + zone de saisie + réponses.
//  La page scrolle ; le bloc grandit naturellement avec le nombre de messages.
// ════════════════════════════════════════════════════════════════════════════

class InlineComments extends ConsumerStatefulWidget {
  const InlineComments({super.key, required this.annId, required this.groupId});
  final String annId;
  final String groupId;

  @override
  ConsumerState<InlineComments> createState() => _InlineCommentsState();
}

class _InlineCommentsState extends ConsumerState<InlineComments> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _replyingTo;
  String? _replyingToName;
  String? _editingId;
  bool    _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit(AnnComment c) {
    setState(() {
      _editingId      = c.id;
      _replyingTo     = null;
      _replyingToName = null;
      _ctrl.text      = c.content;
    });
    _focus.requestFocus();
  }

  void _startReply(AnnComment c) {
    setState(() {
      _editingId      = null;
      _replyingTo     = c.id;
      _replyingToName = c.authorName ?? 'Quelqu\'un';
    });
    _focus.requestFocus();
  }

  void _cancelEdit() => setState(() {
        _editingId = null;
        _replyingTo = null;
        _replyingToName = null;
        _ctrl.clear();
      });

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      if (_editingId != null) {
        await updateCommentScoped(ref, _editingId!, text);
      } else {
        await addCommentScoped(
          ref,
          annId:    widget.annId,
          groupId:  widget.groupId,
          content:  text,
          parentId: _replyingTo,
        );
      }
      _ctrl.clear();
      setState(() {
        _replyingTo = null;
        _replyingToName = null;
        _editingId = null;
      });
      _refresh();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String id) async {
    await deleteCommentScoped(ref, id);
    _refresh();
  }

  // Rafraîchissement immédiat du fil (indépendant du realtime serveur).
  void _refresh() {
    if (!mounted) return;
    ref.invalidate(annCommentsProvider(widget.annId));
    ref.invalidate(annFirstCommentProvider(widget.annId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(annCommentsProvider(widget.annId));
    final me    = ref.watch(authNotifierProvider).valueOrNull;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(messageErreur(e),
                  style: TextStyle(fontSize: 12, color: kTextMuted)),
            ),
            data: (comments) => _list(comments, me?.id ?? ''),
          ),
          const SizedBox(height: 6),
          _composer(me),
        ],
      ),
    );
  }

  Widget _list(List<AnnComment> comments, String meId) {
    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Soyez le premier à commenter.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
      );
    }
    final roots   = comments.where((c) => c.parentId == null).toList();
    final replies = <String, List<AnnComment>>{};
    for (final c in comments) {
      if (c.parentId != null) {
        replies.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in roots) ...[
          _CommentTile(
            comment: c,
            meId: meId,
            isReply: false,
            onReply: () => _startReply(c),
            onEdit: () => _startEdit(c),
            onDelete: () => _delete(c.id),
          ),
          for (final r in (replies[c.id] ?? []))
            _CommentTile(
              comment: r,
              meId: meId,
              isReply: true,
              onEdit: () => _startEdit(r),
              onDelete: () => _delete(r.id),
            ),
        ],
      ],
    );
  }

  Widget _composer(dynamic me) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_editingId != null || _replyingTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Row(children: [
              Container(
                  width: 3,
                  height: 13,
                  margin: const EdgeInsets.only(right: 7),
                  color: _editingId != null ? kAccent : kNavy),
              Text(
                  _editingId != null
                      ? 'Modification du commentaire'
                      : 'Réponse à $_replyingToName',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _editingId != null ? kTextPrimary : kNavy)),
              const Spacer(),
              GestureDetector(
                onTap: _cancelEdit,
                child: Icon(Icons.close_rounded,
                    size: 15, color: kTextMuted),
              ),
            ]),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          UserAvatarCircle(
            name: me?.fullName as String?,
            role: me?.role as String?,
            avatarUrl: me?.avatarUrl as String?,
            radius: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            // Entrée = envoyer ; Maj+Entrée = nouvelle ligne (façon messagerie).
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.enter): _SendIntent(),
                SingleActivator(LogicalKeyboardKey.numpadEnter): _SendIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _SendIntent: CallbackAction<_SendIntent>(
                      onInvoke: (_) {
                    _send();
                    return null;
                  }),
                },
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                hintText: _replyingTo != null
                    ? 'Répondre à $_replyingToName…'
                    : 'Écrire un commentaire…',
                hintStyle: TextStyle(color: kTextMuted, fontSize: 12.5),
                isDense: true,
                filled: true,
                fillColor: kCardBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: kNavy, width: 1.4)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(sending: _sending, onTap: _send),
        ]),
      ],
    );
  }
}

/// Intent « envoyer le commentaire » déclenché par la touche Entrée.
class _SendIntent extends Intent {
  const _SendIntent();
}

// ─── Tuile commentaire (bulle + actions) ──────────────────────────────────────

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.meId,
    required this.isReply,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });
  final AnnComment comment;
  final String meId;
  final bool isReply;
  final VoidCallback? onReply, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final isMine = comment.authorId == meId;
    final name   = comment.authorName ?? 'Utilisateur';

    return Padding(
      padding: EdgeInsets.fromLTRB(isReply ? 40 : 0, 0, 0, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UserAvatarCircle(
          name: name,
          role: comment.authorRole,
          avatarUrl: comment.authorAvatarUrl,
          radius: isReply ? 14 : 16,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                    ),
                    if (comment.authorRole != null) ...[
                      const SizedBox(width: 6),
                      Text(roleLabelFr(comment.authorRole),
                          style: TextStyle(
                              fontSize: 10.5,
                              color: roleColor(comment.authorRole))),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(comment.content,
                      style: TextStyle(
                          fontSize: 13, color: kTextPrimary, height: 1.45)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4),
              child: Row(children: [
                Text(fmtRelativeFr(comment.createdAt),
                    style: TextStyle(fontSize: 10.5, color: kTextMuted)),
                if (onReply != null) ...[
                  const SizedBox(width: 12),
                  _MiniAction('Répondre', kNavy, onReply!),
                ],
                if (isMine && onEdit != null) ...[
                  const SizedBox(width: 12),
                  _MiniAction('Modifier', kTextMuted, onEdit!),
                ],
                if (isMine && onDelete != null) ...[
                  const SizedBox(width: 12),
                  _MiniAction('Supprimer', kRed, onDelete!),
                ],
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction(this.label, this.color, this.onTap);
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onTap});
  final bool sending;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: sending ? null : onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: sending ? kTextMuted : kNavy,
          ),
          child: sending
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 17, color: Colors.white),
        ),
      );
}
