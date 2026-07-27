import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../../core/utils/mention.dart';
import '../../../core/utils/discipline_vocab.dart';
import '../providers/student_dossier_provider.dart';
import '../providers/student_results_provider.dart';
import '../widgets/student_dossier_sections.dart'
    show
        fmtDate,
        enrollmentStatusLabel,
        inscriptionTypeLabel,
        cycleLabel,
        joinPlace;

// ════════════════════════════════════════════════════════════════════════════
//  DOSSIER DE L'ÉLÈVE — document officiel imprimable.
//
//  Ce que le cabinet emporte en réunion. Les blocs vides sont écrits comme
//  tels (« aucun responsable enregistré ») : sur une pièce qui circule, un
//  blanc se lit comme une omission, alors que c'est une information.
//
//  Le pied rappelle ce que le document NE contient PAS — sans cela, un lecteur
//  pourrait croire tenir l'intégralité du dossier scolaire.
// ════════════════════════════════════════════════════════════════════════════
class StudentDossierPdfService {
  static Future<Uint8List> buildPdf({
    required String groupName,
    required StudentDossier d,
    DossierDistinction? distinction,
    StudentResults? results,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();

    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final e = d.enrollment;

    final doc = pw.Document(
      title: 'Dossier élève — ${d.fullName}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Dossier scolaire de l\'élève',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'DOSSIER\nÉLÈVE',
          title: 'Dossier de l\'élève — ${d.fullName}'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (_) => [
        OfficialPdfKit.titleBlock(
          f,
          kicker: groupName.toUpperCase(),
          title: d.fullName,
          line1: [
            if (d.matricule != null) 'Matricule ${d.matricule}',
            if (e.className != null) e.className!,
            if (e.filiere != null) e.filiere!,
          ].join('  ·  '),
          line2: d.school.name,
          statusBadge: d.isActive ? 'ACTIF' : 'INACTIF',
        ),
        if (distinction != null) ...[
          pw.SizedBox(height: 12),
          _distinction(f, distinction),
        ],
        pw.SizedBox(height: 14),
        _kv(f, 'IDENTITÉ', kPdfNavy, [
          ('Matricule', d.matricule ?? '—'),
          ('Sexe', switch (d.gender) { 'F' => 'Féminin', 'M' => 'Masculin', _ => '—' }),
          ('Date de naissance', fmtDate(d.dateOfBirth)),
          ('Lieu de naissance', d.placeOfBirth ?? '—'),
          ('Âge', d.age == null ? '—' : '${d.age} ans'),
          ('Nationalité', d.nationality ?? '—'),
          ('Domicile', joinPlace([d.address, d.city])),
          ('Boursier', d.hasScholarship ? 'Oui' : 'Non'),
          ('Interne', d.isBoarder ? 'Oui' : 'Non'),
        ]),
        pw.SizedBox(height: 12),
        e.isEmpty
            ? _note(f, 'INSCRIPTION',
                'Aucune inscription pour l\'année scolaire en cours : l\'élève est enregistré mais n\'est affecté à aucune classe.')
            : _kv(f, 'INSCRIPTION', kPdfGreen, [
                ('Classe', e.className ?? '—'),
                ('Cycle', cycleLabel(e.cycleCode)),
                ('Niveau', e.levelCode ?? '—'),
                ('Filière', e.filiere ?? '—'),
                ('Date d\'inscription', fmtDate(e.enrollmentDate)),
                ('Type', inscriptionTypeLabel(e.inscriptionType)),
                ('Statut', enrollmentStatusLabel(e.status)),
                ('Redoublement', e.isRepeating ? 'Oui' : 'Non'),
                ('Établissement précédent', e.previousSchool ?? '—'),
              ]),
        pw.SizedBox(height: 12),
        d.tutors.isEmpty
            ? _note(f, 'RESPONSABLES LÉGAUX',
                'Aucun responsable légal enregistré pour cet élève.')
            : OfficialPdfKit.frame(
                title: 'RESPONSABLES LÉGAUX',
                color: kPdfGold,
                fonts: f,
                child: OfficialPdfKit.table(
                  headers: const ['Nom', 'Lien', 'Téléphone', 'Adresse', 'Profession'],
                  flex: const [24, 13, 18, 27, 18],
                  leftAlignCols: const {1, 2, 3, 4},
                  fonts: f,
                  rows: [
                    for (final t in d.tutors)
                      [
                        t.fullName,
                        t.relationshipLabel,
                        [t.phonePrimary, t.phoneSecondary]
                            .whereType<String>()
                            .join(' / '),
                        t.address ?? '—',
                        t.profession ?? '—',
                      ],
                  ],
                ),
              ),
        pw.SizedBox(height: 12),
        (results == null || results.isEmpty)
            ? _note(f, 'RÉSULTATS PAR MATIÈRE',
                'Aucune évaluation publiée pour cette classe sur l\'année en cours.')
            : OfficialPdfKit.frame(
                title: 'RÉSULTATS PAR MATIÈRE',
                color: kPdfNavyL,
                fonts: f,
                child: OfficialPdfKit.table(
                  headers: const [
                    'Matière',
                    'Coef',
                    'Élève',
                    'Classe',
                    'Enseignant',
                  ],
                  flex: const [32, 8, 13, 13, 34],
                  leftAlignCols: const {4},
                  fonts: f,
                  rows: [
                    for (final r in results.subjects)
                      [
                        r.subject,
                        '${r.coefficient}',
                        r.average == null
                            ? 'non évaluée'
                            : r.average!.toStringAsFixed(2),
                        r.classAverage == null
                            ? '—'
                            : r.classAverage!.toStringAsFixed(2),
                        _teacherOf(d, r.subject),
                      ],
                    [
                      'MOYENNE GÉNÉRALE',
                      '',
                      results.overall == null
                          ? '—'
                          : results.overall!.toStringAsFixed(2),
                      results.classOverall == null
                          ? '—'
                          : results.classOverall!.toStringAsFixed(2),
                      results.overall == null ? '' : mentionFor(results.overall!),
                    ],
                  ],
                ),
              ),
        pw.SizedBox(height: 12),
        _kv(f, 'ÉTABLISSEMENT DE RATTACHEMENT', kPdfNavy, [
          ('Établissement', d.school.name),
          ('Département', d.school.department ?? '—'),
          ('Adresse', joinPlace([d.school.address, d.school.city])),
          ('Téléphone', d.school.phone ?? '—'),
          ('Courriel', d.school.email ?? '—'),
          ('Chef d\'établissement',
              d.school.hasDirector ? d.school.directorName! : 'Non désigné'),
          ('Téléphone direction', d.school.directorPhone ?? '—'),
        ]),
        pw.SizedBox(height: 12),
        d.incidents.isEmpty
            ? _note(f, 'CONDUITE',
                'Aucun fait de conduite enregistré : le parcours de l\'élève ne présente aucun incident signalé.')
            : OfficialPdfKit.frame(
                title: 'CONDUITE',
                color: kPdfRed,
                fonts: f,
                child: OfficialPdfKit.table(
                  headers: const ['Date', 'Type', 'Motif', 'Sanction', 'Parents'],
                  flex: const [13, 18, 39, 20, 12],
                  leftAlignCols: const {1, 2, 3},
                  fonts: f,
                  rows: [
                    for (final i in d.incidents)
                      [
                        fmtDate(i.date),
                        incidentTypeLabel(i.type),
                        i.description,
                        i.hasSanction ? sanctionLabel(i.sanction) : 'Aucune',
                        i.parentNotified ? 'Informés' : 'Non',
                      ],
                  ],
                ),
              ),
        pw.SizedBox(height: 16),
        _disclaimer(f),
      ],
    ));

    return doc.save();
  }

  // ── Blocs ────────────────────────────────────────────────────────────────
  static pw.Widget _kv(
          PdfFonts f, String title, PdfColor color, List<(String, String)> rows) =>
      OfficialPdfKit.frame(
        title: title,
        color: color,
        fonts: f,
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: kPdfBorder),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: i.isOdd ? kPdfSurface : PdfColors.white,
                    border: i == rows.length - 1
                        ? null
                        : const pw.Border(
                            bottom: pw.BorderSide(color: kPdfBorder, width: 0.5)),
                  ),
                  child: pw.Row(children: [
                    pw.Expanded(
                      flex: 34,
                      child: pw.Text(rows[i].$1,
                          style: pw.TextStyle(
                              font: f.regular, fontSize: 8.5, color: kPdfMuted)),
                    ),
                    pw.Expanded(
                      flex: 66,
                      child: pw.Text(rows[i].$2,
                          style: pw.TextStyle(
                              font: f.medium, fontSize: 8.5, color: kPdfText)),
                    ),
                  ]),
                ),
            ],
          ),
        ),
      );

  /// Bandeau de rang — imprimé seulement si le dossier a été ouvert depuis le
  /// classement. Le rang y est INDISSOCIABLE de son périmètre ET de sa base :
  /// sur une pièce qui circule, « 1ᵉʳ » sans périmètre se lirait « premier du
  /// pays », et sans base il se lirait « premier à l'examen » — deux décisions
  /// fausses pour un rang qui n'est que du contrôle continu.
  static pw.Widget _distinction(PdfFonts f, DossierDistinction d) {
    final rank = '${d.rank}${d.rank == 1 ? 'er' : 'e'}'
        '${d.exAequo ? ' ex æquo' : ''}';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(
          color: PdfColors.amber50,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: kPdfGold, width: 0.9),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('$rank du classement — ${d.scope}',
                      style: pw.TextStyle(
                          font: f.bold, fontSize: 10, color: kPdfText)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    d.details.join('  -  '),
                    style: pw.TextStyle(
                        font: f.regular, fontSize: 8, color: kPdfMuted),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('${d.average.toStringAsFixed(2)} / 20',
                    style: pw.TextStyle(
                        font: f.bold, fontSize: 14, color: kPdfGold)),
                pw.Text(d.mention,
                    style: pw.TextStyle(
                        font: f.medium, fontSize: 8, color: kPdfMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Enseignant de la matière : la correspondance se fait par nom de matière,
  /// seule clé commune aux affectations et aux évaluations.
  static String _teacherOf(StudentDossier d, String subject) {
    for (final t in d.teachers) {
      if (t.subject.toLowerCase() == subject.toLowerCase()) return t.fullName;
    }
    return '—';
  }

  static pw.Widget _note(PdfFonts f, String title, String text) =>
      OfficialPdfKit.frame(
        title: title,
        color: kPdfMuted,
        fonts: f,
        child: pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(11),
          decoration: pw.BoxDecoration(
            color: kPdfSurface,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: kPdfBorder),
          ),
          child: pw.Text(text,
              style:
                  pw.TextStyle(font: f.regular, fontSize: 8.5, color: kPdfMuted)),
        ),
      );

  static pw.Widget _disclaimer(PdfFonts f) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: kPdfSurface,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: kPdfBorder),
          ),
          child: pw.Text(
            'Document de consultation, établi automatiquement par la plateforme. '
            'Il ne comporte ni données médicales ni notes de suivi internes de '
            'l\'établissement, qui demeurent sous la responsabilité de ce dernier.',
            style: pw.TextStyle(font: f.regular, fontSize: 7.5, color: kPdfMuted),
          ),
        ),
      );

  // ── Téléchargement ───────────────────────────────────────────────────────
  static Future<String?> download({
    required String groupName,
    required StudentDossier d,
    DossierDistinction? distinction,
    StudentResults? results,
  }) async {
    final bytes =
        await buildPdf(groupName: groupName, d: d, distinction: distinction);
    final fileName = 'Dossier_eleve_${_slug(d.fullName)}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le dossier de l\'élève',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (savePath != null) {
        final file = File(savePath);
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsBytes(bytes);
        }
        return savePath;
      }
    } catch (_) {}

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');
