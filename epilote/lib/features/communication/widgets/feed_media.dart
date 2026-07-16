import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/messages_provider.dart';
import 'comm_attachments.dart';
import 'feed_video_player.dart';
import 'media_viewer.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Médias inline d'une publication (style réseau social premium).
//   • 1 image       → grande visionneuse pleine largeur (tap → lightbox zoom).
//   • 1 vidéo       → lecteur inline (tap → plein écran confiné).
//   • ≥ 2 visuels   → CARROUSEL swipe (PageView LAZY) : flèches, points,
//                     compteur « i/N ». Images + vidéos mélangées.
//   • Documents     → puces (CommAttachmentView → PDF in-app / ouverture).
// Ré-exporté par staff_feed_ui.dart (imports existants inchangés).
// ═════════════════════════════════════════════════════════════════════════════

/// Hauteur des médias (plus généreuse qu'un simple aperçu, sans aller jusqu'au
/// plein écran « TikTok »).
const double _kMediaHeight = 440;

class FeedMediaGrid extends StatelessWidget {
  const FeedMediaGrid({
    super.key,
    required this.items,
    this.manageable = false,
    this.onRemove,
  });
  final List<MessageAttachment> items;
  /// L'utilisateur peut-il gérer cette publication (afficher le ✕ par fichier).
  final bool manageable;
  final ValueChanged<MessageAttachment>? onRemove;

  @override
  Widget build(BuildContext context) {
    final visual = items.where((a) => a.isImage || a.isVideo).toList();
    final pdfs   = items.where((a) => a.mime.contains('pdf')).toList();
    final docs   = items
        .where((a) =>
            !a.isImage && !a.isVideo && !a.mime.contains('pdf'))
        .toList();
    final canRemove = manageable && onRemove != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (visual.isNotEmpty)
          FeedMediaCarousel(
              items: visual, manageable: canRemove, onRemove: onRemove),
        // PDF : aperçu 1re page DANS le fil (gouvernemental) ; tap → lecteur.
        for (final p in pdfs) ...[
          const SizedBox(height: 10),
          PdfInlinePreview(
            att: p,
            onRemove:
                canRemove ? () => confirmRemoveAttachment(context, p, onRemove!) : null,
          ),
        ],
        if (docs.isNotEmpty) ...[
          const SizedBox(height: 10),
          if (canRemove)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in docs)
                  Stack(clipBehavior: Clip.none, children: [
                    CommAttachmentView(items: [d], thumbSize: 130),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: AttachmentRemoveBadge(
                          onRemove: () =>
                              confirmRemoveAttachment(context, d, onRemove!)),
                    ),
                  ]),
              ],
            )
          else
            CommAttachmentView(items: docs, thumbSize: 130),
        ],
      ],
    );
  }
}

/// Badge ✕ de suppression d'une pièce jointe (sur média/document gérable).
class AttachmentRemoveBadge extends StatelessWidget {
  const AttachmentRemoveBadge({super.key, required this.onRemove});
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withValues(alpha: 0.62),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onRemove,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
          ),
        ),
      );
}

/// Confirme puis retire UNE pièce jointe (sans supprimer la publication).
Future<void> confirmRemoveAttachment(BuildContext context,
    MessageAttachment att, ValueChanged<MessageAttachment> onRemove) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Retirer ce document ?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: Text('« ${att.name} » sera retiré de la publication. '
          'Les autres fichiers sont conservés.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Retirer'),
        ),
      ],
    ),
  );
  if (ok == true) onRemove(att);
}

// ─── Aperçu PDF inline (1re page rendue + tap → lecteur in-app) ────────────────

class PdfInlinePreview extends StatefulWidget {
  const PdfInlinePreview(
      {super.key, required this.att, this.height = 460, this.onRemove});
  final MessageAttachment att;
  final double height;
  final VoidCallback? onRemove;

  @override
  State<PdfInlinePreview> createState() => _PdfInlinePreviewState();
}

class _PdfInlinePreviewState extends State<PdfInlinePreview> {
  // Cache GLOBAL des 1res pages rendues (clé = identifiant pièce jointe).
  // Évite de re-télécharger + re-rasteriser le PDF à chaque rebuild/scroll
  // (cause du scintillement + des rechargements de ~3 s observés sur Linux).
  static final Map<String, ui.Image> _cache = {};
  static final Map<String, Future<ui.Image?>> _inflight = {};

  ui.Image? _img;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = widget.att.cacheKey;
    final cached = _cache[key];
    if (cached != null) {
      _img = cached;
      return;
    }
    try {
      final img = await (_inflight[key] ??= _render(key));
      if (!mounted) return;
      setState(() {
        _img = img;
        _failed = img == null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _inflight.remove(key);
    }
  }

  /// Télécharge le PDF, rend la 1re page en bitmap (une seule fois) → ui.Image.
  Future<ui.Image?> _render(String key) async {
    final url = cachedSignedUrl(widget.att) ??
        await resolveAttachmentUrl(Supabase.instance.client, widget.att);
    if (url.isEmpty) return null;
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openUri(Uri.parse(url));
      if (doc.pages.isEmpty) return null;
      final page = doc.pages.first;
      // Largeur cible nette (~1000 px) en gardant le ratio de la page.
      const targetW = 1000.0;
      final targetH = targetW * (page.height / page.width);
      final raster = await page.render(
        fullWidth: targetW,
        fullHeight: targetH,
        backgroundColor: 0xFFFFFFFF,
      );
      if (raster == null) return null;
      final image = await _toUiImage(raster);
      raster.dispose();
      _cache[key] = image;
      return image;
    } finally {
      await doc?.dispose();
    }
  }

  Future<ui.Image> _toUiImage(PdfImage raster) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      raster.pixels,
      raster.width,
      raster.height,
      ui.PixelFormat.bgra8888,
      completer.complete,
    );
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    return GestureDetector(
      onTap: () => openAttachment(context, widget.att), // lecteur PDF in-app
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: widget.height,
          width: double.infinity, // pleine largeur même hors Column.stretch
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_failed)
                _PdfFallback(att: widget.att)
              else if (img == null)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else
                // 1re page (bitmap caché) : haut du document, pleine largeur.
                RawImage(
                  image: img,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.medium,
                ),
              // Bandeau supérieur : icône PDF + nom du fichier.
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.att.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (widget.onRemove != null) ...[
                      const SizedBox(width: 8),
                      AttachmentRemoveBadge(onRemove: widget.onRemove!),
                    ],
                  ]),
                ),
              ),
              // Pied : bouton « Voir le document ».
              Positioned(
                bottom: 12, right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: kNavy,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.open_in_full_rounded,
                        color: Colors.white, size: 15),
                    SizedBox(width: 7),
                    Text('Voir le document',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Repli si le moteur PDF ne peut pas rendre l'aperçu (ex. Linux dev).
class _PdfFallback extends StatelessWidget {
  const _PdfFallback({required this.att});
  final MessageAttachment att;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.picture_as_pdf_rounded,
              size: 56, color: kNavy),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(att.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
          const SizedBox(height: 4),
          Text('Appuyez pour ouvrir le document',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
      );
}

// ─── Carrousel média (images + vidéos) ────────────────────────────────────────

class FeedMediaCarousel extends StatefulWidget {
  const FeedMediaCarousel({
    super.key,
    required this.items,
    this.height = _kMediaHeight,
    this.manageable = false,
    this.onRemove,
  });
  final List<MessageAttachment> items;
  final double height;
  final bool manageable;
  final ValueChanged<MessageAttachment>? onRemove;

  @override
  State<FeedMediaCarousel> createState() => _FeedMediaCarouselState();
}

class _FeedMediaCarouselState extends State<FeedMediaCarousel> {
  final PageController _ctrl = PageController();
  int  _index = 0;
  bool _hover = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final n = widget.items.length;
    final next = (_index + delta).clamp(0, n - 1);
    _ctrl.animateToPage(next,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  // Tap → visionneuse plein écran unifiée (carrousel images + vidéos), démarre
  // sur l'élément cliqué et navigue entre TOUS les éléments.
  void _open(int i) => openMediaViewer(context, widget.items, initialIndex: i);

  Widget _slide(MessageAttachment a, int i) {
    if (a.isVideo) {
      // Mobile (libmpv stable) : lecture AUTOMATIQUE muette façon Facebook.
      if (feedAutoplaySupported) {
        return _AutoVideoSlide(
            att: a, height: widget.height, visKey: '${a.cacheKey}-$i');
      }
      // Desktop (Linux/Windows dev) : vignette tap-pour-lire → visionneuse
      // unifiée (un seul lecteur à la demande, pas de crash EGL/libmpv).
      return FeedVideoThumb(
        url: a.url,
        label: a.name,
        height: widget.height,
        radius: BorderRadius.zero,
        onTap: () => _open(i),
      );
    }
    return GestureDetector(
      onTap: () => _open(i),
      child: SignedNetworkImage(
        att: a,
        width: double.infinity,
        height: widget.height,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    const radius = BorderRadius.all(Radius.circular(14));

    // Cas mono-média : pas de chrome de carrousel.
    if (n == 1) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            _slide(widget.items.first, 0),
            if (widget.manageable && widget.onRemove != null)
              Positioned(
                top: 10,
                left: 10,
                child: AttachmentRemoveBadge(
                    onRemove: () => confirmRemoveAttachment(
                        context, widget.items.first, widget.onRemove!)),
              ),
          ]),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit : (_) => setState(() => _hover = false),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            children: [
              // Pages (LAZY : seules les pages visibles/voisines sont construites)
              PageView.builder(
                controller: _ctrl,
                itemCount: n,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _slide(widget.items[i], i),
              ),

              // ✕ retrait du média courant (publication gérable)
              if (widget.manageable && widget.onRemove != null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: AttachmentRemoveBadge(
                      onRemove: () => confirmRemoveAttachment(
                          context, widget.items[_index], widget.onRemove!)),
                ),

              // Compteur « i / N »
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_index + 1} / $n',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),

              // Flèche gauche
              if (_index > 0)
                _NavArrow(
                  alignment: Alignment.centerLeft,
                  icon: Icons.chevron_left_rounded,
                  visible: _hover,
                  onTap: () => _go(-1),
                ),
              // Flèche droite
              if (_index < n - 1)
                _NavArrow(
                  alignment: Alignment.centerRight,
                  icon: Icons.chevron_right_rounded,
                  visible: _hover,
                  onTap: () => _go(1),
                ),

              // Points indicateurs
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < n; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.alignment,
    required this.icon,
    required this.visible,
    required this.onTap,
  });
  final Alignment    alignment;
  final IconData     icon;
  final bool         visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: visible ? 1 : 0,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        ),
      );
}

// ─── Slide vidéo auto-play : résout l'URL signée puis lit en boucle, muet ─────
class _AutoVideoSlide extends StatefulWidget {
  const _AutoVideoSlide(
      {required this.att, required this.height, required this.visKey});
  final MessageAttachment att;
  final double height;
  final String visKey;

  @override
  State<_AutoVideoSlide> createState() => _AutoVideoSlideState();
}

class _AutoVideoSlideState extends State<_AutoVideoSlide> {
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
      return Container(
        height: widget.height,
        color: Colors.black,
        child: const Center(
            child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return InlineFeedVideo(
        url: url, visKey: widget.visKey, height: widget.height);
  }
}
