import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart' show showContentOverlay;
import '../providers/messages_provider.dart'
    show MessageAttachment, cachedSignedUrl, resolveAttachmentUrl;
import '../../../services/powersync/upload_outbox.dart' show pendingFileFor;
import 'feed_video_player.dart' show InlineVideoPlayer;

// ─── Image d'une pièce jointe (Storage privé) ────────────────────────────────
/// Affiche une image en re-signant son URL (bucket privé). `cacheKey` = chemin
/// Storage → l'image déjà vue reste affichable hors-ligne malgré la rotation
/// des signed URLs.
class SignedNetworkImage extends StatefulWidget {
  const SignedNetworkImage({
    super.key,
    required this.att,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });
  final MessageAttachment att;
  final double? width, height;
  final BoxFit  fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<SignedNetworkImage> createState() => _SignedNetworkImageState();
}

class _SignedNetworkImageState extends State<SignedNetworkImage> {
  /// URL résolue (synchrone si déjà en cache → aucun spinner à la réouverture).
  String? _resolvedUrl;

  /// Fichier encore dans la file d'attente d'envoi : l'expéditeur voit sa photo
  /// tout de suite, hors réseau, avant même qu'elle n'ait quitté l'appareil.
  File? _pendingFile;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(SignedNetworkImage old) {
    super.didUpdateWidget(old);
    if (old.att.cacheKey != widget.att.cacheKey) {
      _resolvedUrl = null;
      _pendingFile = null;
      _resolve();
    }
  }

  void _resolve() {
    // Cache synchrone : un contenu déjà ouvert reste affiché sans rechargement.
    final cached = cachedSignedUrl(widget.att);
    if (cached != null) {
      _resolvedUrl = cached;
      return;
    }
    // Pas encore téléversée ? Le fichier est sur le disque, on l'affiche.
    final path = widget.att.resolvedPath;
    if (path != null) {
      pendingFileFor(path).then((f) {
        if (f != null && mounted) setState(() => _pendingFile = f);
      });
    }
    resolveAttachmentUrl(Supabase.instance.client, widget.att).then((u) {
      if (mounted) setState(() => _resolvedUrl = u);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ph = widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          color: kSurface,
          child: const Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        );
    final err = widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: kSurface,
          child: const Icon(Icons.broken_image_outlined, color: kTextMuted),
        );
    // Priorité au fichier local en attente : c'est la seule source disponible
    // hors réseau, et elle est plus fraîche que n'importe quelle URL.
    final pending = _pendingFile;
    if (pending != null) {
      return Image.file(pending,
          width: widget.width, height: widget.height, fit: widget.fit);
    }
    final url = _resolvedUrl;
    if (url == null || url.isEmpty) return ph;
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: widget.att.cacheKey,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (_, _) => ph,
      errorWidget: (_, _, _) => err,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Visionneuse média IN-APP (style WhatsApp) — images en plein écran avec
//  zoom/déplacement + navigation entre plusieurs images, sans quitter la page.
//  Les documents non visualisables (Word/Excel…) s'ouvrent en externe.
// ════════════════════════════════════════════════════════════════════════════

/// Galerie image-seule (rétro-compat) → délègue à la visionneuse unifiée.
Future<void> openImageLightbox(
  BuildContext context,
  List<MessageAttachment> images, {
  int initialIndex = 0,
}) =>
    openMediaViewer(context, images, initialIndex: initialIndex);

/// Visionneuse média plein écran CONFINÉE (sidebar préservée) : carrousse
/// images ET vidéos, swipe horizontal + flèches + compteur. Les images sont
/// zoomables ; la page vidéo active est lue inline (media_kit). Démarre à
/// [initialIndex].
Future<void> openMediaViewer(
  BuildContext context,
  List<MessageAttachment> media, {
  int initialIndex = 0,
}) async {
  if (media.isEmpty) return;
  showContentOverlay(
    context,
    (close) =>
        _MediaViewer(media: media, initialIndex: initialIndex, onClose: close),
  );
}

class _MediaViewer extends StatefulWidget {
  const _MediaViewer(
      {required this.media, required this.initialIndex, required this.onClose});
  final List<MessageAttachment> media;
  final int initialIndex;
  final VoidCallback onClose;

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.media.length - 1);
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.media.length - 1);
    _ctrl.animateToPage(next,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  Widget _page(MessageAttachment a, int i) {
    if (a.isVideo) {
      // 1 seul lecteur à la fois : seule la page ACTIVE instancie media_kit.
      return i == _index
          ? _ViewerVideoPage(att: a)
          : const Center(
              child: Icon(Icons.play_circle_outline_rounded,
                  color: Colors.white38, size: 72));
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: SignedNetworkImage(
          att: a,
          fit: BoxFit.contain,
          placeholder: const Center(
              child: CircularProgressIndicator(color: Colors.white)),
          errorWidget: const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white38, size: 56)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.media.length;
    final current = widget.media[_index];
    return Material(
      color: Colors.black,
      child: Stack(children: [
        PageView.builder(
          controller: _ctrl,
          itemCount: n,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => _page(widget.media[i], i),
        ),

        // Flèches de navigation (desktop / multi-éléments)
        if (_index > 0)
          _ViewerArrow(
              alignment: Alignment.centerLeft,
              icon: Icons.chevron_left_rounded,
              onTap: () => _go(-1)),
        if (_index < n - 1)
          _ViewerArrow(
              alignment: Alignment.centerRight,
              icon: Icons.chevron_right_rounded,
              onTap: () => _go(1)),

        // Barre supérieure : retour + nom + compteur + télécharger
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(children: [
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(current.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      if (n > 1)
                        Text('${_index + 1} / $n',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11.5)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ouvrir / télécharger',
                  onPressed: () async => _openExternal(
                      await resolveAttachmentUrl(
                          Supabase.instance.client, current)),
                  icon: const Icon(Icons.download_rounded,
                      color: Colors.white),
                ),
              ]),
            ),
          ),
        ),

        // Points indicateurs (si plusieurs éléments)
        if (n > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < n; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
              ],
            ),
          ),
      ]),
    );
  }
}

/// Page vidéo de la visionneuse : re-signe l'URL (bucket privé) puis lecture
/// inline media_kit.
class _ViewerVideoPage extends StatefulWidget {
  const _ViewerVideoPage({required this.att});
  final MessageAttachment att;
  @override
  State<_ViewerVideoPage> createState() => _ViewerVideoPageState();
}

class _ViewerVideoPageState extends State<_ViewerVideoPage> {
  String? _url;

  @override
  void initState() {
    super.initState();
    final cached = cachedSignedUrl(widget.att);
    if (cached != null) {
      _url = cached;
    } else {
      resolveAttachmentUrl(Supabase.instance.client, widget.att).then((u) {
        if (mounted) setState(() => _url = u);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 700),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: InlineVideoPlayer(url: url),
        ),
      ),
    );
  }
}

class _ViewerArrow extends StatelessWidget {
  const _ViewerArrow(
      {required this.alignment, required this.icon, required this.onTap});
  final Alignment    alignment;
  final IconData     icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Material(
            color: Colors.white.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      );
}

Future<void> _openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ─── Visualisation PDF in-app ─────────────────────────────────────────────────

/// Bannière de progression pendant le téléchargement du PDF (pdfrx).
Widget _pdfLoading(BuildContext context, int downloaded, int? total) {
  final p = (total != null && total > 0) ? downloaded / total : null;
  return Center(
      child: CircularProgressIndicator(value: p, color: Colors.white));
}

/// Repli propre quand le moteur PDF ne peut pas afficher (ex. Linux desktop).
class _PdfErrorBanner extends StatelessWidget {
  const _PdfErrorBanner({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.picture_as_pdf_rounded,
              size: 54, color: Colors.white38),
          const SizedBox(height: 14),
          const Text('Aperçu PDF indisponible sur cet appareil',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openExternal(url),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Ouvrir le document'),
            style: FilledButton.styleFrom(backgroundColor: kNavy),
          ),
        ]),
      );
}

/// Ouvre un PDF distant SANS quitter l'app (moteur `pdfrx`/pdfium : Android ·
/// iOS · Web · Windows · macOS · **Linux**), dans un panneau confiné à la zone
/// de contenu (sidebar préservée), fermable par ✕ ou clic à côté. pdfrx met le
/// document EN CACHE → réouverture instantanée, pas de re-téléchargement.
Future<void> openPdf(BuildContext context, String url, {String? title}) async {
  if (!context.mounted) return;
  showContentOverlay(
    context,
    (close) => _PdfOverlay(url: url, title: title, onClose: close),
  );
}

/// Panneau PDF centré (≈94 % de la zone de contenu, max 1100 px) sur backdrop.
class _PdfOverlay extends StatelessWidget {
  const _PdfOverlay(
      {required this.url, this.title, required this.onClose});
  final String  url;
  final String? title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Stack(children: [
        // Cliquer à côté ferme le panneau.
        Positioned.fill(child: GestureDetector(onTap: onClose)),
        Center(
          child: LayoutBuilder(builder: (_, c) {
            final w = (c.maxWidth * 0.94).clamp(320.0, 1100.0);
            final h = c.maxHeight * 0.94;
            return Container(
              width: w,
              height: h,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(children: [
                Container(
                  height: 50,
                  color: kNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    const Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title ?? 'Document',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      tooltip: 'Ouvrir / télécharger',
                      onPressed: () => _openExternal(url),
                      icon: const Icon(Icons.download_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ]),
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFF323639),
                    child: PdfViewer.uri(
                      Uri.parse(url),
                      params: PdfViewerParams(
                        backgroundColor: const Color(0xFF323639),
                        loadingBannerBuilder: _pdfLoading,
                        // Dégradation propre si le moteur PDF échoue (ex. Linux
                        // dev) : message + ouverture externe, jamais d'écran rouge.
                        errorBannerBuilder: (context, error, stack, ref) =>
                            _PdfErrorBanner(url: url),
                      ),
                    ),
                  ),
                ),
              ]),
            );
          }),
        ),
      ]),
    );
  }
}
