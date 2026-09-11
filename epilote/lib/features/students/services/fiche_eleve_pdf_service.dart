import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../../core/utils/ine.dart';
import '../../../core/utils/safe_file_name.dart';
import '../../../core/utils/scolarite_libelles.dart';
import '../models/eleve_libelles.dart';
import '../models/tutor_draft.dart';
import '../providers/fiche_eleve_actes_provider.dart';
import '../providers/student_dossier_provider.dart';
import 'fiche_eleve_pdf_data.dart';
import 'fiche_eleve_pdf_interne.dart';

// ⚠️ Ré-exporté : l'écran a besoin de `rassemblerFicheEleve` ET du composeur,
// et un appelant n'a pas à savoir que la lecture et la composition vivent dans
// deux fichiers. La coupe est une règle de taille de fichier, pas une frontière
// pour l'appelant.
export 'fiche_eleve_pdf_data.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FICHE ÉLÈVE IMPRIMÉE — et la question qui décide de tout : POUR QUI ?
//
//  ── DEUX PORTÉES, PARCE QUE LE PAPIER SORT DE L'ÉCOLE ──────────────────────
//  ⚠️ L'écran peut tout montrer à la secrétaire, qui est dans l'établissement
//  et responsable devant lui. Le PAPIER, lui, part : un employeur, une
//  administration, une autre école, un dossier de bourse. Groupe sanguin,
//  allergies, passages à l'infirmerie, sanctions et situation financière de la
//  famille n'ont rien à y faire.
//
//   • FICHE ADMINISTRATIVE — identité, famille, scolarité, parcours, résultats
//     arrêtés, actes délivrés. Ce qui peut être remis à un tiers.
//   • DOSSIER COMPLET INTERNE — tout, santé et conduite et finances comprises.
//
//  Le choix est demandé à chaque impression, jamais présélectionné : une case
//  cochée par défaut finit par être cochée toujours.
//
//  ── LE PIED DIT CE QUE LE DOCUMENT NE CONTIENT PAS ─────────────────────────
//  ⚠️ Sur une pièce qui circule, un blanc se lit comme une omission. Un
//  lecteur qui reçoit une fiche administrative sans conduite ni santé pourrait
//  croire qu'il n'y en a pas ; on écrit donc noir sur blanc ce qui a été
//  volontairement laissé de côté. Même règle que le dossier du groupe.
// ════════════════════════════════════════════════════════════════════════════






class FicheElevePdfService {
  static Future<Uint8List> buildPdf({
    required FicheElevePdfMatiere matiere,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final d = matiere.dossier;
    final courante = matiere.parcours
            .where((p) =>
                matiere.anneeLabel.isEmpty || p.anneeLabel == matiere.anneeLabel)
            .firstOrNull ??
        (matiere.parcours.isEmpty ? null : matiere.parcours.first);

    final doc = pw.Document(
      title: matiere.complet ? 'Dossier élève' : 'Fiche élève',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: d.nomComplet,
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.header(
        logo,
        f,
        badge: matiere.complet ? 'DOSSIER\nINTERNE' : 'FICHE\nÉLÈVE',
      ),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(
          f,
          kicker: matiere.complet
              ? "DOSSIER COMPLET — USAGE INTERNE DE L'ÉTABLISSEMENT"
              : 'FICHE ADMINISTRATIVE DE L\'ÉLÈVE',
          title: fmtOuTiret(d.nomComplet),
          line1: [
            if (d.s('matricule').isNotEmpty) 'Matricule ${d.s('matricule')}',
            d.s('ine').isEmpty ? kIneEnAttente : 'INE ${formatIne(d.s('ine'))}',
            if (courante != null && courante.classe.isNotEmpty)
              'Classe ${courante.classe}',
          ].join('  ·  '),
          line2: 'Édité le $genDate',
        ),
        pw.SizedBox(height: 16),
        ..._etatCivil(f, d),
        pw.SizedBox(height: 12),
        ..._famille(f, d),
        pw.SizedBox(height: 12),
        ..._parcours(f, matiere),
        pw.SizedBox(height: 12),
        ..._resultats(f, matiere),
        pw.SizedBox(height: 12),
        ..._actes(f, matiere.actes),
        if (matiere.complet) ...[
          pw.SizedBox(height: 12),
          ...blocSante(f, matiere),
          pw.SizedBox(height: 12),
          ...blocConduite(f, matiere),
          pw.SizedBox(height: 12),
          ...blocFinances(f, matiere),
        ],
        pw.SizedBox(height: 16),
        _mentionDePortee(f, matiere.complet),
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  // ── Blocs ────────────────────────────────────────────────────────────────

  static List<pw.Widget> _etatCivil(PdfFonts f, StudentDossier d) =>
      OfficialPdfKit.tableSection(
        title: 'ÉTAT CIVIL',
        color: kPdfNavy,
        fonts: f,
        headers: const ['Rubrique', 'Valeur'],
        rows: [
          ['Nom', fmtOuTiret(d.s('last_name'))],
          ['Prénom(s)', fmtOuTiret(d.s('first_name'))],
          [
            'Sexe',
            switch (d.s('gender')) {
              'F' => 'Féminin',
              'M' => 'Masculin',
              _ => '—',
            },
          ],
          [
            'Date de naissance',
            '${fmtDatePdf(d.dob)}${d.age != null ? '  (${d.age} ans)' : ''}',
          ],
          ['Lieu de naissance', fmtOuTiret(d.s('place_of_birth'))],
          ['Nationalité', fmtOuTiret(d.s('nationality'))],
          ['Matricule (école)', fmtOuTiret(d.s('matricule'))],
          [
            'Identifiant national',
            d.s('ine').isEmpty ? kIneEnAttente : formatIne(d.s('ine')),
          ],
        ],
        flex: const [3, 5],
        leftAlignCols: const {0, 1},
        emptyLabel: 'Aucune donnée d\'état civil.',
      );

  static List<pw.Widget> _famille(PdfFonts f, StudentDossier d) {
    final adresse = [d.s('address'), d.s('city'), d.s('region')]
        .where((e) => e.isNotEmpty)
        .join(', ');
    return [
      ...OfficialPdfKit.tableSection(
        title: 'FAMILLE ET DOMICILE',
        color: kPdfNavy,
        fonts: f,
        headers: const ['Rubrique', 'Valeur'],
        rows: [
          [
            'Situation familiale',
            situationFamilialeLabel(d.s('situation_familiale')),
          ],
          ['Domicile', fmtOuTiret(adresse)],
        ],
        flex: const [3, 5],
        leftAlignCols: const {0, 1},
        emptyLabel: '—',
      ),
      pw.SizedBox(height: 10),
      ...OfficialPdfKit.tableSection(
        title: 'RESPONSABLES LÉGAUX',
        color: kPdfNavy,
        fonts: f,
        headers: const ['Nom', 'Lien', 'Téléphone', 'Rôle'],
        rows: [
          for (final t in d.tutors)
            [
              fmtOuTiret(t.fullName),
              tutorRelationshipLabel(t.relationship),
              [
                if ((t.phonePrimary ?? '').isNotEmpty) t.phonePrimary!,
                if ((t.phoneSecondary ?? '').isNotEmpty) t.phoneSecondary!,
              ].join(' · '),
              [
                if (t.isPrimary) 'Contact principal',
                if (t.isEmergency) 'Urgence',
              ].join(' · '),
            ],
        ],
        flex: const [4, 2, 3, 3],
        leftAlignCols: const {0, 1, 2, 3},
        // ⚠️ Le vide est ÉCRIT. Un bloc blanc sur une pièce qui circule se lit
        // comme un oubli de mise en page, alors que c'est un renseignement.
        emptyLabel: 'Aucun responsable légal enregistré.',
      ),
    ];
  }

  static List<pw.Widget> _parcours(PdfFonts f, FicheElevePdfMatiere m) =>
      OfficialPdfKit.tableSection(
        title: 'PARCOURS SCOLAIRE',
        color: kPdfNavy,
        fonts: f,
        headers: const [
          'Année',
          'Classe',
          'Type',
          'Statut',
          'Fin d\'année',
        ],
        rows: [
          for (final p in m.parcours)
            [
              fmtOuTiret(p.anneeLabel),
              [p.classe, if (p.filiere.isNotEmpty) '(${p.filiere})'].join(' '),
              inscriptionTypeLabel(p.type),
              enrollmentStatutLabel(p.statut),
              [
                verdictPassageLabel(p.verdict),
                if (p.redoublant) '· redoublant',
              ].join(' '),
            ],
        ],
        flex: const [2, 3, 2, 3, 3],
        leftAlignCols: const {0, 1, 2, 3, 4},
        emptyLabel: 'Aucune inscription enregistrée.',
      );

  static List<pw.Widget> _resultats(PdfFonts f, FicheElevePdfMatiere m) =>
      OfficialPdfKit.tableSection(
        title: 'RÉSULTATS ARRÊTÉS',
        color: kPdfGreen,
        fonts: f,
        headers: const [
          'Année',
          'Période',
          'Moyenne',
          'Rang',
          'Mention',
          'Décision',
        ],
        rows: [
          for (final b in m.bulletins)
            [
              fmtOuTiret(b.anneeLabel),
              fmtOuTiret(b.trimestre),
              b.moyenne == null ? '—' : '${fmtNum1Pdf(b.moyenne)}/20',
              b.rangLabel,
              fmtOuTiret(b.mention),
              fmtOuTiret(distinctionConseilLabel(b.decision)),
            ],
        ],
        flex: const [2, 2, 2, 2, 3, 3],
        leftAlignCols: const {0, 1, 4, 5},
        emptyLabel: 'Aucun bulletin arrêté à ce jour.',
      );

  static List<pw.Widget> _actes(PdfFonts f, ActesEleve a) => [
        ...OfficialPdfKit.tableSection(
          title: 'DOCUMENTS DÉLIVRÉS PAR L\'ÉTABLISSEMENT',
          color: kPdfNavy,
          fonts: f,
          headers: const ['Date', 'Document', 'Délivré par', 'Motif'],
          rows: [
            for (final x in a.delivres)
              [
                fmtDatePdf(x.date),
                documentDelivreLabel(x.type),
                fmtOuTiret(x.parQui),
                fmtOuTiret(x.motif),
              ],
          ],
          flex: const [2, 4, 3, 4],
          leftAlignCols: const {1, 2, 3},
          emptyLabel: 'Aucun document délivré à ce jour.',
        ),
        pw.SizedBox(height: 10),
        ...OfficialPdfKit.tableSection(
          title: 'EXAMENS D\'ÉTAT',
          color: kPdfGold,
          fonts: f,
          headers: const [
            'Session',
            'Examen',
            'N° candidat',
            'Dossier',
            'Résultat',
          ],
          rows: [
            for (final x in a.examens)
              [
                fmtOuTiret(x.session),
                fmtOuTiret(x.examen),
                fmtOuTiret(x.numero),
                examDossierLabel(x.statutDossier),
                [
                  examResultatLabel(x.resultat),
                  if (x.moyenne != null) '(${fmtNum1Pdf(x.moyenne)})',
                  if (x.mention.isNotEmpty) '· ${x.mention}',
                ].join(' '),
              ],
          ],
          flex: const [2, 3, 3, 3, 4],
          leftAlignCols: const {0, 1, 2, 3, 4},
          emptyLabel: 'Aucune candidature à un examen d\'État.',
        ),
      ];

  static pw.Widget _mentionDePortee(PdfFonts f, bool complet) =>
      OfficialPdfKit.frame(
        title: complet ? 'PORTÉE DE CE DOCUMENT' : 'CE QUE CE DOCUMENT '
            'NE CONTIENT PAS',
        color: complet ? kPdfRed : kPdfMuted,
        fonts: f,
        child: pw.Text(
          complet
              ? "DOSSIER COMPLET — USAGE INTERNE DE L'ÉTABLISSEMENT. Ce "
                  'document contient des données de santé, de conduite et de '
                  "situation financière. Il n'est pas destiné à être remis à "
                  'un tiers. Il ne remplace ni le bulletin scolaire, ni le '
                  'certificat de scolarité, qui font seuls foi de leur objet.'
              : 'FICHE ADMINISTRATIVE. Ce document ne contient VOLONTAIREMENT '
                  'ni donnée de santé, ni fait de conduite, ni situation '
                  "financière : leur absence ici n'atteste pas qu'il n'en "
                  'existe pas. Il ne remplace ni le bulletin scolaire, ni le '
                  'certificat de scolarité, qui font seuls foi de leur objet.',
          style: pw.TextStyle(font: f.regular, fontSize: 8, color: kPdfMuted),
        ),
      );

  static Future<String?> downloadDoc({
    required FicheElevePdfMatiere matiere,
  }) async {
    final bytes = await buildPdf(matiere: matiere);
    final base = matiere.complet ? 'Dossier' : 'Fiche';
    final nom = safeFileName(
      '${base}_${matiere.dossier.nomComplet}_'
      '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      fallback: 'fiche-eleve',
    );
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: matiere.complet
          ? 'Enregistrer le dossier complet'
          : 'Enregistrer la fiche administrative',
      fileName: nom,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
    if (savePath == null) return null;
    // ⚠️ On réécrit toujours : la fenêtre « Enregistrer sous » de Windows rend
    // un chemin sans créer le fichier, et écraser un export plus ancien du
    // même nom laisserait sinon l'ANCIEN contenu en place.
    await File(savePath).writeAsBytes(bytes, flush: true);
    return savePath;
  }
}
