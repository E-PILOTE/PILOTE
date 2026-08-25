import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/messages_provider.dart' show MessageAttachment;
import '../providers/stories_provider.dart';
import 'comm_attachments.dart';
import '../../../core/utils/message_erreur.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Composer de Story — deux modes : Média (photo/vidéo téléversés) ou Texte
//  (fond coloré). Publie une story éphémère 24h via [createStoryScoped].
// ════════════════════════════════════════════════════════════════════════════

List<Color> get _bgPalette => [
  kNavy, // navy
  const Color(0xFF7C3AED), // violet
  kGreen, // vert
  const Color(0xFFE11D48), // rose
  const Color(0xFFF59E0B), // ambre
  const Color(0xFF0EA5E9), // bleu ciel
  kTextPrimary, // noir
  const Color(0xFF059669), // émeraude
];

class StoryComposerDialog extends ConsumerStatefulWidget {
  const StoryComposerDialog({super.key});

  @override
  ConsumerState<StoryComposerDialog> createState() =>
      _StoryComposerDialogState();
}

class _StoryComposerDialogState extends ConsumerState<StoryComposerDialog> {
  bool _textMode = false;
  final _textCtrl    = TextEditingController();
  final _captionCtrl = TextEditingController();
  Color _bg = _bgPalette.first;

  MessageAttachment? _media; // image/vidéo téléversé
  bool _busy = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    if (groupId == null) return;
    setState(() => _busy = true);
    try {
      final items = await pickAndUploadAttachments(
        client: ref.read(supabaseClientProvider),
        groupId: groupId,
        bucket: 'communication-attachments',
      );
      final media = items.firstWhere(
        (a) => a.isImage || a.isVideo,
        orElse: () => items.isNotEmpty
            ? items.first
            : const MessageAttachment(
                url: '', name: '', mime: '', size: 0, kind: 'file'),
      );
      if (media.url.isNotEmpty && (media.isImage || media.isVideo)) {
        setState(() => _media = media);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Choisissez une image ou une vidéo')));
      }
    } on AttachmentUploadException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message), backgroundColor: kRed));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      if (_textMode) {
        if (_textCtrl.text.trim().isEmpty) {
          _toast('Écrivez un texte');
          return;
        }
        await createStoryScoped(
          ref,
          mediaType: 'text',
          textContent: _textCtrl.text.trim(),
          bgColor: '#${(_bg.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        );
      } else {
        if (_media == null) {
          _toast('Ajoutez une photo ou une vidéo');
          return;
        }
        await createStoryScoped(
          ref,
          mediaType: _media!.isVideo ? 'video' : 'image',
          mediaUrl: _media!.url,
          caption: _captionCtrl.text.trim().isEmpty
              ? null
              : _captionCtrl.text.trim(),
        );
      }
      if (mounted) {
        Navigator.pop(context);
        _toast('Story publiée — visible 24 h', ok: true);
      }
    } catch (e) {
      _toast(messageErreur(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: ok ? kGreen : kRed));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: kNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Nouvelle story',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: kTextMuted),
            ),
          ]),
          const SizedBox(height: 12),
          // Sélecteur de mode
          Row(children: [
            _ModeChip(
                label: 'Photo / Vidéo',
                icon: Icons.photo_camera_rounded,
                active: !_textMode,
                onTap: () => setState(() => _textMode = false)),
            const SizedBox(width: 8),
            _ModeChip(
                label: 'Texte',
                icon: Icons.text_fields_rounded,
                active: _textMode,
                onTap: () => setState(() => _textMode = true)),
          ]),
          const SizedBox(height: 16),
          if (_textMode) _buildTextMode() else _buildMediaMode(),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _publish,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('Publier ma story'),
              style: FilledButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTextMode() {
    return Column(children: [
      Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: TextField(
          controller: _textCtrl,
          maxLines: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700),
          cursorColor: Colors.white,
          // Annule le `filled:true` blanc du thème global : le fond doit rester
          // la couleur choisie (_bg), texte blanc centré comme une vraie story.
          decoration: const InputDecoration(
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: 'Exprimez-vous…',
            hintStyle: TextStyle(color: Colors.white60, fontSize: 18),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in _bgPalette)
          GestureDetector(
            onTap: () => setState(() => _bg = c),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                    color: _bg == c ? kNavy : Colors.transparent, width: 3),
              ),
            ),
          ),
      ]),
    ]);
  }

  Widget _buildMediaMode() {
    if (_media != null) {
      return Column(children: [
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(_media!.isVideo
                  ? Icons.videocam_rounded
                  : Icons.image_rounded, size: 40, color: kNavy),
              const SizedBox(height: 8),
              Text(_media!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              TextButton(
                  onPressed: () => setState(() => _media = null),
                  child: const Text('Changer')),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _captionCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Légende (optionnelle)…',
            hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
            isDense: true,
            filled: true,
            fillColor: kSurface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: kBorder)),
          ),
        ),
      ]);
    }
    return InkWell(
      onTap: _busy ? null : _pickMedia,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder, style: BorderStyle.solid),
        ),
        child: Center(
          child: _busy
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 44, color: kNavy),
                  const SizedBox(height: 10),
                  Text('Ajouter une photo ou une vidéo',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                  const SizedBox(height: 4),
                  Text('Nécessite une connexion internet',
                      style: TextStyle(fontSize: 11, color: kTextMuted)),
                ]),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String       label;
  final IconData     icon;
  final bool         active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? kNavy : kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? kNavy : kBorder),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  size: 16, color: active ? Colors.white : kTextMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : kTextMuted)),
            ]),
          ),
        ),
      );
}
