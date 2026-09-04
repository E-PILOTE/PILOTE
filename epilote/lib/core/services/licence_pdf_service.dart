import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'official_pdf_kit.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FICHE D'UNE LICENCE DE TUTELLE — le document qu'on met dans un dossier
//
//  ── POURQUOI ELLE MANQUAIT ────────────────────────────────────────────────
//  Tout se sortait en PDF dans cette plateforme — abonnements, factures, reçus,
//  plans, modules, groupes — SAUF la pièce la plus chère : le marché à quarante
//  millions. Le fondateur : « et bien plus, l'impression etc… ».
//
//  ── ⚠️ CE QUE CE DOCUMENT EST, ET N'EST PAS ───────────────────────────────
//  C'est une FICHE DE SUIVI, pas un contrat et pas une facture. Elle récapitule
//  ce qui a été convenu et où en est l'exécution ; elle n'engage rien par
//  elle-même. Le pied de page le dit, et il ne doit pas disparaître : un
//  document officiel qu'on peut prendre pour un titre de créance finit par être
//  produit comme tel.
//
//  ⚠️ ELLE PORTE LE SOLDE, ET C'EST VOULU. Un état d'exécution qui tairait le
//  reste à régler serait une plaquette, pas un suivi. Mais il est présenté
//  comme un ÉCHÉANCIER — trois lignes, dû / avance / encaissé — et non comme
//  une relance : un marché public se règle en tranches, et le retard de mandat
//  est la norme, pas l'incident.
// ════════════════════════════════════════════════════════════════════════════

/// Ce qu'il faut pour imprimer une licence, quel que soit l'écran d'origine.
///
/// ⚠️ Un type de transport, et non le modèle de l'un des deux espaces : la
/// fiche se demande depuis l'espace du ministère (`LicenceDuGroupe`) ET depuis
/// celui du fondateur (`LicenceTutelle`). Faire dépendre le PDF de l'un des
/// deux aurait obligé à en écrire un second le jour où l'autre le demande.
class LicenceAImprimer {
  const LicenceAImprimer({
    required this.ministere,
    required this.intitule,
    required this.statut,
    required this.statutLabel,
    required this.dateDebut,
    required this.dateFin,
    required this.montantXaf,
    required this.avanceXaf,
    required this.montantRegleXaf,
    this.sigleTutelle,
    this.referenceMarche,
    this.signataire,
    this.notes,
    this.motifStatut,
    this.nbEtablissements,
    this.nbEleves,
  });

  final String ministere, intitule, statut, statutLabel;
  final String? sigleTutelle, referenceMarche, signataire, notes, motifStatut;
  final DateTime dateDebut, dateFin;
  final int montantXaf, avanceXaf, montantRegleXaf;
  final int? nbEtablissements, nbEleves;

  int get soldeXaf => montantXaf - montantRegleXaf;

  int get dureeJours {
    final d = dateFin.difference(dateDebut).inDays;
    return d < 1 ? 1 : d;
  }

  /// Même tolérance que les deux espaces : un marché annuel vaut son montant.
  int get annuelXaf => (dureeJours - 365).abs() <= 15
      ? montantXaf
      : (montantXaf * 365 / dureeJours).round();

  int get moisCouverts =>
      (dureeJours - 365).abs() <= 15 ? 12 : (dureeJours / 30.44).round();

  int get mensuelXaf => (montantXaf / (moisCouverts < 1 ? 1 : moisCouverts)).round();

  double get partReglee =>
      montantXaf <= 0 ? 0 : (montantRegleXaf / montantXaf).clamp(0.0, 1.0);

  double get partEcoulee =>
      (DateTime.now().difference(dateDebut).inDays / dureeJours).clamp(0.0, 1.0);
}

const _navy = PdfColor.fromInt(0xFF1E3A5F);
const _green = PdfColor.fromInt(0xFF009A44);
const _orange = PdfColor.fromInt(0xFFFF6B35);
const _red = PdfColor.fromInt(0xFFDC143C);
const _muted = PdfColor.fromInt(0xFF64748B);
const _border = PdfColor.fromInt(0xFFE2E8F0);
const _surface = PdfColor.fromInt(0xFFF0F4F8);
const _text = PdfColor.fromInt(0xFF0F172A);

PdfColor _couleurStatut(String s) => switch (s) {
      'active' => _green,
      'suspendue' => _red,
      'echue' => _orange,
      'resiliee' => _text,
      _ => _muted,
    };

class LicencePdfService {
  static final _f = NumberFormat('#,##0', 'fr_FR');
  static String _xaf(int v) => '${_f.format(v).replaceAll(',', ' ')} FCFA';
  static String _d(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  static Future<Uint8List> buildPdf(LicenceAImprimer l) async {
    // Polices EMBARQUÉES : `PdfGoogleFonts` retomberait sans bruit sur
    // Helvetica hors ligne — le cas normal d'un poste congolais.
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final maintenant = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());
    final ref = 'LIC-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
    final couleur = _couleurStatut(l.statut);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => ctx.pageNumber == 1
            ? OfficialPdfKit.header(logo, f, badge: 'LICENCE DE TUTELLE')
            : OfficialPdfKit.continuationHeader(f,
                title: 'Licence de tutelle'),
        footer: (ctx) => OfficialPdfKit.footer(ctx, f, maintenant, ref),
        build: (ctx) => [
          pw.SizedBox(height: 14),
          OfficialPdfKit.titleBlock(
            f,
            kicker: l.sigleTutelle == null
                ? 'MINISTÈRE DE TUTELLE'
                : 'MINISTÈRE DE TUTELLE · ${l.sigleTutelle}',
            title: l.ministere,
            line1: l.intitule,
            line2: l.referenceMarche == null
                ? 'Période : ${_d(l.dateDebut)} au ${_d(l.dateFin)}'
                : 'Marché ${l.referenceMarche} · '
                    '${_d(l.dateDebut)} au ${_d(l.dateFin)}',
            statusBadge: l.statutLabel.toUpperCase(),
          ),
          pw.SizedBox(height: 16),
          _blocMontant(f, l, couleur),
          pw.SizedBox(height: 14),
          _echeancier(f, l),
          pw.SizedBox(height: 14),
          _execution(f, l, couleur),
          if (l.nbEtablissements != null || l.nbEleves != null) ...[
            pw.SizedBox(height: 14),
            _couverture(f, l),
          ],
          if (l.motifStatut != null && l.motifStatut!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _encadre(f, 'DERNIÈRE DÉCISION', l.motifStatut!.trim(), couleur),
          ],
          if (l.notes != null && l.notes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _encadre(f, 'NOTES', l.notes!.trim(), _muted),
          ],
          pw.SizedBox(height: 16),
          _mentionAcces(f),
          pw.SizedBox(height: 18),
          _signatures(f, l),
        ],
      ),
    );
    return doc.save();
  }

  // ── 1. Le montant, en grand ─────────────────────────────────────────────
  static pw.Widget _blocMontant(
          PdfFonts f, LicenceAImprimer l, PdfColor couleur) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: _surface,
            border: pw.Border.all(color: _border),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MONTANT DU MARCHÉ',
                        style: pw.TextStyle(
                            font: f.bold, fontSize: 8, color: _muted)),
                    pw.SizedBox(height: 3),
                    // ⚠️ Le montant EXACT. Sur une fiche de marché, un chiffre
                    // arrondi ne se rapproche d'aucun mandat de paiement.
                    pw.Text(_xaf(l.montantXaf),
                        style: pw.TextStyle(
                            font: f.bold, fontSize: 22, color: _text)),
                  ]),
            ),
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _paire(f, 'par an', _xaf(l.annuelXaf)),
                  pw.SizedBox(height: 5),
                  _paire(f, 'par mois (${l.moisCouverts} mois)',
                      _xaf(l.mensuelXaf)),
                ]),
          ]),
        ),
      );

  // ── 2. L'échéancier ─────────────────────────────────────────────────────
  static pw.Widget _echeancier(PdfFonts f, LicenceAImprimer l) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ÉCHÉANCIER',
                  style:
                      pw.TextStyle(font: f.bold, fontSize: 9, color: _muted)),
              pw.SizedBox(height: 8),
              OfficialPdfKit.table(
                fonts: f,
                headers: const ['Poste', 'Montant'],
                flex: const [3, 2],
                rows: [
                  ['Montant du marché', _xaf(l.montantXaf)],
                  ['Avance de démarrage', _xaf(l.avanceXaf)],
                  ['Encaissé à ce jour', _xaf(l.montantRegleXaf)],
                  [
                    l.soldeXaf <= 0 ? 'Solde' : 'Reste à encaisser',
                    _xaf(l.soldeXaf < 0 ? 0 : l.soldeXaf)
                  ],
                ],
              ),
            ]),
      );

  // ── 3. Où en est l'exécution ────────────────────────────────────────────
  static pw.Widget _execution(
      PdfFonts f, LicenceAImprimer l, PdfColor couleur) {
    final retard = l.partEcoulee - l.partReglee;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('EXÉCUTION',
            style: pw.TextStyle(font: f.bold, fontSize: 9, color: _muted)),
        pw.SizedBox(height: 8),
        // ⚠️ LES DEUX BARRES. Le temps consommé et l'argent encaissé ne
        // racontent pas la même histoire ; une seule des deux ne dit rien.
        _barre(f, 'Période écoulée', l.partEcoulee, _navy),
        pw.SizedBox(height: 6),
        _barre(f, 'Marché réglé', l.partReglee,
            retard > 0.15 ? _orange : _green),
        pw.SizedBox(height: 8),
        pw.Text(
            l.montantXaf <= 0
                ? 'Ce marché ne porte aucun montant.'
                : retard > 0.15
                    ? 'Le règlement accuse ${(retard * 100).round()} points de '
                        'retard sur la période consommée.'
                    : 'Le règlement suit la période consommée.',
            style: pw.TextStyle(font: f.regular, fontSize: 9, color: _muted)),
      ]),
    );
  }

  // ── 4. Ce que la licence couvre ─────────────────────────────────────────
  static pw.Widget _couverture(PdfFonts f, LicenceAImprimer l) {
    final cells = <PdfKpi>[
      if (l.nbEtablissements != null)
        PdfKpi('Établissements couverts', '${l.nbEtablissements}', _navy),
      if (l.nbEleves != null)
        PdfKpi('Élèves', _f.format(l.nbEleves).replaceAll(',', ' '), _green),
      if (l.nbEtablissements != null && l.nbEtablissements! > 0)
        PdfKpi('Par établissement / an',
            _xaf((l.annuelXaf / l.nbEtablissements!).round()), _orange),
    ];
    return OfficialPdfKit.kpiGrid(f, cells);
  }

  // ── 5. La mention qui ne doit pas sauter ────────────────────────────────
  static pw.Widget _mentionAcces(PdfFonts f) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(11),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF0FDF4),
            border: pw.Border.all(color: const PdfColor.fromInt(0xFFBBF7D0)),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            'Document de suivi — il récapitule les conditions convenues et '
            'l’état de leur exécution. Il ne constitue ni un contrat ni une '
            'facture. L’accès du ministère et de son réseau à la plateforme ne '
            'dépend pas de l’état de règlement de cette licence.',
            style: pw.TextStyle(font: f.regular, fontSize: 8.5, color: _muted),
          ),
        ),
      );

  // ── 6. Les signatures ───────────────────────────────────────────────────
  static pw.Widget _signatures(PdfFonts f, LicenceAImprimer l) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Row(children: [
          pw.Expanded(child: _cadreSignature(f, 'Pour E-PILOTE CONGO', null)),
          pw.SizedBox(width: 18),
          pw.Expanded(
              child: _cadreSignature(
                  f, 'Pour ${l.ministere}', l.signataire)),
        ]),
      );

  static pw.Widget _cadreSignature(PdfFonts f, String titre, String? nom) =>
      pw.Container(
        height: 78,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(titre,
                  style:
                      pw.TextStyle(font: f.bold, fontSize: 8.5, color: _muted)),
              if (nom != null && nom.trim().isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(nom,
                    style: pw.TextStyle(
                        font: f.medium, fontSize: 9.5, color: _text)),
              ],
            ]),
      );

  // ── Pièces ──────────────────────────────────────────────────────────────
  static pw.Widget _paire(PdfFonts f, String label, String valeur) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(label,
              style: pw.TextStyle(font: f.regular, fontSize: 7.5, color: _muted)),
          pw.Text(valeur,
              style: pw.TextStyle(font: f.bold, fontSize: 11, color: _text)),
        ],
      );

  static pw.Widget _barre(
          PdfFonts f, String label, double valeur, PdfColor couleur) =>
      pw.Row(children: [
        pw.SizedBox(
          width: 92,
          child: pw.Text(label,
              style:
                  pw.TextStyle(font: f.regular, fontSize: 8.5, color: _muted)),
        ),
        // ⚠️ `FractionallySizedBox` n'existe pas dans le paquet `pdf` : la
        // barre se compose de DEUX `Expanded` dont les flex portent la
        // proportion. Multiplier par 1000 garde deux décimales de précision
        // sans passer par des doubles dans un flex (qui n'accepte qu'un int).
        pw.Expanded(
          child: pw.Container(
            height: 8,
            decoration: pw.BoxDecoration(
                color: _surface, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Row(children: [
              pw.Expanded(
                flex: (valeur.clamp(0.0, 1.0) * 1000).round(),
                child: pw.Container(
                    decoration: pw.BoxDecoration(
                        color: couleur,
                        borderRadius: pw.BorderRadius.circular(4))),
              ),
              pw.Expanded(
                flex: 1000 - (valeur.clamp(0.0, 1.0) * 1000).round(),
                child: pw.SizedBox(),
              ),
            ]),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.SizedBox(
          width: 34,
          child: pw.Text('${(valeur * 100).round()} %',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: f.bold, fontSize: 8.5, color: _text)),
        ),
      ]);

  static pw.Widget _encadre(
          PdfFonts f, String titre, String texte, PdfColor couleur) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(11),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(titre,
                    style: pw.TextStyle(
                        font: f.bold, fontSize: 8, color: couleur)),
                pw.SizedBox(height: 3),
                pw.Text(texte,
                    style: pw.TextStyle(
                        font: f.regular, fontSize: 9, color: _text)),
              ]),
        ),
      );

  static Future<void> imprimer(LicenceAImprimer l) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildPdf(l),
      name: 'Licence_${l.ministere.replaceAll(RegExp(r'[^\w]'), '_')}'
          '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
