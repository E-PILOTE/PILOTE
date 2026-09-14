import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/assiduite_mensuelle_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  RELEVÉ MENSUEL D'ASSIDUITÉ — la pièce que la circonscription réclame
//
//  L'appel était saisi tous les jours et totalisé nulle part. L'établissement
//  détenait la donnée et devait la recompter à la main pour la transmettre.
//
//  ── DEUX PARTIS PRIS, ET POURQUOI ─────────────────────────────────────────
//
//  1. UN TAUX SANS POINTAGE S'ÉCRIT « — », JAMAIS « 0 % ». Une classe dont
//     l'appel n'a pas été fait afficherait sinon le pire taux possible, comme
//     un fait, sur la classe dont on ne sait justement rien. Et un chef
//     d'établissement qui lit « 0 % » convoque un professeur.
//
//  2. LES CLASSES SANS AUCUN APPEL SONT NOMMÉES EN TÊTE. C'est l'information
//     la plus actionnable du document, et c'est précisément celle qu'un taux
//     moyen dissout : trois classes à 96 % et une jamais pointée donnent un
//     établissement « à 96 % ».
//
//  ⚠️ `tableSection`, jamais `frame(table())` : une école de vingt classes et
//  une liste d'alerte de cinquante élèves dépassent la page. Huit documents de
//  cette application ne sortaient pas pour cette raison.
// ══════════════════════════════════════════════════════════════════════════════
class AssiduitePdfService {
  static String _pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)} %';

  static Future<Uint8List> buildPdf({
    required EtatAssiduiteMensuel etat,
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());
    final mois = libelleMois(etat.mois);
    final muettes = etat.sansAucunAppel;

    final doc = pw.Document(
      title: 'Relevé d\'assiduité — $mois',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Relevé mensuel d\'assiduité',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          OfficialPdfKit.header(logo, f, badge: 'RELEVÉ\nASSIDUITÉ'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'RELEVÉ MENSUEL D\'ASSIDUITÉ',
            title: schoolName?.trim().isNotEmpty ?? false
                ? schoolName!.trim()
                : 'Assiduité des élèves',
            line1: 'Mois de $mois'
                '${yearLabel?.trim().isNotEmpty ?? false ? ' · Année scolaire ${yearLabel!.trim()}' : ''}',
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),

        // ── L'avertissement se lit AVANT les chiffres ────────────────────
        //  Sous le tableau, le lecteur s'est déjà fait une opinion.
        if (etat.aucunPointage) ...[
          _bandeau(
            f,
            kPdfRed,
            'Aucun appel n\'a été enregistré sur ce mois.',
            'Les colonnes ci-dessous ne valent pas zéro : elles sont vides. '
                'Ce relevé ne peut pas servir de constat d\'absentéisme.',
          ),
          pw.SizedBox(height: 12),
        ] else if (muettes.isNotEmpty) ...[
          _bandeau(
            f,
            kPdfGold,
            '${muettes.length} classe(s) sans aucun appel ce mois-ci.',
            '${muettes.map((c) => c.className).join(' · ')}. '
                'Leur taux est porté « — », et non 0 % : la donnée manque, '
                'elle n\'est pas mauvaise.',
          ),
          pw.SizedBox(height: 12),
        ],

        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Élèves', '${etat.effectif}', kPdfNavy),
          PdfKpi('Demi-journées', '${etat.demiJournees}',
              const PdfColor.fromInt(0xFF0EA5E9)),
          PdfKpi('Taux de présence', _pct(etat.tauxPresence),
              etat.tauxPresence == null ? kPdfMuted : kPdfGreen),
          PdfKpi('Absences injustifiées', '${etat.injustifiees}',
              etat.injustifiees > 0 ? kPdfRed : kPdfMuted),
        ]),
        pw.SizedBox(height: 16),

        ...OfficialPdfKit.tableSection(
          title: 'ASSIDUITÉ PAR CLASSE',
          color: kPdfNavy,
          fonts: f,
          headers: const [
            'Classe',
            'Effectif',
            'Appels',
            'Présents',
            'Absents',
            'dont injust.',
            'Retards',
            'Taux'
          ],
          rows: [
            for (final c in etat.classes)
              [
                c.className,
                '${c.effectif}',
                '${c.demiJournees}',
                '${c.presences}',
                '${c.absences}',
                '${c.injustifiees}',
                '${c.retards}',
                _pct(c.tauxPresence),
              ],
          ],
          flex: const [5, 3, 3, 3, 3, 4, 3, 4],
          leftAlignCols: const {0},
          emptyLabel: 'Aucune classe dans votre périmètre.',
          note: 'Le taux rapporte les présences aux POINTAGES effectués, non '
              'aux jours du mois : une classe pointée huit fois n\'est pas '
              'notée sur vingt. Un appel non fait n\'est pas une absence.',
        ),
        pw.SizedBox(height: 16),

        ...OfficialPdfKit.tableSection(
          title:
              'ÉLÈVES À SUIVRE — $kSeuilAlerteAbsences absences ou plus dans le mois',
          color: kPdfRed,
          fonts: f,
          headers: const [
            'Élève',
            'Matricule',
            'Classe',
            'Absences',
            'dont injust.',
            'Retards'
          ],
          rows: [
            for (final e in etat.alertes)
              [
                e.nom,
                e.matricule ?? '—',
                e.className ?? '—',
                '${e.absences}',
                '${e.injustifiees}',
                '${e.retards}',
              ],
          ],
          flex: const [6, 4, 4, 3, 4, 3],
          leftAlignCols: const {0},
          emptyLabel: etat.aucunPointage
              ? 'Aucun appel enregistré : cette liste ne peut pas être établie.'
              : 'Aucun élève n\'atteint le seuil ce mois-ci.',
          note: 'Classés par absences INJUSTIFIÉES décroissantes — ce sont '
              'elles qui appellent une convocation de la famille.',
        ),
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  /// Bandeau d'avertissement — hauteur fixe, deux lignes : il tient sur une
  /// page par construction, `frame` lui convient.
  static pw.Widget _bandeau(
          PdfFonts f, PdfColor couleur, String titre, String detail) =>
      pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28),
        padding: const pw.EdgeInsets.all(10),
        // ⚠️ PAS de `borderRadius` ici. Le paquet `pdf` n'accepte un rayon
        // qu'avec une bordure UNIFORME : associé à ce filet de gauche, il lève
        // une assertion À LA GÉNÉRATION. Le bandeau n'aurait donc échoué que
        // dans les cas où il s'affiche — un mois sans appel, ou une classe
        // muette —, c'est-à-dire exactement quand le document compte.
        decoration: pw.BoxDecoration(
          color: kPdfSurface,
          border: pw.Border(left: pw.BorderSide(color: couleur, width: 3)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(titre,
                style: pw.TextStyle(
                    font: f.bold, fontSize: 10, color: couleur)),
            pw.SizedBox(height: 3),
            pw.Text(detail,
                style: pw.TextStyle(
                    font: f.regular, fontSize: 8.5, color: kPdfMuted)),
          ],
        ),
      );

  static Future<String?> downloadDoc({
    required EtatAssiduiteMensuel etat,
    String? schoolName,
    String? yearLabel,
  }) async {
    final bytes = await buildPdf(
        etat: etat, schoolName: schoolName, yearLabel: yearLabel);
    final m = etat.mois.mois.toString().padLeft(2, '0');
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le relevé d\'assiduité',
      fileName: 'Assiduite_${etat.mois.annee}-$m.pdf',
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
