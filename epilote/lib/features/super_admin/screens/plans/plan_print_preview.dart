part of '../plans_screen.dart';

// Aperçu avant impression.

class _PlanPrintPreviewModal extends StatefulWidget {
  const _PlanPrintPreviewModal({required this.plan});
  final PlanDetail plan;

  @override
  State<_PlanPrintPreviewModal> createState() => _PlanPrintPreviewModalState();
}

class _PlanPrintPreviewModalState extends State<_PlanPrintPreviewModal> {
  bool _printing    = false;
  bool _downloading = false;

  PlanDetail get p => widget.plan;

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    try {
      await PlanPdfService.printPlan(p);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Impression')),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _handleDownload() async {
    setState(() => _downloading = true);
    try {
      final path = await PlanPdfService.downloadPlan(p);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(
            path != null ? 'PDF sauvegardé : $path' : 'PDF généré',
            overflow: TextOverflow.ellipsis,
          )),
        ]),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Téléchargement')),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref_ = p.id.substring(0, 8).toUpperCase();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 820),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
            decoration: BoxDecoration(
              color: _kNavy,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_rounded, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fiche du plan d\'abonnement',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                Text('Réf. $ref_  •  ${p.name}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10.5)),
              ]),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: PdfPreview(
              build: (format) => PlanPdfService.buildPdf(p),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              maxPageWidth: 680,
              pdfFileName: 'Plan_${p.name.replaceAll(' ', '_')}.pdf',
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.close_rounded, size: 13, color: _kMuted),
                      const SizedBox(width: 5),
                      Text('Fermer', style: TextStyle(
                          color: _kMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: _printing ? null : _handlePrint,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.06),
                      border: Border.all(color: _kNavy.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_printing)
                        SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy))
                      else
                        Icon(Icons.print_rounded, size: 14, color: _kNavy),
                      const SizedBox(width: 6),
                      Text(_printing ? 'Impression…' : 'Imprimer',
                          style: TextStyle(color: _kNavy, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: _downloading ? null : _handleDownload,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kNavy,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(
                        color: _kNavy.withValues(alpha: 0.30),
                        blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_downloading)
                        const SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(_downloading ? 'Génération…' : 'Télécharger PDF',
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Dialog de suppression ────────────────────────────────────────────────────
