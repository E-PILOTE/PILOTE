import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/admin_regional_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  RAPPORT TERRITORIAL RÉGIONAL (niveau groupe).
//
//  Mêmes deux défauts que le rapport analytique, en trois exemplaires.
//
//  ── 1. TROIS TABLES NON PAGINÉES ────────────────────────────────────────────
//  Départements, établissements géolocalisés et projets étaient posés chacun
//  dans UN cadre — lequel enveloppe son contenu dans un `Padding`, incapable de
//  se scinder entre deux pages. Passé une trentaine de lignes, `MultiPage`
//  boucle jusqu'à `TooManyPagesException` et le rapport ne sort pas du tout.
//  `gpsSchools` compte une ligne par école géolocalisée : à la cible nationale,
//  mille. La table des projets n'a, elle, aucune borne d'aucune sorte.
//
//  ── 2. LE DOCUMENT ÉTAIT SIGNÉ DU NOM DU FOURNISSEUR ────────────────────────
//  En-tête recopié en local annonçant « E-PILOTE CONGO » sous les armoiries :
//  un rapport territorial remis à une préfecture portait le nom de l'éditeur du
//  logiciel au lieu de celui du réseau qui le remet. Cf. `PdfIssuer`.
//
//  ── Ce que le groupe apporte encore ─────────────────────────────────────────
//  `groupName` reste un paramètre : il alimente le titre et le nom de fichier.
//  L'EN-TÊTE, lui, vient de l'émetteur de session — c'est la même identité, mais
//  résolue une fois pour tous les documents plutôt que passée de main en main.
// ══════════════════════════════════════════════════════════════════════════════

const _kOrange = PdfColor.fromInt(0xFFFF6B35);
const _kPurple = PdfColor.fromInt(0xFF7C3AED);
const _kBlue = PdfColor.fromInt(0xFF0EA5E9);

class RegionalPdfService {
  static Future<Uint8List> buildPdf({
    required String groupName,
    required AdminRegionalData data,
    required List<AdminProjectPin> projects,
  }) async {
    // Polices EMBARQUÉES (assets/fonts) — cf. OfficialPdfKit.loadFonts().
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();

    final fmtDateL = DateFormat('dd MMMM yyyy', 'fr');
    final maintenant = DateTime.now();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(maintenant);
    final ref = DateFormat('yyyyMMdd-HHmm').format(maintenant);
    final titre = 'Rapport territorial — $groupName';

    // 15 départements officiels (réforme oct. 2024) — source unique partagée.
    final officiels = adminMajorAgglomerations.keys.toList();
    final couverts = <String>{
      ...data.allDepts.map((d) => _norm(d.dept)),
      ...data.gpsSchools
          .map((s) => s.department)
          .whereType<String>()
          .map(_norm),
    };
    final nonCouverts =
        officiels.where((d) => !couverts.contains(_norm(d))).toList();

    final budget = projects.fold<int>(0, (a, p) => a + (p.budgetXaf ?? 0));
    final beneficiaires =
        projects.fold<int>(0, (a, p) => a + (p.beneficiariesEst ?? 0));

    final doc = pw.Document(
      title: titre,
      author: OfficialPdfKit.issuer?.name ?? 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Rapport territorial régional',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'RAPPORT\nTERRITORIAL', title: titre),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'RAPPORT TERRITORIAL RÉGIONAL',
            title: groupName,
            line1: 'Situation arrêtée au ${fmtDateL.format(maintenant)}',
            line2: '${data.totalSchools} établissement(s)  •  '
                '${data.coveredDepts} département(s) couvert(s) sur 15'),
        pw.SizedBox(height: 16),
        _kpis(data, projects.length, f),
        pw.SizedBox(height: 18),
        ..._departements(data, f),
        if (data.gpsSchools.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          ..._geolocalises(data, f),
        ],
        if (projects.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          ..._projets(projects, budget, beneficiaires, f),
        ],
        pw.SizedBox(height: 14),
        _qualite(data, nonCouverts, f),
        pw.SizedBox(height: 20),
      ],
    ));

    return doc.save();
  }

  // ── Indicateurs ─────────────────────────────────────────────────────────────
  //  173 pt × 3 + 2 gouttières de 10 = 539 pt : la largeur utile exacte d'une A4
  //  à marges de 28, donc deux rangées de trois qui touchent les deux bords.
  static pw.Widget _kpis(AdminRegionalData d, int projets, PdfFonts f) =>
      OfficialPdfKit.kpiGrid(
        f,
        [
          PdfKpi('Établissements', '${d.totalSchools}', kPdfNavy),
          PdfKpi('Élèves actifs', '${d.totalStudents}', kPdfGreen),
          PdfKpi('Écoles actives', '${d.activeSchools}', _kBlue),
          PdfKpi('Départements couverts', '${d.coveredDepts} / 15', kPdfGold),
          PdfKpi('Géolocalisées', '${d.gpsCount}', _kPurple),
          PdfKpi('Projets scolaires', '$projets', _kOrange),
        ],
        width: 173,
      );

  // ── Répartition par département ─────────────────────────────────────────────
  //  Le Congo en compte quinze : le cas normal tient sur un bloc. La pagination
  //  couvre le cas sale — `schools.department` est du texte libre, et quelques
  //  saisies fautives suffiraient à en faire lever cinquante.
  static List<pw.Widget> _departements(AdminRegionalData d, PdfFonts f) =>
      OfficialPdfKit.tableSection(
        title: 'RÉPARTITION PAR DÉPARTEMENT',
        color: kPdfNavy,
        fonts: f,
        headers: const ['Département', 'Écoles', 'Élèves', 'Actives', 'Taux'],
        flex: const [6, 2, 3, 2, 2],
        rows: d.allDepts.map((x) {
          final taux =
              x.schoolCount > 0 ? (x.activeCount / x.schoolCount * 100).round() : 0;
          return [
            x.dept,
            '${x.schoolCount}',
            '${x.studentCount}',
            '${x.activeCount}',
            '$taux %',
          ];
        }).toList(),
        emptyLabel: 'Aucune école rattachée à un département.',
      );

  // ── Établissements géolocalisés — une ligne par école ───────────────────────
  //  La table qui dicte la taille du document : jusqu'à mille lignes à la cible
  //  nationale. Deux lignes de libellé à hauteur fixe, car « Complexe Scolaire
  //  Départemental … » écrêté rend trois établissements identiques.
  static List<pw.Widget> _geolocalises(AdminRegionalData d, PdfFonts f) =>
      OfficialPdfKit.tableSection(
        title: 'ÉTABLISSEMENTS GÉOLOCALISÉS (${d.gpsCount})',
        color: _kPurple,
        fonts: f,
        headers: const [
          'Établissement',
          'Type',
          'Département',
          'Élèves',
          'Source',
        ],
        flex: const [9, 3, 5, 2, 4],
        leftAlignCols: const {2},
        rows: d.gpsSchools
            .map((s) => [
                  s.name,
                  _type(s.type),
                  s.department ?? '—',
                  '${s.students}',
                  _source(s.locationSource),
                ])
            .toList(),
        emptyLabel: 'Aucun établissement géolocalisé.',
        perBlock: OfficialPdfKit.kTallRowsPerBlock,
        maxLines: 2,
        rowHeight: OfficialPdfKit.kTallRowHeight,
      );

  // ── Projets scolaires ───────────────────────────────────────────────────────
  //  Aucune borne : un plan quinquennal de constructions en aligne autant qu'il
  //  veut. Le total est porté par la note du dernier bloc, où il se lit — pas
  //  répété sous chacun d'eux, ce qui laisserait croire à un sous-total.
  static List<pw.Widget> _projets(
    List<AdminProjectPin> projets,
    int budget,
    int beneficiaires,
    PdfFonts f,
  ) =>
      OfficialPdfKit.tableSection(
        title: 'PROJETS SCOLAIRES (${projets.length})',
        color: _kOrange,
        fonts: f,
        headers: const [
          'Projet',
          'Statut',
          'Localisation',
          'Budget',
          'Bénéf.',
        ],
        flex: const [8, 4, 5, 5, 3],
        leftAlignCols: const {2},
        rows: projets
            .map((p) => [
                  p.name,
                  _statutProjet(p.status),
                  p.department ?? p.city ?? '—',
                  p.budgetXaf != null ? '${_n(p.budgetXaf!)} F' : '—',
                  p.beneficiariesEst != null ? '${p.beneficiariesEst}' : '—',
                ])
            .toList(),
        emptyLabel: 'Aucun projet enregistré.',
        perBlock: OfficialPdfKit.kTallRowsPerBlock,
        maxLines: 2,
        rowHeight: OfficialPdfKit.kTallRowHeight,
        note: 'Budget cumulé : ${_n(budget)} FCFA'
            '   •   Bénéficiaires estimés : $beneficiaires',
      );

  // ── Qualité des données ─────────────────────────────────────────────────────
  //  Trois lignes, toujours : rien n'y grandit avec le parc. La liste des
  //  départements non couverts en est une aussi — quinze noms au plus, sur une
  //  seule ligne de texte.
  static pw.Widget _qualite(
      AdminRegionalData d, List<String> nonCouverts, PdfFonts f) {
    final pct =
        d.totalSchools > 0 ? (d.gpsCount / d.totalSchools * 100).round() : 0;
    return OfficialPdfKit.frame(
      title: 'QUALITÉ DES DONNÉES',
      color: kPdfGreen,
      fonts: f,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          OfficialPdfKit.statLine(f, 'Écoles sans coordonnées GPS',
              '${d.noGpsCount} / ${d.totalSchools}',
              color: d.noGpsCount == 0 ? kPdfGreen : _kOrange),
          OfficialPdfKit.statLine(f, 'Taux de géolocalisation', '$pct %',
              color: pct >= 80 ? kPdfGreen : (pct >= 40 ? _kOrange : kPdfRed)),
          OfficialPdfKit.statLine(
              f,
              'Départements sans établissement',
              nonCouverts.isEmpty
                  ? 'Aucun — couverture complète'
                  : '${nonCouverts.length}',
              color: nonCouverts.isEmpty ? kPdfGreen : kPdfMuted),
          if (nonCouverts.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                  color: kPdfSurface,
                  borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(
                  'Départements non couverts : ${nonCouverts.join(', ')}',
                  style: pw.TextStyle(
                      font: f.regular, fontSize: 8.5, color: kPdfMuted)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Enregistrement ─────────────────────────────────────────────────────────
  //  ⚠️ Pas de `printReport` ici — et c'est une correction, pas un oubli.
  //  L'écran de la vue régionale n'offrait QUE ce chemin : `Printing.layoutPdf`,
  //  donc sous Windows la boîte de CHOIX D'IMPRIMANTE (`PrintDlg`), ouverte avec
  //  `hwndOwner = nullptr` — elle peut s'afficher DERRIÈRE l'application, et
  //  n'écrit jamais de fichier. Le « Rapport territorial (PDF) » ne pouvait donc
  //  pas être enregistré, quoi qu'on fasse. L'écran passe désormais par
  //  `showPdfPreviewDialog` : on voit le document, puis on l'enregistre ou on
  //  l'imprime.
  static Future<String?> downloadReport({
    required String groupName,
    required AdminRegionalData data,
    required List<AdminProjectPin> projects,
    Uint8List? bytes,
  }) async {
    // `bytes` : enregistrer LE document que l'aperçu vient de montrer. Le
    // reconstruire donnerait au fichier déposé une autre heure d'édition et un
    // autre numéro de référence que ceux lus à l'écran.
    final octets = bytes ??
        await buildPdf(groupName: groupName, data: data, projects: projects);
    final fileName = 'Rapport_territorial_${_slug(groupName)}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le rapport territorial',
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

// Normalisation accent-insensible pour comparer les noms de départements
// (la colonne `department` en base peut différer de l'orthographe officielle).
String _norm(String s) {
  var r = s.toLowerCase().trim();
  const map = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c',
  };
  map.forEach((k, v) => r = r.replaceAll(k, v));
  return r;
}

String _type(String t) => switch (t) {
      'public' => 'Public',
      'prive' => 'Privé',
      _ => t,
    };

String _statutProjet(String s) => switch (s) {
      'etude' => 'Étude',
      'validation' => 'Validation',
      'budgetisation' => 'Budgétisation',
      'construction' => 'Construction',
      'acheve' => 'Achevé',
      _ => s,
    };

String _source(String? s) => switch (s) {
      'gps' => 'GPS terrain',
      'geocoded' => 'Géocodé',
      'manual' => 'Manuel',
      _ => 'Inconnue',
    };
