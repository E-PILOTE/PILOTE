import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/tutelle.dart';
import '../../../core/services/official_pdf_kit.dart';
import '../providers/tutelle_filtres.dart';
import '../providers/tutelle_reseau_provider.dart';
import 'tutelle_pdf_commun.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉTAT DU RÉSEAU SOUS TUTELLE — le document que le ministère remet
//
//  ── LA QUESTION ───────────────────────────────────────────────────────────
//  « Combien d'établissements, d'élèves et d'agents mon ministère supervise-t-il,
//  et où ? » L'écran y répond ; un cabinet demande une pièce signée.
//
//  ── ⚠️ LE PRIVÉ EST LA PREMIÈRE SECTION, PAS UNE ANNEXE ──────────────────
//  Le ministère connaît ses écoles publiques : il les administre. Ce qu'il ne
//  voit nulle part ailleurs, ce sont les établissements PRIVÉS qu'il agrée —
//  sept des vingt-cinq du MEPSA, aucun sous son toit. Le document suit l'ordre
//  de l'écran, et l'écran suit l'angle mort.
//
//  ── ⚠️ TROIS PIÈGES DE CHIFFRES, TRAITÉS ICI ─────────────────────────────
//   1. Un export filtré porte des totaux PARTIELS. La phrase de sélection est
//      imprimée sous le titre, et non laissée à la mémoire du lecteur.
//   2. Le taux d'occupation se calcule sur les seules écoles dont la capacité
//      est connue. Le document DIT sur combien d'écoles il porte — un taux
//      établi sur la moitié du réseau n'est pas le taux du réseau.
//   3. Les lignes départementales totalisent l'effectif annoncé en tête, y
//      compris les écoles sans département (ligne « Non renseigné »). Un état
//      dont les lignes ne font pas le total est un état qu'on ne signe pas.
//
//  ── ⚠️ TOUTES LES TABLES SONT PAGINÉES ───────────────────────────────────
//  Cible nationale : plus de mille établissements. `frame()` ne se scinde pas
//  entre deux pages ; une table non paginée fait boucler `MultiPage` jusqu'à
//  `TooManyPagesException`, et le document ne sort pas du tout.
// ════════════════════════════════════════════════════════════════════════════

class TutelleReseauPdfService {
  static Future<Uint8List> buildReseau({
    required List<TutelleGroupe> groupes,
    required List<TutelleEcole> ecoles,
    required BilanReseau bilan,
    String? tutelle,
    String? selection,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateTime.now();
    final couleur = pdfCouleurTutelle(tutelle);
    final sigle = sigleTutelle(tutelle);
    final intitule = nomTutelle(tutelle) ?? 'Réseau sous tutelle';
    final titre = 'État du réseau — ${sigle ?? 'tutelle'}';

    final sections = sectionsDuReseau(groupes, ecoles);
    final parDept = repartitionParDepartement(ecoles);
    final parSecteur = repartitionParSecteur(ecoles);

    final doc = pw.Document(
      title: titre,
      author: OfficialPdfKit.issuer?.name ?? 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'État du réseau placé sous tutelle ministérielle',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'ÉTAT DU\nRÉSEAU', title: titre),
      footer: (ctx) =>
          OfficialPdfKit.footer(ctx, f, pdfHorodatage(now), pdfReference(now)),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'ÉTAT DU RÉSEAU PLACÉ SOUS TUTELLE',
            title: intitule,
            line1: '${_n(bilan.nbEcoles)} établissement(s) · '
                '${_n(bilan.nbGroupes)} groupe(s) scolaire(s)',
            line2: 'Situation arrêtée au ${pdfDateLongue(now)}'
                '${selection == null ? '' : ' — vue filtrée'}',
            statusBadge: sigle),
        pw.SizedBox(height: 16),
        _kpis(bilan, f),
        pw.SizedBox(height: 18),
        ..._secteurs(parSecteur, bilan, f),
        pw.SizedBox(height: 14),
        ..._departements(parDept, f),
        pw.SizedBox(height: 14),
        ..._groupes(sections, couleur, f),
        pw.SizedBox(height: 14),
        ..._etablissements(ecoles, couleur, f),
        pw.SizedBox(height: 16),
        pdfEncartPortee(f,
            perimetre: 'Document établi sur l’ensemble des établissements '
                'placés sous votre tutelle, sans filtre.',
            selection: selection,
            complement: _qualite(bilan)),
        pw.SizedBox(height: 20),
      ],
    ));

    return doc.save();
  }

  static Future<String?> enregistrerReseau({
    required List<TutelleGroupe> groupes,
    required List<TutelleEcole> ecoles,
    required BilanReseau bilan,
    String? tutelle,
    String? selection,
    Uint8List? bytes,
  }) async =>
      pdfEnregistrer(
        octets: bytes ??
            await buildReseau(
              groupes: groupes,
              ecoles: ecoles,
              bilan: bilan,
              tutelle: tutelle,
              selection: selection,
            ),
        nomFichier:
            pdfNomFichier('Etat_du_reseau', sigleTutelle(tutelle) ?? 'tutelle'),
        titreDialogue: 'Enregistrer l’état du réseau',
      );

  // ─── Indicateurs ───────────────────────────────────────────────────────────
  //  173 pt × 3 + 2 gouttières de 10 = 539 pt, la largeur utile exacte d'une A4
  //  à marges de 28 : deux rangées de trois qui touchent les deux bords.
  static pw.Widget _kpis(BilanReseau b, PdfFonts f) => OfficialPdfKit.kpiGrid(
        f,
        [
          PdfKpi('Établissements', _n(b.nbEcoles), kPdfNavy),
          PdfKpi('Élèves', _n(b.nbEleves), kPdfGreen),
          PdfKpi('Part de filles', _pct(b.partFilles), kPdfGold),
          PdfKpi('Personnel', _n(b.nbPersonnel), kPdfBlue),
          PdfKpi('Classes', _n(b.nbClasses), kPdfPurple),
          PdfKpi('Occupation', _pct(b.tauxOccupation), kPdfOrange),
        ],
        width: 173,
      );

  // ─── Public / privé ────────────────────────────────────────────────────────
  static List<pw.Widget> _secteurs(
          List<LigneReseau> lignes, BilanReseau total, PdfFonts f) =>
      OfficialPdfKit.tableSection(
        title: 'SYNTHÈSE PAR SECTEUR',
        color: kPdfOrange,
        fonts: f,
        headers: const [
          'Secteur',
          'Écoles',
          'Élèves',
          'Filles',
          'Personnel',
          'Classes',
          'Agrément',
        ],
        flex: const [5, 2, 3, 2, 3, 2, 3],
        rows: [
          for (final l in lignes)
            [
              l.libelle,
              _n(l.bilan.nbEcoles),
              _n(l.bilan.nbEleves),
              _pct(l.bilan.partFilles),
              _n(l.bilan.nbPersonnel),
              _n(l.bilan.nbClasses),
              '${_n(l.bilan.nbAgrementDeclare)}/${_n(l.bilan.nbEcoles)}',
            ],
        ],
        emptyLabel: 'Aucun établissement dans la sélection.',
        note: 'Ensemble : ${_n(total.nbEcoles)} établissement(s) · '
            '${_n(total.nbEleves)} élève(s).',
      );

  // ─── Territoire ────────────────────────────────────────────────────────────
  static List<pw.Widget> _departements(List<LigneReseau> lignes, PdfFonts f) =>
      OfficialPdfKit.tableSection(
        title: 'RÉPARTITION PAR DÉPARTEMENT',
        color: kPdfNavy,
        fonts: f,
        headers: const [
          'Département',
          'Écoles',
          'Élèves',
          'Filles',
          'Personnel',
          'Classes',
        ],
        flex: const [6, 2, 3, 2, 3, 2],
        rows: [
          for (final l in lignes)
            [
              l.libelle,
              _n(l.bilan.nbEcoles),
              _n(l.bilan.nbEleves),
              _pct(l.bilan.partFilles),
              _n(l.bilan.nbPersonnel),
              _n(l.bilan.nbClasses),
            ],
        ],
        emptyLabel: 'Aucun établissement dans la sélection.',
        note: 'Le Congo compte 15 départements (réforme d’octobre 2024). '
            'Les établissements dont le département n’est pas saisi figurent '
            'sur la ligne « Non renseigné » — ils restent comptés.',
      );

  // ─── Opérateurs du réseau ──────────────────────────────────────────────────
  //  Une section par pan, le privé d'abord : voir l'en-tête du fichier.
  static List<pw.Widget> _groupes(
      List<SectionReseau> sections, PdfColor accent, PdfFonts f) {
    final out = <pw.Widget>[];
    for (final s in sections) {
      if (out.isNotEmpty) out.add(pw.SizedBox(height: 12));
      out.addAll(OfficialPdfKit.tableSection(
        title: s.titre.toUpperCase(),
        color: s.prive ? kPdfOrange : accent,
        fonts: f,
        headers: const [
          'Groupe scolaire',
          'Département',
          'Écoles',
          'Élèves',
          'Personnel',
          'Agrément',
        ],
        flex: const [7, 4, 2, 3, 3, 4],
        leftAlignCols: const {1, 5},
        rows: [
          for (final g in s.groupes)
            [
              g.nom,
              pdfOuTiret(g.departement),
              _n(g.nbEcoles),
              _n(g.nbEleves),
              _n(g.nbPersonnel),
              pdfAgrement(g.agrementNumero),
            ],
        ],
        maxLines: 2,
        rowHeight: OfficialPdfKit.kTallRowHeight,
        perBlock: OfficialPdfKit.kTallRowsPerBlock,
        emptyLabel: 'Aucun groupe de ce secteur dans la sélection.',
        // ⚠️ Les colonnes de ce tableau viennent des agrégats de la RPC : ce
        // sont les totaux du groupe SOUS CETTE TUTELLE, filtres non appliqués.
        // Dit ici, faute de quoi ils contrediraient la table qui suit.
        note: '${s.explication} Les effectifs de cette table sont les totaux '
            'du groupe sous votre tutelle, filtres de sélection non appliqués.',
      ));
    }
    if (out.isEmpty) {
      out.addAll(OfficialPdfKit.tableSection(
        title: 'GROUPES DU RÉSEAU',
        color: accent,
        fonts: f,
        headers: const ['Groupe scolaire'],
        flex: const [1],
        rows: const [],
        emptyLabel: 'Aucun groupe dans la sélection.',
      ));
    }
    return out;
  }

  // ─── Les établissements, un par ligne ──────────────────────────────────────
  static List<pw.Widget> _etablissements(
          List<TutelleEcole> ecoles, PdfColor accent, PdfFonts f) =>
      OfficialPdfKit.tableSection(
        title: 'ÉTABLISSEMENTS',
        color: accent,
        fonts: f,
        headers: const [
          'Établissement',
          'Groupe',
          'Département',
          'Sect.',
          'Élèves',
          'Pers.',
          'Agrément',
        ],
        flex: const [7, 5, 4, 2, 2, 2, 3],
        leftAlignCols: const {1, 2},
        // ⚠️ Le GROUPE sur deux lignes. Écrêté à une seule, « Réseau Scolaire
        // Saint-Pierre » et « Réseau Scolaire Horizon » s'imprimaient tous
        // deux « Réseau Scolaire » : deux opérateurs privés distincts,
        // indiscernables sur l'état remis au ministère.
        multiLineCols: const {1},
        rows: [
          for (final e in ecoles)
            [
              e.nom,
              e.groupeNom,
              pdfOuTiret(e.departement),
              e.estPublic ? 'Pub.' : 'Pri.',
              _n(e.nbEleves),
              _n(e.nbPersonnel),
              e.aDeclareUnAgrement ? 'Déclaré' : '—',
            ],
        ],
        maxLines: 2,
        rowHeight: OfficialPdfKit.kTallRowHeight,
        perBlock: OfficialPdfKit.kTallRowsPerBlock,
        emptyLabel: 'Aucun établissement ne correspond à la sélection.',
        note: 'Effectifs agrégés. La colonne « Agrément » indique la présence '
            'd’un numéro saisi, non la validité d’un dossier.',
      );

  /// La phrase de qualité des données — ce que le taux d'occupation vaut.
  static String _qualite(BilanReseau b) {
    if (b.nbEcoles == 0) return 'Aucun établissement dans la sélection.';
    if (b.capaciteComplete) {
      return 'Capacité d’accueil renseignée pour les '
          '${_n(b.nbEcoles)} établissement(s) : le taux d’occupation porte sur '
          'la totalité de la sélection.';
    }
    return 'Capacité d’accueil renseignée pour ${_n(b.nbCapaciteConnue)} '
        'établissement(s) sur ${_n(b.nbEcoles)} : le taux d’occupation ne '
        'porte que sur ceux-là et ne vaut pas pour l’ensemble.';
  }
}

// ─── Formatage ───────────────────────────────────────────────────────────────

String _n(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf';
}

/// ⚠️ Le tiret et non « 0 % » : un pourcentage incalculable n'est pas un
/// pourcentage nul. Cf. `BilanReseau.partFilles` et `.tauxOccupation`.
String _pct(double? v) => v == null ? '—' : '${v.round()} %';
