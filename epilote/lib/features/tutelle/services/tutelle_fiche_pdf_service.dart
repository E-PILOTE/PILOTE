import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/tutelle.dart';
import '../../../core/services/official_pdf_kit.dart';
import '../providers/tutelle_filtres.dart';
import '../providers/tutelle_reseau_provider.dart';
import 'tutelle_pdf_commun.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES DEUX FICHES DE LA TUTELLE — un établissement, un groupe scolaire
//
//  Un ministère ne travaille pas qu'en tableaux. Il convoque un chef
//  d'établissement, il écrit à un groupe privé, il joint une pièce à un
//  dossier : il lui faut une FICHE, une page, avec l'en-tête de la République
//  et le nom de l'établissement en grand.
//
//  ── ⚠️ CE QUI EST IMPRIMÉ EST CE QUE 0158 LAISSE SORTIR, RIEN DE PLUS ─────
//  Le chef d'établissement figure ici parce qu'il est l'interlocuteur officiel
//  de la tutelle, et c'est la SEULE personne nommée. Un élève ne le sera
//  jamais : la RPC ne le rend pas, et ce n'est pas un oubli.
//
//  ── ⚠️ LA TABLE DES ÉTABLISSEMENTS EST PAGINÉE ────────────────────────────
//  `frame()` enveloppe son contenu dans un `Padding`, qui ne sait pas se
//  scinder entre deux pages : une table plus haute qu'une feuille fait boucler
//  `MultiPage` jusqu'à `TooManyPagesException` — le document ne sort pas du
//  tout. Un groupe privé congolais peut tenir trente établissements. D'où
//  `tableSection`, jamais `frame(table(...))`.
// ════════════════════════════════════════════════════════════════════════════

class TutelleFichePdfService {
  // ─── Fiche d'établissement ────────────────────────────────────────────────
  static Future<Uint8List> buildEcole({
    required TutelleEcole ecole,
    String? tutelle,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateTime.now();
    final couleur = pdfCouleurTutelle(tutelle);
    final titre = 'Fiche d’établissement — ${ecole.nom}';

    final doc = pw.Document(
      title: titre,
      author: OfficialPdfKit.issuer?.name ?? 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Fiche d’établissement sous tutelle',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'FICHE\nÉTABLISSEMENT', title: titre),
      footer: (ctx) =>
          OfficialPdfKit.footer(ctx, f, pdfHorodatage(now), pdfReference(now)),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'ÉTABLISSEMENT SOUS TUTELLE '
                '${sigleTutelleOuTiret(tutelle)}',
            title: ecole.nom,
            line1: '${ecole.groupeNom} · '
                '${pdfSecteur(ecole.estPublic)}'
                '${ecole.typeEtablissementCourt == null ? '' : ' · ${ecole.typeEtablissementCourt}'}',
            line2: 'Situation arrêtée au ${pdfDateLongue(now)}',
            statusBadge: ecole.actif ? 'Actif' : 'Inactif'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Élèves', _n(ecole.nbEleves), kPdfGreen),
          PdfKpi('Dont filles', _pourcentFilles(ecole), kPdfGold),
          PdfKpi('Personnel', _n(ecole.nbPersonnel), kPdfBlue),
          PdfKpi('Classes', _n(ecole.nbClasses), kPdfNavy),
          PdfKpi('Occupation', _occupation(ecole), kPdfOrange),
        ]),
        pw.SizedBox(height: 18),
        pdfFicheBloc(f,
            titre: 'DIRECTION ET CONTACTS',
            couleur: couleur,
            lignes: [
              // La raison d'être de la fiche : à qui la tutelle s'adresse.
              ('Chef d’établissement',
                  (ecole.chefEtablissement ?? '').trim().isEmpty
                      ? 'Non désigné'
                      : ecole.chefEtablissement!.trim()),
              ('Téléphone', pdfOuTiret(ecole.telephone)),
              ('Courriel', pdfOuTiret(ecole.courriel)),
            ]),
        pw.SizedBox(height: 12),
        pdfFicheBloc(f,
            titre: 'IDENTITÉ ADMINISTRATIVE',
            couleur: kPdfNavy,
            lignes: [
              ('Code établissement', pdfOuTiret(ecole.code)),
              ('Type', pdfOuTiret(ecole.typeEtablissement)),
              ('Secteur', pdfSecteur(ecole.estPublic)),
              ('Groupe scolaire', ecole.groupeNom),
              ('Ministère de tutelle',
                  nomTutelle(tutelle) ?? sigleTutelleOuTiret(tutelle)),
              ('Année de création', ecole.anneeCreation?.toString() ?? '—'),
            ]),
        pw.SizedBox(height: 12),
        pdfFicheBloc(f,
            titre: 'IMPLANTATION',
            couleur: kPdfBlue,
            lignes: [
              ('Département', pdfOuTiret(ecole.departement)),
              ('Ville', pdfOuTiret(ecole.ville)),
              ('Arrondissement', pdfOuTiret(ecole.arrondissement)),
              ('Coordonnées', _coordonnees(ecole)),
            ]),
        pw.SizedBox(height: 12),
        pdfFicheBloc(f,
            titre: 'EFFECTIFS ET CAPACITÉ',
            couleur: kPdfGreen,
            lignes: [
              ('Élèves inscrits', _n(ecole.nbEleves)),
              ('Dont filles',
                  '${_n(ecole.nbFilles)}  (${_pourcentFilles(ecole)})'),
              ('Dont garçons', _n(ecole.nbEleves - ecole.nbFilles)),
              ('Classes ouvertes', _n(ecole.nbClasses)),
              ('Personnel', _n(ecole.nbPersonnel)),
              ('Capacité d’accueil',
                  ecole.capacite == null ? 'Non renseignée' : _n(ecole.capacite!)),
              ('Taux d’occupation', _occupation(ecole)),
            ]),
        pw.SizedBox(height: 12),
        pdfFicheBloc(f,
            titre: 'AGRÉMENT',
            couleur: kPdfPurple,
            lignes: [
              ('Numéro', pdfAgrement(ecole.agrementNumero)),
              ('Type', pdfTypeAgrement(ecole.agrementType)),
              ('Date',
                  ecole.agrementDate == null
                      ? '—'
                      : pdfDateLongue(ecole.agrementDate!)),
            ]),
        pw.SizedBox(height: 16),
        pdfEncartPortee(f,
            perimetre: 'Fiche portant sur un établissement unique du réseau '
                'placé sous votre tutelle.',
            complement: 'Fiche établie à partir des données déclarées par '
                'l’établissement dans E-PILOTE. Elle ne vaut pas attestation '
                'd’agrément.'),
        pw.SizedBox(height: 20),
      ],
    ));

    return doc.save();
  }

  static Future<String?> enregistrerEcole({
    required TutelleEcole ecole,
    String? tutelle,
    Uint8List? bytes,
  }) async =>
      pdfEnregistrer(
        octets: bytes ?? await buildEcole(ecole: ecole, tutelle: tutelle),
        nomFichier: pdfNomFichier('Fiche_etablissement', ecole.nom),
        titreDialogue: 'Enregistrer la fiche d’établissement',
      );

  // ─── Fiche de groupe scolaire ─────────────────────────────────────────────
  static Future<Uint8List> buildGroupe({
    required TutelleGroupe groupe,
    required List<TutelleEcole> ecoles,
    required BilanReseau bilan,
    String? tutelle,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateTime.now();
    final couleur = groupe.estPublic ? kPdfNavy : kPdfOrange;
    final titre = 'Fiche de groupe — ${groupe.nom}';

    // ⚠️ Le document DIT quand il ne couvre pas tout le groupe. Une fiche de
    // groupe filtrée sur un département annoncerait sinon deux établissements
    // pour un opérateur qui en tient cinq.
    final partiel = ecoles.length != groupe.nbEcoles;

    final doc = pw.Document(
      title: titre,
      author: OfficialPdfKit.issuer?.name ?? 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Fiche de groupe scolaire sous tutelle',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'FICHE\nDE GROUPE', title: titre),
      footer: (ctx) =>
          OfficialPdfKit.footer(ctx, f, pdfHorodatage(now), pdfReference(now)),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'GROUPE SCOLAIRE SOUS TUTELLE '
                '${sigleTutelleOuTiret(tutelle)}',
            title: groupe.nom,
            line1: '${pdfSecteur(groupe.estPublic)}'
                '${groupe.departement == null ? '' : ' · ${groupe.departement}'}',
            line2: 'Situation arrêtée au ${pdfDateLongue(now)}',
            statusBadge: groupe.estPublic ? 'Public' : 'Privé'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Établissements', _n(bilan.nbEcoles), kPdfNavy),
          PdfKpi('Élèves', _n(bilan.nbEleves), kPdfGreen),
          PdfKpi('Personnel', _n(bilan.nbPersonnel), kPdfBlue),
          PdfKpi('Classes', _n(bilan.nbClasses), kPdfGold),
          PdfKpi('Agrément déclaré',
              '${_n(bilan.nbAgrementDeclare)}/${_n(bilan.nbEcoles)}',
              kPdfPurple),
        ]),
        pw.SizedBox(height: 18),
        pdfFicheBloc(f,
            titre: 'IDENTITÉ DU GROUPE',
            couleur: couleur,
            lignes: [
              ('Dénomination', groupe.nom),
              ('Secteur', pdfSecteur(groupe.estPublic)),
              ('Département', pdfOuTiret(groupe.departement)),
              ('Courriel', pdfOuTiret(groupe.email)),
              ('Téléphone', pdfOuTiret(groupe.telephone)),
              ('Année de création', groupe.anneeCreation?.toString() ?? '—'),
              ('Statut', groupe.actif ? 'Actif' : 'Inactif'),
              ('Ministère de tutelle',
                  nomTutelle(tutelle) ?? sigleTutelleOuTiret(tutelle)),
            ]),
        pw.SizedBox(height: 12),
        pdfFicheBloc(f,
            titre: 'AGRÉMENT DU GROUPE',
            couleur: kPdfPurple,
            lignes: [
              ('Numéro', pdfAgrement(groupe.agrementNumero)),
              ('Type', pdfTypeAgrement(groupe.agrementType)),
              ('Date',
                  groupe.agrementDate == null
                      ? '—'
                      : pdfDateLongue(groupe.agrementDate!)),
              // L'agrément descend du groupe vers ses écoles par déclencheur
              // (migration 0158) : le dire évite qu'on cherche une saisie
              // par établissement qui n'existe pas.
              ('Portée',
                  'Mention portée par le groupe ; ses établissements en '
                      'héritent automatiquement.'),
            ]),
        pw.SizedBox(height: 14),
        ...OfficialPdfKit.tableSection(
          title: 'ÉTABLISSEMENTS DU GROUPE',
          color: couleur,
          fonts: f,
          headers: const [
            'Établissement',
            'Type',
            'Ville',
            'Chef d’établissement',
            'Élèves',
            'Pers.',
            'Cl.',
          ],
          flex: const [7, 3, 3, 6, 2, 2, 2],
          leftAlignCols: const {1, 2, 3},
          // ⚠️ Le CHEF D'ÉTABLISSEMENT sur deux lignes : c'est la raison
          // d'être de cette table, et un nom congolais complet ne tient pas
          // sur une ligne de 129 pt.
          multiLineCols: const {3},
          rows: [
            for (final e in ecoles)
              [
                e.nom,
                pdfOuTiret(e.typeEtablissementCourt),
                pdfOuTiret(e.ville),
                (e.chefEtablissement ?? '').trim().isEmpty
                    ? 'Non désigné'
                    : e.chefEtablissement!.trim(),
                _n(e.nbEleves),
                _n(e.nbPersonnel),
                _n(e.nbClasses),
              ],
          ],
          maxLines: 2,
          rowHeight: OfficialPdfKit.kTallRowHeight,
          perBlock: OfficialPdfKit.kTallRowsPerBlock,
          emptyLabel: 'Aucun établissement de ce groupe dans la sélection.',
          note: 'Total : ${_n(bilan.nbEcoles)} établissement(s) · '
              '${_n(bilan.nbEleves)} élève(s) · '
              '${_n(bilan.nbPersonnel)} agent(s).',
        ),
        pw.SizedBox(height: 16),
        pdfEncartPortee(f,
            perimetre: 'Document portant sur l’ensemble des établissements '
                'que ce groupe tient sous votre tutelle.',
            selection: partiel
                ? 'Sélection partielle : ${ecoles.length} établissement(s) '
                    'sur les ${groupe.nbEcoles} que ce groupe tient sous '
                    'cette tutelle'
                : null),
        pw.SizedBox(height: 20),
      ],
    ));

    return doc.save();
  }

  static Future<String?> enregistrerGroupe({
    required TutelleGroupe groupe,
    required List<TutelleEcole> ecoles,
    required BilanReseau bilan,
    String? tutelle,
    Uint8List? bytes,
  }) async =>
      pdfEnregistrer(
        octets: bytes ??
            await buildGroupe(
                groupe: groupe,
                ecoles: ecoles,
                bilan: bilan,
                tutelle: tutelle),
        nomFichier: pdfNomFichier('Fiche_groupe', groupe.nom),
        titreDialogue: 'Enregistrer la fiche de groupe',
      );
}

// ─── Formatage ───────────────────────────────────────────────────────────────

/// Séparateur d'unités insécable — un effectif ministériel se lit en tranches
/// de trois, et le PDF ne doit pas les couper en fin de ligne.
String _n(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf';
}

/// ⚠️ Jamais « 0 % » quand il n'y a aucun élève : l'absence d'effectif n'est
/// pas une absence de filles.
String _pourcentFilles(TutelleEcole e) =>
    e.nbEleves == 0 ? '—' : '${(e.nbFilles * 100 / e.nbEleves).round()} %';

/// ⚠️ Jamais « 0 % » faute de capacité renseignée : cela se lirait comme une
/// école vide, alors que c'est une case non remplie.
String _occupation(TutelleEcole e) =>
    e.occupation == null ? '—' : '${(e.occupation! * 100).round()} %';

String _coordonnees(TutelleEcole e) =>
    (e.latitude == null || e.longitude == null)
        ? 'Non géolocalisé'
        : '${e.latitude!.toStringAsFixed(5)}, '
            '${e.longitude!.toStringAsFixed(5)}';
