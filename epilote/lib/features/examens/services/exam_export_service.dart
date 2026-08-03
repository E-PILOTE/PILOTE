import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/safe_file_name.dart';

import '../../../core/services/official_pdf_kit.dart';
import '../providers/candidate_file_provider.dart';
import '../providers/exam_candidates_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Export EXAMENS — la LISTE DES CANDIDATS.
//
//  Ce n'est pas un confort : c'est le document que l'établissement DÉPOSE au
//  centre d'examen. Il engage l'école, doit être exhaustif, daté et traçable —
//  d'où l'en-tête officiel (République du Congo + emblème), la référence
//  d'édition en pied de page, et le rappel de la tutelle et de la session.
//
//  Le CSV sert l'autre besoin : retraiter la liste (tableur du ministère,
//  publipostage des convocations).
// ══════════════════════════════════════════════════════════════════════════════
class ExamExportService {
  static String _fmtDate(DateTime? d) =>
      d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);

  static Future<Uint8List> buildCandidateListPdf({
    required List<ExamCandidateRow> candidates,
    required String examName,
    required String examShortName,
    required String? yearLabel,
    required String? schoolName,
    String? tutelle,
    DateTime? writtenFrom,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final complets =
        candidates.where((c) => c.dossierStatus != 'incomplet').length;
    final deposes = candidates.where((c) => c.isSubmitted).length;
    final filles = candidates.where((c) => c.gender == 'F').length;

    final doc = pw.Document(
      title: 'Liste des candidats — $examShortName',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Liste officielle des candidats à $examName',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          OfficialPdfKit.header(logo, f, badge: 'LISTE DES\nCANDIDATS'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: '${tutelle?.toUpperCase() ?? ''} · $examShortName'
                '${yearLabel != null ? ' · SESSION $yearLabel' : ''}',
            title: (schoolName?.trim().isNotEmpty ?? false)
                ? schoolName!.trim()
                : 'Liste des candidats',
            line1: '${candidates.length} candidat'
                '${candidates.length > 1 ? 's' : ''} — $examName'
                '${writtenFrom != null ? ' · épreuves du ${_fmtDate(writtenFrom)}' : ''}',
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Candidats', '${candidates.length}', kPdfNavy),
          PdfKpi('Dossiers complets', '$complets',
              complets == candidates.length ? kPdfGreen : kPdfRed),
          PdfKpi('Déposés', '$deposes', kPdfGreen),
          PdfKpi('Filles', '$filles', const PdfColor.fromInt(0xFF0EA5E9)),
        ], width: 130),
        pw.SizedBox(height: 16),
        if (candidates.isEmpty)
          OfficialPdfKit.empty(
              'Aucun candidat inscrit à cette session.', f.regular)
        else
          OfficialPdfKit.frame(
            title: 'CANDIDATS — ${examShortName.toUpperCase()}',
            color: kPdfNavy,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const [
                'N°',
                'Nom et prénom',
                'Matricule',
                'Né(e) le',
                'Sexe',
                'Classe',
                'N° candidat',
                'Dossier',
              ],
              rows: [
                for (final (i, c) in candidates.indexed)
                  [
                    '${i + 1}',
                    c.fullName,
                    c.matricule ?? '—',
                    _fmtDate(c.dateOfBirth),
                    c.gender ?? '—',
                    c.className ?? '—',
                    c.candidateNumber ?? '—',
                    _dossierLabel(c.dossierStatus),
                  ],
              ],
              fonts: f,
              flex: const [2, 7, 4, 4, 2, 4, 4, 4],
              leftAlignCols: const {1, 2},
            ),
          ),
        pw.SizedBox(height: 8),
      ],
    ));
    return doc.save();
  }

  // ── FICHE D'INSCRIPTION D'UN CANDIDAT ──────────────────────────────────────
  //  Le document qu'on pose sur le comptoir de la DEC, et celui qu'on ressort
  //  quand un parent conteste. Il récapitule ce qui engage l'école : l'identité
  //  exacte portée sur la liste officielle, et l'état pièce par pièce du dossier.
  static Future<Uint8List> buildCandidateFilePdf({
    required CandidateFile c,
    required String? schoolName,
    List<({String label, String state})> pieces = const [],
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final doc = pw.Document(
      title: 'Fiche d\'inscription — ${c.fullName}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Fiche d\'inscription à ${c.examName ?? ''}',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          OfficialPdfKit.header(logo, f, badge: 'FICHE\nD\'INSCRIPTION'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: '${c.tutelle?.toUpperCase() ?? ''} · '
                '${c.examShortName ?? ''}'
                '${c.yearLabel != null ? ' · SESSION ${c.yearLabel}' : ''}',
            title: c.fullName,
            line1: '${c.examName ?? ''}'
                '${c.candidateNumber != null ? ' · N° candidat ${c.candidateNumber}' : ''}',
            line2: (schoolName?.trim().isNotEmpty ?? false)
                ? schoolName!.trim()
                : ''),
        pw.SizedBox(height: 12),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Dossier', _dossierLabel(c.dossierStatus),
              c.dossierStatus == 'incomplet' ? kPdfRed : kPdfGreen),
          PdfKpi('Classe', c.className ?? '—', kPdfNavy),
          PdfKpi('N° candidat', c.candidateNumber ?? '—', kPdfNavy),
        ]),
        pw.SizedBox(height: 12),
        OfficialPdfKit.frame(
          title: 'IDENTITÉ DU CANDIDAT',
          color: kPdfNavy,
          fonts: f,
          child: OfficialPdfKit.table(
            headers: const ['Rubrique', 'Information'],
            rows: [
              ['Nom et prénom', c.fullName],
              ['Matricule', c.matricule ?? '—'],
              ['Né(e) le', _fmtDate(c.dateOfBirth)],
              ['Lieu de naissance', c.placeOfBirth ?? '—'],
              ['Sexe', c.gender ?? '—'],
              ['Nationalité', c.nationality ?? '—'],
            ],
            fonts: f,
            flex: const [5, 11],
            leftAlignCols: const {0, 1},
          ),
        ),
        pw.SizedBox(height: 10),
        OfficialPdfKit.frame(
          title: 'SCOLARITÉ ET CANDIDATURE',
          color: kPdfNavy,
          fonts: f,
          child: OfficialPdfKit.table(
            headers: const ['Rubrique', 'Information'],
            rows: [
              ['Classe', c.className ?? '—'],
              ['Filière', c.filiereLabel ?? '—'],
              ['Niveau', c.levelName ?? '—'],
              ['Redoublant', c.isRepeater ? 'Oui' : 'Non'],
              ['Examen', c.examName ?? '—'],
              ['Session', c.yearLabel ?? '—'],
              ['Début des épreuves', _fmtDate(c.writtenFrom)],
              ['Inscrit le', _fmtDate(c.registeredAt)],
              ['Dossier déposé le', _fmtDate(c.submittedAt)],
            ],
            fonts: f,
            flex: const [5, 11],
            leftAlignCols: const {0, 1},
          ),
        ),
        if (pieces.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          OfficialPdfKit.frame(
            title: 'PIÈCES DU DOSSIER',
            color: c.dossierStatus == 'incomplet' ? kPdfRed : kPdfGreen,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const ['Pièce exigée', 'État'],
              rows: [
                for (final p in pieces) [p.label, p.state],
              ],
              fonts: f,
              flex: const [11, 5],
              leftAlignCols: const {0},
            ),
          ),
        ],
        pw.SizedBox(height: 8),
      ],
    ));
    return doc.save();
  }

  static Future<String?> downloadCandidateFile({
    required CandidateFile c,
    required String? schoolName,
    List<({String label, String state})> pieces = const [],
  }) async {
    final bytes = await buildCandidateFilePdf(
        c: c, schoolName: schoolName, pieces: pieces);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer la fiche d\'inscription',
      fileName: safeFileName(
        'Fiche_${c.fullName}_${c.examShortName ?? ''}.pdf'
            .replaceAll(' ', '_'),
      ),
      bytes: bytes,
    );
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes);
    }
    return path;
  }

  static String _dossierLabel(String? s) => switch (s) {
        'complet' => 'Complet',
        'depose' => 'Déposé',
        'valide' => 'Validé',
        'rejete' => 'Rejeté',
        _ => 'Incomplet',
      };

  static Future<String?> downloadCandidateListPdf({
    required List<ExamCandidateRow> candidates,
    required String examName,
    required String examShortName,
    required String? yearLabel,
    required String? schoolName,
    String? tutelle,
    DateTime? writtenFrom,
  }) async {
    final bytes = await buildCandidateListPdf(
      candidates: candidates,
      examName: examName,
      examShortName: examShortName,
      yearLabel: yearLabel,
      schoolName: schoolName,
      tutelle: tutelle,
      writtenFrom: writtenFrom,
    );
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer la liste des candidats',
      fileName: safeFileName(
        'Candidats_${examShortName}_${yearLabel ?? ''}.pdf'
            .replaceAll(' ', '_'),
      ),
      bytes: bytes,
    );
    if (path == null) return null;
    // Desktop : saveFile ne matérialise pas toujours le fichier -> on écrit.
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes);
    }
    return path;
  }

  /// CSV brut — pour le tableur du ministère et le publipostage des convocations.
  static Future<String?> downloadCsv({
    required List<ExamCandidateRow> candidates,
    required String examShortName,
    String? yearLabel,
  }) async {
    String esc(String? v) {
      final s = (v ?? '').replaceAll('"', '""');
      return '"$s"';
    }

    final b = StringBuffer()
      ..writeln('Nom;Matricule;Date de naissance;Sexe;Classe;'
          'Numero candidat;Dossier;Resultat;Moyenne;Mention');
    for (final c in candidates) {
      b.writeln([
        esc(c.fullName),
        esc(c.matricule),
        esc(_fmtDate(c.dateOfBirth)),
        esc(c.gender),
        esc(c.className),
        esc(c.candidateNumber),
        esc(_dossierLabel(c.dossierStatus)),
        esc(c.result),
        esc(c.average?.toStringAsFixed(2)),
        esc(c.mention),
      ].join(';'));
    }

    final bytes = Uint8List.fromList(
      // BOM UTF-8 : sans lui Excel massacre les accents des noms congolais.
      // BOM UTF-8 + encodage UTF-8 : `codeUnits` rendait les unités UTF-16
      // telles quelles, soit du Latin-1 sous une en-tête annonçant de
      // l'UTF-8. Excel affichait un losange noir en fin de « Kimbembé », sur des
      // listes déposées au ministère.
      [0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())],
    );
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Exporter en CSV',
      fileName: safeFileName(
        'Candidats_${examShortName}_${yearLabel ?? ''}.csv'
            .replaceAll(' ', '_'),
      ),
      bytes: bytes,
    );
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes);
    }
    return path;
  }
}
