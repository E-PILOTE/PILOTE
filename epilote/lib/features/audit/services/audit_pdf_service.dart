import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../../core/utils/safe_file_name.dart';
import '../providers/audit_models.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE JOURNAL D'AUDIT, EN DOCUMENT — et pas seulement en tableur
//
//  ── POURQUOI CE FICHIER EXISTE ─────────────────────────────────────────────
//  ⚠️ Le journal ne sortait QU'EN CSV. Or c'est la pièce qu'on produit
//  précisément quand quelque chose est contesté : qui a modifié cette note,
//  qui a annulé ce paiement, qui a supprimé ce dossier. Une pièce qu'on
//  produit pour trancher doit être DATÉE, PAGINÉE et PORTER L'EN-TÊTE de
//  l'établissement — un tableur n'a rien de tout cela, et s'ouvre
//  différemment sur chaque poste.
//
//  Le CSV reste : il sert à recouper le journal dans un tableur quand il y a
//  des milliers de lignes. C'est un outil d'enquête, pas une pièce.
//
//  ── PAYSAGE, ET C'EST OBLIGÉ ───────────────────────────────────────────────
//  ⚠️ Sept colonnes — date, action, objet, enregistrement, agent, rôle, école
//  — ne tiennent pas en A4 portrait sans écraser les noms. En paysage, la
//  pagination change : `kRowsPerBlock` vaut 28 parce qu'il a été calculé sur
//  une page portrait de 842 pt ; une page paysage n'en fait que 595, et le
//  même bloc n'y tient pas. Un bloc plus haut qu'une page fait boucler
//  `MultiPage` jusqu'à `TooManyPagesException` — aucun document produit.
//  On utilise donc `kRowsPerBlockLandscape`.
//
//  ── CE QUI N'EST PAS IMPRIMÉ, ET POURQUOI ──────────────────────────────────
//  ⚠️ L'ADRESSE IP et le USER AGENT restent hors du document. Ils figurent au
//  CSV, qui sert l'enquête technique ; sur une pièce qui circule, ils
//  n'apprennent rien à un lecteur humain et exposent des données de connexion
//  d'agents nommés. Le pied du document le dit, plutôt que de le taire.
// ════════════════════════════════════════════════════════════════════════════

String _dt(DateTime? d) =>
    d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d);

String _od(String? v) => (v ?? '').trim().isEmpty ? '—' : v!.trim();

class AuditPdfService {
  static Future<Uint8List> buildPdf({
    required List<AuditEntry> entries,
    String? schoolName,
    String? periodeLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    // Le journal se lit du plus récent au plus ancien : on cherche presque
    // toujours ce qui vient de se passer.
    final tries = [...entries]..sort((a, b) {
        final da = a.createdAt, db = b.createdAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

    final agents = tries.map((e) => e.userName).toSet().length;
    final suppressions = tries
        .where((e) => e.action.toUpperCase().startsWith('DELETE'))
        .length;
    final objets = tries.map((e) => e.tableName).toSet().length;

    final doc = pw.Document(
      title: 'Journal d\'audit',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Journal des opérations',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          OfficialPdfKit.header(logo, f, badge: 'JOURNAL\nD\'AUDIT'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(
          f,
          kicker: 'JOURNAL DES OPÉRATIONS',
          title: schoolName?.trim().isNotEmpty ?? false
              ? schoolName!.trim()
              : 'Journal d\'audit',
          line1: periodeLabel?.trim().isNotEmpty ?? false
              ? 'Période : ${periodeLabel!.trim()}'
              : null,
          line2: 'Édité le $genDate',
        ),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Opérations', '${tries.length}', kPdfNavy),
          PdfKpi('Agents concernés', '$agents',
              const PdfColor.fromInt(0xFF0EA5E9)),
          PdfKpi('Types d\'objets', '$objets', kPdfGold),
          PdfKpi(
            'Suppressions',
            '$suppressions',
            suppressions > 0 ? kPdfRed : kPdfGreen,
          ),
        ]),
        pw.SizedBox(height: 16),
        ...OfficialPdfKit.tableSection(
          title: 'REGISTRE DES OPÉRATIONS',
          color: kPdfNavy,
          fonts: f,
          headers: const [
            'Date et heure',
            'Opération',
            'Objet',
            'Enregistrement',
            'Agent',
            'Rôle',
            'École',
          ],
          rows: [
            for (final e in tries)
              [
                _dt(e.createdAt),
                e.actionLabel,
                e.entityLabel,
                _od(e.recordId),
                _od(e.userName),
                e.roleLbl,
                _od(e.schoolName),
              ],
          ],
          flex: const [3, 3, 3, 4, 4, 3, 4],
          leftAlignCols: const {0, 1, 2, 3, 4, 5, 6},
          emptyLabel: 'Aucune opération sur la période retenue.',
        ),
        pw.SizedBox(height: 12),
        OfficialPdfKit.frame(
          title: 'PORTÉE DE CE DOCUMENT',
          color: kPdfMuted,
          fonts: f,
          child: pw.Text(
            'Ce registre porte les opérations enregistrées par la plateforme '
            'sur le périmètre et la période retenus au moment de l\'édition. '
            'L\'adresse IP et le poste de connexion ne sont VOLONTAIREMENT pas '
            'imprimés : ils figurent dans l\'export de données, destiné à '
            'l\'enquête technique. Leur absence ici ne signifie pas qu\'ils '
            'n\'ont pas été enregistrés.',
            style: pw.TextStyle(font: f.regular, fontSize: 8, color: kPdfMuted),
          ),
        ),
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  static Future<String?> downloadDoc({
    required List<AuditEntry> entries,
    String? schoolName,
    String? periodeLabel,
  }) async {
    final bytes = await buildPdf(
      entries: entries,
      schoolName: schoolName,
      periodeLabel: periodeLabel,
    );
    final nom = safeFileName(
      'Journal_audit_${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.pdf',
      fallback: 'journal-audit',
    );
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le journal d\'audit',
      fileName: nom,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
    if (savePath == null) return null;
    await File(savePath).writeAsBytes(bytes, flush: true);
    return savePath;
  }
}
