import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/announcement_interactions_provider.dart';
import '../widgets/staff_feed_ui.dart';
import '../../auth/providers/auth_provider.dart';

/// Dialogue de commentaires pour une annonce.
/// Affiche le fil de commentaires + zone de saisie.
class StaffCommentsSheet extends ConsumerStatefulWidget {
  const StaffCommentsSheet({
    super.key,
    required this.annId,
    required this.groupId,
    required this.annTitle,
  });
  final String annId;
  final String groupId;
  final String annTitle;

  @override
  ConsumerState<StaffCommentsSheet> createState() => _StaffCommentsSheetState();
}

class _StaffCommentsSheetState extends ConsumerState<StaffCommentsSheet> {
  final _ctrl    = TextEditingController();
  String? _replyingTo;
  String? _replyingToName;
  String? _editingId;
  bool    _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _startEdit(AnnComment c) => setState(() {
        _editingId      = c.id;
        _replyingTo     = null;
        _replyingToName = null;
        _ctrl.text      = c.content;
      });

  void _cancelEdit() => setState(() {
        _editingId = null;
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
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(annCommentsProvider(widget.annId));
    final me    = ref.watch(authNotifierProvider).valueOrNull;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          children: [
            // ── En-tête ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder)),
              ),
              child: Row(children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 20, color: kNavy),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Commentaires',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary),
                  ),
                ),
                async.when(
                  data: (list) => _CountChip(list.length),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, size: 20, color: kTextMuted),
                  tooltip: 'Fermer',
                ),
              ]),
            ),

            // ── Liste ─────────────────────────────────────────────────────────
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Erreur : $e',
                      style: TextStyle(color: kTextMuted))),
                data: (comments) {
                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 40, color: kTextMuted),
                          const SizedBox(height: 12),
                          Text('Aucun commentaire pour l\'instant',
                              style: TextStyle(color: kTextMuted, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Soyez le premier à réagir !',
                              style: TextStyle(color: kTextMuted, fontSize: 12)),
                        ],
                      ),
                    );
                  }
                  // Séparer commentaires de niveau 1 et réponses
                  final roots   = comments.where((c) => c.parentId == null).toList();
                  final replies = <String, List<AnnComment>>{};
                  for (final c in comments) {
                    if (c.parentId != null) {
                      replies.putIfAbsent(c.parentId!, () => []).add(c);
                    }
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: roots.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, indent: 64, color: kBorder),
                    itemBuilder: (ctx, i) {
                      final c    = roots[i];
                      final reps = replies[c.id] ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CommentTile(
                            comment:    c,
                            meId:       me?.id ?? '',
                            isReply:    false,
                            onReply:    () => setState(() {
                              _editingId      = null;
                              _replyingTo     = c.id;
                              _replyingToName = c.authorName ?? 'Quelqu\'un';
                            }),
                            onEdit:   () => _startEdit(c),
                            onDelete: () => deleteCommentScoped(ref, c.id),
                          ),
                          for (final r in reps)
                            _CommentTile(
                              comment:  r,
                              meId:     me?.id ?? '',
                              isReply:  true,
                              onEdit:   () => _startEdit(r),
                              onDelete: () => deleteCommentScoped(ref, r.id),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // ── Zone de saisie ────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: kBorder)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_editingId != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(width: 3, height: 14,
                            color: kAccent, margin: const EdgeInsets.only(right: 8)),
                        Text('Modification du commentaire',
                            style: TextStyle(
                                fontSize: 11.5, color: kTextPrimary,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: _cancelEdit,
                          child: Icon(Icons.close_rounded,
                              size: 16, color: kTextMuted),
                        ),
                      ]),
                    )
                  else if (_replyingTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(width: 3, height: 14,
                            color: kNavy, margin: const EdgeInsets.only(right: 8)),
                        Text('Répondre à $_replyingToName',
                            style: TextStyle(
                                fontSize: 11.5, color: kNavy,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () =>
                              setState(() { _replyingTo = null; _replyingToName = null; }),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: kTextMuted),
                        ),
                      ]),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          maxLines: 4,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(fontSize: 13.5),
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: _replyingTo != null
                                ? 'Répondre à $_replyingToName…'
                                : 'Écrire un commentaire…',
                            hintStyle:
                                TextStyle(color: kTextMuted, fontSize: 13),
                            filled: true,
                            fillColor: kSurface,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kBorder)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kBorder)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kNavy, width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SendButton(sending: _sending, onTap: _send),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tuile commentaire ────────────────────────────────────────────────────────
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
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isMine = comment.authorId == meId;
    final name   = comment.authorName ?? 'Utilisateur';
    final color  = roleColor(comment.authorRole);
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).take(2)
            .map((p) => p[0].toUpperCase()).join()
        : '?';

    return Padding(
      padding: EdgeInsets.fromLTRB(isReply ? 56 : 16, 10, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar (couleur = identité du rôle)
          Container(
            width: isReply ? 30 : 36,
            height: isReply ? 30 : 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, Color.lerp(color, Colors.black, 0.25)!],
              ),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: TextStyle(
                    fontSize: isReply ? 10 : 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bulle de commentaire
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: isMine
                        ? kNavy.withValues(alpha: 0.07)
                        : kSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isMine
                            ? kNavy.withValues(alpha: 0.2)
                            : kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      if (comment.authorRole != null) ...[
                        const SizedBox(height: 1),
                        Text(roleLabelFr(comment.authorRole),
                            style: TextStyle(fontSize: 11, color: color)),
                      ],
                      const SizedBox(height: 6),
                      SelectableText(comment.content,
                          style: TextStyle(
                              fontSize: 13.5, color: kTextPrimary, height: 1.5)),
                    ],
                  ),
                ),
                // Actions sous la bulle
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(children: [
                    Text(fmtRelativeFr(comment.createdAt),
                        style: TextStyle(
                            fontSize: 11, color: kTextMuted)),
                    if (onReply != null) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onReply,
                        child: Text('Répondre',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kNavy)),
                      ),
                    ],
                    if (isMine && onEdit != null) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onEdit,
                        child: Text('Modifier',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kTextMuted)),
                      ),
                    ],
                    if (isMine && onDelete != null) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onDelete,
                        child: Text('Supprimer',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kRed)),
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets utilitaires ──────────────────────────────────────────────────────
class _CountChip extends StatelessWidget {
  const _CountChip(this.count);
  final int count;
  @override
  Widget build(BuildContext context) => count == 0
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w800, color: kNavy)));
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onTap});
  final bool sending;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: sending ? null : onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: sending ? kTextMuted : kNavy,
          ),
          child: sending
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
        ),
      );
}
