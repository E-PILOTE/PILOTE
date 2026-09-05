part of '../administrators_screen.dart';

// Dépôt de la photo dans le formulaire.

class _AvatarUploadBox extends StatelessWidget {
  const _AvatarUploadBox({
    required this.initials,
    required this.color,
    required this.avatarUrl,
    required this.previewBytes,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });

  final String    initials;
  final Color     color;
  final String?   avatarUrl;
  final Uint8List? previewBytes;
  final bool      uploading;
  final VoidCallback onPick, onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = previewBytes != null || (avatarUrl != null && avatarUrl!.startsWith('http'));

    return Column(children: [
      Stack(children: [
        // Cercle avatar
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(
              color: hasImage ? _kBorder : color.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: uploading
              ? Center(child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy)))
              : previewBytes != null
                  ? Image.memory(previewBytes!, fit: BoxFit.cover)
                  : (avatarUrl != null && avatarUrl!.startsWith('http'))
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Center(child: Text(initials,
                            style: TextStyle(color: color, fontSize: 26,
                                fontWeight: FontWeight.w800))),
                        )
                      : Center(child: Text(initials,
                          style: TextStyle(color: color, fontSize: 26,
                              fontWeight: FontWeight.w800))),
        ),
        // Bouton modifier (pastille)
        if (!uploading)
          Positioned(
            right: 0, bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onPick,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: _kNavy,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisSize: MainAxisSize.min, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onPick,
            child: Text('Changer', style: TextStyle(
                color: _kNavy, fontSize: 11, fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: _kNavy)),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRemove,
              child: const Text('Supprimer', style: TextStyle(
                  color: _kRed, fontSize: 11, fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: _kRed)),
            ),
          ),
        ],
      ]),
    ]);
  }
}

// ─── Modal création / édition ─────────────────────────────────────────────────
