part of '../school_groups_screen.dart';

// Dépôt du logo du groupe.

class _LogoUploadBox extends StatelessWidget {
  const _LogoUploadBox({
    required this.name,
    required this.onPick,
    required this.onRemove,
    this.logoUrl,
    this.previewBytes,
    this.uploading = false,
  });
  final String      name;
  final String?     logoUrl;
  final Uint8List?  previewBytes;
  final bool        uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  static List<Color> get _colors => [_kNavy, _kGreen, _kPurple, _kOrange, const Color(0xFF0EA5E9)];

  String get _initials => initialesEtablissement(name);

  Color get _color => name.isNotEmpty
      ? _colors[name.codeUnitAt(0) % _colors.length]
      : _kNavy;

  bool get _hasImage =>
      previewBytes != null ||
      (logoUrl != null && logoUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ── Aperçu ──────────────────────────────────────────────────────────
      Stack(alignment: Alignment.topRight, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: uploading ? null : onPick,
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasImage
                      ? _kNavy.withValues(alpha: 0.35)
                      : _kBorder,
                  width: _hasImage ? 2 : 1.5,
                ),
                color: _kSurface,
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildContent(),
            ),
          ),
        ),
        // Bouton supprimer si image présente
        if (_hasImage && !uploading)
          Positioned(
            top: -4, right: -4,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: _kRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 11, color: Colors.white),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      // ── Bouton sélectionner ──────────────────────────────────────────────
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: uploading ? null : onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kNavy.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                uploading ? Icons.hourglass_top_rounded : Icons.upload_rounded,
                size: 12, color: _kNavy,
              ),
              const SizedBox(width: 4),
              Text(
                uploading ? 'Upload…' : (_hasImage ? 'Changer' : 'Logo'),
                style: TextStyle(
                  color: _kNavy, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildContent() {
    if (uploading) {
      return Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy),
        ),
      );
    }
    if (previewBytes != null) {
      return Image.memory(previewBytes!, fit: BoxFit.cover);
    }
    if (logoUrl != null && logoUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: logoUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) => Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy),
          ),
        ),
        errorWidget: (_, _, _) => _initialsWidget(),
      );
    }
    return _initialsWidget();
  }

  Widget _initialsWidget() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.add_photo_alternate_rounded,
          size: 22, color: _kMuted.withValues(alpha: 0.5)),
      const SizedBox(height: 3),
      Text(_initials, style: TextStyle(
          color: _color, fontSize: 20, fontWeight: FontWeight.w900)),
    ]),
  );
}
