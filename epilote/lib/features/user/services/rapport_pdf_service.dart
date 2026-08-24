import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/rapports_provider.dart';
import 'rapport_effectifs.dart';
import 'rapport_personnel.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES ÉTATS OFFICIELS DE L'ÉTABLISSEMENT
//
//  Deux documents destinés à être signés et transmis : l'état des effectifs et
//  l'état de recouvrement. Ils ne CALCULENT rien — le comptage vit dans
//  `rapport_effectifs.dart`, le recouvrement dans `paiements_provider.dart`,
//  tous deux sous tests. Ici on ne fait que mettre en page.
//
//  ⚠️ `pw.MultiPage` et `OfficialPdfKit.tableSection`, jamais `pw.Page` : le
//  nombre de classes suit l'école. À vingt classes un document sur page fixe
//  déborde SANS erreur — les totaux sortent simplement du papier.
// ════════════════════════════════════════════════════════════════════════════

final _fmtEntier = NumberFormat.decimalPattern('fr');
String _n(int v) => _fmtEntier.format(v);
String _f(int v) => '${_fmtEntier.format(v)} F';

const _kBleu = PdfColor.fromInt(0xFF0EA5E9);

class RapportPdfService {
  // ── État des effectifs ─────────────────────────────────────────────────────
  static Future<Uint8List> etatEffectifs({
    required EtatEffectifs etat,
    required String? anneeLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final maintenant = DateTime.now();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(maintenant);
    final ref = DateFormat('yyyyMMdd-HHmm').format(maintenant);
    const titre = 'État des effectifs';

    final doc = pw.Document(
      title: titre,
      author: OfficialPdfKit.issuer?.name ?? 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Effectifs par classe et par cycle',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'ÉTAT DES\nEFFECTIFS', title: titre),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'ÉTAT DES EFFECTIFS',
            title: anneeLabel ?? 'Année en cours',
            line1: 'Arrêté au ${DateFormat('dd MMMM yyyy', 'fr').format(maintenant)} '
                '— ${_n(etat.total.total)} élève(s) inscrit(s)',
            line2: 'Élèves dont l\'inscription est active à cette date. '
                'Les dossiers en attente, retirés ou transférés en sont exclus.'),
        pw.SizedBox(height: 16),
        _kpis(etat.total, f),
        pw.SizedBox(height: 18),
        for (final bloc in etat.blocs) ...[
          ...OfficialPdfKit.tableSection(
            title: 'CYCLE ${bloc.cycle.toUpperCase()}',
            color: kPdfNavy,
            fonts: f,
            headers: _kEntetes,
            rows: [
              for (final l in bloc.classes) _ligne(l),
              _ligne(bloc.total),
            ],
            flex: _kFlex,
            leftAlignCols: const {0},
            emptyLabel: 'Aucune classe rattachée à ce cycle.',
          ),
          pw.SizedBox(height: 12),
        ],
        ...OfficialPdfKit.tableSection(
          title: 'RÉCAPITULATIF',
          color: kPdfGreen,
          fonts: f,
          headers: _kEntetes,
          rows: [_ligne(etat.total)],
          flex: _kFlex,
          leftAlignCols: const {0},
          emptyLabel: 'Aucun élève inscrit.',
          note: _noteSexe(etat.total),
        ),
        pw.SizedBox(height: 24),
        _signatures(f),
        pw.SizedBox(height: 16),
      ],
    ));

    return doc.save();
  }

  static const _kEntetes = [
    'Classe',
    'Effectif',
    'Filles',
    'Garçons',
    'Non précisé',
    'Internes',
    'Boursiers',
  ];
  static const _kFlex = [4, 2, 2, 2, 2, 2, 2];

  static List<String> _ligne(LigneEffectif l) {
    final part = partFilles(l);
    return [
      l.className,
      _n(l.total),
      part == null ? _n(l.filles) : '${_n(l.filles)} (${part.round()} %)',
      _n(l.garcons),
      // Un tiret plutôt qu'un zéro : « 0 » se lit comme un comptage, le tiret
      // comme « rien à signaler ». La colonne n'existe que pour les anomalies.
      l.sexeInconnu == 0 ? '—' : _n(l.sexeInconnu),
      l.internes == 0 ? '—' : _n(l.internes),
      l.boursiers == 0 ? '—' : _n(l.boursiers),
    ];
  }

  /// ⚠️ La mention n'apparaît QUE s'il y a des sexes non renseignés. Imprimée
  /// à chaque fois, elle deviendrait du décor qu'on ne lit plus ; imprimée
  /// jamais, un état où filles + garçons ≠ effectif passerait pour une erreur
  /// de calcul.
  static String? _noteSexe(LigneEffectif total) => total.sexeInconnu == 0
      ? null
      : '${_n(total.sexeInconnu)} élève(s) sans sexe renseigné : ils comptent '
          'dans l\'effectif mais ni chez les filles ni chez les garçons.';

  static pw.Widget _kpis(LigneEffectif t, PdfFonts f) {
    final part = partFilles(t);
    return OfficialPdfKit.kpiGrid(f, [
      PdfKpi('Élèves inscrits', _n(t.total), kPdfNavy),
      PdfKpi('Filles', part == null ? '—' : '${part.round()} %', kPdfGold),
      PdfKpi('Internes', _n(t.internes), _kBleu),
    ]);
  }

  // ── État de recouvrement ───────────────────────────────────────────────────
  static Future<Uint8List> etatRecouvrement({
    required List<LigneRecouvrement> lignes,
    required String? anneeLabel,
    required bool sansBareme,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final maintenant = DateTime.now();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(maintenant);
    final ref = DateFormat('yyyyMMdd-HHmm').format(maintenant);
    const titre = 'État de recouvrement';

    final effectif = lignes.fold(0, (a, l) => a + l.effectif);
    final aJour = lignes.fold(0, (a, l) => a + l.aJour);
    final du = lignes.fold(0, (a, l) => a + l.du);
    final encaisse = lignes.fold(0, (a, l) => a + l.encaisse);

    final doc = pw.Document(
      title: titre,
      author: OfficialPdfKit.issuer?.name ?? 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Recouvrement des frais de scolarité par classe',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'ÉTAT DE\nRECOUVREMENT', title: titre),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'ÉTAT DE RECOUVREMENT',
            title: anneeLabel ?? 'Année en cours',
            line1: 'Arrêté au ${DateFormat('dd MMMM yyyy', 'fr').format(maintenant)}',
            line2: 'Frais de scolarité uniquement. Les frais d\'examen relèvent '
                'du module Examens et n\'entrent pas dans ce document.'),
        pw.SizedBox(height: 16),
        if (sansBareme)
          _avertissement(f,
              'Aucun barème n\'est publié pour cette année : le dû ne peut pas '
              'être établi. Les montants encaissés restent exacts.')
        else
          OfficialPdfKit.kpiGrid(f, [
            PdfKpi('Élèves à jour', '$aJour / $effectif', kPdfGreen),
            PdfKpi('Encaissé', _f(encaisse), kPdfNavy),
            PdfKpi('Reste dû', _f((du - encaisse).clamp(0, du)), kPdfRed),
          ]),
        pw.SizedBox(height: 18),
        ...OfficialPdfKit.tableSection(
          title: 'RECOUVREMENT PAR CLASSE',
          color: kPdfNavy,
          fonts: f,
          headers: const [
            'Classe',
            'Effectif',
            'À jour',
            'Dû à ce jour',
            'Encaissé',
            'Reste dû',
          ],
          rows: [
            for (final l in lignes)
              [
                l.className,
                _n(l.effectif),
                '${l.aJour}/${l.effectif}',
                _f(l.du),
                _f(l.encaisse),
                _f(resteDe(l)),
              ],
            [
              'TOTAL ÉTABLISSEMENT',
              _n(effectif),
              '$aJour/$effectif',
              _f(du),
              _f(encaisse),
              _f((du - encaisse).clamp(0, du)),
            ],
          ],
          flex: const [4, 2, 2, 3, 3, 3],
          leftAlignCols: const {0},
          emptyLabel: 'Aucune classe.',
          note: 'Le dû tient compte de la date d\'entrée de chaque élève et des '
              'exonérations accordées : deux élèves d\'une même classe peuvent '
              'devoir des montants différents.',
        ),
        pw.SizedBox(height: 24),
        _signatures(f),
        pw.SizedBox(height: 16),
      ],
    ));

    return doc.save();
  }

  // ── État du personnel ──────────────────────────────────────────────────────
  static Future<Uint8List> etatPersonnel({
    required EtatPersonnel etat,
    required String? anneeLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final maintenant = DateTime.now();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(maintenant);
    final ref = DateFormat('yyyyMMdd-HHmm').format(maintenant);
    const titre = 'État du personnel';

    final doc = pw.Document(
      title: titre,
      author: OfficialPdfKit.issuer?.name ?? 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Personnel en poste par catégorie et par statut d\'emploi',
    );

    List<String> ligne(LignePersonnel l) => [
          l.libelle,
          _n(l.enFonction),
          l.inactifs == 0 ? '—' : _n(l.inactifs),
        ];

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'ÉTAT DU\nPERSONNEL', title: titre),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'ÉTAT DU PERSONNEL',
            title: anneeLabel ?? 'Année en cours',
            line1: 'Arrêté au ${DateFormat('dd MMMM yyyy', 'fr').format(maintenant)} '
                '— ${_n(etat.total.enFonction)} agent(s) en poste',
            line2: 'Élèves et parents exclus : ce sont des usagers, pas du '
                'personnel.'),
        pw.SizedBox(height: 16),
        if (!etat.directionEnPoste)
          _avertissement(f,
              'Aucun agent de direction n\'est en fonction dans cette école. '
              'À corriger avant transmission — cet état doit être signé.')
        else
          OfficialPdfKit.kpiGrid(f, [
            PdfKpi('Agents en poste', _n(etat.total.enFonction), kPdfNavy),
            PdfKpi('Catégories', '${etat.categories.length}', _kBleu),
            PdfKpi('Comptes désactivés', _n(etat.total.inactifs), kPdfMuted),
          ]),
        pw.SizedBox(height: 18),
        ...OfficialPdfKit.tableSection(
          title: 'PAR CATÉGORIE',
          color: kPdfNavy,
          fonts: f,
          headers: const ['Catégorie', 'En poste', 'Désactivés'],
          rows: [
            for (final l in etat.categories) ligne(l),
            ligne(etat.total),
          ],
          flex: const [5, 2, 2],
          leftAlignCols: const {0},
          emptyLabel: 'Aucun agent rattaché à cette école.',
        ),
        pw.SizedBox(height: 12),
        ...OfficialPdfKit.tableSection(
          title: 'PAR STATUT D\'EMPLOI',
          color: kPdfGreen,
          fonts: f,
          headers: const ['Statut', 'En poste', 'Désactivés'],
          rows: [for (final l in etat.statuts) ligne(l)],
          flex: const [5, 2, 2],
          leftAlignCols: const {0},
          emptyLabel: 'Aucun agent rattaché à cette école.',
          note: _noteStatut(etat.statuts),
        ),
        pw.SizedBox(height: 24),
        _signatures(f),
        pw.SizedBox(height: 16),
      ],
    ));

    return doc.save();
  }

  /// ⚠️ Comme la mention sur les sexes non renseignés : imprimée SEULEMENT s'il
  /// y a lieu. Un avertissement systématique cesse d'être lu.
  static String? _noteStatut(List<LignePersonnel> statuts) {
    final inconnu = statuts.where((l) => l.libelle == kStatutNonRenseigne);
    if (inconnu.isEmpty) return null;
    final n = inconnu.fold(0, (a, l) => a + l.enFonction + l.inactifs);
    return '$n agent(s) sans statut d\'emploi renseigné : ils comptent dans '
        'l\'effectif, mais leur régime ne peut pas être déclaré.';
  }

  static pw.Widget _avertissement(PdfFonts f, String texte) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: kPdfSurface,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: kPdfGold, width: 1.2),
          ),
          child: pw.Text(texte,
              style:
                  pw.TextStyle(font: f.medium, fontSize: 9.5, color: kPdfText)),
        ),
      );

  /// Un état officiel se signe. Sans ces cases, le document sort tel quel et
  /// l'agent le complète à la main, de travers, sur chaque exemplaire.
  static pw.Widget _signatures(PdfFonts f) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            for (final r in const ['Le Secrétaire', 'Le Chef d\'établissement'])
              pw.Container(
                width: 200,
                padding: const pw.EdgeInsets.only(top: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      top: pw.BorderSide(color: kPdfBorder, width: 0.8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(r,
                        style: pw.TextStyle(
                            font: f.medium, fontSize: 9, color: kPdfMuted)),
                    pw.SizedBox(height: 34),
                  ],
                ),
              ),
          ],
        ),
      );
}
