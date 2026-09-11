import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/tutelle.dart';
import '../../../core/services/official_pdf_kit.dart';
import '../providers/tutelle_destinataires_provider.dart';
import 'tutelle_pdf_commun.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'INSTRUCTION DE TUTELLE — rendre opposable ce qui n'était qu'un message
//
//  ── LE MANQUE, ET IL ÉTAIT LE SEUL DE CET ESPACE ──────────────────────────
//  La « circulaire de tutelle » a été supprimée (migration 0174) : quatre
//  écrans et un vocabulaire propre pour un objet dont la base ne comptait
//  AUCUNE ligne. Le remplacement — écrire par la messagerie — est le bon
//  choix : un ministère n'a pas à apprendre un quatrième geste pour écrire à
//  quelqu'un.
//
//  Mais il laissait une conséquence non traitée, relevée des DEUX côtés de
//  l'analyse (`08-cat-communication.md` D.1 #1 et `11-espace-tutelle.md`
//  D.1 #1) : **une instruction de tutelle est un acte administratif**, et un
//  fil de discussion ne se classe pas. Il ne s'imprime pas, il ne se joint pas
//  à un dossier, il ne s'oppose à personne. Le message part, il est lu — et
//  trois mois plus tard, plus rien ne prouve ce qui a été prescrit, à qui, ni
//  quand.
//
//  ── CE QUE CE DOCUMENT AJOUTE, ET CE QU'IL N'AJOUTE PAS ───────────────────
//  Il n'ajoute AUCUN canal. Le message part comme avant, par la messagerie.
//  Ce service rend simplement la pièce que le ministère garde : l'objet, le
//  texte intégral, la date, et — c'est là tout l'enjeu — **la liste nommée des
//  destinataires**. C'est elle qui fait l'opposabilité : pas « on a écrit au
//  réseau », mais « le 10 septembre 2026, à l'administrateur du groupe X et
//  aux chefs de tels établissements, nommément ».
//
//  ⚠️ Ce n'est PAS un accusé de réception. Le document dit ce qui a été
//  ADRESSÉ, jamais ce qui a été lu — la plateforme n'a aucun moyen d'établir
//  la seconde chose, et l'écrire sous un en-tête de la République serait lui
//  faire porter une attestation qu'elle ne peut pas tenir.
//
//  ── ⚠️ LE CORPS NE VA PAS DANS UN `frame()` ──────────────────────────────
//  `frame()` enveloppe son contenu dans un `Padding`, qui ne sait pas se
//  scinder entre deux pages : une instruction d'une page et demie ferait
//  boucler `MultiPage` jusqu'à `TooManyPagesException` — et ce n'est pas un
//  document tronqué qu'on obtient, c'est AUCUN document. Le texte est donc
//  posé en paragraphes libres, qui se coupent naturellement. Même raison que
//  la table paginée de `tutelle_fiche_pdf_service`.
// ════════════════════════════════════════════════════════════════════════════

class TutelleInstructionPdfService {
  /// L'instruction telle qu'elle a été adressée.
  ///
  /// [emiseLe] est passée par l'appelant plutôt que relue ici : le document
  /// doit porter l'heure de l'ENVOI, pas celle de l'impression. Un ministère
  /// qui réédite sa pièce trois mois plus tard doit retrouver la même date.
  static Future<Uint8List> build({
    required String objet,
    required String corps,
    required String groupeNom,
    required List<DestinataireTutelle> destinataires,
    required DateTime emiseLe,
    String? tutelle,
    String? signataire,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final couleur = pdfCouleurTutelle(tutelle);
    final titre = 'Instruction — $objet';

    // Le groupe d'abord, les établissements ensuite : c'est l'ordre
    // hiérarchique de l'adresse, et celui dans lequel une administration lit
    // un bordereau.
    final auGroupe = [for (final d in destinataires) if (d.estLeGroupe) d];
    final auxEcoles = [for (final d in destinataires) if (!d.estLeGroupe) d]
      ..sort((a, b) => (a.ecole ?? '').compareTo(b.ecole ?? ''));

    final doc = pw.Document(
      title: titre,
      author: OfficialPdfKit.issuer?.name ?? 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Instruction de tutelle adressée à $groupeNom',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'INSTRUCTION', title: titre),
      footer: (ctx) => OfficialPdfKit.footer(
          ctx, f, pdfHorodatage(emiseLe), pdfReference(emiseLe)),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'INSTRUCTION DE TUTELLE '
                '${sigleTutelleOuTiret(tutelle)}',
            title: objet,
            line1: 'Adressée à $groupeNom',
            line2: 'Émise le ${pdfDateLongue(emiseLe)}',
            statusBadge: 'Adressée'),
        pw.SizedBox(height: 16),

        // ── Les destinataires, nommés ────────────────────────────────────
        // C'est CE bloc qui fait la valeur de la pièce. Un document qui dit
        // « adressé au réseau » n'oppose rien à personne.
        pdfFicheBloc(f,
            titre: 'DESTINATAIRES',
            couleur: couleur,
            lignes: [
              for (final d in auGroupe)
                ('Administration du groupe', _nomEtFonction(d)),
              for (final d in auxEcoles)
                (pdfOuTiret(d.ecole), _nomEtFonction(d)),
              if (destinataires.isEmpty)
                ('Aucun destinataire', '—'),
            ]),
        pw.SizedBox(height: 16),

        // ── Le texte, en paragraphes libres (cf. l'en-tête) ──────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.Text('TEXTE DE L’INSTRUCTION',
              style: pw.TextStyle(
                  font: f.bold,
                  fontSize: 8,
                  color: kPdfNavy,
                  letterSpacing: 0.8)),
        ),
        pw.SizedBox(height: 7),
        for (final paragraphe in _paragraphes(corps))
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(28, 0, 28, 8),
            child: pw.Text(paragraphe,
                textAlign: pw.TextAlign.justify,
                style: pw.TextStyle(
                    font: f.regular,
                    fontSize: 10,
                    height: 1.5,
                    color: kPdfText)),
          ),
        pw.SizedBox(height: 14),

        _portee(f, nombre: destinataires.length),

        if ((signataire ?? '').trim().isNotEmpty) ...[
          pw.SizedBox(height: 22),
          _bandeauSignature(f, signataire!.trim(), emiseLe),
        ],
      ],
    ));

    return doc.save();
  }

  /// « Nom (fonction) », ou la fonction seule si le nom manque.
  ///
  /// ⚠️ Jamais l'identifiant : un UUID sur une pièce administrative n'apprend
  /// rien au lecteur et ne l'aide pas à savoir si l'on s'est trompé de
  /// personne. Même règle qu'à l'écran (`DestinataireTutelle.libelle`).
  static String _nomEtFonction(DestinataireTutelle d) {
    final nom = (d.nom ?? '').trim();
    return nom.isEmpty ? d.fonction : '$nom  ·  ${d.fonction}';
  }

  /// Découpe le corps en paragraphes, en préservant les lignes vides voulues.
  ///
  /// Un texte administratif se lit par alinéas. Le rendre d'un bloc rendrait
  /// une instruction de dix lignes illisible sur le papier.
  static List<String> _paragraphes(String corps) {
    final net = corps.replaceAll('\r\n', '\n').trim();
    if (net.isEmpty) return const ['—'];
    return [
      for (final p in net.split(RegExp(r'\n\s*\n')))
        if (p.trim().isNotEmpty) p.trim().replaceAll('\n', ' '),
    ];
  }

  /// L'encart de portée — propre à l'instruction.
  ///
  /// ⚠️ Il ne réutilise PAS `pdfEncartPortee` : celui-là parle d'effectifs
  /// agrégés et d'agréments, ce qui n'a aucun sens ici. Une phrase générique
  /// recyclée sous un en-tête officiel est exactement ce que cet encart existe
  /// pour empêcher.
  static pw.Widget _portee(PdfFonts f, {required int nombre}) {
    final lignes = <String>[
      nombre == 0
          ? 'Aucun destinataire n’a été retenu au moment de l’envoi.'
          : 'Adressée à $nombre destinataire${nombre > 1 ? 's' : ''}, '
              'nommément désigné${nombre > 1 ? 's' : ''} ci-dessus.',
      'Ce document atteste de ce qui a été ADRESSÉ, et de la date à laquelle '
          'l’envoi a été effectué. Il ne vaut pas accusé de réception : la '
          'plateforme n’établit pas la lecture d’un message.',
      'Chaque destinataire a reçu sa propre copie dans sa messagerie et peut y '
          'répondre individuellement.',
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

  /// Le pied de signature — à droite, comme sur un acte.
  static pw.Widget _bandeauSignature(PdfFonts f, String qui, DateTime quand) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 210,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Fait le ${pdfDateLongue(quand)}',
                      style: pw.TextStyle(
                          font: f.regular, fontSize: 9, color: kPdfMuted)),
                  pw.SizedBox(height: 4),
                  pw.Text(qui,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          font: f.bold, fontSize: 10, color: kPdfText)),
                  pw.SizedBox(height: 46),
                  pw.Container(height: 0.8, color: kPdfBorder),
                  pw.SizedBox(height: 4),
                  pw.Text('Signature et cachet',
                      style: pw.TextStyle(
                          font: f.regular, fontSize: 8, color: kPdfMuted)),
                ],
              ),
            ),
          ],
        ),
      );
}
