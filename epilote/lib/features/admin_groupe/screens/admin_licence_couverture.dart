import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../tutelle/providers/tutelle_reseau_provider.dart';
import '../providers/admin_licence_provider.dart';
import '../providers/admin_subscription_provider.dart';
import 'admin_licence_modales.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE LA LICENCE ACHÈTE — chiffres cliquables, graphes, détail en modale
//
//  ── LE DÉFAUT, DIT PAR LE FONDATEUR ───────────────────────────────────────
//  « Je trouve ces pages pauvres, je pense que c'est mal conçu. Les KPI
//    doivent être bien disponibles, cliquables si possible. On a besoin de
//    voir le détail de la licence avec des modales, et des graphes pour
//    définir les utilisations. Les KPI que tu as mis en bas, la taille ne
//    correspond pas. »
//
//  Trois défauts distincts, et le troisième était le plus bête :
//
//   1. DES CHIFFRES MORTS. Cinq nombres alignés dans un `Wrap`, sans rien
//      derrière. « 12 500 élèves » ne se vérifie pas et ne mène nulle part.
//   2. AUCUN GRAPHE. Un marché national se défend avec une couverture
//      territoriale, pas avec une liste de totaux.
//   3. ⚠️ UNE TAILLE INVENTÉE. J'avais écrit un `_Chiffre` maison — icône
//      34 px, valeur 17 px — à côté du `_QuotaGrid` hérité (cartes de 110 px)
//      et du `KpiGrid` du reste de l'application (118 px). Trois gabarits de
//      carte sur la MÊME page. Tout passe désormais par `KpiGrid`, comme
//      partout ailleurs ; le gabarit maison a disparu, et la grille de quotas
//      avec — ses trois jauges affichaient « Illimité » pour un ministère.
// ════════════════════════════════════════════════════════════════════════════

class LicenceCouvertureSection extends ConsumerWidget {
  const LicenceCouvertureSection({super.key, required this.sub});

  final GroupSubscription sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licences = ref.watch(licencesDuGroupeProvider).valueOrNull;
    final licence = licences == null ? null : licenceAMontrer(licences);
    final reseau = ref.watch(reseauSuperviseProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      reseau.when(
        loading: () => const _ReseauEnAttente(),
        // ⚠️ On DIT l'échec plutôt que d'afficher « 0 établissement ». Un zéro
        // faux sur cette page finit recopié dans un état ministériel.
        error: (e, _) => AdminErrorBanner(message: '$e'),
        data: (r) => _Couverture(sub: sub, reseau: r, licence: licence),
      ),
      if (licences != null && licences.length > 1) ...[
        const SizedBox(height: 22),
        const AdminSectionTitle('Licences précédentes',
            icon: Icons.history_rounded,
            subtitle: 'Les marchés antérieurs restent consultables'),
        const SizedBox(height: 12),
        _Historique(licences: licences),
      ],
    ]);
  }
}

class _Couverture extends ConsumerWidget {
  const _Couverture(
      {required this.sub, required this.reseau, required this.licence});

  final GroupSubscription sub;
  final ReseauSupervise reseau;
  final LicenceDuGroupe? licence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = CouvertureLicence.calculer(sub: sub, reseau: reseau);
    final l = licence;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const AdminSectionTitle('Ce que couvre votre licence',
          icon: Icons.hub_rounded,
          subtitle: 'Chaque chiffre s’ouvre sur son détail'),
      const SizedBox(height: 12),
      // ⚠️ LE MÊME `KpiGrid` que partout ailleurs dans l'application : mêmes
      // cartes, même hauteur, même comportement au survol. C'est ce qui
      // manquait — trois gabarits différents sur une page se voient tout de
      // suite, même sans savoir pourquoi.
      KpiGrid(items: [
        KpiData(
          label: 'Établissements couverts',
          value: '${c.ecolesTotal}',
          sub: reseau.nbEcolesPropres > 0
              ? 'dont ${reseau.nbEcolesPropres} en propre'
              : 'sur tout votre réseau',
          icon: Icons.school_rounded,
          color: kNavy,
          onTap: () => ouvrirDetailEtablissements(context, reseau, c),
        ),
        KpiData(
          label: 'Élèves',
          value: fmtInt(c.eleves),
          sub: c.filles > 0
              ? '${(c.filles * 100 / c.eleves).round()} % de filles'
              : 'effectif couvert',
          icon: Icons.groups_rounded,
          color: kGreen,
          onTap: () => ouvrirDetailEleves(context, reseau, c),
        ),
        KpiData(
          label: 'Personnels',
          value: fmtInt(c.personnel),
          sub: '${reseau.groupes.length} groupe'
              '${reseau.groupes.length > 1 ? 's' : ''} supervisé'
              '${reseau.groupes.length > 1 ? 's' : ''}',
          icon: Icons.badge_rounded,
          color: kAccent,
          onTap: () => ouvrirDetailGroupes(context, reseau),
        ),
        KpiData(
          label: 'Modules ouverts',
          value: '${sub.moduleCount}',
          sub: 'inclus à la licence',
          icon: Icons.extension_rounded,
          color: kListPurple,
          onTap: () => ouvrirDetailDroits(context),
        ),
        if (l != null) ...[
          KpiData(
            label: 'Coût par établissement',
            value: fmtXaf(l.coutAnnuelParEtablissement(c.ecolesTotal) ?? 0),
            sub: 'par an — le chiffre qui se défend',
            icon: Icons.calculate_rounded,
            color: kListOrange,
            onTap: () => ouvrirDetailCoutUnitaire(context, l, c),
          ),
          KpiData(
            label: 'Marché réglé',
            value: '${((l.partReglee ?? 0) * 100).round()} %',
            sub: l.soldee
                ? 'intégralement réglé'
                : 'reste ${fmtXaf(l.soldeXaf)}',
            icon: Icons.payments_rounded,
            color: (l.partReglee ?? 0) >= l.partEcoulee ? kGreen : kListOrange,
            progressValue: l.partReglee,
            trend: '${(l.partEcoulee * 100).round()} % écoulé',
            trendUp: (l.partReglee ?? 0) >= l.partEcoulee,
            onTap: () => ouvrirDetailReglement(context, l),
          ),
        ],
      ]),
      const SizedBox(height: 22),
      const AdminSectionTitle('Utilisation de votre réseau',
          icon: Icons.insights_rounded,
          subtitle: 'Où sont les élèves que votre licence couvre'),
      const SizedBox(height: 12),
      _GraphesUtilisation(reseau: reseau, couverture: c),
      const SizedBox(height: 22),
      const _DroitsDeTutelle(),
    ]);
  }
}

// ─── Les graphes ────────────────────────────────────────────────────────────
//
//  ⚠️ DEUX QUESTIONS, DEUX GRAPHES, et pas un de plus.
//   • « Où sont mes élèves ? »        → répartition par département (barres).
//   • « Qui compose mon réseau ? »    → poids de chaque groupe (anneau).
//  Un troisième graphe sur les mêmes données ferait joli et n'apprendrait
//  rien : chaque graphe doit répondre à une question qu'on se pose vraiment.
class _GraphesUtilisation extends StatelessWidget {
  const _GraphesUtilisation({required this.reseau, required this.couverture});

  final ReseauSupervise reseau;
  final CouvertureLicence couverture;

  @override
  Widget build(BuildContext context) {
    if (reseau.ecoles.isEmpty) {
      return AdminCard(
        child: Text(
            'Aucun établissement supervisé pour l’instant : il n’y a rien à '
            'représenter.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
      );
    }
    return LayoutBuilder(builder: (_, c) {
      final cote = c.maxWidth >= 900;
      final departements = _ParDepartement(reseau: reseau);
      final groupes = _ParGroupe(reseau: reseau);
      return cote
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: departements),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: groupes),
            ])
          : Column(children: [
              departements,
              const SizedBox(height: 14),
              groupes,
            ]);
    });
  }
}

class _PointDep {
  const _PointDep(this.departement, this.eleves, this.ecoles);
  final String departement;
  final int eleves, ecoles;
}

class _ParDepartement extends StatelessWidget {
  const _ParDepartement({required this.reseau});

  final ReseauSupervise reseau;

  @override
  Widget build(BuildContext context) {
    final parDep = <String, ({int eleves, int ecoles})>{};
    for (final e in reseau.ecoles) {
      // ⚠️ `departement` est nullable côté RPC : une école sans département
      // se range sous « Non renseigné » plutôt que de disparaître du graphe.
      final d = (e.departement ?? '').trim().isEmpty
          ? 'Non renseigné'
          : e.departement!;
      final v = parDep[d] ?? (eleves: 0, ecoles: 0);
      parDep[d] = (eleves: v.eleves + e.nbEleves, ecoles: v.ecoles + 1);
    }
    final points = [
      for (final e in parDep.entries)
        _PointDep(e.key, e.value.eleves, e.value.ecoles),
    ]..sort((a, b) => b.eleves.compareTo(a.eleves));
    // Au-delà de dix barres, un graphe de département devient un mur.
    final visibles = points.take(10).toList();

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Élèves par département',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: kTextPrimary)),
        Text(
            points.length > visibles.length
                ? '${visibles.length} premiers sur ${points.length}'
                : '${points.length} département${points.length > 1 ? 's' : ''} couvert${points.length > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 11, color: kTextMuted)),
        SizedBox(
          height: 240,
          // ⚠️ `CategoryAxis` en X (String) et `NumericAxis` en Y (num) —
          // inverser fait planter Syncfusion en « String is not a subtype of
          // num », et l'erreur ne dit pas laquelle des deux est fautive.
          child: SfCartesianChart(
            margin: const EdgeInsets.only(top: 12),
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
              labelRotation: -35,
              majorGridLines: const MajorGridLines(width: 0),
              labelStyle: TextStyle(fontSize: 9.5, color: kTextMuted),
            ),
            primaryYAxis: NumericAxis(
              axisLine: const AxisLine(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
              labelStyle: TextStyle(fontSize: 9.5, color: kTextMuted),
            ),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: <CartesianSeries<_PointDep, String>>[
              ColumnSeries<_PointDep, String>(
                dataSource: visibles,
                xValueMapper: (p, _) => p.departement,
                yValueMapper: (p, _) => p.eleves.toDouble(),
                name: 'Élèves',
                color: kNavy,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
                width: 0.6,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PointGroupe {
  const _PointGroupe(this.nom, this.eleves);
  final String nom;
  final int eleves;
}

class _ParGroupe extends StatelessWidget {
  const _ParGroupe({required this.reseau});

  final ReseauSupervise reseau;

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final g in reseau.groupes)
        if (g.nbEleves > 0) _PointGroupe(g.nom, g.nbEleves),
    ]..sort((a, b) => b.eleves.compareTo(a.eleves));

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Poids des groupes supervisés',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: kTextPrimary)),
        Text('${points.length} groupe${points.length > 1 ? 's' : ''} tiers',
            style: TextStyle(fontSize: 11, color: kTextMuted)),
        SizedBox(
          height: 240,
          child: points.isEmpty
              ? Center(
                  child: Text('Aucun groupe tiers',
                      style: TextStyle(fontSize: 12, color: kTextMuted)))
              : SfCircularChart(
                  margin: const EdgeInsets.only(top: 8),
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    overflowMode: LegendItemOverflowMode.wrap,
                    textStyle: TextStyle(fontSize: 9.5, color: kTextMuted),
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CircularSeries<_PointGroupe, String>>[
                    DoughnutSeries<_PointGroupe, String>(
                      dataSource: points,
                      xValueMapper: (p, _) => p.nom,
                      yValueMapper: (p, _) => p.eleves.toDouble(),
                      innerRadius: '62%',
                      dataLabelSettings: const DataLabelSettings(
                          isVisible: false),
                    ),
                  ],
                ),
        ),
      ]),
    );
  }
}

/// Ce que la licence ouvre en propre, au-delà des chiffres. Écrit en toutes
/// lettres parce que c'est l'objet du marché : ce sont ces quatre droits que
/// la plateforme vend, et aucun autre écran ne les listait.
class _DroitsDeTutelle extends StatelessWidget {
  const _DroitsDeTutelle();

  @override
  Widget build(BuildContext context) => AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.verified_rounded, size: 17, color: kGreen),
              const SizedBox(width: 8),
              Text('Ce que la licence vous ouvre',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ]),
            const SizedBox(height: 12),
            for (final (icone, titre, texte) in kDroitsDeTutelle)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child:
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icone, size: 15, color: kGreen),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titre,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary)),
                          Text(texte,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: kTextMuted,
                                  height: 1.4)),
                        ]),
                  ),
                ]),
              ),
          ],
        ),
      );
}

// ─── Historique ─────────────────────────────────────────────────────────────
class _Historique extends StatelessWidget {
  const _Historique({required this.licences});

  final List<LicenceDuGroupe> licences;

  @override
  Widget build(BuildContext context) {
    final courante = licenceAMontrer(licences);
    final autres = [
      for (final l in licences)
        if (!identical(l, courante)) l,
    ];
    return Column(
      children: [
        for (final l in autres)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                AdminBadge(l.statutLabel,
                    color: couleurStatutLicence(l.statut)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.intitule,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary)),
                        Text(
                            '${_annee(l.dateDebut)} → ${_annee(l.dateFin)}'
                            '${l.referenceMarche == null ? '' : ' · ${l.referenceMarche}'}',
                            style:
                                TextStyle(fontSize: 11, color: kTextMuted)),
                      ]),
                ),
                const SizedBox(width: 12),
                Text(fmtXaf(l.montantXaf),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ]),
            ),
          ),
      ],
    );
  }
}

class _ReseauEnAttente extends StatelessWidget {
  const _ReseauEnAttente();

  @override
  Widget build(BuildContext context) => AdminCard(
        child: Row(children: [
          SizedBox(
              width: 14,
              height: 14,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: kTextMuted)),
          const SizedBox(width: 10),
          Text('Décompte de votre réseau…',
              style: TextStyle(fontSize: 12.5, color: kTextMuted)),
        ]),
      );
}

String _annee(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
