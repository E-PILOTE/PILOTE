import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:story_view/story_view.dart' as sv;

import '../../../core/widgets/admin_ui.dart';
import '../providers/stories_provider.dart';
import '../widgets/feed_video_player.dart' show videoPlaybackSupported;
import '../widgets/staff_feed_ui.dart' show fmtRelativeFr, roleColor, roleLabelFr;

// ════════════════════════════════════════════════════════════════════════════
//  Viewer Stories plein écran (type WhatsApp) — PageView horizontal par auteur,
//  chaque page = un `StoryView` (progress bars + gestures). Marque les vues,
//  enchaîne d'un auteur à l'autre, ferme à la fin.
// ════════════════════════════════════════════════════════════════════════════

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.initialIndex,
  });

  final List<StoryGroup> groups;
  final int              initialIndex;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextAuthor() {
    if (_current < widget.groups.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageCtrl,
        onPageChanged: (i) => setState(() => _current = i),
        itemCount: widget.groups.length,
        itemBuilder: (_, i) => _AuthorStoryPage(
          group: widget.groups[i],
          isActive: i == _current,
          onComplete: _nextAuthor,
          onClose: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

// ─── Une page = toutes les stories d'un auteur ────────────────────────────────

class _AuthorStoryPage extends ConsumerStatefulWidget {
  const _AuthorStoryPage({
    required this.group,
    required this.isActive,
    required this.onComplete,
    required this.onClose,
  });
  final StoryGroup   group;
  final bool         isActive;
  final VoidCallback onComplete;
  final VoidCallback onClose;

  @override
  ConsumerState<_AuthorStoryPage> createState() => _AuthorStoryPageState();
}

class _AuthorStoryPageState extends ConsumerState<_AuthorStoryPage> {
  final sv.StoryController _controller = sv.StoryController();
  late final List<sv.StoryItem> _items;
  StoryItem? _shownStory;

  @override
  void initState() {
    super.initState();
    _items = _buildItems();
  }

  List<sv.StoryItem> _buildItems() {
    return widget.group.items.map((s) {
      final cap = (s.caption != null && s.caption!.isNotEmpty)
          ? Text(s.caption!,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.4),
              textAlign: TextAlign.center)
          : null;
      if (s.isText) {
        return sv.StoryItem.text(
          title: s.textContent ?? '',
          backgroundColor: _parseColor(s.bgColor) ?? kNavy,
          duration: const Duration(seconds: 5),
          textStyle: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, height: 1.4),
        );
      }
      if (s.isVideo && s.mediaUrl != null) {
        // video_player ne supporte pas Linux desktop → image de secours.
        if (!videoPlaybackSupported) {
          return sv.StoryItem.text(
            title: '🎬 ${s.caption ?? 'Vidéo'}\n\n(lecture vidéo sur mobile)',
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 4),
          );
        }
        return sv.StoryItem.pageVideo(
          s.mediaUrl!,
          controller: _controller,
          caption: cap,
          duration: const Duration(seconds: 15),
        );
      }
      if (s.mediaUrl != null) {
        return sv.StoryItem.pageImage(
          url: s.mediaUrl!,
          controller: _controller,
          caption: cap,
          duration: const Duration(seconds: 5),
        );
      }
      return sv.StoryItem.text(
        title: s.textContent ?? '',
        backgroundColor: _parseColor(s.bgColor) ?? kNavy,
        duration: const Duration(seconds: 5),
      );
    }).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final color = roleColor(g.authorRole);
    return Stack(
      children: [
        Positioned.fill(
          child: sv.StoryView(
            storyItems: _items,
            controller: _controller,
            repeat: false,
            inline: false,
            indicatorColor: Colors.white24,
            indicatorForegroundColor: Colors.white,
            onComplete: widget.onComplete,
            onVerticalSwipeComplete: (dir) {
              if (dir == sv.Direction.down) widget.onClose();
            },
            onStoryShow: (item, index) {
              if (index >= 0 && index < g.items.length) {
                _shownStory = g.items[index];
                // Marque la vue (post-frame pour éviter setState pendant build).
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_shownStory != null) {
                    markStoryViewed(ref, _shownStory!);
                  }
                });
              }
            },
          ),
        ),
        // En-tête : auteur + temps + fermeture
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 34, 8, 0),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      color,
                      Color.lerp(color, Colors.black, 0.3)!,
                    ]),
                  ),
                  alignment: Alignment.center,
                  child: Text(_initials(g.authorName),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.authorName ?? 'Membre',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700)),
                      Row(children: [
                        if (g.authorRole != null)
                          Text('${roleLabelFr(g.authorRole)} · ',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        Text(
                            _shownStory == null
                                ? ''
                                : fmtRelativeFr(_shownStory!.createdAt),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

Color? _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  final p = parts[0];
  return p.substring(0, p.length > 1 ? 2 : 1).toUpperCase();
}
