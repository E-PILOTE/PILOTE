// ══════════════════════════════════════════════════════════════════════════════
//  L'ÉTAT STATISTIQUE DE RENTRÉE — le document remonté à la circonscription
//
//  ── CE QUI EST IMPRIMÉ EN PREMIER, ET POURQUOI ────────────────────────────
//  La DATE DE RÉFÉRENCE DES ÂGES, et les LACUNES s'il y en a. Ce sont les deux
//  choses qu'un lecteur doit savoir avant de lire un seul total : à quelle date
//  se rapportent les chiffres, et ce que l'école n'a pas su renseigner.
//
//  Un état statistique n'a pas le droit d'être joli avant d'être honnête. Un
//  total faux ressemble à un total ; un total incomplet aussi. Seule la mention
//  les distingue.
//
//  ── LES COLONNES « NON RENSEIGNÉ » NE DISPARAISSENT PAS QUAND ELLES SONT À 0
//  Elles restent, vides. Leur présence dit au lecteur que la question a été
//  posée et que la réponse est zéro — ce qui n'est pas la même chose qu'une
//  colonne qu'on n'a pas jugé utile d'afficher.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/tutelle.dart';
import '../../../core/services/official_pdf_kit.dart';
import '../providers/etat_rentree_provider.dart';

/// L'établissement, tel qu'il se déclare en tête de l'état.
class EnTeteEtablissement {
  const EnTeteEtablissement({
    required this.nom,
    this.code,
    this.type,
    this.tutelle,
    this.departement,
    this.arrondissement,
    this.ville,
  });

  final String nom;
  final String? code, type, tutelle, departement, arrondissement, ville;
}

String _libelleType(String? t) => switch (t) {
      'public' => 'Public',
      'prive' => 'Privé',
      _ => '—',
    };

/// Libellés des rôles, pour le tableau du personnel.
String libelleRolePersonnel(String role) => switch (role) {
      'enseignant' => 'Enseignants',
      'directeur' => 'Directeurs',
      'proviseur' => 'Proviseurs',
      'secretaire' => 'Secrétaires',
      'comptable' => 'Comptables',
      'surveillant' => 'Surveillants',
      'cpe' => "Conseillers principaux d'éducation",
      'infirmier' => 'Infirmiers',
      'responsable_cantine' => 'Responsables de cantine',
      // Un rôle inconnu s'affiche tel quel : le taire retirerait des agents du
      // total, et un état statistique se juge sur ses totaux.
      _ => role,
    };

class EtatRentreePdfService {
  static Future<Uint8List> build({
    required EtatRentree etat,
    required EnTeteEtablissement etablissement,
    required String yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 20),
      header: (ctx) => OfficialPdfKit.headerFor(
        ctx,
        logo,
        f,
        badge: 'ÉTAT\nDE RENTRÉE',
        title: 'État statistique de rentrée — ${etablissement.nom}',
      ),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        _titre(f, yearLabel),
        pw.SizedBox(height: 10),
        _identification(f, etablissement),
        pw.SizedBox(height: 8),
        _reference(f, etat.dateReference),
        if (!etat.lacunes.aucune) ...[
          pw.SizedBox(height: 8),
          _lacunes(f, etat.lacunes),
        ],
        pw.SizedBox(height: 14),
        _section(f, 'A — EFFECTIFS PAR NIVEAU'),
        pw.SizedBox(height: 6),
        _tableEffectifs(f, etat),
        pw.SizedBox(height: 16),
        _section(f, 'B — RÉPARTITION PAR ÂGE'),
        pw.SizedBox(height: 6),
        _tableAges(f, etat),
        pw.SizedBox(height: 16),
        _section(f, 'C — SITUATIONS PARTICULIÈRES'),
        pw.SizedBox(height: 6),
        _particularites(f, etat),
        pw.SizedBox(height: 16),
        _section(f, "D — PERSONNEL DE L'ÉTABLISSEMENT"),
        pw.SizedBox(height: 6),
        _tablePersonnel(f, etat),
        pw.SizedBox(height: 18),
        _certification(f, etat, etablissement),
      ],
    ));

    return doc.save();
  }

  // ── Chrome ────────────────────────────────────────────────────────────────

  static pw.Widget _titre(PdfFonts f, String yearLabel) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ÉTAT STATISTIQUE DE RENTRÉE',
              style: pw.TextStyle(
                  font: f.bold,
                  fontSize: 14,
                  color: kPdfNavy,
                  letterSpacing: 1)),
          pw.Text('Année scolaire $yearLabel',
              style:
                  pw.TextStyle(font: f.regular, fontSize: 9, color: kPdfMuted)),
        ],
      );

  static pw.Widget _section(PdfFonts f, String titre) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: kPdfSurface,
        child: pw.Text(titre,
            style: pw.TextStyle(
                font: f.bold, fontSize: 9, color: kPdfNavy, letterSpacing: 0.6)),
      );

  static pw.Widget _identification(PdfFonts f, EnTeteEtablissement e) {
    pw.Widget champ(String label, String? valeur) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font: f.regular, fontSize: 6.5, color: kPdfMuted)),
              pw.Text(
                  valeur == null || valeur.trim().isEmpty ? '—' : valeur.trim(),
                  maxLines: 2,
                  style: pw.TextStyle(
                      font: f.medium, fontSize: 8.5, color: kPdfText)),
            ],
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: kPdfBorder, width: 0.6),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(children: [
        pw.Row(children: [
          champ('Établissement', e.nom),
          champ('Code', e.code),
          champ('Statut', _libelleType(e.type)),
          champ('Tutelle', sigleTutelleOuTiret(e.tutelle)),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          champ('Département', e.departement),
          champ('Arrondissement', e.arrondissement),
          champ('Ville', e.ville),
          champ('', null),
        ]),
      ]),
    );
  }

  static pw.Widget _reference(PdfFonts f, DateTime d) => pw.Text(
        'Âges calculés au ${DateFormat('dd MMMM yyyy', 'fr').format(d)} '
        '(ouverture de l’année scolaire) — le même état réédité plus tard '
        'donnera les mêmes chiffres.',
        style: pw.TextStyle(font: f.regular, fontSize: 7.5, color: kPdfMuted),
      );

  static pw.Widget _lacunes(PdfFonts f, LacunesEtat l) {
    final points = <String>[
      if (l.sansSexe > 0) '${l.sansSexe} sans sexe renseigné',
      if (l.sansDateNaissance > 0)
        '${l.sansDateNaissance} sans date de naissance',
      if (l.sansClasse > 0) '${l.sansClasse} sans classe rattachée',
      if (l.sansEleve > 0) '${l.sansEleve} inscription sans dossier élève',
    ];
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: pdfTint(kPdfGold, 0.16),
        border: pw.Border.all(color: kPdfGold, width: 0.6),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(
        'DONNÉES INCOMPLÈTES — ${points.join(' ; ')}. Ces élèves sont COMPTÉS '
        'dans les totaux généraux ; ils manquent seulement dans les colonnes '
        'qui exigent la donnée absente. Les totaux restent donc justes.',
        style: pw.TextStyle(font: f.medium, fontSize: 7.5, color: kPdfText),
      ),
    );
  }

  // ── Tableaux ──────────────────────────────────────────────────────────────

  static pw.Widget _cellule(PdfFonts f, String t,
          {bool gras = false, bool droite = false, PdfColor? fond}) =>
      pw.Container(
        color: fond,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
        child: pw.Text(t,
            textAlign: droite ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
                font: gras ? f.bold : f.regular,
                fontSize: 7.5,
                color: kPdfText)),
      );

  static pw.Widget _tableEffectifs(PdfFonts f, EtatRentree e) {
    pw.TableRow ligne(List<String> v, {bool gras = false, PdfColor? fond}) =>
        pw.TableRow(
          decoration: fond == null ? null : pw.BoxDecoration(color: fond),
          children: [
            for (var i = 0; i < v.length; i++)
              _cellule(f, v[i], gras: gras, droite: i > 0),
          ],
        );

    return pw.Table(
      border: pw.TableBorder.all(color: kPdfBorder, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.6),
        1: pw.FlexColumnWidth(0.9),
        2: pw.FlexColumnWidth(0.8),
        3: pw.FlexColumnWidth(0.8),
        4: pw.FlexColumnWidth(1.1),
        5: pw.FlexColumnWidth(1),
        6: pw.FlexColumnWidth(1),
        7: pw.FlexColumnWidth(1),
        8: pw.FlexColumnWidth(1.1),
      },
      children: [
        ligne(const [
          'Niveau',
          'Classes',
          'G',
          'F',
          'Total',
          'Redoub.',
          'Nouv.',
          'Non rens.',
          'Élèves/classe',
        ], gras: true, fond: kPdfSurface),
        for (final n in e.niveaux)
          ligne([
            n.levelName,
            '${n.classes}',
            '${n.garcons}',
            '${n.filles}',
            '${n.total}',
            '${n.redoublants}',
            '${n.nouveaux}',
            '${n.sexeInconnu}',
            n.classes == 0 ? '—' : n.parClasse.toStringAsFixed(1),
          ]),
        ligne([
          'TOTAL',
          '${e.totalClasses}',
          '${e.totalGarcons}',
          '${e.totalFilles}',
          '${e.totalEleves}',
          '${e.totalRedoublants}',
          '${e.totalNouveaux}',
          '${e.lacunes.sansSexe}',
          e.totalClasses == 0
              ? '—'
              : (e.totalEleves / e.totalClasses).toStringAsFixed(1),
        ], gras: true, fond: pdfTint(kPdfNavy, 0.08)),
      ],
    );
  }

  static pw.Widget _tableAges(PdfFonts f, EtatRentree e) {
    final compte = e.tranches.fold(0, (s, t) => s + t.total);
    return pw.Column(children: [
      pw.Table(
        border: pw.TableBorder.all(color: kPdfBorder, width: 0.4),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: kPdfSurface),
            children: [
              _cellule(f, "Tranche d'âge", gras: true),
              _cellule(f, 'Garçons', gras: true, droite: true),
              _cellule(f, 'Filles', gras: true, droite: true),
              _cellule(f, 'Total', gras: true, droite: true),
            ],
          ),
          for (final t in e.tranches)
            pw.TableRow(children: [
              _cellule(f, t.libelle),
              _cellule(f, '${t.garcons}', droite: true),
              _cellule(f, '${t.filles}', droite: true),
              _cellule(f, '${t.total}', droite: true),
            ]),
        ],
      ),
      if (compte != e.totalEleves) ...[
        pw.SizedBox(height: 4),
        pw.Text(
          'Ce tableau porte sur $compte élèves des ${e.totalEleves} inscrits : '
          '${e.totalEleves - compte} n’ont pas de date de naissance '
          'renseignée et ne peuvent donc être classés par âge.',
          style:
              pw.TextStyle(font: f.regular, fontSize: 7, color: kPdfMuted),
        ),
      ],
    ]);
  }

  static pw.Widget _particularites(PdfFonts f, EtatRentree e) {
    pw.Widget bloc(String label, int n) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: kPdfBorder, width: 0.5),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('$n',
                    style: pw.TextStyle(
                        font: f.bold, fontSize: 13, color: kPdfNavy)),
                pw.Text(label,
                    style: pw.TextStyle(
                        font: f.regular, fontSize: 7, color: kPdfMuted)),
              ],
            ),
          ),
        );

    return pw.Row(children: [
      bloc('Internes', e.internes),
      bloc('Boursiers', e.boursiers),
      bloc('Aide sociale', e.aideSociale),
      bloc('Affectés', e.affectes),
    ]);
  }

  static pw.Widget _tablePersonnel(PdfFonts f, EtatRentree e) => pw.Table(
        border: pw.TableBorder.all(color: kPdfBorder, width: 0.4),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(1),
          4: pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: kPdfSurface),
            children: [
              _cellule(f, 'Fonction', gras: true),
              _cellule(f, 'Hommes', gras: true, droite: true),
              _cellule(f, 'Femmes', gras: true, droite: true),
              _cellule(f, 'Non rens.', gras: true, droite: true),
              _cellule(f, 'Total', gras: true, droite: true),
            ],
          ),
          for (final p in e.personnel)
            pw.TableRow(children: [
              _cellule(f, libelleRolePersonnel(p.role)),
              _cellule(f, '${p.hommes}', droite: true),
              _cellule(f, '${p.femmes}', droite: true),
              _cellule(f, '${p.inconnu}', droite: true),
              _cellule(f, '${p.total}', droite: true),
            ]),
          pw.TableRow(
            decoration: pw.BoxDecoration(color: pdfTint(kPdfNavy, 0.08)),
            children: [
              _cellule(f, 'TOTAL', gras: true),
              _cellule(f, '${e.personnel.fold(0, (s, p) => s + p.hommes)}',
                  gras: true, droite: true),
              _cellule(f, '${e.personnel.fold(0, (s, p) => s + p.femmes)}',
                  gras: true, droite: true),
              _cellule(f, '${e.personnel.fold(0, (s, p) => s + p.inconnu)}',
                  gras: true, droite: true),
              _cellule(f, '${e.totalPersonnel}', gras: true, droite: true),
            ],
          ),
        ],
      );

  static pw.Widget _certification(
      PdfFonts f, EtatRentree e, EnTeteEtablissement etab) {
    final part = e.partFilles;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: kPdfNavy, width: 0.8),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('CERTIFICATION',
              style: pw.TextStyle(
                  font: f.bold,
                  fontSize: 8.5,
                  color: kPdfNavy,
                  letterSpacing: 0.6)),
          pw.SizedBox(height: 5),
          pw.Text(
            'Le présent état porte sur ${e.totalEleves} élève'
            '${e.totalEleves > 1 ? 's' : ''} inscrit'
            '${e.totalEleves > 1 ? 's' : ''} et régulièrement présent'
            '${e.totalEleves > 1 ? 's' : ''} à la date de son établissement, '
            'répartis en ${e.totalClasses} classe'
            '${e.totalClasses > 1 ? 's' : ''}'
            '${part == null ? '' : ', dont ${part.toStringAsFixed(1)} % de filles'}. '
            "L'effectif du personnel s'élève à ${e.totalPersonnel} agent"
            '${e.totalPersonnel > 1 ? 's' : ''}.'
            '${e.lacunes.aucune ? '' : ' ${e.lacunes.total} donnée'
                '${e.lacunes.total > 1 ? 's' : ''} manquante'
                '${e.lacunes.total > 1 ? 's' : ''} est signalée en tête.'}',
            style: pw.TextStyle(
                font: f.regular, fontSize: 8, color: kPdfText, lineSpacing: 2),
          ),
          pw.SizedBox(height: 16),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    etab.ville == null || etab.ville!.isEmpty
                        ? 'Le ${DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now())}'
                        : 'Fait à ${etab.ville}, le '
                            '${DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now())}',
                    style: pw.TextStyle(
                        font: f.regular, fontSize: 8, color: kPdfMuted)),
                pw.SizedBox(height: 26),
                pw.Container(width: 160, height: 0.6, color: kPdfBorder),
                pw.SizedBox(height: 3),
                pw.Text('Le Chef d’établissement',
                    style: pw.TextStyle(
                        font: f.regular, fontSize: 7.5, color: kPdfMuted)),
              ],
            ),
          ]),
        ],
      ),
    );
  }
}
