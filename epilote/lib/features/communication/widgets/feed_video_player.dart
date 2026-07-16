import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart' show showContentOverlay;

// ═════════════════════════════════════════════════════════════════════════════
// Lecture vidéo du feed social / chat / stories — moteur `media_kit` (libmpv).
// Couvre TOUTES les cibles : Android · iOS · macOS · Windows · **Linux** · Web.
// (Remplace `video_player`, qui n'a aucun moteur natif sur Linux/Windows
// desktop ; c'était la cause du repli « ouverture externe » en dev Linux.)
// ═════════════════════════════════════════════════════════════════════════════

/// `media_kit` lit la vidéo sur toutes les plateformes de l'app.
const bool videoPlaybackSupported = true;

/// Autoplay inline (façon Facebook) RÉSERVÉ au mobile (Android/iOS), où libmpv
/// est stable. Sur desktop (Linux/Windows dev) le pipeline EGL de libmpv plante
/// quand plusieurs lecteurs se créent/détruisent au scroll
/// (« EGL display or context is invalid » → S/W rendering → crash). Sur ces
/// cibles on bascule sur une vignette « tap-pour-lire » (un seul lecteur, à la
/// demande).
bool get feedAutoplaySupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Vignette vidéo inline (style feed) : cadre sombre + bouton lecture.
/// Tap → plein écran (lecteur natif) ou ouverture externe sur Linux.
class FeedVideoThumb extends StatelessWidget {
  const FeedVideoThumb({
    super.key,
    required this.url,
    this.height = 240,
    this.radius = const BorderRadius.all(Radius.circular(12)),
    this.label,
    this.onTap,
  });

  final String       url;
  final double       height;
  final BorderRadius radius;
  final String?      label;
  /// Action au tap (par défaut : lecteur via [url]). Permet de re-signer une
  /// URL fraîche (bucket privé) avant lecture.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: const Color(0xFF10151C),
        child: InkWell(
          onTap: onTap ?? () => openVideo(context, url, title: label),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Texture discrète de fond
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1B2430),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bouton lecture
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 16),
                    ],
                  ),
                  child: Icon(Icons.play_arrow_rounded,
                      size: 36, color: kNavy),
                ),
                // Badge « Vidéo »
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.videocam_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(label ?? 'Vidéo',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ouvre une vidéo dans un panneau CONFINÉ à la zone de contenu (la sidebar
/// reste visible et cliquable). Bouton « ouvrir en externe » en repli ultime.
Future<void> openVideo(BuildContext context, String url, {String? title}) async {
  if (!context.mounted) return;
  showContentOverlay(
    context,
    (close) => _VideoDialog(url: url, title: title, onClose: close),
  );
}

// ─── Panneau vidéo confiné (moteur media_kit / libmpv) ───────────────────────

class _VideoDialog extends StatefulWidget {
  const _VideoDialog(
      {required this.url, this.title, required this.onClose});
  final String  url;
  final String? title;
  final VoidCallback onClose;

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late final Player           _player = Player();
  late final VideoController  _controller = VideoController(_player);
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.open(Media(widget.url));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: Stack(children: [
        Positioned.fill(child: GestureDetector(onTap: widget.onClose)),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (widget.title != null)
                Expanded(
                  child: Text(widget.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                )
              else
                const Spacer(),
              IconButton(
                tooltip: 'Ouvrir en externe',
                onPressed: () => _openExternal(widget.url),
                icon: const Icon(Icons.open_in_new_rounded,
                    color: Colors.white70, size: 20),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ]),
            const SizedBox(height: 8),
            if (_error != null)
              _VideoError(url: widget.url)
            else
              ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1000, maxHeight: 640),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    // Contrôles Material natifs (play/seek/volume/plein écran).
                    child: Video(controller: _controller),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _VideoError extends StatelessWidget {
  const _VideoError({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.black, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white54, size: 40),
          const SizedBox(height: 12),
          const Text('Lecture impossible',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _openExternal(url),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Ouvrir le document'),
            style: FilledButton.styleFrom(backgroundColor: kNavy),
          ),
        ]),
      );
}

Future<void> _openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ─── Lecteur vidéo INLINE (visionneuse galerie / carrousel plein écran) ───────
/// Lecteur media_kit autonome : initialise sa propre [Player] et la libère à la
/// destruction. Utilisé dans la visionneuse média plein écran pour la page
/// vidéo active (1 seul lecteur à la fois → pas de fuite mémoire).
class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({super.key, required this.url, this.autoPlay = true});
  final String url;
  final bool   autoPlay;

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  late final Player          _player = Player();
  late final VideoController _controller = VideoController(_player);

  @override
  void initState() {
    super.initState();
    _player.open(Media(widget.url), play: widget.autoPlay);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Video(controller: _controller, controls: AdaptiveVideoControls);
}

// ─── Vidéo AUTOPLAY inline façon Facebook (feed) ──────────────────────────────
/// Lecture automatique MUETTE quand la vidéo entre dans le champ (≥60 % visible),
/// pause quand elle en sort ; boucle ; contrôles natifs (play/seek/volume/plein
/// écran) au survol/tap. Tape sur la zone vidéo = bascule le son (muet ↔ son).
class InlineFeedVideo extends StatefulWidget {
  const InlineFeedVideo({
    super.key,
    required this.url,
    required this.visKey,
    this.height = 440,
  });
  final String url;
  /// Clé de visibilité unique (évite les collisions entre cartes/slides).
  final String visKey;
  final double height;

  @override
  State<InlineFeedVideo> createState() => _InlineFeedVideoState();
}

class _InlineFeedVideoState extends State<InlineFeedVideo> {
  // ⚠️ libmpv (media_kit) devient instable si l'on crée un Player par carte du
  // fil. On instancie donc PARESSEUSEMENT : seule la vidéo réellement visible
  // détient un Player (créé à l'entrée ≥60 %, libéré à la sortie).
  Player?          _player;
  VideoController? _controller;
  bool _muted   = true;
  bool _visible = false;

  void _ensurePlayer() {
    if (_player != null) return;
    try {
      final p = Player();
      final c = VideoController(p);
      p.setVolume(_muted ? 0 : 100);
      p.setPlaylistMode(PlaylistMode.loop);
      p.open(Media(widget.url), play: true);
      if (!mounted) {
        p.dispose();
        return;
      }
      setState(() {
        _player = p;
        _controller = c;
      });
    } catch (_) {/* lecture inline indisponible : on garde le poster */}
  }

  void _releasePlayer() {
    final p = _player;
    _player = null;
    _controller = null;
    p?.dispose();
    if (mounted) setState(() {});
  }

  void _onVisibility(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.6;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _ensurePlayer();
    } else {
      _releasePlayer();
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _player?.setVolume(_muted ? 0 : 100);
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return VisibilityDetector(
      key: Key('feedvideo-${widget.visKey}'),
      onVisibilityChanged: _onVisibility,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: controller == null
            ? const _VideoPoster()
            : Stack(
                fit: StackFit.expand,
                children: [
                  Video(
                    controller: controller,
                    controls: AdaptiveVideoControls,
                    fill: Colors.black,
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _toggleMute,
                        child: Padding(
                          padding: const EdgeInsets.all(9),
                          child: Icon(
                              _muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Poster sombre affiché tant que la vidéo n'est pas (encore) visible.
class _VideoPoster extends StatelessWidget {
  const _VideoPoster();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B2430), Colors.black],
          ),
        ),
        child: Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: Colors.white54, size: 64),
        ),
      );
}
