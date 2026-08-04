import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/attestation_kit.dart';
import '../../../core/services/official_pdf_kit.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE REÇU DE PAIEMENT
//
//  L'application comptait une trentaine d'exports PDF — bulletins, convocations,
//  attestations, bordereaux de paie — et AUCUN pour un encaissement. Or au
//  Congo le reçu EST la preuve : un parent qui verse 5 000 F et repart les
//  mains vides revient trois mois plus tard contester, et l'école n'a rien à
//  lui opposer.
//
//  ⚠️ `pw.Page`, jamais `MultiPage` : un reçu tient sur une page, et le
//  `frame()` du kit officiel ne se scinde pas (TooManyPages).
// ════════════════════════════════════════════════════════════════════════════

/// Ce qu'un reçu doit porter pour faire preuve.
class RecuPaiement {
  const RecuPaiement({
    required this.numero,
    required this.eleve,
    required this.classe,
    required this.montant,
    required this.date,
    required this.methode,
    required this.encaissePar,
    this.matricule,
    this.motifFrais,
    this.annuleLe,
    this.motifAnnulation,
  });

  final String numero, eleve, classe, methode, encaissePar;
  final int montant;
  final DateTime date;
  final String? matricule, motifFrais, annuleLe, motifAnnulation;

  bool get estAnnule => annuleLe != null;
}

final _montant = NumberFormat.decimalPattern('fr');

String _xaf(int v) => '${_montant.format(v)} FCFA';

Future<Uint8List> construireRecuPaiement({required RecuPaiement recu}) async {
  final fonts = await OfficialPdfKit.loadFonts();
  final logo = await OfficialPdfKit.loadLogo();
  final issuer = OfficialPdfKit.issuer;

  pw.Widget ligne(String label, String valeur) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: fonts.medium, fontSize: 10, color: kPdfMuted)),
          ),
          pw.Expanded(
            child: pw.Text(valeur,
                style: pw.TextStyle(font: fonts.bold, fontSize: 11)),
          ),
        ]),
      );

  return AttestationKit.build(
    titre: 'REÇU DE PAIEMENT',
    kicker: 'Pièce comptable',
    badge: 'REÇU',
    emetteur: issuer?.name ?? 'Établissement',
    sousTitre: issuer?.subtitle ?? '',
    fonts: fonts,
    logo: logo,
    quand: recu.date,
    corps: [
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: pdfTint(kPdfNavy, 0.06),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('N° ${recu.numero}',
                style: pw.TextStyle(font: fonts.bold, fontSize: 12)),
            pw.Text(_xaf(recu.montant),
                style: pw.TextStyle(
                    font: fonts.bold, fontSize: 16, color: kPdfGreen)),
          ],
        ),
      ),
      pw.SizedBox(height: 18),
      ligne('Élève', recu.eleve),
      if (recu.matricule != null) ligne('Matricule', recu.matricule!),
      ligne('Classe', recu.classe),
      ligne('Objet', recu.motifFrais ?? 'Frais scolaires'),
      ligne('Date', AttestationKit.jourLong.format(recu.date)),
      ligne('Mode de règlement', recu.methode),
      ligne('Encaissé par', recu.encaissePar),
      if (recu.estAnnule) ...[
        pw.SizedBox(height: 16),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: pdfTint(kPdfRed, 0.08),
            border: pw.Border.all(color: kPdfRed, width: 0.8),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('PAIEMENT ANNULÉ le ${recu.annuleLe}',
                  style: pw.TextStyle(
                      font: fonts.bold, fontSize: 11, color: kPdfRed)),
              if (recu.motifAnnulation != null)
                pw.Text(recu.motifAnnulation!,
                    style: pw.TextStyle(font: fonts.regular, fontSize: 10)),
            ],
          ),
        ),
      ],
    ],
  );
}
