// ══════════════════════════════════════════════════════════════════════════════
//  LA CHARPENTE COMMUNE DES ATTESTATIONS
//
//  Un certificat de scolarité, un certificat de radiation et une attestation de
//  travail sont trois papiers différents, mais UN SEUL objet administratif :
//  une autorité y certifie un fait, en foi de quoi elle signe. Ce qui change,
//  c'est le fait ; ce qui ne doit jamais changer, c'est la forme — l'en-tête,
//  la formule, l'emplacement de la signature et du cachet.
//
//  D'où ce fichier. Deux charpentes divergeraient, et le jour où le ministère
//  refuserait un papier pour un défaut de forme, personne ne saurait lequel des
//  deux modèles corriger.
//
//  ⚠️ PAGE UNIQUE, jamais `MultiPage`. Une attestation qui déborde perd sa
//  valeur : la signature doit se trouver sous le texte qu'elle authentifie.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'official_pdf_kit.dart';

class AttestationKit {
  static final jourLong = DateFormat('dd MMMM yyyy', 'fr');
  static final jourCourt = DateFormat('dd/MM/yyyy', 'fr');

  /// Assemble le document : en-tête officiel, cartouche de titre, corps, puis
  /// le bloc de signature poussé en bas de page.
  static Future<Uint8List> build({
    required String titre,
    required String kicker,
    required String badge,
    required String emetteur,
    required String sousTitre,
    required PdfFonts fonts,
    required pw.MemoryImage? logo,
    required List<pw.Widget> corps,
    required DateTime quand,
    String? city,
    String? signataire,
    String? fonction,
  }) async {
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(quand);
    final ref = DateFormat('yyyyMMdd-HHmmss').format(quand);

    final doc = pw.Document(
      title: titre,
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: emetteur,
    );

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          OfficialPdfKit.header(logo, fonts, badge: badge),
          pw.SizedBox(height: 18),
          OfficialPdfKit.titleBlock(fonts,
              kicker: kicker, title: titre, line1: emetteur, line2: sousTitre),
          pw.SizedBox(height: 24),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: corps),
          ),
          pw.Spacer(),
          signature(fonts, city, quand, signataire, fonction),
          pw.SizedBox(height: 14),
          OfficialPdfKit.footer(ctx, fonts, now, ref),
        ],
      ),
    ));
    return doc.save();
  }

  /// « Je soussigné(e), X, fonction, de ÉTABLISSEMENT, certifie »
  static pw.Widget formuleSoussigne(
      PdfFonts f, String? signataire, String? fonction, String emetteur) {
    final qui = (signataire == null || signataire.trim().isEmpty)
        ? 'Je soussigné(e)'
        : 'Je soussigné(e), ${signataire.trim()}';
    final quoi = (fonction == null || fonction.trim().isEmpty)
        ? ', chef d’établissement,'
        : ', ${fonction.trim()},';
    return paragraphe(f, [texte(f, '$qui$quoi de $emetteur, certifie ')]);
  }

  static pw.Widget formuleFinale(PdfFonts f) => paragraphe(f, [
        texte(
            f,
            'En foi de quoi, la présente attestation est délivrée pour servir '
            'et valoir ce que de droit.'),
      ]);

  /// Le bloc de signature — et l'espace qu'il réserve à la main et au cachet.
  /// Sans cet espace, le document n'a aucune valeur au guichet.
  static pw.Widget signature(PdfFonts f, String? city, DateTime quand,
      String? signataire, String? fonction) {
    // Sans ville, « Fait à  le 11 août 2026 » : un « à » suspendu et une double
    // espace, en bas d'un document officiel. La formule sans lieu est « Fait
    // le … », pas « Fait à le … ». Le cas se produit dès qu'un document est
    // édité au niveau du groupe, qui n'a pas de commune.
    final ville = city?.trim() ?? '';
    final faitLe = ville.isEmpty
        ? 'Fait le ${jourLong.format(quand)}'
        : 'Fait à $ville, le ${jourLong.format(quand)}';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Row(children: [
        pw.Spacer(),
        pw.SizedBox(
          width: 210,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(faitLe,
                  style: pw.TextStyle(
                      font: f.regular, fontSize: 10, color: kPdfText)),
              pw.SizedBox(height: 6),
              pw.Text(
                  fonction?.trim().isNotEmpty ?? false
                      ? fonction!.trim()
                      : 'Le chef d’établissement',
                  style: pw.TextStyle(
                      font: f.medium, fontSize: 10, color: kPdfNavy)),
              pw.SizedBox(height: 54),
              pw.Container(height: 0.8, width: 170, color: kPdfBorder),
              pw.SizedBox(height: 4),
              pw.Text(
                  signataire?.trim().isNotEmpty ?? false
                      ? signataire!.trim()
                      : 'Signature et cachet',
                  style: pw.TextStyle(
                      font: f.regular, fontSize: 8.5, color: kPdfMuted)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Assemblages de texte ───────────────────────────────────────────────────
  static pw.Widget paragraphe(PdfFonts f, List<pw.InlineSpan> spans) =>
      pw.RichText(
        text: pw.TextSpan(
          style: pw.TextStyle(
              font: f.regular, fontSize: 11, color: kPdfText, lineSpacing: 4),
          children: spans,
        ),
      );

  static pw.InlineSpan texte(PdfFonts f, String s) =>
      pw.TextSpan(text: s, style: pw.TextStyle(font: f.regular));

  static pw.InlineSpan fort(PdfFonts f, String s) =>
      pw.TextSpan(text: s, style: pw.TextStyle(font: f.bold));
}
