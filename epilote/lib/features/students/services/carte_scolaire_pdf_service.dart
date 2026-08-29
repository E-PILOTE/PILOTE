// ══════════════════════════════════════════════════════════════════════════════
//  LA CARTE SCOLAIRE — le seul papier que l'élève porte sur lui
//
//  ── CE QU'ELLE EST, ET CE QU'ELLE N'EST PAS ────────────────────────────────
//  Les attestations (`attestations_pdf_service.dart`) sont des papiers de
//  GUICHET : on les délivre à la demande, pour une bourse, un visa, une
//  inscription ailleurs. La carte, elle, est produite EN MASSE à la rentrée,
//  une fois pour toute une classe, et c'est l'élève qui la garde — au portail,
//  dans le bus, à l'examen. Ce n'est pas une variante d'attestation : c'est
//  l'autre moitié du métier, et elle manquait entièrement.
//
//  ── FORMAT ISO/CEI 7810 ID-1 (85,6 × 54 mm) ────────────────────────────────
//  Le format d'une carte bancaire. Ce n'est pas une coquetterie : c'est ce qui
//  entre dans un portefeuille, ce que les pochettes plastique du marché
//  acceptent, et ce que toute imprimante à badges attend. Une carte au format
//  « à peu près » se corne dans une poche en une semaine.
//
//  Dix cartes par A4 (2 colonnes × 5 rangées), avec des REPÈRES DE COUPE : une
//  école qui n'a pas d'imprimante à badges découpe aux ciseaux, et c'est le cas
//  de la quasi-totalité du parc.
//
//  ── LE VERSO EST MIROITÉ, ET C'EST TOUT LE SUJET ───────────────────────────
//  En recto-verso, la feuille se retourne sur son bord long : la colonne de
//  GAUCHE au recto revient à DROITE au verso. Une planche verso dans le même
//  ordre que le recto donne cent cartes dont le dos appartient à quelqu'un
//  d'autre — un défaut qu'on ne voit qu'après avoir découpé, c'est-à-dire trop
//  tard. [_planche] inverse donc l'ordre des colonnes au verso.
//
//  ── LE REFUS EST ICI AUSSI LA PARTIE UTILE ─────────────────────────────────
//  [peutDelivrerCarte] n'accepte que l'inscription `active`. Une carte scolaire
//  pour un élève radié est un laissez-passer : elle ouvre un portail, elle
//  obtient un tarif, elle atteste d'une qualité perdue. Comme le certificat de
//  scolarité, elle ne se délivre qu'à qui est présent.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../../core/utils/ine.dart';

/// Dimensions ISO/CEI 7810 ID-1, en points PDF.
const double kCarteLargeur = 85.6 * PdfPageFormat.mm;
const double kCarteHauteur = 54.0 * PdfPageFormat.mm;

/// Disposition de la planche A4.
const int kCartesParRangee = 2;
const int kRangeesParPlanche = 5;
const int kCartesParPlanche = kCartesParRangee * kRangeesParPlanche; // 10

/// Marges et gouttières de la planche. Publiques parce que c'est ce que le
/// garde de format vérifie : cinq rangées de 54 mm laissent 27 mm pour tout le
/// reste sur une A4, et la contrainte se serre par le haut.
const double kMargePlancheH = 14 * PdfPageFormat.mm;
const double kMargePlancheV = 8 * PdfPageFormat.mm;
const double kGouttiereColonne = 6 * PdfPageFormat.mm;
const double kGouttiereRangee = 2 * PdfPageFormat.mm;

/// Statuts d'inscription pour lesquels une carte scolaire est vraie.
///
/// Le même verrou que `peutDelivrerScolarite`, et pour la même raison : la
/// carte affirme une qualité présente. La délivrer à qui est parti fabrique un
/// titre valide au nom d'une école qui ne le reconnaît plus.
bool peutDelivrerCarte(String? enrollmentStatus) => enrollmentStatus == 'active';

/// L'élève tel qu'il apparaît sur sa carte.
class CarteEleve {
  const CarteEleve({
    required this.firstName,
    required this.lastName,
    required this.className,
    required this.matricule,
    this.ine,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
    this.bloodGroup,
    this.isBoarder = false,
    this.photo,
  });

  final String firstName, lastName, className, matricule;
  final String? ine, gender, placeOfBirth, bloodGroup;
  final DateTime? dateOfBirth;
  final bool isBoarder;

  /// Octets de la photo, déjà décodés. `null` = aucune photo disponible sur ce
  /// poste ; la carte s'imprime alors avec un cadre vide et le dit.
  final Uint8List? photo;

  String get fullName => '${lastName.toUpperCase()} $firstName'.trim();
  String get ne => gender == 'F' ? 'Née' : 'Né';

  /// Ce que porte le QR : l'identifiant national s'il existe, le matricule
  /// sinon. Jamais rien d'autre — un QR n'est pas un dossier scolaire, et cette
  /// carte va vivre dans la poche d'un enfant.
  String get codeQr => (ine != null && ine!.isNotEmpty) ? ine! : matricule;
}

/// Découpe un lot en rangées de [kCartesParRangee], et INVERSE l'ordre des
/// colonnes au verso.
///
/// ── POURQUOI CETTE FONCTION EST À PART, ET PUBLIQUE ──────────────────────────
/// C'est le seul endroit du module où une erreur ne se voit pas à l'écran. Une
/// planche verso dans le même ordre que le recto donne des cartes dont le dos
/// appartient au voisin — et on ne s'en aperçoit qu'après avoir découpé.
/// Un aperçu PDF ne le révèle pas non plus : les deux pages semblent correctes
/// séparément. Seule la feuille retournée le montre. Elle est donc isolée pour
/// être testée pour ce qu'elle est : une permutation.
///
/// La feuille se retourne sur son bord LONG : la colonne de gauche au recto
/// revient à droite au verso. Les cases manquantes de la dernière rangée sont
/// `null` — et au verso elles passent à gauche, ce qui est exactement ce qu'il
/// faut : elles sont en face du vide du recto.
List<List<CarteEleve?>> rangeesPlanche(
  List<CarteEleve> lot, {
  required bool verso,
}) {
  final rangees = <List<CarteEleve?>>[];
  for (var i = 0; i < lot.length; i += kCartesParRangee) {
    final r = <CarteEleve?>[
      for (var k = 0; k < kCartesParRangee; k++)
        i + k < lot.length ? lot[i + k] : null,
    ];
    rangees.add(verso ? r.reversed.toList() : r);
  }
  return rangees;
}

String _jour(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

class CarteScolairePdfService {
  /// Une planche A4 de cartes, recto puis verso (verso miroité pour le
  /// recto-verso). Rendue vide si [eleves] est vide.
  static Future<Uint8List> planche({
    required List<CarteEleve> eleves,
    required String schoolName,
    required String yearLabel,
    String? city,
    bool avecVerso = true,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final doc = pw.Document();

    for (var i = 0; i < eleves.length; i += kCartesParPlanche) {
      final lot = eleves.sublist(
          i, (i + kCartesParPlanche).clamp(0, eleves.length));

      doc.addPage(_planche(
        lot: lot,
        verso: false,
        builder: (e) => _recto(e, f, logo, schoolName, yearLabel),
      ));

      if (avecVerso) {
        doc.addPage(_planche(
          lot: lot,
          verso: true,
          builder: (e) => _verso(e, f, schoolName, yearLabel, city),
        ));
      }
    }

    return doc.save();
  }

  /// Une carte seule, recto et verso côte à côte sur une page à sa mesure —
  /// pour le guichet, quand un élève perd la sienne en cours d'année.
  static Future<Uint8List> carteUnique({
    required CarteEleve eleve,
    required String schoolName,
    required String yearLabel,
    String? city,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final doc = pw.Document();

    doc.addPage(pw.Page(
      pageFormat: const PdfPageFormat(
        kCarteLargeur * 2 + 24,
        kCarteHauteur + 24,
        marginAll: 12,
      ),
      build: (_) => pw.Row(children: [
        _cadre(_recto(eleve, f, logo, schoolName, yearLabel)),
        pw.SizedBox(width: 12),
        _cadre(_verso(eleve, f, schoolName, yearLabel, city)),
      ]),
    ));

    return doc.save();
  }

  // ── La planche ────────────────────────────────────────────────────────────

  static pw.Page _planche({
    required List<CarteEleve> lot,
    required bool verso,
    required pw.Widget Function(CarteEleve) builder,
  }) {
    final rangees = rangeesPlanche(lot, verso: verso);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      // ── LA HAUTEUR EST LE POINT SERRÉ, PAS LA LARGEUR ────────────────────
      // Cinq cartes de 54 mm font déjà 270 mm sur les 297 d'une A4 : il ne
      // reste que 27 mm pour DEUX marges et QUATRE gouttières. D'où 8 mm de
      // marge et 2 mm entre rangées (16 + 8 + 270 = 294 mm), qui laissent
      // 3 mm de battement à la dérive d'entraînement du papier.
      //
      // La première version prenait 12 mm de marge et 3 mm de gouttière après
      // CHAQUE rangée, dernière comprise : 807 pt de contenu pour 774 pt de
      // page. La cinquième rangée se serait imprimée hors du papier — un
      // défaut que l'aperçu à l'écran montre sans le signaler, et qui coûte
      // une rame avant qu'on le comprenne. Le garde est
      // `test/carte_scolaire_test.dart`.
      margin: const pw.EdgeInsets.symmetric(
        horizontal: kMargePlancheH,
        vertical: kMargePlancheV,
      ),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          for (var r = 0; r < rangees.length; r++) ...[
            if (r > 0) pw.SizedBox(height: kGouttiereRangee),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                for (var k = 0; k < rangees[r].length; k++) ...[
                  if (k > 0) pw.SizedBox(width: kGouttiereColonne),
                  rangees[r][k] == null
                      ? pw.SizedBox(
                          width: kCarteLargeur, height: kCarteHauteur)
                      : _cadre(builder(rangees[r][k]!)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Le trait de coupe : un liseré fin tout autour de la carte. Une école sans
  /// imprimante à badges découpe dessus.
  static pw.Widget _cadre(pw.Widget carte) => pw.Container(
        width: kCarteLargeur,
        height: kCarteHauteur,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: kPdfBorder, width: 0.4),
          borderRadius: pw.BorderRadius.circular(3 * PdfPageFormat.mm),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 3 * PdfPageFormat.mm,
          verticalRadius: 3 * PdfPageFormat.mm,
          child: carte,
        ),
      );

  // ── Recto ─────────────────────────────────────────────────────────────────

  static pw.Widget _recto(
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

  static pw.Widget _bandeauTricolore() => pw.Row(children: [
        pw.Expanded(child: pw.Container(height: 3, color: kPdfGreen)),
        pw.Expanded(child: pw.Container(height: 3, color: kPdfGold)),
        pw.Expanded(child: pw.Container(height: 3, color: kPdfRed)),
      ]);

  static pw.Widget _enTete(
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
  static pw.Widget _photo(CarteEleve e, PdfFonts f) {
    // Proportions d'une photo d'identité (22 × 28 mm). À cette taille, les
    // 256 px du côté long produits par `compressAvatar` valent environ 295 dpi
    // — la limite basse de ce qu'une impression rend proprement, et la raison
    // pour laquelle il ne faut pas descendre la compression des avatars.
    const l = 22.0 * PdfPageFormat.mm;
    const h = 28.0 * PdfPageFormat.mm;
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

  static pw.Widget _identite(CarteEleve e, PdfFonts f) => pw.Column(
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

  static pw.Widget _ligne(PdfFonts f, String label, String valeur) =>
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

  static pw.Widget _pied(PdfFonts f, String yearLabel) => pw.Container(
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

  static pw.Widget _verso(
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

  static pw.Widget _bandeauTricoloreCourt() => pw.Row(children: [
        pw.Container(width: 10, height: 3, color: kPdfGreen),
        pw.Container(width: 10, height: 3, color: kPdfGold),
        pw.Container(width: 10, height: 3, color: kPdfRed),
      ]);
}
