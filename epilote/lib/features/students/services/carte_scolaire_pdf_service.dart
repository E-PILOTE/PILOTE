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

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import 'carte_scolaire_dessin.dart';
import 'carte_scolaire_modele.dart';

// Le format, la règle de délivrance et le modèle restent visibles depuis ce
// fichier : c'est lui que les appelants importent, et le découpage interne ne
// doit pas leur coûter un import de plus.
export 'carte_scolaire_modele.dart';

class CarteScolairePdfService {
  /// Enregistre des octets déjà fabriqués là où l'agent choisit.
  ///
  /// Rend le chemin retenu, ou `null` si l'agent a renoncé — ce `null` n'est
  /// PAS une erreur, et l'appelant ne doit rien annoncer dans ce cas.
  ///
  /// ⚠️ On réécrit le fichier quand le sélecteur l'a créé vide. Certaines
  /// implémentations de `saveFile` ne posent que le chemin sans écrire les
  /// octets ; sans ce filet, l'école se retrouverait avec un PDF de 0 octet
  /// portant le bon nom — et ne s'en apercevrait qu'en l'ouvrant, souvent
  /// devant les familles.
  static Future<String?> enregistrer({
    required Uint8List octets,
    required String nomFichier,
    String titreDialogue = 'Enregistrer les cartes',
  }) async {
    final chemin = await FilePicker.platform.saveFile(
      dialogTitle: titreDialogue,
      fileName: nomFichier,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: octets,
    );
    if (chemin == null) return null;
    final f = File(chemin);
    if (!await f.exists() || await f.length() == 0) {
      await f.writeAsBytes(octets);
    }
    return chemin;
  }

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
        builder: (e) => carteRecto(e, f, logo, schoolName, yearLabel),
      ));

      if (avecVerso) {
        doc.addPage(_planche(
          lot: lot,
          verso: true,
          builder: (e) => carteVerso(e, f, schoolName, yearLabel, city),
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
        _cadre(carteRecto(eleve, f, logo, schoolName, yearLabel)),
        pw.SizedBox(width: 12),
        _cadre(carteVerso(eleve, f, schoolName, yearLabel, city)),
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
}
