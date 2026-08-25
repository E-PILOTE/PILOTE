import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../finance/providers/decompte_du_provider.dart';
import '../providers/inscriptions_data_provider.dart';
import '../models/tutor_draft.dart';
import '../../../core/utils/ine.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FICHE D'INSCRIPTION — le papier que la famille emporte.
//
//  ── POURQUOI ELLE MANQUAIT ─────────────────────────────────────────────────
//  L'école ne délivrait AUCUN document. Le module « Documents » ne fait que
//  contrôler les pièces REÇUES (acte de naissance, certificat médical…) ; rien
//  ne sortait. Une famille qui venait d'inscrire son enfant repartait sans
//  trace écrite : ni matricule, ni classe, ni date, rien à présenter en cas de
//  contestation, et rien à rapporter le jour où le dossier serait contrôlé.
//
//  Cette fiche est le récépissé du guichet. Elle porte ce qui engage l'école :
//  l'identité de l'enfant, son matricule, sa classe, l'année, les contacts de
//  la famille, l'état du dossier de pièces, et deux signatures.
//
//  ── UNE FICHE N'EST PAS UN CERTIFICAT DE SCOLARITÉ ─────────────────────────
//  Tant que l'inscription est « en attente de validation », le document le dit
//  en toutes lettres et son bandeau change : on ne remet pas à une famille un
//  papier qui laisserait croire que l'enfant est scolarisé alors que la
//  direction n'a pas encore statué.
//
//  ── ET ELLE PORTE L'ARGENT ─────────────────────────────────────────────────
//  Elle ne le portait pas. Une famille repartait avec un papier qui disait la
//  classe et le matricule, et pas un mot de ce qu'elle devait — alors que
//  c'est la première question posée au guichet. Le décompte y figure donc
//  ligne par ligne (`DecompteDu`) : ce qui est dû, ce qui a été versé, ce qui
//  reste, et la remise s'il y en a une.
//
//  ⚠️ Le bloc est OMIS quand aucun barème n'est publié, jamais rempli de zéros.
//  « 0 F » se lirait « scolarité gratuite », et trente écoles publiques du
//  réseau n'ont aucun tarif posé : elles délivreraient toutes une fiche
//  affirmant la gratuité.
// ════════════════════════════════════════════════════════════════════════════

/// Un dossier à imprimer — l'unité d'un tirage groupé.
typedef FicheEntree = ({
  InscriptionRow row,
  StudentDossier dossier,
  DecompteDu? frais,
});

class InscriptionFicheService {
  static Future<Uint8List> buildPdf({
    required InscriptionRow row,
    required StudentDossier dossier,
    String? schoolName,
    String? yearLabel,
    DecompteDu? frais,
  }) =>
      buildLot(
        [(row: row, dossier: dossier, frais: frais)],
        schoolName: schoolName,
        yearLabel: yearLabel,
      );

  /// Un seul document, une fiche par dossier.
  ///
  /// ── POURQUOI CE TIRAGE GROUPÉ ──────────────────────────────────────────────
  /// Une rentrée congolaise, c'est quarante familles au guichet le même matin.
  /// La fiche ne s'obtenait qu'en ouvrant un dossier, en cliquant, en attendant
  /// l'aperçu, en imprimant, en fermant — quarante fois. Le secrétariat
  /// renonçait, et les familles repartaient sans papier : le document existait
  /// et ne sortait pas.
  ///
  /// ⚠️ Les polices et l'emblème sont chargés UNE fois pour tout le lot. Les
  /// recharger par fiche multipliait le coût par quarante sur des postes que
  /// l'on sait lents.
  static Future<Uint8List> buildLot(
    List<FicheEntree> entrees, {
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final doc = pw.Document(
      title: entrees.length == 1
          ? 'Fiche d\'inscription — ${entrees.first.row.fullName}'
          : 'Fiches d\'inscription (${entrees.length})',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Fiche d\'inscription',
    );

    for (final e in entrees) {
      _addFiche(doc, e,
          fonts: f,
          logo: logo,
          now: now,
          ref: ref,
          genDate: genDate,
          schoolName: schoolName,
          yearLabel: yearLabel);
    }

    return doc.save();
  }

  static void _addFiche(
    pw.Document doc,
    FicheEntree e, {
    required PdfFonts fonts,
    required dynamic logo,
    required String now,
    required String ref,
    required String genDate,
    String? schoolName,
    String? yearLabel,
  }) {
    final f = fonts;
    final row = e.row;
    final dossier = e.dossier;
    final frais = e.frais;
    final validated = row.status == 'active';
    final pending = row.status == 'pending_validation';

    // ⚠️ `MultiPage` et non `Page`, DEPUIS QUE LE BLOC FRAIS EXISTE.
    //
    // Sans frais, la fiche mesurait environ 690 pt sur les 842 d'une A4 : elle
    // tenait, et une page fixe suffisait. Le décompte ajoute jusqu'à huit
    // lignes de tableau et deux mentions — de quoi franchir le bord. Une école
    // privée avec inscription + APE + mensualité + cantine + transport + tenue,
    // sur un dossier à trois tuteurs, dépasse la page ; les signatures et le
    // pied seraient sortis du papier sans qu'aucune erreur ne le dise.
    //
    // C'est exactement le piège déjà rencontré sur l'export des inscriptions
    // (cf. `enrollment_pdf_shared.dart`) : ce qui déborde ne prévient pas.
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      // L'emblème et le bandeau tricolore ne s'impriment qu'en première page ;
      // une éventuelle seconde reçoit le bandeau de continuation.
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'FICHE\nD\'INSCRIPTION',
          title: 'Fiche d\'inscription — ${row.fullName}'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
          pw.SizedBox(height: 14),
          OfficialPdfKit.titleBlock(
            f,
            kicker: 'ANNÉE SCOLAIRE ${yearLabel ?? ''}'.trim(),
            title: row.fullName,
            line1: [
              if (row.ine != null) 'INE : ${formatIne(row.ine)}',
              if (row.matricule.isNotEmpty) 'Matricule : ${row.matricule}',
              'Classe : ${row.className}',
            ].join('   ·   '),
            line2: schoolName,
            // Court À DESSEIN : le cartouche du chrome officiel ne borne pas
            // la pastille, et « EN ATTENTE DE VALIDATION » débordait du cadre.
            // Le sens complet est porté par la mention en bas de page.
            statusBadge: validated
                ? 'VALIDÉE'
                : pending
                    ? 'EN ATTENTE'
                    : _statusLabel(row.status).toUpperCase(),
          ),
          pw.SizedBox(height: 16),
          _identity(f, row, dossier),
          pw.SizedBox(height: 14),
          _schooling(f, row, yearLabel),
          pw.SizedBox(height: 14),
          _family(f, dossier),
          if (frais != null && !frais.vide) ...[
            pw.SizedBox(height: 14),
            _frais(f, frais),
          ],
          pw.SizedBox(height: 14),
          _notice(f, pending: pending),
          // `Spacer` ne peut plus pousser les signatures en bas : dans un
          // `MultiPage`, la hauteur restante n'est pas connue à la construction.
          // Un espace fixe suffit — et vaut mieux qu'un document qui ne sort
          // pas du tout.
          pw.SizedBox(height: 26),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _signature(f, 'Le parent ou tuteur'),
                _signature(f, 'Le chef d\'établissement'),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28),
            child: pw.Text('Établie le $genDate.',
                style: pw.TextStyle(
                    font: f.regular, fontSize: 8.5, color: kPdfMuted)),
          ),
          pw.SizedBox(height: 8),
      ],
    ));
  }

  // ── Blocs ────────────────────────────────────────────────────────────────

  static pw.Widget _identity(
      PdfFonts f, InscriptionRow row, StudentDossier d) {
    final dob = d.dob;
    return OfficialPdfKit.frame(
      title: 'IDENTITÉ DE L\'ÉLÈVE',
      color: kPdfNavy,
      fonts: f,
      child: _rows(f, [
        ('Nom et prénom', row.fullName),
        // L'INE d'abord : c'est le numéro que la famille devra présenter si
        // l'enfant change d'établissement. Le matricule, lui, ne vaut que
        // dans cette école — il ne servira à rien ailleurs.
        (
          'Identifiant national',
          row.ine == null
              ? 'Attribué à la synchronisation'
              : formatIne(row.ine)
        ),
        ('Matricule (école)', row.matricule),
        ('Sexe', switch (row.gender) { 'F' => 'Féminin', 'M' => 'Masculin', _ => '—' }),
        (
          'Date de naissance',
          dob == null ? '—' : DateFormat('dd/MM/yyyy').format(dob)
        ),
        ('Lieu de naissance', _or(d.s('place_of_birth'))),
        ('Nationalité', _or(d.s('nationality'))),
        ('Adresse', _or([d.s('address'), d.s('city')]
            .where((v) => v.isNotEmpty)
            .join(', '))),
      ]),
    );
  }

  static pw.Widget _schooling(
      PdfFonts f, InscriptionRow row, String? yearLabel) {
    return OfficialPdfKit.frame(
      title: 'SCOLARITÉ',
      color: kPdfNavy,
      fonts: f,
      child: _rows(f, [
        ('Année scolaire', _or(yearLabel)),
        ('Classe', row.className),
        if (row.filiereLabel != null) ('Filière', row.filiereLabel!),
        ('Type d\'inscription', _typeLabel(row.inscriptionType)),
        if (row.isRepeating) ('Situation', 'Redoublant'),
        (
          'Date d\'inscription',
          row.enrollmentDate == null
              ? '—'
              : DateFormat('dd/MM/yyyy').format(row.enrollmentDate!)
        ),
        ('Statut du dossier', _statusLabel(row.status)),
      ]),
    );
  }

  static pw.Widget _family(PdfFonts f, StudentDossier d) {
    // Une fiche sans contact serait un papier sans utilité : c'est par ce
    // numéro que l'école joint la famille.
    if (d.tutors.isEmpty) {
      return OfficialPdfKit.frame(
        title: 'PARENTS ET TUTEURS',
        color: kPdfNavy,
        fonts: f,
        child: _rows(f, [('Contact', 'Aucun contact enregistré')]),
      );
    }
    return OfficialPdfKit.frame(
      title: 'PARENTS ET TUTEURS',
      color: kPdfNavy,
      fonts: f,
      child: OfficialPdfKit.table(
        headers: const ['Nom', 'Lien', 'Téléphone', 'Contact principal'],
        rows: [
          for (final t in d.tutors)
            [
              '${t.firstName} ${t.lastName}'.trim(),
              tutorRelationshipLabel(t.relationship),
              _or(t.phonePrimary),
              t.isPrimary ? 'Oui' : '',
            ],
        ],
        fonts: f,
        flex: const [24, 14, 16, 14],
        leftAlignCols: const {1},
      ),
    );
  }

  /// Le décompte, tel qu'on le lit sur un comptoir.
  ///
  /// ⚠️ Le tableau montre le tarif PLEIN puis la remise sur sa propre ligne,
  /// plutôt que des montants déjà réduits. Une famille exonérée doit pouvoir
  /// vérifier que la remise annoncée est bien celle qui a été appliquée — un
  /// tarif silencieusement diminué ne se contrôle pas, et se conteste mal.
  static pw.Widget _frais(PdfFonts f, DecompteDu d) {
    final rows = <List<String>>[
      for (final l in d.lignes)
        [
          l.feeType == 'mensualite' && d.mois > 1
              ? '${l.libelle} (${d.mois} mois)'
              : l.libelle,
          _xaf(l.montant),
        ],
    ];
    if (d.estExonere) {
      rows.add(['Exonération de scolarité (${d.exoneration} %)',
        '− ${_xaf(d.remise)}']);
    }
    rows.add(['TOTAL DÛ', _xaf(d.net)]);
    rows.add(['Déjà versé', _xaf(d.verse)]);
    rows.add(['RESTE À RÉGLER', _xaf(d.reste)]);

    return pw.Column(children: [
      OfficialPdfKit.frame(
        title: 'FRAIS DE SCOLARITÉ',
        color: kPdfNavy,
        fonts: f,
        child: OfficialPdfKit.table(
          headers: const ['Désignation', 'Montant (FCFA)'],
          rows: rows,
          fonts: f,
          flex: const [46, 18],
          leftAlignCols: const {0},
        ),
      ),
      if (d.estExonere && (d.motifExoneration ?? '').trim().isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 30, right: 30, top: 5),
          child: pw.Text('Motif de l\'exonération : ${d.motifExoneration!.trim()}',
              style: pw.TextStyle(
                  font: f.regular, fontSize: 8.5, color: kPdfMuted)),
        ),
      // Les frais d'examen sont absents à dessein : ils ne concernent que les
      // candidats inscrits à une session, et le module Examens les facture
      // séparément. Le dire évite qu'une famille de terminale croie sa fiche
      // incomplète — ou, pire, qu'elle croie n'avoir plus rien à payer.
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 30, right: 30, top: 5),
        child: pw.Text(
            'Les frais d\'examen ne figurent pas sur cette fiche : ils sont '
            'réclamés séparément aux candidats inscrits à une session.',
            style:
                pw.TextStyle(font: f.regular, fontSize: 8.5, color: kPdfMuted)),
      ),
    ]);
  }

  /// Un montant que l'on peut recopier sur un reçu manuscrit : espace fine
  /// tous les trois chiffres, jamais de séparateur décimal — le franc CFA n'a
  /// pas de centime.
  static String _xaf(int v) {
    final s = v.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  static pw.Widget _notice(PdfFonts f, {required bool pending}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(11),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: kPdfNavy, width: 0.6),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            pending
                ? 'Ce document atteste du DÉPÔT du dossier d\'inscription. Il ne '
                    'vaut pas certificat de scolarité : l\'inscription doit encore '
                    'être validée par la direction de l\'établissement. Conservez-le '
                    'et présentez-le à toute demande.'
                : 'Conservez cette fiche : elle porte l\'identifiant national de '
                    'l\'élève — à présenter en cas de changement d\'établissement, '
                    'pour que sa scolarité ne reparte pas de zéro — ainsi que son '
                    'matricule, sa classe et les contacts déclarés. Signalez à '
                    'l\'établissement tout changement d\'adresse ou de téléphone.',
            style: pw.TextStyle(
                font: f.regular, fontSize: 9, lineSpacing: 2, color: kPdfText),
          ),
        ),
      );

  static pw.Widget _rows(PdfFonts f, List<(String, String)> rows) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 2),
        child: pw.Column(
          children: [
            for (final (label, value) in rows)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 150,
                      child: pw.Text(label,
                          style: pw.TextStyle(
                              font: f.regular,
                              fontSize: 9.5,
                              color: kPdfMuted)),
                    ),
                    pw.Expanded(
                      child: pw.Text(_or(value),
                          style: pw.TextStyle(
                              font: f.medium, fontSize: 9.5, color: kPdfText)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  static pw.Widget _signature(PdfFonts f, String label) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: f.medium, fontSize: 9.5)),
          pw.SizedBox(height: 38),
          pw.Container(width: 165, height: 0.6, color: PdfColors.grey600),
        ],
      );

  static String _or(String? v) =>
      (v == null || v.trim().isEmpty) ? '—' : v.trim();

  static String _typeLabel(String t) => switch (t) {
        'new' => 'Nouvelle inscription',
        'reinscription' => 'Réinscription',
        'transfer' => 'Transfert',
        _ => t,
      };

  static String _statusLabel(String s) => switch (s) {
        'active' => 'Validée',
        'pending_validation' => 'En attente de validation',
        'rejected' => 'Rejetée',
        'withdrawn' => 'Retirée',
        'transferred' => 'Transférée',
        'graduated' => 'Diplômée',
        _ => s,
      };
}
