import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/stories_provider.dart';
import '../screens/story_viewer.dart';
import 'staff_feed_ui.dart' show roleColor;
import 'story_composer.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Bandeau Stories façon Facebook web — tray de cartes verticales 9:16 avec
//  aperçu du média en fond, anneau d'avatar (bleu = non vues / gris = vues),
//  scrim + prénom. Carte « Créer une story » en tête. Tap → viewer plein écran.
// ════════════════════════════════════════════════════════════════════════════

const double _kCardW = 112;
const double _kCardH = 186;

class StoriesStrip extends ConsumerWidget {
  const StoriesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async  = ref.watch(scopedStoriesProvider);
    final viewed = ref.watch(viewedStoryIdsProvider).valueOrNull ?? const <String>{};
    final me     = ref.watch(authNotifierProvider).valueOrNull;

    final stories = async.valueOrNull ?? const <StoryItem>[];
    final groups  = groupStories(stories);

    // Ma story en premier (si j'en ai), puis les autres.
    final myGroup = groups.where((g) => g.authorId == me?.id).firstOrNull;
    final others  = groups.where((g) => g.authorId != me?.id).toList();

    return Container(
      height: _kCardH + 20,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          // Carte « Créer une story »
          _CreateStoryCard(
            avatarUrl: me?.avatarUrl,
            role: me?.role,
            onAdd: () => showDialog<void>(
                context: context, builder: (_) => const StoryComposerDialog()),
            onView: myGroup == null
                ? null
                : () => _openViewer(context, [myGroup, ...others], 0),
            hasStory: myGroup != null,
          ),
          // Cartes des autres auteurs
          for (var i = 0; i < others.length; i++)
            _StoryCard(
              group: others[i],
              allViewed: others[i].items.every((s) => viewed.contains(s.id)),
              onTap: () => _openViewer(
                context,
                myGroup != null ? [myGroup, ...others] : others,
                myGroup != null ? i + 1 : i,
              ),
            ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, List<StoryGroup> groups, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StoryViewerScreen(groups: groups, initialIndex: index),
      fullscreenDialog: true,
    ));
  }
}

// ─── Carte « Créer une story » ────────────────────────────────────────────────

class _CreateStoryCard extends StatelessWidget {
  const _CreateStoryCard({
    required this.onAdd,
    required this.hasStory,
    this.onView,
    this.avatarUrl,
    this.role,
  });
  final VoidCallback  onAdd;
  final VoidCallback? onView;
  final bool          hasStory;
  final String?       avatarUrl, role;

  @override
  Widget build(BuildContext context) {
    const footer = 50.0;
    final color = roleColor(role);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: hasStory ? onView : onAdd,
        child: SizedBox(
          width: _kCardW,
          height: _kCardH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Carte (haut média / bas blanc « Créer une story »)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: avatarUrl != null && avatarUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => _RoleFill(color: color),
                              placeholder: (_, _) => _RoleFill(color: color),
                            )
                          : _RoleFill(color: color),
                    ),
                  ),
                  Container(
                    height: footer,
                    width: double.infinity,
                    color: Colors.white,
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Créer une story',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary)),
                  ),
                ]),
              ),
              // Bouton ⊕ centré sur la couture
              Positioned(
                left: 0,
                right: 0,
                bottom: footer - 16,
                child: Center(
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kNavy,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleFill extends StatelessWidget {
  const _RoleFill({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.34)!],
          ),
        ),
        child: const Center(
          child: Icon(Icons.person_rounded, color: Colors.white54, size: 34),
        ),
      );
}

// ─── Carte story d'un auteur ──────────────────────────────────────────────────

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.group,
    required this.allViewed,
    required this.onTap,
  });
  final StoryGroup   group;
  final bool         allViewed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(group.authorRole);
    final cover = group.items.lastWhere(
      (s) => s.mediaType == 'image' && (s.mediaUrl?.isNotEmpty ?? false),
      orElse: () => group.items.last,
    );
    final ringColor = allViewed ? kBorder : kAccent;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: _kCardW,
          height: _kCardH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(fit: StackFit.expand, children: [
              // Fond : média / texte / dégradé rôle
              _StoryBackground(item: cover, color: color),
              // Scrim dégradé bas (lisibilité du nom)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xB3000000),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
              // Anneau avatar (haut-gauche)
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: ringColor,
                    shape: BoxShape.circle,
                  ),
                  child: _Avatar(
                    name: group.authorName,
                    avatarUrl: group.authorAvatarUrl,
                    color: color,
                  ),
                ),
              ),
              // Prénom (bas-gauche)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  group.authorName?.split(' ').first ?? 'Membre',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.15,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Fond de la carte : image (cover), texte (dégradé + extrait), sinon rôle.
class _StoryBackground extends StatelessWidget {
  const _StoryBackground({required this.item, required this.color});
  final StoryItem item;
  final Color     color;

  @override
  Widget build(BuildContext context) {
    if (item.isImage && (item.mediaUrl?.isNotEmpty ?? false)) {
      return CachedNetworkImage(
        imageUrl: item.mediaUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) => _Fallback(color: color),
        errorWidget: (_, _, _) => _Fallback(color: color, broken: true),
      );
    }
    if (item.isText) {
      final bg = _parseHex(item.bgColor) ?? color;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bg, Color.lerp(bg, Colors.black, 0.32)!],
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.fromLTRB(8, 28, 8, 32),
        child: Text(
          item.textContent ?? '',
          maxLines: 4,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      );
    }
    // Vidéo (pas de vignette) ou média manquant → dégradé rôle + icône.
    return _Fallback(color: color, video: item.isVideo);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback(
      {required this.color, this.video = false, this.broken = false});
  final Color color;
  final bool  video, broken;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.34)!],
          ),
        ),
        child: Center(
          child: Icon(
              broken
                  ? Icons.broken_image_outlined
                  : video
                      ? Icons.play_circle_fill_rounded
                      : Icons.auto_stories_rounded,
              color: Colors.white70,
              size: 30),
        ),
      );
}

// ─── Avatar rond (image ou initiales) ─────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({this.name, this.avatarUrl, required this.color});
  final String? name, avatarUrl;
  final Color   color;

  @override
  Widget build(BuildContext context) {
    const d = 30.0;
    final ring = Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle, color: Colors.white,
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                width: d, height: d, fit: BoxFit.cover,
                errorWidget: (_, _, _) => _initialsCircle(d),
                placeholder: (_, _) => _initialsCircle(d),
              )
            : _initialsCircle(d),
      ),
    );
    return ring;
  }

  Widget _initialsCircle(double d) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.3)!],
          ),
        ),
        alignment: Alignment.center,
        child: Text(_initials(name),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
}

Color? _parseHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var h = hex.replaceFirst('#', '').trim();
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
