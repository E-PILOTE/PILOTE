// ═════════════════════════════════════════════════════════════════════════════
//  LE DESSIN D'UNE CARTE — recto et verso, rien d'autre.
//
//  Aucune décision ici : ni qui a droit à une carte, ni comment les cartes se
//  rangent sur une planche. Seulement de l'encre. La séparation tient le
//  fichier sous la barre des 500 lignes du dépôt et, surtout, elle isole la
//  partie qu'on relit à l'œil de celles qu'on relit par un test.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../../core/utils/cadre_identite.dart';
import '../../../core/utils/ine.dart';
import 'carte_scolaire_modele.dart';

String _jour(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

// ── Recto ─────────────────────────────────────────────────────────────────

pw.Widget carteRecto(
  CarteEleve e,
  PdfFonts f,
  pw.ImageProvider? logo,
  String schoolName,
  String yearLabel,
) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _bandeauTricolore(),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _enTete(f, logo, schoolName, yearLabel),
                pw.SizedBox(height: 5),
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _photo(e, f),
                      pw.SizedBox(width: 7),
                      pw.Expanded(child: _identite(e, f)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _pied(f, yearLabel),
      ],
    );

pw.Widget _bandeauTricolore() => pw.Row(children: [
      pw.Expanded(child: pw.Container(height: 3, color: kPdfGreen)),
      pw.Expanded(child: pw.Container(height: 3, color: kPdfGold)),
      pw.Expanded(child: pw.Container(height: 3, color: kPdfRed)),
    ]);

pw.Widget _enTete(
        PdfFonts f, pw.ImageProvider? logo, String school, String year) =>
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      if (logo != null) ...[
        pw.SizedBox(width: 15, height: 15, child: pw.Image(logo)),
        pw.SizedBox(width: 5),
      ],
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('RÉPUBLIQUE DU CONGO',
                style: pw.TextStyle(
                    font: f.medium,
                    fontSize: 4.6,
                    color: kPdfMuted,
                    letterSpacing: 0.4)),
            pw.Text(school.toUpperCase(),
                maxLines: 2,
                style: pw.TextStyle(
                    font: f.bold, fontSize: 6.6, color: kPdfNavy)),
          ],
        ),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
        decoration: pw.BoxDecoration(
          color: kPdfNavy,
          borderRadius: pw.BorderRadius.circular(2.5),
        ),
        child: pw.Text('CARTE SCOLAIRE',
            style: pw.TextStyle(
                font: f.bold,
                fontSize: 5,
                color: PdfColors.white,
                letterSpacing: 0.5)),
      ),
    ]);

/// Le cadre photo. Vide, il ne reste pas muet : une carte sans visage
/// n'identifie personne, et celui qui la découpe doit le savoir avant de la
/// remettre à l'élève.
pw.Widget _photo(CarteEleve e, PdfFonts f) {
  // Proportions d'une photo d'identité — `kPhotoIdentiteLargeurMm/HauteurMm`,
  // les MÊMES constantes que le recadrage (`core/utils/cadre_identite.dart`) :
  // deux rapports qui divergent rogneraient la photo deux fois.
  //
  // Définition obtenue : les 256 px du plus long côté produits par
  // `compressAvatar` tombent sur les 28 mm de hauteur, soit **232 dpi**. C'est
  // en dessous des 300 dpi d'une impression idéale, et suffisant pour une carte
  // d'identification. Le chiffre de 295 dpi qui figurait ici supposait les
  // 256 px sur la LARGEUR (22 mm) — ce qui n'arrive jamais sur une photo
  // portrait.
  //
  // ⚠️ Ne pas relever `kMaxAvatarEdge` pour gagner ces dpi : 320 px donnerait
  // 290 dpi mais ~50 % d'octets en plus sur CHAQUE avatar, synchronisés vers
  // chaque poste de mille écoles. Le gain d'impression ne vaut pas ce transfert.
  // Le vrai levier est le cadrage à la prise de vue, qui ne coûte rien.
  const l = kPhotoIdentiteLargeurMm * PdfPageFormat.mm;
  const h = kPhotoIdentiteHauteurMm * PdfPageFormat.mm;
  final octets = e.photo;

  return pw.Container(
    width: l,
    height: h,
    decoration: pw.BoxDecoration(
      color: kPdfSurface,
      border: pw.Border.all(color: kPdfBorder, width: 0.5),
      borderRadius: pw.BorderRadius.circular(2),
    ),
    child: octets == null
        ? pw.Center(
            child: pw.Text('PHOTO\nMANQUANTE',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    font: f.medium,
                    fontSize: 4.8,
                    color: kPdfRed,
                    lineSpacing: 1.5)),
          )
        : pw.ClipRRect(
            horizontalRadius: 2,
            verticalRadius: 2,
            child: pw.Image(pw.MemoryImage(octets), fit: pw.BoxFit.cover),
          ),
  );
}

pw.Widget _identite(CarteEleve e, PdfFonts f) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(e.fullName,
            maxLines: 2,
            style:
                pw.TextStyle(font: f.bold, fontSize: 8.6, color: kPdfText)),
        pw.SizedBox(height: 4),
        _ligne(f, 'Classe', e.className),
        _ligne(f, 'Matricule', e.matricule),
        _ligne(f, '${e.ne} le', _jour(e.dateOfBirth)),
        if (e.placeOfBirth != null && e.placeOfBirth!.trim().isNotEmpty)
          _ligne(f, 'à', e.placeOfBirth!.trim()),
      ],
    );

pw.Widget _ligne(PdfFonts f, String label, String valeur) =>
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.2),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
          width: 34,
          child: pw.Text(label,
              style: pw.TextStyle(
                  font: f.regular, fontSize: 5.4, color: kPdfMuted)),
        ),
        pw.Expanded(
          child: pw.Text(valeur,
              maxLines: 1,
              style: pw.TextStyle(
                  font: f.medium, fontSize: 6.2, color: kPdfText)),
        ),
      ]),
    );

pw.Widget _pied(PdfFonts f, String yearLabel) => pw.Container(
      color: kPdfNavy,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Année scolaire $yearLabel',
              style: pw.TextStyle(
                  font: f.medium, fontSize: 5.2, color: PdfColors.white)),
          pw.Text('Unité · Travail · Progrès',
              style: pw.TextStyle(
                  font: f.regular,
                  fontSize: 4.8,
                  color: pdfTint(kPdfGold, 0.9))),
        ],
      ),
    );

// ── Verso ─────────────────────────────────────────────────────────────────

pw.Widget carteVerso(
  CarteEleve e,
  PdfFonts f,
  String schoolName,
  String yearLabel,
  String? city,
) =>
    pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(
              width: 46,
              height: 46,
              padding: const pw.EdgeInsets.all(1.5),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: kPdfBorder, width: 0.5),
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: e.codeQr,
                drawText: false,
                color: kPdfText,
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _ligne(
                    f,
                    'Identifiant',
                    e.ine == null || e.ine!.isEmpty
                        ? 'non attribué'
                        : formatIne(e.ine),
                  ),
                  if (e.bloodGroup != null && e.bloodGroup!.trim().isNotEmpty)
                    _ligne(f, 'Groupe sanguin', e.bloodGroup!.trim()),
                  if (e.isBoarder) _ligne(f, 'Régime', 'Interne'),
                ],
              ),
            ),
          ]),
          pw.SizedBox(height: 5),
          pw.Text(
            'Cette carte est personnelle. Elle est valable pour la seule '
            'année scolaire $yearLabel et doit être restituée à '
            "l'établissement en cas de départ.",
            style: pw.TextStyle(
                font: f.regular,
                fontSize: 4.9,
                color: kPdfMuted,
                lineSpacing: 1.2),
          ),
          pw.Spacer(),
          pw.Text(
            'En cas de perte, la rapporter à : $schoolName'
            '${city == null || city.isEmpty ? '' : ' — $city'}.',
            maxLines: 2,
            style: pw.TextStyle(
                font: f.regular, fontSize: 4.9, color: kPdfMuted),
          ),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(height: 0.5, width: 62, color: kPdfBorder),
                  pw.SizedBox(height: 1.5),
                  pw.Text('Le Chef d’établissement',
                      style: pw.TextStyle(
                          font: f.regular, fontSize: 4.6, color: kPdfMuted)),
                ],
              ),
            ),
            _bandeauTricoloreCourt(),
          ]),
        ],
      ),
    );

pw.Widget _bandeauTricoloreCourt() => pw.Row(children: [
      pw.Container(width: 10, height: 3, color: kPdfGreen),
      pw.Container(width: 10, height: 3, color: kPdfGold),
      pw.Container(width: 10, height: 3, color: kPdfRed),
    ]);
