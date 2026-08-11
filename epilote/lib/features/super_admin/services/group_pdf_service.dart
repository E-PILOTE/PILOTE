import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/services/official_pdf_kit.dart';

import '../providers/school_groups_provider.dart';

// ─── Couleurs PDF ──────────────────────────────────────────────────────────────
const _navy    = PdfColor.fromInt(0xFF1E3A5F);
const _navyL   = PdfColor.fromInt(0xFF2A4E7A);
const _green   = PdfColor.fromInt(0xFF009A44);
const _gold    = PdfColor.fromInt(0xFFFBBC04);
const _red     = PdfColor.fromInt(0xFFDC143C);
const _purple  = PdfColor.fromInt(0xFF7C3AED);
const _orange  = PdfColor.fromInt(0xFFFF6B35);
const _muted   = PdfColor.fromInt(0xFF64748B);
const _border  = PdfColor.fromInt(0xFFE2E8F0);
const _surface = PdfColor.fromInt(0xFFF0F4F8);
const _text    = PdfColor.fromInt(0xFF0F172A);

// ─── Service principal ────────────────────────────────────────────────────────

class GroupPdfService {
  static Future<Uint8List> buildPdf(GroupDetail g) async {
    // ── Polices ──────────────────────────────────────────────────────────────
    // Polices EMBARQUÉES (assets/fonts) — cf. OfficialPdfKit.loadFonts().
    // `PdfGoogleFonts` allait les chercher sur fonts.gstatic.com et, en cas
    // d'échec, retombait SANS BRUIT sur Helvetica : sur un poste hors ligne —
    // le cas normal d'une école congolaise — le document officiel sortait dans
    // une police de secours sans Unicode, et nul ne le voyait avant impression.
    final polices = await OfficialPdfKit.loadFonts();
    final fontRegular = polices.regular;
    final fontBold = polices.bold;
    final fontMedium = polices.medium;

    // Logo plateforme : SVG non chargeable dans un service isolé → bloc "EP"

    // ── Logo groupe depuis URL réseau ─────────────────────────────────────────
    pw.ImageProvider? groupLogoImage;
    if (g.logoUrl != null && g.logoUrl!.startsWith('http')) {
      try {
        groupLogoImage = await networkImage(g.logoUrl!);
      } catch (_) {}
    }

    // ── Formatters ───────────────────────────────────────────────────────────
    final fmtDate  = DateFormat('dd/MM/yyyy');
    final fmtDateL = DateFormat('dd MMMM yyyy', 'fr');
    final now      = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref_     = g.id.substring(0, 8).toUpperCase();

    String fmtXaf(double v) {
      if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} M FCFA';
      if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)} k FCFA';
      return '${v.toStringAsFixed(0)} FCFA';
    }

    // ── Construction du document ──────────────────────────────────────────────
    final doc = pw.Document(
      title: 'Fiche Officielle — ${g.name}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Fiche d\'identité groupe scolaire',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => _buildHeader(
          g, groupLogoImage, fontBold, fontMedium, fontRegular, now, ref_),
      footer: (ctx) => _buildFooter(
          ctx, fontRegular, fontMedium, now, ref_),
      build: (ctx) => [
        pw.SizedBox(height: 16),
        // ── Bloc nom groupe ──────────────────────────────────────────────────
        _nameBlock(g, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 18),
        // ── 2 colonnes : Coordonnées + Abonnement ────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _section(
              title: 'COORDONNÉES',
              color: _navy,
              fontBold: fontBold,
              fontRegular: fontRegular,
              rows: [
                _Row('Email admin',   g.adminEmail),
                _Row('Téléphone',     g.phone ?? '—'),
                _Row('Département',   g.department ?? '—'),
                _Row('Adresse',       g.address ?? '—'),
              ],
            )),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _section(
              title: 'ABONNEMENT',
              color: _gold,
              fontBold: fontBold,
              fontRegular: fontRegular,
              rows: [
                _Row('Plan', g.planName),
                _Row('Tarif mensuel',
                    '${fmtXaf(g.priceXaf.toDouble())} FCFA'),
                _Row('Début',
                    g.subscriptionStart != null
                        ? fmtDate.format(g.subscriptionStart!)
                        : '—'),
                _Row('Expiration',
                    g.subscriptionEnd != null
                        ? fmtDate.format(g.subscriptionEnd!)
                        : '—'),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 12),
        // ── Capacité & Quotas (pleine largeur) ───────────────────────────────
        _section(
          title: 'CAPACITÉ & QUOTAS',
          color: _green,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            _Row('Écoles enregistrées',
                '${g.schoolCount} école${g.schoolCount > 1 ? "s" : ""}'),
            _Row('Capacité max (écoles)',
                g.maxSchools == -1 ? 'Illimitée' : '${g.maxSchools}'),
            _Row('Capacité max (élèves)',
                g.maxStudents == -1 ? 'Illimitée' : '${g.maxStudents}'),
            _Row('Taux d\'utilisation',
                g.maxSchools > 0
                    ? '${(g.schoolCount / g.maxSchools * 100).round()} %'
                    : '—'),
          ],
        ),
        pw.SizedBox(height: 12),
        // ── Historique ───────────────────────────────────────────────────────
        _section(
          title: 'HISTORIQUE',
          color: _purple,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            if (g.foundedYear != null)
              _Row('Fondation', '${g.foundedYear}'),
            _Row('Enregistrement plateforme',
                fmtDateL.format(g.createdAt)),
            if (g.subscriptionStart != null)
              _Row('Démarrage abonnement',
                  fmtDateL.format(g.subscriptionStart!)),
            _Row('Dernière mise à jour',
                fmtDateL.format(g.updatedAt)),
          ],
        ),
        if (g.notes?.isNotEmpty == true) ...[
          pw.SizedBox(height: 12),
          _section(
            title: 'NOTES INTERNES',
            color: _orange,
            fontBold: fontBold,
            fontRegular: fontRegular,
            rows: [_Row('Remarques', g.notes!)],
          ),
        ],
        pw.SizedBox(height: 24),
      ],
    ));

    return doc.save();
  }

  // ── En-tête letterhead ─────────────────────────────────────────────────────
  static pw.Widget _buildHeader(
    GroupDetail g,
    pw.ImageProvider? groupLogoImage,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
    String now,
    String ref_,
  ) {
    return pw.Column(children: [
      // Bande tricolore Congo
      pw.Row(children: [
        pw.Expanded(child: pw.Container(height: 5, color: _green)),
        pw.Expanded(child: pw.Container(height: 5, color: _gold)),
        pw.Expanded(child: pw.Container(height: 5, color: _red)),
      ]),
      // Letterhead blanc
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 14),
        color: PdfColors.white,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Logo plateforme (bloc texte stylisé)
            pw.Container(
              width: 50, height: 50,
              decoration: pw.BoxDecoration(
                color: _navy,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text('EP',
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 18,
                      color: PdfColors.white)),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RÉPUBLIQUE DU CONGO',
                    style: pw.TextStyle(
                        font: fontMedium,
                        fontSize: 7.5,
                        color: _muted,
                        letterSpacing: 1.5)),
                pw.SizedBox(height: 2),
                pw.Text('E-PILOTE CONGO',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        color: _navy)),
                pw.Text('Plateforme Nationale de Gestion Scolaire',
                    style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 9,
                        color: _muted)),
              ],
            )),
            // Logo groupe
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 58, height: 58,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _border, width: 1.5),
                    borderRadius: pw.BorderRadius.circular(10),
                    color: _surface,
                  ),
                  child: groupLogoImage != null
                      ? pw.ClipRRect(
                          horizontalRadius: 10,
                          verticalRadius: 10,
                          child: pw.Image(groupLogoImage, fit: pw.BoxFit.cover),
                        )
                      : pw.Center(child: pw.Text(
                          _initials(g.name),
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 18,
                              color: _navy),
                        )),
                ),
                pw.SizedBox(height: 3),
                pw.Text('LOGO OFFICIEL',
                    style: pw.TextStyle(
                        font: fontMedium,
                        fontSize: 6.5,
                        color: _muted,
                        letterSpacing: 1)),
              ],
            ),
          ],
        ),
      ),
      // Ligne séparatrice dégradée
      pw.Container(
        height: 2,
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [_navy, _navyL, PdfColors.white],
          ),
        ),
      ),
      pw.SizedBox(height: 8),
    ]);
  }

  // ── Pied de page ──────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(
    pw.Context ctx,
    pw.Font fontRegular,
    pw.Font fontMedium,
    String now,
    String ref_,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(28, 8, 28, 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            top: pw.BorderSide(color: _border, width: 0.8)),
      ),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(
          'Document officiel généré le $now  •  E-PILOTE CONGO  •  Réf. $ref_',
          style: pw.TextStyle(
              font: fontRegular, fontSize: 7.5, color: _muted),
        )),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
            color: _navy,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(
                font: fontMedium,
                fontSize: 7.5,
                color: PdfColors.white),
          ),
        ),
      ]),
    );
  }

  // ── Bloc nom du groupe ─────────────────────────────────────────────────────
  static pw.Widget _nameBlock(
    GroupDetail g,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    final statusColor = switch (g.subscriptionStatus) {
      'active'    => _green,
      'trial'     => _purple,
      'suspended' => _orange,
      _           => _red,
    };

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Expanded(child: pw.Text(
              g.name.toUpperCase(),
              style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 20,
                  color: _text),
            )),
            // Badge statut
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: _alpha(statusColor, 0.12),
                border: pw.Border.all(
                    color: _alpha(statusColor, 0.4), width: 1),
                borderRadius: pw.BorderRadius.circular(20),
              ),
              child: pw.Row(children: [
                pw.Container(
                    width: 7, height: 7,
                    decoration: pw.BoxDecoration(
                      color: statusColor,
                      shape: pw.BoxShape.circle,
                    )),
                pw.SizedBox(width: 5),
                pw.Text(g.statusLabel.toUpperCase(),
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8,
                        color: statusColor,
                        letterSpacing: 0.5)),
              ]),
            ),
          ]),
          pw.SizedBox(height: 8),
          // Badges type + plan + fondé
          pw.Wrap(spacing: 6, runSpacing: 4, children: [
            _badge(g.groupTypeLabel, _navy, fontMedium),
            _badge('Plan ${g.planName}', _gold, fontMedium),
            if (g.foundedYear != null)
              _badge('Fondé en ${g.foundedYear}', _muted, fontMedium),
          ]),
          pw.SizedBox(height: 12),
          pw.Divider(color: _border, thickness: 0.8),
        ],
      ),
    );
  }

  // ── Section avec titre et lignes ──────────────────────────────────────────
  static pw.Widget _section({
    required String      title,
    required PdfColor    color,
    required pw.Font     fontBold,
    required pw.Font     fontRegular,
    required List<_Row>  rows,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border, width: 0.8),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // En-tête section
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: pw.BoxDecoration(
                color: _alpha(color, 0.08),
                border: pw.Border(
                    bottom: pw.BorderSide(color: _alpha(color, 0.2), width: 0.8)),
              ),
              child: pw.Text(title,
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 9,
                      color: color,
                      letterSpacing: 0.8)),
            ),
            // Lignes de données
            ...rows.asMap().entries.map((e) {
              final isLast = e.key == rows.length - 1;
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: pw.BoxDecoration(
                  border: isLast
                      ? null
                      : const pw.Border(
                          bottom: pw.BorderSide(
                              color: _border, width: 0.5)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 110,
                      child: pw.Text(e.value.label,
                          style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 9,
                              color: _muted)),
                    ),
                    pw.Expanded(child: pw.Text(e.value.value,
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 9.5,
                            color: _text))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Badge compact ─────────────────────────────────────────────────────────
  static pw.Widget _badge(String label, PdfColor color, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: _alpha(color, 0.10),
        border: pw.Border.all(color: _alpha(color, 0.3), width: 0.8),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(label,
          style: pw.TextStyle(font: font, fontSize: 8.5, color: color)),
    );
  }

  // ── Utilitaires ───────────────────────────────────────────────────────────
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'G';
  }

  // ── Impression système ────────────────────────────────────────────────────
  static Future<void> printGroup(GroupDetail g) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildPdf(g),
      name: 'Fiche_${g.name.replaceAll(' ', '_')}.pdf',
    );
  }

  // ── Téléchargement ────────────────────────────────────────────────────────
  static Future<String?> downloadGroup(GroupDetail g) async {
    final bytes = await buildPdf(g);
    final fileName =
        'Fiche_${g.name.replaceAll(RegExp(r'[^\w]'), '_')}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    // Dialogue natif "Enregistrer sous"
    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la fiche PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (savePath != null) {
        // Sur certaines plateformes, saveFile écrit déjà les bytes ;
        // sur Linux, on doit l'écrire manuellement.
        final f = File(savePath);
        if (!await f.exists() || await f.length() == 0) {
          await f.writeAsBytes(bytes);
        }
        return savePath;
      }
    } catch (_) {}

    // Fallback : sauvegarde directe dans ~/Documents
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

PdfColor _alpha(PdfColor c, double a) =>
    PdfColor(c.red, c.green, c.blue, a);

class _Row {
  const _Row(this.label, this.value);
  final String label, value;
}
