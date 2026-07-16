part of 'documents_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DÉTAIL D'UN DOSSIER — checklist complète (pièces exigées + facultatives),
//  téléversement (Storage privé, internet requis), vérification (cachet admin),
//  consultation (URL signée) et retrait. Écritures gardées par permissions.
// ════════════════════════════════════════════════════════════════════════════
class _DossierDetail extends ConsumerStatefulWidget {
  const _DossierDetail({required this.dossier});
  final StudentDossier dossier;
  @override
  ConsumerState<_DossierDetail> createState() => _DossierDetailState();
}

class _DossierDetailState extends ConsumerState<_DossierDetail> {
  final _uploading = <String>{};

  String get _studentId => widget.dossier.student.id;

  Future<void> _upload(String slug, String label) async {
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final schoolId = profile?.schoolId ?? '';
    final groupId = profile?.groupId ?? '';
    if (schoolId.isEmpty || groupId.isEmpty) return;

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;

    setState(() => _uploading.add(slug));
    try {
      final client = ref.read(supabaseClientProvider);
      final path = await uploadStudentDocumentFile(
        client: client,
        schoolId: schoolId,
        studentId: _studentId,
        typeSlug: slug,
        fileName: f.name,
        bytes: bytes,
      );
      await insertStudentDocumentRow(
        groupId: groupId,
        schoolId: schoolId,
        studentId: _studentId,
        documentType: slug,
        documentName: label,
        fileUrl: path,
      );
      _snack('« $label » téléversé', kGreen);
    } catch (e) {
      _snack('Téléversement impossible (connexion requise) : $e', kRed);
    } finally {
      if (mounted) setState(() => _uploading.remove(slug));
    }
  }

  Future<void> _view(DocRow d) async {
    final client = ref.read(supabaseClientProvider);
    final url = await signedStudentDocUrl(client, d.fileUrl);
    if (url == null) {
      _snack('Aperçu indisponible (connexion requise)', kAccent);
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _toggleVerify(DocRow d) async {
    final me = ref.read(authNotifierProvider).valueOrNull?.id;
    await runModuleWrite(
      context,
      () => setDocumentVerified(
          id: d.id, verified: !d.isVerified, verifiedBy: me),
      success: d.isVerified ? 'Vérification retirée' : 'Pièce vérifiée',
    );
  }

  Future<void> _delete(DocRow d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Retirer cette pièce ?'),
        content: Text('« ${d.typeLabel} » sera retirée du dossier.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runModuleWrite(context, () => deleteStudentDocument(d.id),
        success: 'Pièce retirée');
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    // Le détail se relit en direct depuis le flux des pièces de l'élève.
    final docs =
        ref.watch(studentDocRowsProvider(_studentId)).valueOrNull ?? const [];
    final s = widget.dossier.student;
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canUpdate = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));

    final byType = <String, List<DocRow>>{};
    for (final d in docs) {
      byType.putIfAbsent(d.documentType, () => []).add(d);
    }
    final presentRequired =
        kRequiredDocTypes.where(byType.containsKey).length;
    final complete = presentRequired == kRequiredDocTypes.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // En-tête.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.04),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    (complete ? kGreen : kAccent).withValues(alpha: 0.12),
                child: Text(
                  s.firstName.isNotEmpty ? s.firstName[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: complete ? kGreen : kAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 17),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.lastFirst,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      const SizedBox(height: 2),
                      Text(
                          [
                            if (s.className != null) s.className!,
                            s.matricule
                          ].join(' · '),
                          style:
                              TextStyle(fontSize: 12.5, color: kTextMuted)),
                    ]),
              ),
              AdminBadge(
                complete
                    ? 'Dossier complet'
                    : '$presentRequired/${kRequiredDocTypes.length} exigées',
                color: complete ? kGreen : kAccent,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Liste des types de pièces.
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(16),
              shrinkWrap: true,
              children: [
                const _Section('Pièces exigées'),
                for (final e in studentDocTypes.entries)
                  if (kRequiredDocTypes.contains(e.key))
                    _DocTypeTile(
                      slug: e.key,
                      label: e.value,
                      required: true,
                      pieces: byType[e.key] ?? const [],
                      uploading: _uploading.contains(e.key),
                      canCreate: canCreate,
                      canUpdate: canUpdate,
                      canDelete: canDelete,
                      onUpload: () => _upload(e.key, e.value),
                      onView: _view,
                      onVerify: _toggleVerify,
                      onDelete: _delete,
                    ),
                const SizedBox(height: 8),
                const _Section('Pièces complémentaires'),
                for (final e in studentDocTypes.entries)
                  if (!kRequiredDocTypes.contains(e.key))
                    _DocTypeTile(
                      slug: e.key,
                      label: e.value,
                      required: false,
                      pieces: byType[e.key] ?? const [],
                      uploading: _uploading.contains(e.key),
                      canCreate: canCreate,
                      canUpdate: canUpdate,
                      canDelete: canDelete,
                      onUpload: () => _upload(e.key, e.value),
                      onView: _view,
                      onVerify: _toggleVerify,
                      onDelete: _delete,
                    ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: kTextMuted)),
      );
}

class _DocTypeTile extends StatelessWidget {
  const _DocTypeTile({
    required this.slug,
    required this.label,
    required this.required,
    required this.pieces,
    required this.uploading,
    required this.canCreate,
    required this.canUpdate,
    required this.canDelete,
    required this.onUpload,
    required this.onView,
    required this.onVerify,
    required this.onDelete,
  });
  final String slug, label;
  final bool required, uploading, canCreate, canUpdate, canDelete;
  final List<DocRow> pieces;
  final VoidCallback onUpload;
  final ValueChanged<DocRow> onView, onVerify, onDelete;

  @override
  Widget build(BuildContext context) {
    final present = pieces.isNotEmpty;
    final accent = !present
        ? (required ? kRed : kTextMuted)
        : pieces.any((p) => p.isVerified)
            ? kGreen
            : const Color(0xFF0EA5E9);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(13, 11, 8, present ? 4 : 11),
          child: Row(children: [
            Icon(
                present
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 17,
                color: accent),
            const SizedBox(width: 9),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
            if (required)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: kRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5)),
                child: Text('exigée',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kRed)),
              ),
            if (canCreate)
              uploading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : TextButton.icon(
                      onPressed: onUpload,
                      icon: const Icon(Icons.upload_rounded, size: 16),
                      label: Text(present ? 'Remplacer' : 'Ajouter',
                          style: const TextStyle(fontSize: 12.5)),
                      style: TextButton.styleFrom(
                          foregroundColor: kNavy,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8)),
                    ),
          ]),
        ),
        for (final p in pieces)
          _PieceRow(
            piece: p,
            canUpdate: canUpdate,
            canDelete: canDelete,
            onView: () => onView(p),
            onVerify: () => onVerify(p),
            onDelete: () => onDelete(p),
          ),
      ]),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({
    required this.piece,
    required this.canUpdate,
    required this.canDelete,
    required this.onView,
    required this.onVerify,
    required this.onDelete,
  });
  final DocRow piece;
  final bool canUpdate, canDelete;
  final VoidCallback onView, onVerify, onDelete;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(38, 0, 8, 9),
      child: Row(children: [
        Icon(
            piece.isExpired
                ? Icons.event_busy_rounded
                : Icons.insert_drive_file_outlined,
            size: 14,
            color: piece.isExpired ? kRed : kTextMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            piece.isExpired
                ? 'Expirée le ${_fmtDate(piece.expiryDate)}'
                : 'Déposée le ${_fmtDate(piece.createdAt)}'
                    '${piece.isVerified ? ' · vérifiée' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11.5,
                color: piece.isExpired ? kRed : kTextMuted),
          ),
        ),
        _IconAction(
            icon: Icons.visibility_outlined, tip: 'Consulter', onTap: onView),
        if (canUpdate)
          _IconAction(
            icon: piece.isVerified
                ? Icons.verified_rounded
                : Icons.verified_outlined,
            tip: piece.isVerified ? 'Retirer la vérification' : 'Vérifier',
            color: piece.isVerified ? kGreen : kTextMuted,
            onTap: onVerify,
          ),
        if (canDelete)
          _IconAction(
              icon: Icons.delete_outline_rounded,
              tip: 'Retirer',
              color: kRed,
              onTap: onDelete),
      ]),
    );
  }
}

class _IconAction extends StatelessWidget {
  _IconAction({
    required this.icon,
    required this.tip,
    required this.onTap,
    Color? color,
  }) : color = color ?? kTextMuted;
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, size: 17, color: color),
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      );
}
