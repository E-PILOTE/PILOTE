import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/announcement_interactions_provider.dart';
import '../widgets/staff_feed_ui.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Widgets SOCIAUX du fil d'annonces — réactions, commentaires, partage.
// Extraits de announcements_feed_cards.dart (règle ≤ 500 lignes/fichier).
// ═════════════════════════════════════════════════════════════════════════════

String initialsOf(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  final p = parts[0];
  return p.substring(0, p.length > 1 ? 2 : 1).toUpperCase();
}

// ─── Dialog « Qui a réagi » ───────────────────────────────────────────────────

class ReactionPeopleDialog extends ConsumerWidget {
  const ReactionPeopleDialog({super.key, required this.annId});
  final String annId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(annReactionPeopleProvider(annId));
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 480),
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.emoji_emotions_rounded, size: 18, color: kNavy),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Réactions',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: kTextMuted),
            ),
          ]),
          const SizedBox(height: 8),
          const Divider(height: 1, color: kBorder),
          Flexible(
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erreur : $e',
                    style: const TextStyle(color: kTextMuted, fontSize: 12)),
              ),
              data: (people) => people.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Aucune réaction',
                          style:
                              TextStyle(color: kTextMuted, fontSize: 12.5)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: people.length,
                      itemBuilder: (_, i) {
                        final p = people[i];
                        final color = roleColor(p.role);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: 0.14),
                              ),
                              alignment: Alignment.center,
                              child: Text(initialsOf(p.name),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: color)),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: kTextPrimary)),
                                    if (p.role != null)
                                      Text(roleLabelFr(p.role),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: kTextMuted)),
                                  ]),
                            ),
                            Text(reactionEmoji(p.reaction),
                                style: const TextStyle(fontSize: 18)),
                          ]),
                        );
                      },
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Pill compteur de réaction ────────────────────────────────────────────────

class ReactionCountPill extends StatelessWidget {
  const ReactionCountPill(this.emoji, this.count, {super.key});
  final String emoji;
  final int    count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          Text('$count',
              style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
}

// ─── Preview 1er commentaire ──────────────────────────────────────────────────

class CommentPreviewTile extends StatelessWidget {
  const CommentPreviewTile(
      {super.key, required this.comment, required this.more, required this.onTap});
  final AnnComment comment;
  final int        more;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(comment.authorRole);
    final init  = initialsOf(comment.authorName);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            alignment: Alignment.center,
            child: Text(init,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12.5, color: kTextPrimary),
                    children: [
                      if (comment.authorName != null)
                        TextSpan(
                            text: '${comment.authorName} ',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      TextSpan(text: comment.content),
                    ],
                  ),
                ),
                if (more > 0) ...[
                  const SizedBox(height: 3),
                  Text('Voir $more autre${more > 1 ? 's' : ''} commentaire${more > 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: kNavy,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Contenu repliable (« Voir plus / Voir moins ») ──────────────────────────

class ExpandableContent extends StatefulWidget {
  const ExpandableContent({
    super.key,
    required this.text,
    this.onHashtag,
    this.collapsedLines = 6,
  });
  final String                text;
  final ValueChanged<String>? onHashtag;
  final int                   collapsedLines;

  @override
  State<ExpandableContent> createState() => _ExpandableContentState();
}

class _ExpandableContentState extends State<ExpandableContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14, color: kTextPrimary, height: 1.55);
    return LayoutBuilder(builder: (context, constraints) {
      // Mesure si le texte dépasse le nombre de lignes replié.
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.collapsedLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = tp.didExceedMaxLines;

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        HashtagText(widget.text,
            maxLines: _expanded ? null : widget.collapsedLines,
            overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
            onHashtag: widget.onHashtag,
            style: style),
        if (overflows)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_expanded ? 'Voir moins' : 'Voir plus',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kNavy)),
            ),
          ),
      ]);
    });
  }
}

// ─── Double-tap pour aimer (cœur animé style Instagram) ───────────────────────

class DoubleTapLike extends StatefulWidget {
  const DoubleTapLike({super.key, required this.child, required this.onLike});
  final Widget       child;
  final VoidCallback onLike;

  @override
  State<DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<DoubleTapLike>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  void _burst() {
    widget.onLike();
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _burst,
      behavior: HitTestBehavior.opaque,
      child: Stack(alignment: Alignment.center, children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              if (_c.value == 0 || _c.value == 1) {
                return const SizedBox.shrink();
              }
              final scale = Curves.elasticOut.transform(
                  (_c.value * 1.6).clamp(0.0, 1.0));
              final opacity = _c.value < 0.6
                  ? 1.0
                  : (1 - (_c.value - 0.6) / 0.4).clamp(0.0, 1.0);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 86,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 12)]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─── Couleur par type de réaction ─────────────────────────────────────────────
Color reactionColor(String? type) => switch (type) {
      'love' => const Color(0xFFE0245E),
      'clap' => const Color(0xFFF7B928),
      'like' => const Color(0xFF1877F2),
      _      => kTextMuted,
    };

// ─── Barre d'actions (Réagir · Commenter · Partager) — premium ───────────────

class AnnSocialActionBar extends StatelessWidget {
  const AnnSocialActionBar({
    super.key,
    required this.myReaction,
    required this.commentCount,
    required this.onReact,
    required this.onComment,
    required this.onShare,
  });
  final String?            myReaction;
  final int                commentCount;
  final ValueChanged<String> onReact;
  final VoidCallback       onComment;
  final VoidCallback       onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(children: [
        Expanded(child: _ReactButton(myReaction: myReaction, onSelect: onReact)),
        Expanded(
          child: _ActBtn(
            icon: Icons.mode_comment_outlined,
            label: 'Commenter',
            count: commentCount,
            onTap: onComment,
          ),
        ),
        Expanded(
          child: _ActBtn(
            icon: Icons.share_outlined,
            label: 'Partager',
            onTap: onShare,
          ),
        ),
      ]),
    );
  }
}

// ─── Bouton Réagir : tap=toggle, survol(desktop)/appui long(mobile)=barre ──────

class _ReactButton extends StatefulWidget {
  const _ReactButton({this.myReaction, required this.onSelect});
  final String?              myReaction;
  final ValueChanged<String> onSelect;

  @override
  State<_ReactButton> createState() => _ReactButtonState();
}

class _ReactButtonState extends State<_ReactButton> {
  final _key = GlobalKey();
  OverlayEntry? _entry;
  bool _hovering = false;

  @override
  void dispose() {
    _removeBar();
    super.dispose();
  }

  void _showBar() {
    if (_entry != null) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos  = box.localToGlobal(Offset.zero);
    final size = box.size;
    _entry = OverlayEntry(
      builder: (_) => _ReactionBar(
        anchor: pos,
        anchorWidth: size.width,
        current: widget.myReaction,
        onSelect: (r) {
          _removeBar();
          widget.onSelect(r);
        },
        onKeepOpen: () {},
        onClose: _removeBar,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _removeBar() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.myReaction != null;
    final emoji  = active ? reactionEmoji(widget.myReaction!) : null;
    final label  = active ? reactionLabel(widget.myReaction!) : 'J’aime';
    final color  = active ? reactionColor(widget.myReaction) : kTextMuted;

    return MouseRegion(
      onEnter: (_) {
        _hovering = true;
        Future.delayed(const Duration(milliseconds: 350), () {
          if (_hovering && mounted) _showBar();
        });
      },
      onExit: (_) {
        _hovering = false;
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!_hovering && mounted) _removeBar();
        });
      },
      child: GestureDetector(
        onTap: () => widget.onSelect(widget.myReaction ?? 'like'),
        onLongPress: _showBar,
        child: _HoverBg(
          child: Padding(
            key: _key,
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Icône/emoji avec rebond au changement d'état.
              TweenAnimationBuilder<double>(
                key: ValueKey(widget.myReaction ?? '_'),
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 280),
                curve: Curves.elasticOut,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: emoji != null
                    ? Text(emoji, style: const TextStyle(fontSize: 18))
                    : Icon(Icons.thumb_up_alt_outlined, size: 18, color: color),
              ),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: color)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Barre de réactions flottante (style Facebook) ────────────────────────────

class _ReactionBar extends StatefulWidget {
  const _ReactionBar({
    required this.anchor,
    required this.anchorWidth,
    required this.current,
    required this.onSelect,
    required this.onKeepOpen,
    required this.onClose,
  });
  final Offset               anchor;
  final double               anchorWidth;
  final String?              current;
  final ValueChanged<String> onSelect;
  final VoidCallback         onKeepOpen, onClose;

  @override
  State<_ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<_ReactionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const barW = 4 * 56.0 + 16;
    var left = widget.anchor.dx + widget.anchorWidth / 2 - barW / 2;
    final maxW = MediaQuery.sizeOf(context).width;
    if (left < 8) left = 8;
    if (left + barW > maxW - 8) left = maxW - 8 - barW;

    return Stack(children: [
      // Barrière de fermeture
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onClose,
        ),
      ),
      Positioned(
        left: left,
        top: widget.anchor.dy - 62,
        child: MouseRegion(
          onEnter: (_) => widget.onKeepOpen(),
          onExit: (_) => widget.onClose(),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final e in kReactions.entries)
                    _ReactionEmoji(
                      emoji: e.value.$1,
                      label: e.value.$2,
                      active: e.key == widget.current,
                      onTap: () => widget.onSelect(e.key),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _ReactionEmoji extends StatefulWidget {
  const _ReactionEmoji({
    required this.emoji,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String       emoji, label;
  final bool         active;
  final VoidCallback onTap;

  @override
  State<_ReactionEmoji> createState() => _ReactionEmojiState();
}

class _ReactionEmojiState extends State<_ReactionEmoji> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.4 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Tooltip(
            message: widget.label,
            child: Container(
              width: 48,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(widget.emoji, style: const TextStyle(fontSize: 30)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bouton d'action générique (fond arrondi au survol) ──────────────────────

class _ActBtn extends StatelessWidget {
  const _ActBtn({
    required this.icon,
    required this.label,
    this.count = 0,
    this.onTap,
  });
  final IconData      icon;
  final String        label;
  final int           count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _HoverBg(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: kTextMuted),
              const SizedBox(width: 7),
              Flexible(
                child: Text(count > 0 ? '$label ($count)' : label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kTextMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Effet de fond arrondi au survol (desktop) — états interactifs premium.
class _HoverBg extends StatefulWidget {
  const _HoverBg({required this.child});
  final Widget child;
  @override
  State<_HoverBg> createState() => _HoverBgState();
}

class _HoverBgState extends State<_HoverBg> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _hover ? kSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.child,
        ),
      );
}
