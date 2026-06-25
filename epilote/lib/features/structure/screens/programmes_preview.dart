part of 'programmes_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  APERÇU PDF avant impression / enregistrement — fenêtre in-app (widget
//  `PdfPreview` du package printing). L'utilisateur voit le rendu paginé puis
//  choisit Imprimer ou Enregistrer, sans passer directement par la boîte système.
// ════════════════════════════════════════════════════════════════════════════
class _ProgrammePreviewDialog extends StatelessWidget {
  const _ProgrammePreviewDialog({required this.rows, this.yearLabel});
  final List<ProgrammeRow> rows;
  final String? yearLabel;

  Future<Uint8List> _build(PdfPageFormat _) =>
      ProgrammesPdfService.buildPdf(rows: rows, yearLabel: yearLabel);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = (size.width * 0.72).clamp(420.0, 900.0);
    final h = (size.height * 0.88).clamp(420.0, 1100.0);
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: w,
        height: h,
        child: Column(children: [
          // En-tête.
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
            decoration: const BoxDecoration(
              color: kNavy,
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              const Icon(Icons.picture_as_pdf_outlined,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Aperçu — Programmes pédagogiques',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                        '${_pl(rows.length, 'programme', 'programmes')}'
                        '${yearLabel != null ? ' · $yearLabel' : ''}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Corps : aperçu paginé + actions (Imprimer / Enregistrer).
          Expanded(
            child: PdfPreview(
              build: _build,
              useActions: true,
              allowPrinting: true,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: 'Programmes_pedagogiques.pdf',
              pdfPreviewPageDecoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
              ),
              previewPageMargin: const EdgeInsets.all(12),
              scrollViewDecoration: const BoxDecoration(color: kSurface),
              loadingWidget: const Center(
                child: CircularProgressIndicator(color: kNavy),
              ),
              actionBarTheme: const PdfActionBarTheme(
                backgroundColor: Colors.white,
                iconColor: kNavy,
                elevation: 0,
              ),
              actions: [
                PdfPreviewAction(
                  icon: const Icon(Icons.download_rounded),
                  onPressed: (ctx, build, format) async {
                    final messenger = ScaffoldMessenger.of(ctx);
                    try {
                      final path = await ProgrammesPdfService.downloadDoc(
                          rows: rows, yearLabel: yearLabel);
                      if (path != null) {
                        messenger.showSnackBar(SnackBar(
                            backgroundColor: kGreen,
                            content: Text('PDF enregistré : $path')));
                      }
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(
                          backgroundColor: kRed,
                          content: Text('Erreur enregistrement : $e')));
                    }
                  },
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
