import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../students/widgets/scope_drilldown_panel.dart' show scopeCycleName;
import '../../user/widgets/staff_account_widgets.dart' show staffRoleLabel;
import '../providers/staff_directory_provider.dart';
import '../providers/staff_dossier_provider.dart' show employmentStatusLabel;

// ══════════════════════════════════════════════════════════════════════════════
//  Export ANNUAIRE DU PERSONNEL — PDF officiel (tableau agents : nom, rôle,
//  catégorie, statut, cycle, matricule, contact) + export CSV brut.
// ══════════════════════════════════════════════════════════════════════════════
class PersonnelExportService {
  static Future<Uint8List> buildPdf({
    required List<StaffMember> agents,
    String? schoolName,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final actifs = agents.where((a) => a.isActive).length;
    final enseignants =
        agents.where((a) => a.role == 'enseignant').length;

    final doc = pw.Document(
      title: 'Annuaire du personnel',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Répertoire du personnel',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.header(logo, f, badge: 'ANNUAIRE\nPERSONNEL'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'RÉPERTOIRE DU PERSONNEL',
            title: (schoolName?.trim().isNotEmpty ?? false)
                ? schoolName!.trim()
                : 'Annuaire du personnel',
            line1: '${agents.length} agent${agents.length > 1 ? 's' : ''} '
                '— $actifs actif${actifs > 1 ? 's' : ''}',
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Effectif', '${agents.length}', kPdfNavy),
          PdfKpi('Actifs', '$actifs', kPdfGreen),
          PdfKpi('Enseignants', '$enseignants',
              const PdfColor.fromInt(0xFF0EA5E9)),
          PdfKpi('Inactifs', '${agents.length - actifs}',
              agents.length - actifs > 0 ? kPdfRed : kPdfMuted),
        ], width: 130),
        pw.SizedBox(height: 16),
        if (agents.isEmpty)
          OfficialPdfKit.empty('Aucun agent à exporter.', f.regular)
        else
          OfficialPdfKit.frame(
            title: 'PERSONNEL',
            color: kPdfNavy,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const [
                'Nom', 'Fonction', 'Statut', 'Cycle', 'Matricule', 'Téléphone'
              ],
              rows: [
                for (final a in agents)
                  [
                    a.lastFirst,
                    staffRoleLabel(a.role),
                    (a.employmentStatus ?? '').isEmpty
                        ? '—'
                        : employmentStatusLabel(a.employmentStatus),
                    (a.teachingCycle ?? '').isEmpty
                        ? '—'
                        : scopeCycleName(a.teachingCycle),
                    a.employeeNumber ?? '—',
                    a.phone ?? '—',
                  ],
              ],
              fonts: f,
              flex: const [5, 4, 3, 3, 3, 3],
              leftAlignCols: const {0, 1},
            ),
          ),
        pw.SizedBox(height: 8),
      ],
    ));
    return doc.save();
  }

  static Future<String?> downloadPdf({
    required List<StaffMember> agents,
    String? schoolName,
  }) async {
    final bytes = await buildPdf(agents: agents, schoolName: schoolName);
    return _save(bytes, 'Annuaire_personnel_'
        '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf', ['pdf']);
  }

  // ─── Export CSV ──────────────────────────────────────────────────────────────
  static String _csvCell(String? v) {
    final s = (v ?? '').replaceAll('"', '""');
    return '"$s"';
  }

  static Future<String?> downloadCsv({required List<StaffMember> agents}) async {
    final b = StringBuffer();
    b.writeln('Nom,Prénom,Fonction,Statut,Cycle enseigné,Matricule,'
        'Téléphone,Actif');
    for (final a in agents) {
      b.writeln([
        _csvCell(a.lastName),
        _csvCell(a.firstName),
        _csvCell(staffRoleLabel(a.role)),
        _csvCell((a.employmentStatus ?? '').isEmpty
            ? ''
            : employmentStatusLabel(a.employmentStatus)),
        _csvCell((a.teachingCycle ?? '').isEmpty
            ? ''
            : scopeCycleName(a.teachingCycle)),
        _csvCell(a.employeeNumber),
        _csvCell(a.phone),
        _csvCell(a.isActive ? 'Oui' : 'Non'),
      ].join(','));
    }
    // BOM UTF-8 : cet annuaire part vers un tableur, et les patronymes
    // congolais sont accentués. Il manquait la marque ET l'encodage.
    final bytes = Uint8List.fromList(
      [0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())],
    );
    return _save(bytes, 'Annuaire_personnel_'
        '${DateFormat('yyyyMMdd').format(DateTime.now())}.csv', ['csv']);
  }

  static Future<String?> _save(
      Uint8List bytes, String fileName, List<String> exts) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: exts,
      bytes: bytes,
    );
    if (savePath != null) {
      final file = File(savePath);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(bytes);
      }
    }
    return savePath;
  }
}
