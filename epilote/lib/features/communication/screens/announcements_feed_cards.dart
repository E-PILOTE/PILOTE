import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/announcement_interactions_provider.dart';
import '../providers/announcements_provider.dart';
import '../providers/communication_scope.dart';
import '../providers/messages_provider.dart' show MessageAttachment;
import '../widgets/inline_comments.dart';
import '../widgets/staff_feed_ui.dart';
import 'announcements_feed_social.dart';

/// Route Messagerie selon le périmètre courant (chat lié à une publication).
String _messagerieRoute(CommScope scope) => switch (scope) {
      CommScope.platform => Routes.superMessagesInbox,
      CommScope.group    => Routes.adminMessagerie,
      CommScope.school   => Routes.messagerie,
    };

// Couleurs & labels de rôle : helpers PARTAGÉS `roleColor` / `roleLabelFr`
// (staff_feed_ui.dart) — réutilisés par la messagerie et les commentaires.

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  final p = parts[0];
  return p.substring(0, p.length > 1 ? 2 : 1).toUpperCase();
}

// ─── Carte publication (fil social premium) ────────────────────────────────

class StaffAnnCard extends ConsumerStatefulWidget {
  const StaffAnnCard({
    super.key,
    required this.ann,
    this.onTap,
    this.manageable = false,
    this.checked    = false,
    this.onCheckToggle,
    this.onEdit,
    this.onTogglePin,
    this.onArchive,
    this.onRemoveAttachment,
    this.onDelete,
    this.onHashtag,
  });
  final AnnouncementDetail ann;
  final VoidCallback?       onTap;
  final bool                manageable;
  final bool                checked;
  final VoidCallback?       onCheckToggle;
  final VoidCallback?       onEdit;
  final VoidCallback?       onTogglePin;
  final VoidCallback?       onArchive;
  final ValueChanged<MessageAttachment>? onRemoveAttachment;
  final VoidCallback?       onDelete;

  /// Tap sur un #hashtag du contenu → filtre le fil sur ce tag.
  final ValueChanged<String>? onHashtag;

  @override
  ConsumerState<StaffAnnCard> createState() => _StaffAnnCardState();
}

class _StaffAnnCardState extends ConsumerState<StaffAnnCard> {
  // Fil de commentaires inline (jamais de modal) — ouvert/fermé dans la carte.
  bool _commentsOpen = false;

  @override
  Widget build(BuildContext context) {
    final ann           = widget.ann;
    final onTap         = widget.onTap;
    final manageable    = widget.manageable;
    final checked       = widget.checked;
    final onCheckToggle = widget.onCheckToggle;
    final onEdit        = widget.onEdit;
    final onTogglePin   = widget.onTogglePin;
    final onArchive     = widget.onArchive;
    final onRemoveAttachment = widget.onRemoveAttachment;
    final onDelete      = widget.onDelete;
    final onHashtag     = widget.onHashtag;

    final reactions   = ref.watch(annReactionsProvider(ann.id));
    final comments    = ref.watch(annCommentsProvider(ann.id));
    final firstCmt    = ref.watch(annFirstCommentProvider(ann.id));
    final savedIds    = ref.watch(savedAnnouncementIdsProvider).valueOrNull
        ?? const <String>{};
    final rxState     = reactions.valueOrNull ?? const AnnReactionState();
    final commentList = comments.valueOrNull ?? [];
    final commentCount = commentList.length;
    final myReaction  = rxState.myReaction;
    final isSaved     = savedIds.contains(ann.id);

    final aColor = audienceColor(ann.targetAudience);

    void doubleTapLike() {
      // Double-tap → ❤️ (n'enlève jamais ; ajoute/maintient « love »).
      if (myReaction != 'love') {
        toggleReactionScoped(ref,
            annId: ann.id, groupId: ann.groupId, reaction: 'love');
      }
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: checked ? kNavy.withValues(alpha: 0.45) : kBorder,
                width: checked ? 1.5 : 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ruban épinglé
              if (ann.isPinned)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  ),
                  child: Row(children: [
                    Icon(Icons.push_pin_rounded,
                        size: 13,
                        color: Color.lerp(kAccent, Colors.black, 0.3)),
                    const SizedBox(width: 6),
                    Text('Épinglée',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color.lerp(kAccent, Colors.black, 0.4))),
                  ]),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── En-tête auteur ──────────────────────────────────────
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (manageable) ...[
                        InkWell(
                          onTap: onCheckToggle,
                          borderRadius: BorderRadius.circular(6),
                          child: Icon(
                              checked
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 20,
                              color: checked ? kNavy : kBorder),
                        ),
                        const SizedBox(width: 10),
                      ],
                      _AuthorAvatar(
                          name: ann.authorName,
                          role: ann.authorRole,
                          avatarUrl: ann.authorAvatarUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    ann.authorName ??
                                        (ann.schoolId != null
                                            ? 'Direction'
                                            : 'Réseau scolaire'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: kTextPrimary),
                                  ),
                                ),
                                if (ann.authorRole != null) ...[
                                  const SizedBox(width: 7),
                                  _RoleBadge(role: ann.authorRole),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            // Méta sur une ligne, ellipsée → jamais d'overflow,
                            // même dans une carte de masonry très étroite.
                            Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text: fmtRelativeFr(
                                        ann.publishedAt ?? ann.createdAt),
                                    style: TextStyle(
                                        fontSize: 11.5, color: kTextMuted)),
                                TextSpan(
                                    text: '  ·  ',
                                    style: TextStyle(
                                        fontSize: 11.5, color: kTextMuted)),
                                TextSpan(
                                    text: ann.targetAudienceLabel,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: aColor)),
                                if (_isEdited(ann))
                                  TextSpan(
                                      text: '  ·  modifié',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontStyle: FontStyle.italic,
                                          color: kTextMuted)),
                                if (ann.isArchived)
                                  TextSpan(
                                      text: '  ·  archivé',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: kAccent)),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Discuter → ouvre le chat avec l'auteur (deep-link peer).
                      _IconBtn(
                        icon: Icons.chat_bubble_rounded,
                        color: kNavy,
                        tooltip: 'Discuter avec l\'auteur',
                        onTap: () {
                          final scope =
                              ref.read(communicationContextProvider).scope;
                          final route = _messagerieRoute(scope);
                          context.go('$route?peer=${ann.createdBy}');
                        },
                      ),
                      // Enregistrer (bookmark) — pour tous.
                      _IconBtn(
                        icon: isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: isSaved ? kNavy : kTextMuted,
                        tooltip: isSaved ? 'Retirer des favoris' : 'Enregistrer',
                        onTap: () => toggleSaveScoped(
                            ref, ann.id, ann.groupId, isSaved),
                      ),
                      // Menu ⋯ universel (gestion + actions sociales).
                      PopupMenuButton<String>(
                        tooltip: 'Options',
                        icon: Icon(Icons.more_horiz_rounded,
                            size: 20, color: kTextMuted),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        onSelected: (v) => switch (v) {
                          'edit'    => onEdit?.call(),
                          'pin'     => onTogglePin?.call(),
                          'archive' => onArchive?.call(),
                          'delete'  => onDelete?.call(),
                          'save'    => toggleSaveScoped(
                              ref, ann.id, ann.groupId, isSaved),
                          'copy'    => _copyLink(context),
                          _         => null,
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'save',
                              child: _MenuRow(
                                  isSaved
                                      ? Icons.bookmark_remove_rounded
                                      : Icons.bookmark_add_rounded,
                                  isSaved
                                      ? 'Retirer des favoris'
                                      : 'Enregistrer')),
                          const PopupMenuItem(
                              value: 'copy',
                              child:
                                  _MenuRow(Icons.link_rounded, 'Copier le lien')),
                          if (manageable) ...[
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                                value: 'edit',
                                child: _MenuRow(
                                    Icons.edit_rounded, 'Modifier')),
                            PopupMenuItem(
                                value: 'pin',
                                child: _MenuRow(
                                    ann.isPinned
                                        ? Icons.push_pin_outlined
                                        : Icons.push_pin_rounded,
                                    ann.isPinned ? 'Dépingler' : 'Épingler')),
                            PopupMenuItem(
                                value: 'archive',
                                child: _MenuRow(
                                    ann.isArchived
                                        ? Icons.unarchive_rounded
                                        : Icons.archive_rounded,
                                    ann.isArchived
                                        ? 'Désarchiver'
                                        : 'Archiver')),
                            PopupMenuItem(
                                value: 'delete',
                                child: _MenuRow(Icons.delete_outline_rounded,
                                    'Supprimer',
                                    color: kRed)),
                          ],
                        ],
                      ),
                    ]),

                    const SizedBox(height: 14),

                    // Titre + contenu + médias — double-tap = ❤️ (Instagram).
                    DoubleTapLike(
                      onLike: doubleTapLike,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ann.title,
                              style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                  color: kTextPrimary)),
                          const SizedBox(height: 8),
                          // Contenu repliable + #hashtags cliquables
                          ExpandableContent(
                              text: ann.content, onHashtag: onHashtag),
                          if (ann.attachments.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            FeedMediaGrid(
                              items: ann.attachments,
                              manageable: manageable,
                              onRemove: onRemoveAttachment,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // ── Compteurs réactions détaillés (tap = qui a réagi) ───────────
              if (rxState.likeCount > 0 ||
                  rxState.loveCount > 0 ||
                  rxState.clapCount > 0 ||
                  commentCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Row(children: [
                    if (rxState.total > 0)
                      InkWell(
                        onTap: () => _openReactionPeople(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 2),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (rxState.likeCount > 0)
                              ReactionCountPill('👍', rxState.likeCount),
                            if (rxState.loveCount > 0)
                              ReactionCountPill('❤️', rxState.loveCount),
                            if (rxState.clapCount > 0)
                              ReactionCountPill('👏', rxState.clapCount),
                          ]),
                        ),
                      ),
                    const Spacer(),
                    if (commentCount > 0)
                      GestureDetector(
                        onTap: () => setState(() => _commentsOpen = true),
                        child: Text(
                            '$commentCount commentaire${commentCount > 1 ? 's' : ''}',
                            style: TextStyle(
                                fontSize: 12, color: kTextMuted)),
                      ),
                  ]),
                ),

              // ── Preview 1er commentaire (masquée si le fil est ouvert) ───────
              if (firstCmt.valueOrNull != null && !_commentsOpen)
                CommentPreviewTile(
                  comment: firstCmt.valueOrNull!,
                  more: commentCount > 1 ? commentCount - 1 : 0,
                  onTap: () => setState(() => _commentsOpen = true),
                ),

              // ── Séparateur ───────────────────────────────────────────────────
              Divider(height: 1, thickness: 1, color: kBorder),

              // ── Barre d'actions ──────────────────────────────────────────────
              AnnSocialActionBar(
                myReaction: myReaction,
                commentCount: commentCount,
                onReact: (r) => toggleReactionScoped(
                    ref,
                    annId: ann.id,
                    groupId: ann.groupId,
                    reaction: r),
                onComment: () =>
                    setState(() => _commentsOpen = !_commentsOpen),
                onShare: () => _share(context),
              ),

              // ── Fil de commentaires INLINE (s'étire dans la carte) ──────────
              if (_commentsOpen)
                InlineComments(annId: ann.id, groupId: ann.groupId),
            ],
          ),
        ),
      ),
    );
  }

  void _openReactionPeople(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => ReactionPeopleDialog(annId: widget.ann.id),
      );

  void _share(BuildContext context) {
    final ann = widget.ann;
    final text = '${ann.title}\n\n${ann.content}';
    Clipboard.setData(ClipboardData(text: text));
    _toast(context, 'Contenu copié dans le presse-papiers');
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: 'epilote://annonce/${widget.ann.id}'));
    _toast(context, 'Lien de la publication copié');
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }
}

/// Une annonce est « modifiée » si updated_at dépasse nettement la publication.
bool _isEdited(AnnouncementDetail a) {
  final ref = a.publishedAt ?? a.createdAt;
  return a.updatedAt.difference(ref).inSeconds > 90;
}

// ─── Petit bouton icône (header de card) ──────────────────────────────────────
class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData     icon;
  final Color        color;
  final String       tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 20, color: color),
      );
}

// ─── Ligne de menu (icône + libellé) ──────────────────────────────────────────
class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color});
  final IconData icon;
  final String   label;
  final Color?   color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? kTextPrimary),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(fontSize: 12.5, color: color ?? kTextPrimary)),
      ]);
}

// ─── Avatar auteur (initiales colorées par rôle) ──────────────────────────────

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({this.name, this.role, this.avatarUrl});
  final String? name, role, avatarUrl;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    final init  = _initials(name);
    final initialsAvatar = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.28)!],
        ),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(init,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700)),
    );
    final url = avatarUrl?.trim();
    if (url == null || url.isEmpty) return initialsAvatar;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        placeholder: (_, _) => initialsAvatar,
        errorWidget: (_, _, _) => initialsAvatar,
      ),
    );
  }
}

// ─── Badge rôle ───────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String? role;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(roleLabelFr(role),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}
