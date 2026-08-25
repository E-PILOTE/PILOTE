import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/admin_reports_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  RAPPORT ANALYTIQUE DU GROUPE (niveau groupe).
//
//  Ce service traînait deux défauts qui ne se voient qu'en production.
//
//  ── 1. LA TABLE DES ÉTABLISSEMENTS N'ÉTAIT PAS PAGINÉE ──────────────────────
//  `_schoolsSection` posait `data.schoolRows` — une ligne par établissement du
//  groupe, donc jusqu'à mille — dans UN cadre, lui-même enveloppé dans un
//  `Padding` incapable de se scinder entre deux pages. Passé une trentaine de
//  lignes, `MultiPage` boucle jusqu'à `TooManyPagesException` : le rapport ne
//  sort pas du tout. Pas « mal paginé », pas « tronqué » — absent. Les deux
//  plus gros groupes en comptent aujourd'hui 14 et 12 : le défaut dormait à
//  deux écoles près de se réveiller.
//
//  ── 2. LE DOCUMENT ÉTAIT SIGNÉ DU NOM DU FOURNISSEUR ────────────────────────
//  Ce fichier portait sa PROPRE copie de l'en-tête officiel, laquelle écrivait
//  « E-PILOTE CONGO / Plateforme Nationale de Gestion Scolaire » sous les
//  armoiries. Un rapport du ministère déposé au ministère était donc émis au
//  nom de l'éditeur du logiciel. `OfficialPdfKit` + `PdfIssuer` traitent
//  exactement ce problème et vingt-sept services les utilisent ; celui-ci ne
//  leur était jamais passé.
//
//  En adoptant le kit, l'en-tête prend le nom du groupe connecté, les pages 2+
//  reçoivent le filet de continuation au lieu de répéter l'emblème pleine
//  hauteur, et E-PILOTE retourne à sa place : le pied de page, comme outil qui
//  a produit le document et non comme auteur.
// ══════════════════════════════════════════════════════════════════════════════

const _kOrange = PdfColor.fromInt(0xFFFF6B35);
const _kPurple = PdfColor.fromInt(0xFF7C3AED);
const _kBlue = PdfColor.fromInt(0xFF0EA5E9);

class ReportsPdfService {
  static Future<Uint8List> buildPdf({required ReportData data}) async {
    // Polices EMBARQUÉES (assets/fonts) — cf. OfficialPdfKit.loadFonts().
    // `PdfGoogleFonts` allait les chercher sur fonts.gstatic.com et, en cas
    // d'échec, retombait SANS BRUIT sur Helvetica : sur un poste hors ligne —
    // le cas normal d'une école congolaise — le document officiel sortait dans
    // une police de secours sans Unicode, et nul ne le voyait avant impression.
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();

    final fmtDateL = DateFormat('dd MMMM yyyy', 'fr');
    final maintenant = DateTime.now();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(maintenant);
    final ref = DateFormat('yyyyMMdd-HHmm').format(maintenant);
    final periode = '${fmtDateL.format(data.periodStart)} '
        'au ${fmtDateL.format(data.periodEnd)}';
    final titre = 'Rapport analytique — ${data.periodLabel}';

    final doc = pw.Document(
      title: 'Rapport — ${data.groupName}',
      author: OfficialPdfKit.issuer?.name ?? 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Rapport de synthèse du groupe scolaire',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'RAPPORT\nANALYTIQUE', title: titre),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'RAPPORT ANALYTIQUE',
            title: data.periodLabel,
            line1: 'Période : $periode',
            line2: 'Périmètre : ${data.scopeLabel}  •  Plan ${data.planName}  •  '
                'Édité le ${fmtDateL.format(maintenant)}'),
        pw.SizedBox(height: 16),
        _kpis(data, f),
        pw.SizedBox(height: 18),
        _structure(data, f),
        pw.SizedBox(height: 14),
        _finance(data, f),
        pw.SizedBox(height: 14),
        _rh(data, f),
        pw.SizedBox(height: 14),
        ..._etablissements(data, f),
        pw.SizedBox(height: 20),
      ],
    ));

    return doc.save();
  }

  // ── Indicateurs ─────────────────────────────────────────────────────────────
  //  173 pt × 3 + 2 gouttières de 10 = 539 pt, la largeur utile exacte d'une A4
  //  à marges de 28. Deux rangées de trois qui touchent les deux bords : une
  //  largeur choisie au hasard laissait une bande blanche à droite.
  static pw.Widget _kpis(ReportData d, PdfFonts f) => OfficialPdfKit.kpiGrid(
        f,
        [
          PdfKpi('Établissements', '${d.schoolsTotal}', kPdfNavy),
          PdfKpi('Élèves', _n(d.elevesTotal), kPdfGreen),
          PdfKpi('Personnel', _n(d.personnelTotal), _kBlue),
          PdfKpi('Classes', '${d.classesTotal}', _kPurple),
          PdfKpi('Nouv. inscrits (période)', _n(d.elevesNouveaux), kPdfGold),
          PdfKpi('Taux recouvrement',
              '${d.tauxPaiement.toStringAsFixed(0)} %', _kOrange),
        ],
        width: 173,
      );

  // ── Structure & effectifs ───────────────────────────────────────────────────
  //  Ces trois cadres portent un nombre de lignes FIXE — un par indicateur, plus
  //  les types de contrat, qui sont une énumération en base. Rien n'y grandit
  //  avec le parc : ils n'ont donc pas à être paginés.
  static pw.Widget _structure(ReportData d, PdfFonts f) {
    final e = d.elevesTotal;
    final pctG = e > 0 ? (d.studentsM * 100 / e).round() : 0;
    final pctF = e > 0 ? (d.studentsF * 100 / e).round() : 0;
    return _cadre(
      title: 'STRUCTURE & EFFECTIFS',
      color: _kBlue,
      fonts: f,
      note: 'Encadrement : 1 agent pour '
          '${d.ratioEncadrement.toStringAsFixed(1)} élève(s)  •  '
          '${d.coveredDepts} département(s) couvert(s)',
      lignes: [
        ('Établissements publics', '${d.publicCount}', kPdfNavy),
        ('Établissements privés', '${d.priveCount}', kPdfNavy),
        null,
        ('Élèves — garçons', '${_n(d.studentsM)}  ($pctG %)', _kBlue),
        ('Élèves — filles', '${_n(d.studentsF)}  ($pctF %)', _kPurple),
        ('Nouvelles inscriptions (période)', _n(d.elevesNouveaux), kPdfGreen),
        null,
        ('Classes ouvertes', _n(d.classesTotal), _kOrange),
      ],
    );
  }

  static pw.Widget _finance(ReportData d, PdfFonts f) {
    final aDesDonnees = d.revenusTotal > 0 || d.paiementsCount > 0;
    return _cadre(
      title: 'INDICATEURS FINANCIERS (PÉRIODE)',
      color: kPdfGreen,
      fonts: f,
      note: aDesDonnees
          ? 'Taux de recouvrement : ${d.tauxPaiement.toStringAsFixed(1)} %  '
              '(${d.elevesAJour} élève(s) à jour sur ${d.elevesTotal})'
          : null,
      vide: aDesDonnees
          ? null
          : 'Aucune donnée financière sur la période sélectionnée.',
      lignes: [
        ('Revenus de la période', '${_n(d.revenusTotal.round())} FCFA',
            kPdfGreen),
        ('Paiements confirmés', '${d.paiementsCount}', kPdfNavy),
        ('Revenu moyen / élève',
            '${_n(d.revenuMoyenParEleve.round())} FCFA', _kBlue),
        ('Élèves à jour', _n(d.elevesAJour), kPdfGreen),
        ('Élèves impayés', _n(d.elevesImpayes),
            d.elevesImpayes > 0 ? kPdfRed : kPdfGreen),
      ],
    );
  }

  static pw.Widget _rh(ReportData d, PdfFonts f) {
    final parContrat = d.staffByContract.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _cadre(
      title: 'RESSOURCES HUMAINES',
      color: _kPurple,
      fonts: f,
      note: d.personnelTotal == 0
          ? null
          : "Part des fonctionnaires de l'État : "
              '${d.tauxFonctionnaires.toStringAsFixed(1)} %',
      vide: d.personnelTotal == 0
          ? 'Aucun personnel enregistré sur ce périmètre.'
          : null,
      lignes: [
        ("Fonctionnaires de l'État (titulaires)", '${d.fonctionnaires}',
            kPdfNavy),
        ('Personnel non fonctionnaire', '${d.nonFonctionnaires}', _kOrange),
        ('Recrutements (période)', '${d.personnelNouveau}', kPdfGreen),
        if (parContrat.isNotEmpty) null,
        for (final c in parContrat)
          (_contrat(c.key), '${c.value}', kPdfMuted),
      ],
    );
  }

  // ── Répartition par établissement — LA liste qui suit le parc ───────────────
  //  Colonne des noms large et deux lignes autorisées : les intitulés congolais
  //  sont longs — « Collège d'Enseignement Technique de … » fait à lui seul
  //  trente-cinq caractères avant la commune. Écrêtés à une ligne, trois
  //  établissements deviennent indiscernables l'un de l'autre.
  static List<pw.Widget> _etablissements(ReportData d, PdfFonts f) =>
      OfficialPdfKit.tableSection(
        title: 'RÉPARTITION PAR ÉTABLISSEMENT (${d.schoolRows.length})',
        color: kPdfNavy,
        fonts: f,
        headers: const [
          'Établissement',
          'Type',
          'Élèves',
          'Personnel',
          'Classes',
          'Revenus',
          'Statut',
        ],
        flex: const [9, 3, 2, 3, 2, 4, 3],
        rows: d.schoolRows
            .map((s) => [
                  s.name,
                  _type(s.type),
                  '${s.students}',
                  '${s.staff}',
                  '${s.classes}',
                  _n(s.revenue.round()),
                  s.isActive ? 'Active' : 'Inactive',
                ])
            .toList(),
        emptyLabel: 'Aucun établissement sur ce périmètre.',
        perBlock: OfficialPdfKit.kTallRowsPerBlock,
        maxLines: 2,
        rowHeight: OfficialPdfKit.kTallRowHeight,
      );

  // ── Cadre à lignes « pastille · libellé · valeur » ──────────────────────────
  //  `null` dans [lignes] = un filet de séparation.
  static pw.Widget _cadre({
    required String title,
    required PdfColor color,
    required PdfFonts fonts,
    required List<(String, String, PdfColor)?> lignes,
    String? note,
    String? vide,
  }) {
    return OfficialPdfKit.frame(
      title: title,
      color: color,
      fonts: fonts,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (vide != null)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: kPdfSurface,
                  borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(vide,
                  style: pw.TextStyle(
                      font: fonts.regular, fontSize: 9, color: kPdfMuted)),
            )
          else
            for (final l in lignes)
              if (l == null)
                pw.Divider(color: kPdfBorder, thickness: 0.5)
              else
                OfficialPdfKit.statLine(fonts, l.$1, l.$2, color: l.$3),
          if (note != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(note,
                style: pw.TextStyle(
                    font: fonts.medium, fontSize: 9, color: kPdfMuted)),
          ],
        ],
      ),
    );
  }

  // ── Enregistrement ─────────────────────────────────────────────────────────
  //  ⚠️ Pas de `printReport` ici. `Printing.layoutPdf` ouvre sous Windows la
  //  boîte de CHOIX D'IMPRIMANTE (`PrintDlg`), avec `hwndOwner = nullptr` : elle
  //  peut s'afficher DERRIÈRE l'application, n'écrit jamais de fichier, et rend
  //  « non imprimé » sans erreur si on l'annule. Les écrans passent par
  //  `showPdfPreviewDialog`, qui montre le document PUIS laisse enregistrer ou
  //  imprimer — c'est le chemin des vingt autres exports de l'application.
  static Future<String?> downloadReport({
    required ReportData data,
    Uint8List? bytes,
  }) async {
    // `bytes` permet d'enregistrer un document DÉJÀ construit — celui que
    // l'aperçu affiche. Sans cela, valider l'aperçu regénérerait le PDF, et
    // l'agent enregistrerait un document qu'il n'a, à la lettre, pas vu : même
    // contenu, mais autre heure d'édition et autre numéro de référence.
    final octets = bytes ?? await buildPdf(data: data);
    final fileName = 'Rapport_${_slug(data.groupName)}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le rapport',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: octets,
      );
      if (savePath != null) {
        // Sous Windows, `file_picker` IGNORE `bytes` : il ne rend qu'un chemin.
        final f = File(savePath);
        if (!await f.exists() || await f.length() == 0) {
          await f.writeAsBytes(octets);
        }
        return savePath;
      }
    } catch (_) {}

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(octets);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Milliers séparés par une espace — la convention francophone.
String _n(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf';
}

String _slug(String s) => s.replaceAll(RegExp(r'[^\w]+'), '_');

String _type(String t) => switch (t) {
      'public' => 'Public',
      'prive' => 'Privé',
      _ => t,
    };

String _contrat(String c) => switch (c) {
      'permanent' => 'Titulaires (permanents)',
      'contractuel' => 'Contractuels',
      'vacataire' => 'Vacataires',
      'stagiaire' => 'Stagiaires',
      _ => c,
    };
