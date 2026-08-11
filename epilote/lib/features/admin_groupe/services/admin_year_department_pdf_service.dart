import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/attestation_kit.dart';
import '../../../core/services/official_pdf_kit.dart';
import '../providers/admin_academic_year_provider.dart';
import '../providers/admin_year_analytics_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  FICHE DÉPARTEMENTALE DE PRÉPARATION D'UNE ANNÉE.
//
//  L'extrait qu'on détache du bilan national pour l'envoyer à UNE direction
//  départementale. Le bilan complet lui montrerait mille établissements dont
//  neuf cent quarante ne la concernent pas ; ici, son périmètre entier, et la
//  part qu'il représente dans le groupe — sans quoi « 4 300 élèves » ne se
//  compare à rien.
//
//  Paginé DÈS L'ORIGINE. Un département congolais peut compter plus de cent
//  établissements, et un cadre plus haut qu'une feuille fait boucler
//  `MultiPage` jusqu'à `TooManyPagesException` : le document ne sort alors pas
//  du tout. Le seuil mesuré sur l'ancienne structure était de 35 lignes.
// ══════════════════════════════════════════════════════════════════════════════

const _kPurple = PdfColor.fromInt(0xFF7C3AED);

class YearDepartmentPdfService {
  /// Qualité du signataire — neutre : l'émetteur peut être un ministère comme
  /// un réseau privé. Cf. `AcademicYearPdfService`.
  static const _kFonction = 'Le responsable du groupe scolaire';

  static Future<Uint8List> buildPdf({
    required AdminYear year,
    required YearDepartmentDetail detail,
    String? signataire,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();

    final fmtDateL = DateFormat('dd MMMM yyyy', 'fr');
    final maintenant = DateTime.now();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(maintenant);
    final ref = DateFormat('yyyyMMdd-HHmm').format(maintenant);
    final titre = '${detail.department} — préparation ${year.label}';

    final doc = pw.Document(
      title: titre,
      author: OfficialPdfKit.issuer?.name ?? 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: "Préparation de l'année scolaire par département",
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'FICHE\nDÉPARTEMENTALE', title: titre),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: "PRÉPARATION DE L'ANNÉE SCOLAIRE",
            title: detail.department,
            line1: 'Année ${year.label} — du ${fmtDateL.format(year.startDate)} '
                'au ${fmtDateL.format(year.endDate)}',
            line2: 'Extrait départemental du bilan du groupe  •  '
                'Édité le ${fmtDateL.format(maintenant)}',
            statusBadge: _badge(detail)),
        pw.SizedBox(height: 16),
        _kpis(detail, f),
        pw.SizedBox(height: 18),
        _part(detail, f),
        pw.SizedBox(height: 14),
        ..._etablissements(detail, f),
        pw.SizedBox(height: 26),
        AttestationKit.signature(f, null, maintenant, signataire, _kFonction),
        pw.SizedBox(height: 20),
      ],
    ));

    return doc.save();
  }

  /// Ce qu'il faut lire en premier : le département a-t-il fini, ou non.
  static String _badge(YearDepartmentDetail d) {
    if (d.ecolesTotal == 0) return 'Aucun établissement';
    if (d.ecolesEnAttente == 0) return 'Département prêt';
    return '${d.ecolesEnAttente} en attente';
  }

  static pw.Widget _kpis(YearDepartmentDetail d, PdfFonts f) =>
      OfficialPdfKit.kpiGrid(
        f,
        [
          PdfKpi('Établissements', '${d.ecolesTotal}', kPdfNavy),
          PdfKpi('Préparés', '${d.ecolesPreparees}/${d.ecolesTotal}',
              d.ecolesEnAttente == 0 ? kPdfGreen : kPdfGold),
          PdfKpi('Taux de préparation',
              '${(d.tauxPreparation * 100).round()} %', _kPurple),
          PdfKpi('Classes ouvertes', '${d.classes}', kPdfNavy),
          PdfKpi('Élèves inscrits', '${d.eleves}', kPdfGreen),
          PdfKpi('Moy. élèves / classe',
              d.moyenneElevesParClasse.toStringAsFixed(1), kPdfGold),
        ],
        width: 173,
      );

  // ── La part du département dans le groupe ───────────────────────────────────
  //  Trois lignes fixes : un chiffre départemental isolé ne se compare à rien.
  static pw.Widget _part(YearDepartmentDetail d, PdfFonts f) =>
      OfficialPdfKit.frame(
        title: 'PART DANS LE GROUPE',
        color: kPdfNavy,
        fonts: f,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            OfficialPdfKit.statLine(f, 'Élèves',
                '${d.eleves} sur ${d.groupeEleves}  '
                '(${(d.partEleves * 100).toStringAsFixed(1)} %)',
                color: kPdfGreen),
            OfficialPdfKit.statLine(f, 'Classes',
                '${d.classes} sur ${d.groupeClasses}  '
                '(${(d.partClasses * 100).toStringAsFixed(1)} %)',
                color: kPdfNavy),
            OfficialPdfKit.statLine(f, 'Établissements',
                '${d.ecolesTotal} sur ${d.groupeEcoles}  '
                '(${(d.partEcoles * 100).toStringAsFixed(1)} %)',
                color: _kPurple),
          ],
        ),
      );

  // ── Les établissements du département ───────────────────────────────────────
  //  Rang par effectif décroissant : c'est l'ordre dans lequel une direction
  //  départementale lit sa carte scolaire. Rang de compétition — deux écoles à
  //  effectif égal partagent le leur.
  static List<pw.Widget> _etablissements(
          YearDepartmentDetail d, PdfFonts f) =>
      OfficialPdfKit.tableSection(
        title: 'ÉTABLISSEMENTS DU DÉPARTEMENT (${d.ecolesTotal})',
        color: _kPurple,
        fonts: f,
        headers: const [
          'Établissement',
          'Rang',
          'Type',
          'Classes',
          'Élèves',
          'État',
        ],
        flex: const [9, 2, 3, 2, 2, 3],
        rows: d.ecoles
            .map((s) => [
                  s.name,
                  '${d.rangDe(s.id) ?? '—'}',
                  _type(s.type),
                  '${s.classes}',
                  '${s.eleves}',
                  s.adopted ? 'Préparée' : 'En attente',
                ])
            .toList(),
        emptyLabel: 'Aucun établissement rattaché à ce département.',
        perBlock: OfficialPdfKit.kTallRowsPerBlock,
        maxLines: 2,
        rowHeight: OfficialPdfKit.kTallRowHeight,
      );

  static String _type(String t) => switch (t) {
        'public' => 'Public',
        'prive' => 'Privé',
        _ => t.isEmpty ? 'Autre' : t,
      };

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  // ── Enregistrement ─────────────────────────────────────────────────────────
  //  Pas de `printReport` : cf. `regional_pdf_service.dart`. L'impression passe
  //  par l'aperçu partagé, qui montre le document avant de l'envoyer.
  static Future<String?> downloadReport({
    required AdminYear year,
    required YearDepartmentDetail detail,
    Uint8List? bytes,
  }) async {
    // `bytes` : enregistrer LE document que l'aperçu vient de montrer — même
    // heure d'édition, même numéro de référence.
    final octets = bytes ?? await buildPdf(year: year, detail: detail);
    final fileName = '${_slug(detail.department)}_${_slug(year.label)}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer la fiche départementale',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: octets,
    );
    if (savePath != null) {
      // Sous Windows, `file_picker` IGNORE `bytes` : il ne rend qu'un chemin.
      final file = File(savePath);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(octets);
      }
    }
    return savePath;
  }
}
