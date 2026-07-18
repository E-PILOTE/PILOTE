import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../models/stage_detail.dart';
import '../providers/stages_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  STAGES — les documents officiels : ATTESTATION, CONVENTION, LISTE, CSV.
//
//  L'attestation de fin de stage n'est pas un confort : c'est une PIÈCE du
//  dossier du baccalauréat technique/professionnel (note METP). Elle doit donc
//  s'imprimer avec l'en-tête officiel (République du Congo + emblème), être
//  datée et traçable. La convention encadre le stage (école–entreprise–élève).
// ══════════════════════════════════════════════════════════════════════════════
class StageExportService {
  static String _d(DateTime? d) =>
      d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
  static String _dLong(DateTime? d) =>
      d == null ? '—' : DateFormat('dd MMMM yyyy', 'fr').format(d);

  static String _statusLabel(String s) => switch (s) {
        'en_cours' => 'En cours',
        'termine' => 'Terminé',
        'valide' => 'Validé',
        'interrompu' => 'Interrompu',
        _ => 'Prévu',
      };

  // ── Paragraphe justifié réutilisable ──────────────────────────────────────
  static pw.Widget _para(String text, pw.Font font, {double size = 11}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(text,
            textAlign: pw.TextAlign.justify,
            style: pw.TextStyle(font: font, fontSize: size, lineSpacing: 2.5)),
      );

  static pw.Widget _signatureBlock(PdfFonts f, String left, String right) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 26),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [left, right].map((label) {
            return pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(label,
                      style: pw.TextStyle(
                          font: f.bold, fontSize: 10.5, color: kPdfNavy)),
                  pw.SizedBox(height: 44),
                  pw.Container(width: 150, height: 0.8, color: PdfColors.grey500),
                  pw.SizedBox(height: 3),
                  pw.Text('Nom, signature et cachet',
                      style: pw.TextStyle(
                          font: f.regular,
                          fontSize: 8.5,
                          color: PdfColors.grey600)),
                ],
              ),
            );
          }).toList(),
        ),
      );

  // ════════════════════════════════════════════════════════════════════════
  //  ATTESTATION DE FIN DE STAGE
  // ════════════════════════════════════════════════════════════════════════
  static Future<Uint8List> buildAttestationPdf({
    required StageDetail s,
    required String? schoolName,
    String? cityHint,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = 'ATT-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
    final issued = s.attestationIssuedAt ?? DateTime.now();
    final city = cityHint ?? s.companyCity ?? 'Brazzaville';
    final school = (schoolName?.trim().isNotEmpty ?? false)
        ? schoolName!.trim()
        : 'L\'établissement';

    final naissance = s.dateOfBirth != null
        ? ', né(e) le ${_dLong(s.dateOfBirth)}'
        : '';
    final filiere =
        s.filiereLabel != null ? ' (filière ${s.filiereLabel})' : '';
    final tutor = s.companyTutorName != null
        ? ', sous la responsabilité de ${s.companyTutorName}'
        : '';
    final place = s.companyPlace != null ? ' sis à ${s.companyPlace}' : '';
    final note = s.evaluationGrade != null
        ? 'Ce stage a été sanctionné par la note de '
            '${s.evaluationGrade!.toStringAsFixed(2)}/20. '
        : '';

    final doc = pw.Document(
      title: 'Attestation de stage — ${s.studentName}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Attestation de fin de stage',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          OfficialPdfKit.header(logo, f, badge: 'ATTESTATION\nDE STAGE'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'STAGE EN ENTREPRISE',
            title: school,
            line1: 'Attestation de fin de stage',
            line2: 'Éditée le ${_dLong(DateTime.now())}'),
        pw.SizedBox(height: 22),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('ATTESTATION DE FIN DE STAGE',
                    style: pw.TextStyle(
                        font: f.bold, fontSize: 15, color: kPdfNavy)),
              ),
              pw.SizedBox(height: 22),
              _para(
                'Je soussigné(e), responsable de $school, atteste que '
                'l\'élève ${s.studentName}$naissance'
                '${s.matricule != null ? ' (matricule ${s.matricule})' : ''}, '
                'inscrit(e) en classe de ${s.className ?? '—'}$filiere, a '
                'effectué un stage de formation en entreprise au sein de '
                '${s.companyName ?? 'l\'entreprise d\'accueil'}$place, '
                'du ${_dLong(s.startDate)} au ${_dLong(s.endDate)}$tutor.',
                f.regular,
              ),
              if (s.title != null)
                _para('Objet du stage : ${s.title}.', f.regular),
              if (note.isNotEmpty) _para(note, f.regular),
              if (s.evaluationComment != null)
                _para('Appréciation : ${s.evaluationComment}.', f.regular),
              _para(
                'En foi de quoi la présente attestation lui est délivrée pour '
                'servir et valoir ce que de droit.',
                f.regular,
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Fait à $city, le ${_dLong(issued)}',
                    style: pw.TextStyle(
                        font: f.medium, fontSize: 11, color: kPdfNavy)),
              ),
              _signatureBlock(
                  f, 'Le tuteur en entreprise', 'Le chef d\'établissement'),
            ],
          ),
        ),
      ],
    ));
    return doc.save();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CONVENTION DE STAGE
  // ════════════════════════════════════════════════════════════════════════
  static Future<Uint8List> buildConventionPdf({
    required StageDetail s,
    required String? schoolName,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = 'CONV-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
    final school = (schoolName?.trim().isNotEmpty ?? false)
        ? schoolName!.trim()
        : 'L\'établissement';

    pw.Widget partie(String titre, List<String> lignes) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(titre,
                  style: pw.TextStyle(
                      font: f.bold, fontSize: 10.5, color: kPdfNavy)),
              pw.SizedBox(height: 3),
              for (final l in lignes)
                pw.Text(l,
                    style: pw.TextStyle(
                        font: f.regular, fontSize: 10.5, lineSpacing: 2)),
            ],
          ),
        );

    final doc = pw.Document(
      title: 'Convention de stage — ${s.studentName}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Convention de stage en entreprise',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          OfficialPdfKit.header(logo, f, badge: 'CONVENTION\nDE STAGE'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'STAGE EN ENTREPRISE',
            title: school,
            line1: 'Convention de stage',
            line2: 'Éditée le ${_dLong(DateTime.now())}'),
        pw.SizedBox(height: 20),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _para(
                'Entre les parties désignées ci-après, il est convenu ce qui '
                'suit pour l\'organisation d\'un stage de formation en '
                'entreprise :',
                f.regular,
              ),
              pw.SizedBox(height: 6),
              partie('1. L\'établissement de formation', [
                school,
                if (s.schoolTutorName != null)
                  'Enseignant référent : ${s.schoolTutorName}',
              ]),
              partie('2. L\'entreprise d\'accueil', [
                s.companyName ?? '—',
                if (s.companySector != null) 'Secteur : ${s.companySector}',
                if (s.companyPlace != null) 'Adresse : ${s.companyPlace}',
                if (s.companyContact != null) 'Contact : ${s.companyContact}',
                if (s.companyTutorName != null)
                  'Tuteur en entreprise : ${s.companyTutorName}'
                      '${s.companyTutorPhone != null ? ' (${s.companyTutorPhone})' : ''}',
              ]),
              partie('3. Le stagiaire', [
                s.studentName,
                if (s.matricule != null) 'Matricule : ${s.matricule}',
                'Classe : ${s.className ?? '—'}'
                    '${s.filiereLabel != null ? ' · filière ${s.filiereLabel}' : ''}',
              ]),
              pw.SizedBox(height: 4),
              OfficialPdfKit.frame(
                title: 'OBJET ET DURÉE',
                color: kPdfNavy,
                fonts: f,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                        'Objet : ${s.title ?? 'stage de formation en milieu professionnel'}',
                        style: pw.TextStyle(font: f.regular, fontSize: 10.5)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        'Période : du ${_dLong(s.startDate)} au ${_dLong(s.endDate)}',
                        style: pw.TextStyle(font: f.regular, fontSize: 10.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              _para(
                'Le stagiaire demeure sous statut scolaire pendant toute la '
                'durée du stage. Il s\'engage à respecter le règlement intérieur '
                'et les consignes de sécurité de l\'entreprise, ainsi que la '
                'confidentialité des informations dont il aurait connaissance. '
                'L\'entreprise désigne un tuteur chargé de l\'accueil et du suivi, '
                'et délivre une attestation de fin de stage.',
                f.regular,
                size: 10.5,
              ),
              _signatureBlock(f, 'Pour l\'entreprise', 'Pour l\'établissement'),
              pw.SizedBox(height: 14),
              pw.Center(
                child: pw.Text('Le stagiaire (lu et approuvé)',
                    style: pw.TextStyle(
                        font: f.bold, fontSize: 10, color: kPdfNavy)),
              ),
            ],
          ),
        ),
      ],
    ));
    return doc.save();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  LISTE DES STAGES (PDF)
  // ════════════════════════════════════════════════════════════════════════
  static Future<Uint8List> buildStageListPdf({
    required List<InternshipRow> rows,
    required String? schoolName,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = 'STG-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';

    final attest = rows.where((r) => r.hasAttestation).length;
    final due = rows.where((r) => r.attestationOverdue).length;
    final ongoing =
        rows.where((r) => r.status == InternshipStatus.enCours).length;

    final doc = pw.Document(
      title: 'Liste des stages',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Liste des stages en entreprise',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          OfficialPdfKit.header(logo, f, badge: 'LISTE DES\nSTAGES'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'STAGES EN ENTREPRISE',
            title: (schoolName?.trim().isNotEmpty ?? false)
                ? schoolName!.trim()
                : 'Liste des stages',
            line1: '${rows.length} stage${rows.length > 1 ? 's' : ''}',
            line2: 'Éditée le ${_dLong(DateTime.now())}'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Stages', '${rows.length}', kPdfNavy),
          PdfKpi('En cours', '$ongoing', kPdfGreen),
          PdfKpi('Attestations', '$attest', kPdfGreen),
          PdfKpi('Dues', '$due', due > 0 ? kPdfRed : kPdfNavy),
        ], width: 130),
        pw.SizedBox(height: 16),
        if (rows.isEmpty)
          OfficialPdfKit.empty('Aucun stage enregistré.', f.regular)
        else
          OfficialPdfKit.frame(
            title: 'STAGES',
            color: kPdfNavy,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const [
                'N°',
                'Élève',
                'Classe',
                'Filière',
                'Entreprise',
                'Période',
                'Statut',
                'Attest.',
              ],
              rows: [
                for (final (i, r) in rows.indexed)
                  [
                    '${i + 1}',
                    r.studentName,
                    r.className ?? '—',
                    r.filiereLabel ?? '—',
                    r.companyName ?? '—',
                    r.startDate == null
                        ? '—'
                        : '${_d(r.startDate)}–${_d(r.endDate)}',
                    _statusLabel(r.status.name == 'enCours'
                        ? 'en_cours'
                        : r.status.name),
                    r.hasAttestation ? 'Oui' : (r.attestationOverdue ? 'DUE' : '—'),
                  ],
              ],
              fonts: f,
              flex: const [2, 7, 4, 4, 6, 5, 3, 3],
              leftAlignCols: const {1, 4},
            ),
          ),
        pw.SizedBox(height: 8),
      ],
    ));
    return doc.save();
  }

  // ── Téléchargements ────────────────────────────────────────────────────────
  static Future<String?> _save(Uint8List bytes, String fileName,
      String dialogTitle) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName.replaceAll(' ', '_'),
      bytes: bytes,
    );
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes);
    }
    return path;
  }

  static Future<String?> downloadAttestation(
      {required StageDetail s, required String? schoolName}) async {
    final bytes = await buildAttestationPdf(s: s, schoolName: schoolName);
    return _save(bytes, 'Attestation_${s.studentName}.pdf',
        'Enregistrer l\'attestation');
  }

  static Future<String?> downloadConvention(
      {required StageDetail s, required String? schoolName}) async {
    final bytes = await buildConventionPdf(s: s, schoolName: schoolName);
    return _save(
        bytes, 'Convention_${s.studentName}.pdf', 'Enregistrer la convention');
  }

  static Future<String?> downloadStageList(
      {required List<InternshipRow> rows, required String? schoolName}) async {
    final bytes = await buildStageListPdf(rows: rows, schoolName: schoolName);
    return _save(bytes, 'Stages.pdf', 'Enregistrer la liste des stages');
  }

  /// CSV brut — pour le tableur.
  static Future<String?> downloadCsv({required List<InternshipRow> rows}) async {
    String esc(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';

    final b = StringBuffer()
      ..writeln('Eleve;Classe;Filiere;Entreprise;Debut;Fin;Statut;'
          'Convention;Attestation');
    for (final r in rows) {
      b.writeln([
        esc(r.studentName),
        esc(r.className),
        esc(r.filiereLabel),
        esc(r.companyName),
        esc(_d(r.startDate)),
        esc(_d(r.endDate)),
        esc(_statusLabel(
            r.status.name == 'enCours' ? 'en_cours' : r.status.name)),
        esc(r.conventionSigned ? 'Signee' : 'Non'),
        esc(r.hasAttestation ? 'Delivree' : (r.attestationOverdue ? 'Due' : 'Non')),
      ].join(';'));
    }
    final bytes = Uint8List.fromList(
      [0xEF, 0xBB, 0xBF, ...b.toString().codeUnits],
    );
    return _save(bytes, 'Stages.csv', 'Exporter en CSV');
  }
}
