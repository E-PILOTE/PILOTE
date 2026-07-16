import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';

import 'admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  APERÇU PDF PARTAGÉ — fenêtre in-app (widget `PdfPreview`) réutilisée par tous
//  les écrans : en-tête sobre (clair, accent fin), aperçu paginé, actions
//  Imprimer / Enregistrer. Évite la duplication et la boîte système directe.
// ════════════════════════════════════════════════════════════════════════════

typedef PdfBuilder = Future<Uint8List> Function(PdfPageFormat format);

Future<void> showPdfPreviewDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  required PdfBuilder build,
  required String pdfFileName,
  Future<String?> Function()? onDownload,
  // Résolu au corps, pas en défaut : une valeur par défaut doit être une
  // constante de compilation, or les jetons suivent désormais le thème.
  Color? accent,
}) {
  // Locale plutôt que `accent ??=` : une variable capturée par la closure du
  // builder n'est pas promue par Dart.
  final acc = accent ?? kNavy;
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _PdfPreviewDialog(
      title: title,
      subtitle: subtitle,
      builder: build,
      pdfFileName: pdfFileName,
      onDownload: onDownload,
      accent: acc,
    ),
  );
}

class _PdfPreviewDialog extends StatelessWidget {
  const _PdfPreviewDialog({
    required this.title,
    required this.subtitle,
    required this.builder,
    required this.pdfFileName,
    required this.onDownload,
    required this.accent,
  });
  final String title;
  final String? subtitle;
  final PdfBuilder builder;
  final String pdfFileName;
  final Future<String?> Function()? onDownload;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = (size.width * 0.72).clamp(420.0, 900.0);
    final h = (size.height * 0.9).clamp(420.0, 1180.0);
    return Dialog(
      backgroundColor: kCardBg,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: w,
        height: h,
        child: Column(children: [
          // En-tête sobre : pastille accent + titre, sur fond blanc.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            decoration: BoxDecoration(
              color: kCardBg,
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.picture_as_pdf_outlined,
                    size: 18, color: accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: kTextPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: kTextMuted, fontSize: 11.5)),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, color: kTextMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Aperçu paginé + actions.
          Expanded(
            child: PdfPreview(
              build: builder,
              useActions: true,
              allowPrinting: true,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: pdfFileName,
              previewPageMargin: const EdgeInsets.all(12),
              scrollViewDecoration: BoxDecoration(color: kSurface),
              pdfPreviewPageDecoration: BoxDecoration(
                color: kCardBg,
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
              ),
              loadingWidget: Center(
                child: CircularProgressIndicator(color: accent),
              ),
              actionBarTheme: PdfActionBarTheme(
                backgroundColor: Colors.white,
                iconColor: accent,
                elevation: 0,
              ),
              actions: [
                if (onDownload != null)
                  PdfPreviewAction(
                    icon: const Icon(Icons.download_rounded),
                    onPressed: (ctx, _, _) async {
                      final messenger = ScaffoldMessenger.of(ctx);
                      try {
                        final path = await onDownload!();
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
