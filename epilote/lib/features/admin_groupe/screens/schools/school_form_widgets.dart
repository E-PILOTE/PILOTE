part of '../admin_schools_screen.dart';

// Widgets locaux du formulaire école

// ─── Widgets locaux du formulaire école ────────────────────────────────────────

class _SchoolLogoUploadBox extends StatelessWidget {
  const _SchoolLogoUploadBox({
    required this.name,
    required this.onPick,
    required this.onRemove,
    this.logoUrl,
    this.previewBytes,
    this.uploading = false,
  });
  final String       name;
  final String?      logoUrl;
  final Uint8List?   previewBytes;
  final bool         uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  static List<Color> get _colors => [kNavy, kGreen, _kPurple, _kOrange, _kBlue];

  String get _initials => initialesEtablissement(name);

  Color get _color =>
      name.isNotEmpty ? _colors[name.codeUnitAt(0) % _colors.length] : kNavy;

  bool get _hasImage =>
      previewBytes != null || (logoUrl != null && logoUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(alignment: Alignment.topRight, clipBehavior: Clip.none, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: uploading ? null : onPick,
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasImage ? kNavy.withValues(alpha: 0.35) : kBorder,
                  width: _hasImage ? 2 : 1.5,
                ),
                color: kSurface,
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildContent(),
            ),
          ),
        ),
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
                    color: kRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.close_rounded, size: 11, color: Colors.white),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: uploading ? null : onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kNavy.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(uploading ? Icons.hourglass_top_rounded : Icons.upload_rounded,
                  size: 12, color: kNavy),
              const SizedBox(width: 4),
              Text(
                uploading ? 'Upload…' : (_hasImage ? 'Changer' : 'Logo'),
                style: TextStyle(
                    color: kNavy, fontSize: 11, fontWeight: FontWeight.w700),
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
          child: CircularProgressIndicator(strokeWidth: 2, color: kNavy),
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
            child: CircularProgressIndicator(strokeWidth: 2, color: kNavy),
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
              size: 22, color: kTextMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 3),
          Text(_initials, style: TextStyle(
              color: _color, fontSize: 20, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _SchFormLabel extends StatelessWidget {
  const _SchFormLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 3, height: 13,
        decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(
        color: kNavy, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1,
      )),
    ]),
  );
}

class _SchFormDivider extends StatelessWidget {
  const _SchFormDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Divider(color: kBorder, height: 1),
  );
}

class _SchSaveBtn extends StatelessWidget {
  const _SchSaveBtn({
    required this.isEdit,
    required this.btnCtrl,
    required this.btnScale,
    required this.btnHov,
    required this.onHover,
    required this.onTap,
  });
  final bool isEdit;
  final AnimationController btnCtrl;
  final Animation<double>   btnScale;
  final bool btnHov;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => onHover(true),
    onExit:  (_) => onHover(false),
    child: GestureDetector(
      onTapDown:  (_) => btnCtrl.forward(),
      onTapUp:    (_) { btnCtrl.reverse(); onTap(); },
      onTapCancel: () => btnCtrl.reverse(),
      child: ScaleTransition(
        scale: btnScale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [const Color(0xFF1A2F5A), kNavy],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: btnHov
                ? [BoxShadow(color: kNavy.withValues(alpha: 0.30),
                    blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              isEdit ? 'Enregistrer' : 'Créer l\'école',
              style: const TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            AnimatedSlide(
              offset: btnHov ? const Offset(0.15, 0) : Offset.zero,
              duration: const Duration(milliseconds: 180),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}

/// Décoration commune des champs du formulaire école.
InputDecoration schoolInputDec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
  filled: true,
  fillColor: kSurface,
  border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
  focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: kNavy, width: 1.5)),
  errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kRed)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
);

// ─── Formats de logo acceptés par le bucket `group-logos` ───────────────────
const kSchoolLogoExts = ['png', 'jpg', 'jpeg', 'webp', 'svg'];

String schoolLogoMimeForExt(String ext) => switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      _ => 'image/jpeg',
    };

// ─── Briques visuelles de la section « Offre éducative » ────────────────────

Widget eduSubHeader(String title, {required VoidCallback onAdd}) => Row(children: [
      Text(title.toUpperCase(), style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w800,
          color: kTextMuted, letterSpacing: 0.8)),
      const Spacer(),
      InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, size: 14, color: kNavy),
            const SizedBox(width: 3),
            Text('Ajouter', style: TextStyle(
                fontSize: 11, color: kNavy, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]);

Widget eduChip({
  required String label,
  required bool selected,
  required Color color,
  required VoidCallback onTap,
  bool custom = false,
  void Function(String action)? onMenu,
}) {
  final body = Padding(
    padding: EdgeInsets.fromLTRB(12, 8, onMenu != null ? 2 : 12, 8),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (selected) ...[
        const Icon(Icons.check_rounded, size: 14, color: Colors.white),
        const SizedBox(width: 5),
      ],
      Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : kTextPrimary)),
      if (custom) ...[
        const SizedBox(width: 5),
        Container(width: 5, height: 5, decoration: BoxDecoration(
            color: selected ? kCardBg : _kPurple, shape: BoxShape.circle)),
      ],
    ]),
  );
  return Container(
    decoration: BoxDecoration(
      color: selected ? color : kCardBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: selected ? color : kBorder, width: 1.2),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: body,
        ),
      ),
      if (onMenu != null)
        SizedBox(
          width: 28, height: 30,
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            tooltip: 'Gérer',
            icon: Icon(Icons.more_vert_rounded, size: 15,
                color: selected ? Colors.white : kTextMuted),
            onSelected: onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Renommer')),
              PopupMenuItem(value: 'disable', child: Text('Désactiver')),
            ],
          ),
        ),
    ]),
  );
}

Widget eduError(String msg) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kRed.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, size: 16, color: kRed),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: TextStyle(fontSize: 12, color: kRed))),
      ]),
    );
