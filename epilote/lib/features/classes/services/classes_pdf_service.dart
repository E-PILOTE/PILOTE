import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../../core/utils/safe_file_name.dart';
import '../../../data/models/class_model.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉTAT DES CLASSES — le document que l'écran Classes ne savait pas produire
//
//  ── LE TROU QUE CE FICHIER COMBLE ──────────────────────────────────────────
//  ⚠️ L'écran Classes n'offrait QU'UN export CSV. C'était le seul module de
//  l'espace école dans ce cas, alors que la répartition des classes est
//  précisément une pièce qu'on imprime : on l'affiche au mur à la rentrée, on
//  la remet à l'inspection, on la joint à une demande de poste.
//
//  Un tableur n'est pas un document. Il n'a ni en-tête d'établissement, ni
//  date d'édition, ni pagination, et il s'ouvre différemment sur chaque poste.
//
//  ── CE QUE LE DOCUMENT DIT, ET QUE LE CSV NE DISAIT PAS ────────────────────
//  Le TAUX D'OCCUPATION, classe par classe. C'est la seule lecture qui décide
//  quelque chose : une 6ᵉ à 112 % ne se répare pas en septembre, elle se
//  répare en juin, en ouvrant une division. Le CSV portait l'effectif et la
//  capacité côte à côte et laissait le calcul à l'œil.
//
//  ⚠️ Une capacité NON RENSEIGNÉE ne vaut pas zéro et ne produit pas un taux :
//  elle s'écrit « — ». Un taux de 0 % sur une classe pleine ferait fermer la
//  mauvaise division.
//
//  ── L'ORDRE EST CELUI DE LA SCOLARITÉ ──────────────────────────────────────
//  Les classes sont groupées par CYCLE puis rangées par `level_order`, et non
//  par ordre alphabétique : « Terminale » avant « 6ᵉ » est ce que produit un
//  tri sur le nom, et c'est illisible sur un état signé.
// ════════════════════════════════════════════════════════════════════════════

/// Les cycles dans l'ordre où une scolarité les traverse.
const _ordreCycles = <String>[
  'prescolaire',
  'primaire',
  'college',
  'lycee',
  'technique',
  'professionnel',
];

int _rangCycle(String? code) {
  final i = _ordreCycles.indexOf(code ?? '');
  // Un cycle inconnu passe en dernier plutôt que de s'insérer au hasard.
  return i < 0 ? _ordreCycles.length : i;
}

String _nomCycle(String? code) => switch (code) {
      'prescolaire' => 'Préscolaire',
      'primaire' => 'Primaire',
      'college' => 'Collège',
      'lycee' => 'Lycée',
      'technique' => 'Technique',
      'professionnel' => 'Professionnel',
      null || '' => 'Cycle non précisé',
      _ => code,
    };

/// Le taux d'occupation, ou `null` quand la capacité n'est pas renseignée.
double? _occupation(ClassModel c) {
  final cap = c.capacity;
  if (cap == null || cap <= 0) return null;
  return (c.studentCount ?? 0) / cap * 100;
}

class ClassesPdfService {
  static Future<Uint8List> buildPdf({
    required List<ClassModel> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final parCycle = <String, List<ClassModel>>{};
    for (final c in rows) {
      parCycle.putIfAbsent(c.cycleCode ?? '', () => []).add(c);
    }
    final cycles = parCycle.keys.toList()
      ..sort((a, b) => _rangCycle(a).compareTo(_rangCycle(b)));
    for (final k in cycles) {
      parCycle[k]!.sort((a, b) {
        final o = (a.levelOrder ?? 9999).compareTo(b.levelOrder ?? 9999);
        return o != 0 ? o : a.name.compareTo(b.name);
      });
    }

    final effectif = rows.fold<int>(0, (s, c) => s + (c.studentCount ?? 0));
    final capacite = rows.fold<int>(0, (s, c) => s + (c.capacity ?? 0));
    // ⚠️ Compté sur les seules classes dont la capacité est CONNUE : inclure
    // les autres ferait passer pour « sous-remplie » une école qui n'a
    // simplement pas renseigné ses capacités.
    final saturees = rows.where((c) {
      final t = _occupation(c);
      return t != null && t >= 100;
    }).length;
    final sansCapacite = rows.where((c) => _occupation(c) == null).length;

    final doc = pw.Document(
      title: 'État des classes',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Répartition des classes et taux d\'occupation',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          OfficialPdfKit.header(logo, f, badge: 'ÉTAT DES\nCLASSES'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(
          f,
          kicker: 'RÉPARTITION DES CLASSES',
          title: schoolName?.trim().isNotEmpty ?? false
              ? schoolName!.trim()
              : 'État des classes',
          line1: yearLabel?.trim().isNotEmpty ?? false
              ? 'Année scolaire : ${yearLabel!.trim()}'
              : null,
          line2: 'Édité le $genDate',
        ),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Classes', '${rows.length}', kPdfNavy),
          PdfKpi('Élèves inscrits', '$effectif', kPdfGreen),
          PdfKpi(
            'Capacité déclarée',
            capacite == 0 ? '—' : '$capacite',
            const PdfColor.fromInt(0xFF0EA5E9),
          ),
          PdfKpi(
            'Classes saturées',
            '$saturees',
            saturees > 0 ? kPdfRed : kPdfGreen,
          ),
        ]),
        pw.SizedBox(height: 16),
        for (final cyc in cycles) ...[
          // ⚠️ `tableSection`, JAMAIS `frame(table())` : `frame` enveloppe son
          // contenu dans un `Padding`, qui ne sait pas se scinder entre deux
          // pages. Passé ~28 lignes, `MultiPage` boucle et lève
          // `TooManyPagesException` — on n'obtient AUCUN document.
          ...OfficialPdfKit.tableSection(
            title: _nomCycle(cyc).toUpperCase(),
            color: kPdfNavy,
            fonts: f,
            headers: const [
              'Classe',
              'Niveau',
              'Filière',
              'Salle',
              'Professeur principal',
              'Effectif',
              'Capacité',
              'Occupation',
            ],
            rows: [
              for (final c in parCycle[cyc]!)
                [
                  c.name,
                  c.levelName ?? c.levelCode ?? '—',
                  c.filiereLabel ?? '—',
                  c.room ?? '—',
                  c.teacherName ?? '— non désigné —',
                  '${c.studentCount ?? 0}',
                  c.capacity == null ? '—' : '${c.capacity}',
                  // Le tiret, pas un zéro : voir l'en-tête de ce fichier.
                  _occupation(c) == null
                      ? '—'
                      : '${_occupation(c)!.toStringAsFixed(0)} %',
                ],
            ],
            flex: const [3, 2, 2, 2, 4, 2, 2, 2],
            leftAlignCols: const {0, 1, 2, 3, 4},
            emptyLabel: 'Aucune classe dans ce cycle.',
          ),
          pw.SizedBox(height: 12),
        ],
        // ⚠️ Ce que le document NE dit PAS s'écrit, au lieu de se taire. Un état où
        // des classes n'ont pas de capacité laisse croire à une école
        // sous-remplie ; la phrase empêche la lecture fausse.
        if (sansCapacite > 0)
          OfficialPdfKit.frame(
            title: 'LECTURE DE CE DOCUMENT',
            color: kPdfMuted,
            fonts: f,
            child: pw.Text(
              '$sansCapacite classe${sansCapacite > 1 ? 's' : ''} '
              '${sansCapacite > 1 ? 'n\'ont' : 'n\'a'} pas de capacité '
              'renseignée : leur taux d\'occupation est inconnu, et non nul. '
              'Les totaux de capacité et le compte des classes saturées ne '
              'portent que sur les classes dont la capacité est connue.',
              style:
                  pw.TextStyle(font: f.regular, fontSize: 8, color: kPdfMuted),
            ),
          ),
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  static Future<String?> downloadDoc({
    required List<ClassModel> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final bytes =
        await buildPdf(rows: rows, schoolName: schoolName, yearLabel: yearLabel);
    final nom = safeFileName(
      'Classes_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      fallback: 'classes',
    );
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer l\'état des classes',
      fileName: nom,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
    if (savePath == null) return null;
    // On réécrit toujours : la fenêtre « Enregistrer sous » de Windows rend un
    // chemin sans créer le fichier, et écraser un export plus ancien du même
    // nom laisserait sinon l'ANCIEN contenu en place.
    await File(savePath).writeAsBytes(bytes, flush: true);
    return savePath;
  }
}
