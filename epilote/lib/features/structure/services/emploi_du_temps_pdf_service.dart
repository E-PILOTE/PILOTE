import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/timetable_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Service : EMPLOI DU TEMPS — export officiel A4 paysage. Grille hebdomadaire
//  (lignes = horaires, colonnes = Lun→Sam), mise en page OfficialPdfKit. Le
//  contenu d'une case s'adapte à la vue (classe / enseignant / salle).
// ══════════════════════════════════════════════════════════════════════════════

/// Vue de l'export — décide la ligne secondaire des cases.
enum TtPdfView { classe, enseignant, salle }

class EmploiDuTempsPdfService {
  static const _days = [1, 2, 3, 4, 5, 6];

  // Palette déterministe par matière (alignée sur l'écran).
  static const _palette = <int>[
    0xFF0EA5E9, 0xFF22C55E, 0xFFF59E0B, 0xFF8B5CF6, 0xFFEC4899,
    0xFF14B8A6, 0xFFEF4444, 0xFF6366F1, 0xFF84CC16, 0xFFF97316,
  ];
  static PdfColor _subjectColor(String id) =>
      PdfColor.fromInt(_palette[id.hashCode.abs() % _palette.length]);

  static Future<Uint8List> buildPdf({
    required List<TimetableSlot> slots,
    required String entityTitle,
    required TtPdfView view,
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    // Plages horaires uniques triées.
    final ranges = <String, (String, String)>{};
    for (final s in slots) {
      ranges['${s.hhmmStart}-${s.hhmmEnd}'] = (s.hhmmStart, s.hhmmEnd);
    }
    final rows = ranges.values.toList()..sort((a, b) => a.$1.compareTo(b.$1));

    TimetableSlot? slotAt(int day, String start, String end) {
      for (final s in slots) {
        if (s.dayOfWeek == day && s.hhmmStart == start && s.hhmmEnd == end) {
          return s;
        }
      }
      return null;
    }

    final totalMin = slots.fold<int>(0, (a, e) => a + e.durationMinutes);
    final hours = totalMin / 60;
    final hoursLabel = hours == hours.roundToDouble()
        ? '${hours.toInt()}h'
        : '${hours.toStringAsFixed(1)}h';
    final kicker = switch (view) {
      TtPdfView.classe => 'EMPLOI DU TEMPS · CLASSE',
      TtPdfView.enseignant => 'EMPLOI DU TEMPS · ENSEIGNANT',
      TtPdfView.salle => 'EMPLOI DU TEMPS · SALLE',
    };

    final doc = pw.Document(
      title: 'Emploi du temps',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Emploi du temps hebdomadaire',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          OfficialPdfKit.header(logo, f, badge: 'EMPLOI\nDU TEMPS'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 12),
        OfficialPdfKit.titleBlock(f,
            kicker: kicker,
            title: entityTitle,
            line1: schoolName?.trim().isNotEmpty ?? false
                ? schoolName!.trim()
                : null,
            line2: [
              if (yearLabel?.trim().isNotEmpty ?? false)
                'Année scolaire : ${yearLabel!.trim()}',
              'Édité le $genDate',
            ].join('  •  ')),
        pw.SizedBox(height: 14),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Créneaux', '${slots.length}', kPdfNavy),
          PdfKpi('Heures / semaine', hoursLabel,
              const PdfColor.fromInt(0xFF0EA5E9)),
          PdfKpi('Matières',
              '${slots.map((s) => s.subjectId).toSet().length}', kPdfGreen),
          PdfKpi(view == TtPdfView.enseignant ? 'Classes' : 'Enseignants',
              '${(view == TtPdfView.enseignant ? slots.map((s) => s.classId) : slots.map((s) => s.staffId)).toSet().length}',
              const PdfColor.fromInt(0xFF8B5CF6)),
        ], width: 150),
        pw.SizedBox(height: 16),
        if (slots.isEmpty)
          OfficialPdfKit.empty(
              'Aucun créneau à exporter pour cet emploi du temps.', f.regular)
        else
          OfficialPdfKit.frame(
            title: 'SEMAINE TYPE',
            color: kPdfNavy,
            fonts: f,
            child: _grid(f, rows, slotAt, view),
          ),
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  /// Livret établissement : UNE page par entité (classe). Idéal pour distribuer
  /// l'ensemble des emplois du temps en un seul document.
  static Future<Uint8List> buildBooklet({
    required List<({String title, List<TimetableSlot> slots})> sections,
    TtPdfView view = TtPdfView.classe,
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final doc = pw.Document(
      title: 'Emplois du temps — établissement',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Emplois du temps hebdomadaires',
    );

    for (final sec in sections) {
      final ranges = <String, (String, String)>{};
      for (final s in sec.slots) {
        ranges['${s.hhmmStart}-${s.hhmmEnd}'] = (s.hhmmStart, s.hhmmEnd);
      }
      final rows = ranges.values.toList()..sort((a, b) => a.$1.compareTo(b.$1));
      TimetableSlot? slotAt(int day, String start, String end) {
        for (final s in sec.slots) {
          if (s.dayOfWeek == day && s.hhmmStart == start && s.hhmmEnd == end) {
            return s;
          }
        }
        return null;
      }

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        header: (ctx) =>
            OfficialPdfKit.header(logo, f, badge: 'EMPLOI\nDU TEMPS'),
        footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          OfficialPdfKit.titleBlock(f,
              kicker: 'EMPLOI DU TEMPS · CLASSE',
              title: sec.title,
              line1: schoolName?.trim().isNotEmpty ?? false
                  ? schoolName!.trim()
                  : null,
              line2: [
                if (yearLabel?.trim().isNotEmpty ?? false)
                  'Année scolaire : ${yearLabel!.trim()}',
                'Édité le $genDate',
              ].join('  •  ')),
          pw.SizedBox(height: 14),
          if (sec.slots.isEmpty)
            OfficialPdfKit.empty('Aucun créneau pour cette classe.', f.regular)
          else
            OfficialPdfKit.frame(
              title: 'SEMAINE TYPE',
              color: kPdfNavy,
              fonts: f,
              child: _grid(f, rows, slotAt, view),
            ),
        ],
      ));
    }
    return doc.save();
  }

  static Future<String?> downloadBooklet({
    required List<({String title, List<TimetableSlot> slots})> sections,
    String? schoolName,
    String? yearLabel,
  }) async {
    final bytes = await buildBooklet(
        sections: sections, schoolName: schoolName, yearLabel: yearLabel);
    final fileName =
        'EDT_Etablissement_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer les emplois du temps',
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
    }
    return savePath;
  }

  static pw.Widget _grid(
    PdfFonts f,
    List<(String, String)> rows,
    TimetableSlot? Function(int, String, String) slotAt,
    TtPdfView view,
  ) {
    pw.Widget headerCell(String t) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          color: kPdfSurface,
          child: pw.Text(t.toUpperCase(),
              style: pw.TextStyle(font: f.bold, fontSize: 8, color: kPdfNavy)),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: kPdfBorder, width: 0.6),
      columnWidths: {
        0: const pw.FixedColumnWidth(54),
        for (var i = 1; i <= 6; i++) i: const pw.FlexColumnWidth(),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(children: [
          headerCell('Horaire'),
          for (final d in _days) headerCell(frDays[d]),
        ]),
        for (final r in rows)
          pw.TableRow(children: [
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Column(children: [
                pw.Text(r.$1,
                    style: pw.TextStyle(
                        font: f.bold, fontSize: 8, color: kPdfText)),
                pw.Text(r.$2,
                    style: pw.TextStyle(
                        font: f.regular, fontSize: 7, color: kPdfMuted)),
              ]),
            ),
            for (final d in _days) _bodyCell(f, slotAt(d, r.$1, r.$2), view),
          ]),
      ],
    );
  }

  static pw.Widget _bodyCell(PdfFonts f, TimetableSlot? s, TtPdfView view) {
    if (s == null) return pw.SizedBox(height: 44);
    final color = _subjectColor(s.subjectId);
    final secondary = switch (view) {
      TtPdfView.classe => s.teacherName,
      TtPdfView.enseignant => s.className,
      TtPdfView.salle => s.className,
    };
    final trailing = view == TtPdfView.salle ? s.teacherName : s.room;
    return pw.Container(
      height: 44,
      padding: const pw.EdgeInsets.fromLTRB(6, 5, 5, 5),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.10),
        border: pw.Border(left: pw.BorderSide(color: color, width: 2.5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(s.subjectName ?? 'Matière',
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(font: f.bold, fontSize: 8, color: color)),
          if ((secondary ?? '').trim().isNotEmpty)
            pw.Text(secondary!.trim(),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style:
                    pw.TextStyle(font: f.regular, fontSize: 7, color: kPdfText)),
          if ((trailing ?? '').trim().isNotEmpty)
            pw.Text(trailing!.trim(),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                    font: f.regular, fontSize: 6.5, color: kPdfMuted)),
        ],
      ),
    );
  }

  static Future<String?> downloadDoc({
    required List<TimetableSlot> slots,
    required String entityTitle,
    required TtPdfView view,
    String? schoolName,
    String? yearLabel,
  }) async {
    final bytes = await buildPdf(
        slots: slots,
        entityTitle: entityTitle,
        view: view,
        schoolName: schoolName,
        yearLabel: yearLabel);
    final safe = entityTitle.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final fileName =
        'EDT_${safe}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer l\'emploi du temps',
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
    }
    return savePath;
  }
}
