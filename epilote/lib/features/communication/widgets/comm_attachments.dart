import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/messages_provider.dart';
import 'audio_message_player.dart';
import 'feed_video_player.dart';
import '../../../core/utils/media_compression.dart';
import 'media_viewer.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Pièces jointes — module PARTAGÉ (messagerie, annonces, événements).
//  Viewer (images inline, audio/vidéo/documents en chips → application
//  externe), liste éditable pour les composeurs, et picker+upload Storage.
//  ⚠️ L'upload exige internet ; la LECTURE des images déjà vues est cachée
//  (CachedNetworkImage) et reste disponible hors-ligne.
// ════════════════════════════════════════════════════════════════════════════

/// Taille maximale d'une pièce jointe (Storage) : 25 Mo.
const int kMaxAttachmentBytes = 25 * 1024 * 1024;

String humanFileSize(int bytes) {
  if (bytes <= 0) return '';
  const units = ['o', 'Ko', 'Mo', 'Go'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

IconData attachmentIcon(String mime) {
  if (mime.startsWith('image/')) return Icons.image_rounded;
  if (mime.startsWith('audio/')) return Icons.audiotrack_rounded;
  if (mime.startsWith('video/')) return Icons.videocam_rounded;
  if (mime.contains('pdf')) return Icons.picture_as_pdf_rounded;
  if (mime.contains('word') ||
      mime.contains('msword') ||
      mime.contains('opendocument.text')) {
    return Icons.description_rounded;
  }
  if (mime.contains('excel') ||
      mime.contains('sheet') ||
      mime.contains('csv')) {
    return Icons.table_chart_rounded;
  }
  if (mime.contains('powerpoint') || mime.contains('presentation')) {
    return Icons.slideshow_rounded;
  }
  return Icons.insert_drive_file_rounded;
}

/// Ouvre la pièce jointe SANS quitter l'app quand c'est possible (image →
/// lightbox, PDF → viewer in-app, vidéo → lecteur). Les autres documents
/// (Word/Excel…) s'ouvrent dans l'application système.
Future<void> openAttachment(BuildContext context, MessageAttachment a,
    {List<MessageAttachment>? gallery}) async {
  if (a.isImage) {
    final imgs = (gallery ?? [a]).where((x) => x.isImage).toList();
    final idx = imgs.indexWhere((x) => x.cacheKey == a.cacheKey);
    await openImageLightbox(context, imgs, initialIndex: idx < 0 ? 0 : idx);
    return;
  }
  // Bucket privé → re-signer une URL fraîche avant d'ouvrir vidéo/PDF/externe.
  final url = await resolveAttachmentUrl(Supabase.instance.client, a);
  if (!context.mounted) return;
  if (a.isVideo) {
    await openVideo(context, url, title: a.name);
    return;
  }
  if (a.mime.contains('pdf')) {
    await openPdf(context, url, title: a.name);
    return;
  }
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Impossible d'ouvrir la pièce jointe — "
            'vérifiez votre connexion internet.')));
  }
}

// ─── Viewer (lecture) ─────────────────────────────────────────────────────────
class CommAttachmentView extends StatelessWidget {
  const CommAttachmentView(
      {super.key, required this.items, this.thumbSize = 150, this.mine = false});
  final List<MessageAttachment> items;
  final double thumbSize;

  /// Bulle sortante (couleur du lecteur audio).
  final bool mine;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((a) {
          if (a.isImage) {
            return _ImageThumb(att: a, size: thumbSize, gallery: items);
          }
          if (a.isAudio) {
            // Note vocale → lecteur INLINE (play/pause + progression).
            return AudioMessagePlayer(att: a, mine: mine);
          }
          if (a.isVideo) {
            return SizedBox(
              width: thumbSize * 1.4,
              child: FeedVideoThumb(
                  url: a.url, label: a.name, height: thumbSize,
                  onTap: () => openAttachment(context, a),
                  radius: const BorderRadius.all(Radius.circular(10))),
            );
          }
          return _FileChip(att: a);
        }).toList(),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.att, required this.size, this.gallery});
  final MessageAttachment att;
  final double size;
  final List<MessageAttachment>? gallery;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => openAttachment(context, att, gallery: gallery),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SignedNetworkImage(
            att: att,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: _FileChip(att: att),
          ),
        ),
      );
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.att});
  final MessageAttachment att;

  @override
  Widget build(BuildContext context) {
    final accent = att.isAudio
        ? kGreen
        : att.isVideo
            ? kAccent
            : kNavy;
    final action = att.isAudio
        ? 'Écouter'
        : att.isVideo
            ? 'Regarder'
            : 'Ouvrir';
    return InkWell(
      onTap: () => openAttachment(context, att),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              att.isAudio || att.isVideo
                  ? Icons.play_circle_fill_rounded
                  : attachmentIcon(att.mime),
              size: 22,
              color: accent),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(att.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary)),
                Text('$action · ${humanFileSize(att.size)}',
                    style: const TextStyle(fontSize: 10, color: kTextMuted)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Liste éditable (composeur / formulaire) ─────────────────────────────────
/// Pièces jointes en attente d'envoi : miniature image (tap → aperçu plein
/// écran) ou puce document (tap → aperçu PDF/ouverture), chacune avec un
/// bouton de retrait. Permet de PRÉVISUALISER avant publication.
class CommAttachmentEditList extends StatelessWidget {
  const CommAttachmentEditList(
      {super.key, required this.items, required this.onRemove});
  final List<MessageAttachment> items;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final images = items.where((a) => a.isImage).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < items.length; i++)
            _PendingChip(
              att: items[i],
              gallery: images,
              onRemove: () => onRemove(i),
            ),
        ],
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip(
      {required this.att, required this.gallery, required this.onRemove});
  final MessageAttachment att;
  final List<MessageAttachment> gallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final removeBtn = Positioned(
      top: -6,
      right: -6,
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
              color: Colors.black54, shape: BoxShape.circle),
          padding: const EdgeInsets.all(2),
          child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
        ),
      ),
    );
    // Image : miniature 64×64, tap → aperçu lightbox.
    if (att.isImage) {
      return SizedBox(
        width: 70,
        height: 70,
        child: Stack(clipBehavior: Clip.none, children: [
          GestureDetector(
            onTap: () => openAttachment(context, att, gallery: gallery),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SignedNetworkImage(
                  att: att, width: 64, height: 64, fit: BoxFit.cover),
            ),
          ),
          removeBtn,
        ]),
      );
    }
    // Document / audio / vidéo : puce tap → aperçu (PDF) / ouverture.
    return Stack(clipBehavior: Clip.none, children: [
      InkWell(
        onTap: () => openAttachment(context, att),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(attachmentIcon(att.mime), size: 18, color: kNavy),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(att.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                  Text('Aperçu · ${humanFileSize(att.size)}',
                      style: const TextStyle(fontSize: 10, color: kTextMuted)),
                ],
              ),
            ),
          ]),
        ),
      ),
      removeBtn,
    ]);
  }
}

// ─── Sélecteur d'emoji (panneau, sans dépendance externe) ─────────────────────
const _kEmojis = [
  '😀', '😃', '😄', '😁', '😅', '😂', '🙂', '😉', '😊', '😍',
  '😘', '😎', '🤩', '🤔', '🙄', '😴', '😢', '😭', '😡', '🥳',
  '👍', '👎', '👏', '🙏', '💪', '🤝', '👌', '✌️', '👋', '🫶',
  '❤️', '🧡', '💛', '💚', '💙', '💜', '🔥', '⭐', '✨', '🎉',
  '✅', '❌', '⚠️', '📌', '📎', '📚', '📝', '📅', '⏰', '💡',
  '🏫', '🎓', '👨‍🏫', '👩‍🏫', '🧑‍🎓', '📊', '💰', '🚀', '🌍', '☑️',
];

class CommEmojiPicker extends StatelessWidget {
  const CommEmojiPicker({super.key, required this.onPick});
  final void Function(String emoji) onPick;

  @override
  Widget build(BuildContext context) => Container(
        height: 168,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: GridView.count(
          crossAxisCount: 10,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          children: _kEmojis
              .map((e) => InkWell(
                    onTap: () => onPick(e),
                    borderRadius: BorderRadius.circular(6),
                    child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 20))),
                  ))
              .toList(),
        ),
      );
}

// ─── Picker + upload Storage ──────────────────────────────────────────────────

/// Ouvre le sélecteur de fichiers (multi) puis téléverse chaque fichier dans
/// [bucket]. Renvoie les pièces jointes prêtes à embarquer dans le jsonb.
/// Lève une [AttachmentUploadException] claire si hors-ligne ou fichier trop gros.
Future<List<MessageAttachment>> pickAndUploadAttachments({
  required SupabaseClient client,
  required String groupId,
  String bucket = 'communication-attachments',
  bool imagesOnly = false,
}) async {
  final res = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: true,
    type: imagesOnly ? FileType.image : FileType.any,
  );
  if (res == null || res.files.isEmpty) return const [];

  final out = <MessageAttachment>[];
  for (final f in res.files) {
    final raw = f.bytes;
    if (raw == null) continue;
    final rawMime = MessageAttachment.mimeForExtension(f.extension);
    // Compression « effet WhatsApp » AVANT le contrôle de taille : une photo
    // de 8 Mo tombe à ~400 Ko et passe sous la limite ; data économisée.
    final c = await compressForUpload(
        bytes: raw, fileName: f.name, mime: rawMime);
    if (c.bytes.length > kMaxAttachmentBytes) {
      throw AttachmentUploadException(
          '« ${f.name} » dépasse la taille maximale '
          '(${humanFileSize(kMaxAttachmentBytes)}) même après compression.');
    }
    try {
      out.add(await uploadMessageAttachment(
        client: client,
        groupId: groupId,
        fileName: c.fileName,
        bytes: c.bytes,
        mime: c.mime,
        bucket: bucket,
      ));
    } on StorageException catch (e) {
      throw AttachmentUploadException(
          'Téléversement de « ${f.name} » refusé : ${e.message}');
    } catch (_) {
      throw const AttachmentUploadException(
          'Téléversement impossible : les pièces jointes nécessitent une '
          'connexion internet. Votre texte, lui, peut partir hors-ligne.');
    }
  }
  return out;
}

class AttachmentUploadException implements Exception {
  const AttachmentUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}
