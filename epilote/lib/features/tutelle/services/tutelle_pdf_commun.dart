import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../../core/utils/safe_file_name.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE PARTAGENT LES TROIS DOCUMENTS DE LA TUTELLE
//
//  État du réseau, fiche de groupe, fiche d'établissement : trois documents,
//  une seule identité, un seul encart de portée, un seul enregistrement.
//  Écrire trois fois la phrase « effectifs agrégés, aucune donnée nominative »
//  aurait garanti qu'elle finisse par diverger — et c'est la phrase qui engage
//  le ministère, pas celle qu'on peut laisser dériver.
//
//  ── ⚠️ L'ENCART DE PORTÉE N'EST PAS UNE MENTION LÉGALE DÉCORATIVE ─────────
//  Un PDF quitte l'application : il est imprimé, agrafé, transmis. Il perd le
//  contexte de l'écran qui l'a produit. Sans la portée écrite dessus, un
//  tableau de 7 écoles filtré sur un département se lit comme l'état du réseau
//  entier — et c'est ce chiffre-là qui remonte au cabinet.
// ════════════════════════════════════════════════════════════════════════════

const kPdfPurple = PdfColor.fromInt(0xFF7C3AED);
const kPdfBlue = PdfColor.fromInt(0xFF0EA5E9);
const kPdfOrange = PdfColor.fromInt(0xFFFF6B35);

/// Couleur du ministère, dans la palette du document (cf. `couleurTutelle`).
PdfColor pdfCouleurTutelle(String? t) =>
    (t ?? '').toLowerCase().contains('metp') ? kPdfPurple : kPdfNavy;

String pdfDateLongue(DateTime d) => DateFormat('dd MMMM yyyy', 'fr').format(d);
String pdfHorodatage(DateTime d) =>
    DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(d);
String pdfReference(DateTime d) => DateFormat('yyyyMMdd-HHmm').format(d);

/// Valeur affichable, ou un tiret. Le tiret DIT l'absence ; une cellule vide
/// laisse croire à un défaut d'impression.
String pdfOuTiret(String? v) => (v ?? '').trim().isEmpty ? '—' : v!.trim();

String pdfSecteur(bool estPublic) => estPublic ? 'Public' : 'Privé';

String pdfTypeAgrement(String? t) => switch (t) {
      'definitif' => 'Définitif',
      'provisoire' => 'Provisoire',
      _ => '—',
    };

/// Numéro d'agrément pour un document.
///
/// ⚠️ « Non déclaré », JAMAIS « non agréé ». La plateforme n'instruit aucun
/// dossier : elle rend la mention qu'on lui a saisie. Imprimer « non agréé »
/// sous l'en-tête d'un ministère ferait porter à un logiciel une accusation
/// qu'il n'a aucun moyen d'établir — sur du papier à en-tête officiel.
String pdfAgrement(String? numero) =>
    (numero ?? '').trim().isEmpty ? 'Non déclaré' : numero!.trim();

/// L'encart qui dit ce que le document couvre — et ce qu'il ne couvre pas.
///
/// [perimetre] : ce que CE document couvre, en une phrase. ⚠️ Obligatoire et
/// non défaut : une phrase générique écrite ici finissait par annoncer
/// « l'ensemble des établissements placés sous votre tutelle » en tête d'une
/// fiche portant sur UNE école. Chaque document doit nommer son propre
/// périmètre, sous peine de mentir sur du papier à en-tête.
///
/// [selection] : la phrase de filtres (`descriptionDesFiltres`), ou `null` si
/// le document porte sur tout son périmètre.
pw.Widget pdfEncartPortee(
  PdfFonts f, {
  required String perimetre,
  String? selection,
  String? complement,
}) {
  final lignes = <String>[
    if (selection != null)
      '$selection — les totaux de ce document portent sur cette sélection, '
          'et non sur le périmètre entier.'
    else
      perimetre,
    'Effectifs AGRÉGÉS arrêtés au jour d’édition. Aucun nom d’élève, aucune '
        'note, aucune absence, aucun paiement, aucune donnée d’abonnement.',
    'Un agrément « non déclaré » signale une mention absente du système, en '
        'aucun cas un établissement en situation irrégulière.',
    ?complement,
  ];

  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 28),
    child: pw.Container(
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: kPdfSurface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: kPdfBorder),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('PORTÉE DU DOCUMENT',
              style: pw.TextStyle(
                  font: f.bold,
                  fontSize: 8,
                  color: kPdfNavy,
                  letterSpacing: 0.8)),
          pw.SizedBox(height: 5),
          for (final l in lignes)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('•  ',
                      style: pw.TextStyle(
                          font: f.bold, fontSize: 8, color: kPdfMuted)),
                  pw.Expanded(
                    child: pw.Text(l,
                        style: pw.TextStyle(
                            font: f.regular, fontSize: 8, color: kPdfMuted)),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// Bloc « libellé : valeur » sur deux colonnes — la forme d'une fiche
/// d'identité, par opposition au tableau d'une liste.
pw.Widget pdfFicheBloc(
  PdfFonts f, {
  required String titre,
  required PdfColor couleur,
  required List<(String, String)> lignes,
}) =>
    OfficialPdfKit.frame(
      title: titre,
      color: couleur,
      fonts: f,
      child: pw.Column(
        children: [
          for (var i = 0; i < lignes.length; i++)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 5.5),
              decoration: i == lignes.length - 1
                  ? null
                  : const pw.BoxDecoration(
                      border: pw.Border(
                          bottom: pw.BorderSide(
                              color: kPdfBorder, width: 0.6))),
              child: pw.Row(children: [
                pw.Expanded(
                  flex: 4,
                  child: pw.Text(lignes[i].$1,
                      style: pw.TextStyle(
                          font: f.regular, fontSize: 9, color: kPdfMuted)),
                ),
                pw.Expanded(
                  flex: 6,
                  child: pw.Text(lignes[i].$2,
                      maxLines: 2,
                      style: pw.TextStyle(
                          font: f.medium, fontSize: 9.5, color: kPdfText)),
                ),
              ]),
            ),
        ],
      ),
    );

// ════════════════════════════════════════════════════════════════════════════
//  ENREGISTREMENT
//
//  ⚠️ Sous Windows — la plateforme de déploiement — `FilePicker.saveFile`
//  IGNORE l'argument `bytes` et ne rend qu'un chemin : sans la réécriture
//  explicite qui suit, l'agent obtient un fichier de zéro octet. Le repli sur
//  le dossier Documents couvre le cas d'une boîte système indisponible : mieux
//  vaut un fichier déposé quelque part de nommable qu'un export perdu.
// ════════════════════════════════════════════════════════════════════════════
Future<String?> pdfEnregistrer({
  required Uint8List octets,
  required String nomFichier,
  required String titreDialogue,
}) async {
  final nom = safeFileName(nomFichier, fallback: 'document_tutelle.pdf');
  try {
    final chemin = await FilePicker.platform.saveFile(
      dialogTitle: titreDialogue,
      fileName: nom,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: octets,
    );
    if (chemin != null) {
      final f = File(chemin);
      if (!await f.exists() || await f.length() == 0) {
        await f.writeAsBytes(octets);
      }
      return chemin;
    }
  } catch (_) {
    // Boîte système absente ou refusée : on ne renonce pas à l'export.
  }

  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$nom');
    await file.writeAsBytes(octets);
    return file.path;
  } catch (_) {
    return null;
  }
}

/// Nom de fichier daté : deux exports du même jour ne s'écrasent pas
/// silencieusement, et l'agent retrouve la date sans ouvrir le document.
String pdfNomFichier(String prefixe, String sujet) =>
    '${prefixe}_${sujet.replaceAll(RegExp(r'[^\w]+'), '_')}'
    '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
