part of '../economie_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE DÉTAIL DERRIÈRE CHAQUE KPI
//
//  ── LE DÉFAUT ─────────────────────────────────────────────────────────────
//  Quatre nombres en haut de l'écran — abonnements, licences, coût, marge — et
//  rien derrière. « 245 000 F par mois » ne se vérifie pas, ne se conteste pas
//  et ne se corrige pas : on ne sait pas de QUI il vient. Le fondateur : « les
//  KPI doivent être bien disponibles, cliquables si possible, on a besoin de
//  voir le détail ».
//
//  ── LA RÈGLE DE CES QUATRE FICHES ─────────────────────────────────────────
//  Chacune montre la DÉCOMPOSITION du nombre affiché, ligne par ligne, et la
//  somme se retrouve en bas. Rien d'autre : ce ne sont pas des tableaux de
//  bord, ce sont des justificatifs. Un chiffre qu'on ne peut pas décomposer
//  est un chiffre qu'on finit par ne plus croire.
//
//  ⚠️ Le graphe accompagne, il ne remplace pas les lignes. Sur sept groupes,
//  une barre de plus qu'une autre ne dit rien qu'un montant ne dise mieux.
// ════════════════════════════════════════════════════════════════════════════

void _ouvrirDetailRevenu(BuildContext context, EconomieData d) {
  showDialog<void>(
    context: context,
    builder: (_) => _KpiDetail(
      icone: Icons.school_rounded,
      titre: 'Revenu des abonnements',
      sousTitre: 'Groupes actifs, tarif ramené au mois',
      couleur: kNavy,
      total: d.mrrAbonnementsXaf,
      totalLabel: 'Total mensuel',
      corps: const _ExplicationAbonnements(),
    ),
  );
}

void _ouvrirDetailLicences(BuildContext context, EconomieData d) {
  final actives = [
    for (final l in d.licences)
      if (l.estActive) l,
  ];
  showDialog<void>(
    context: context,
    builder: (_) => _KpiDetail(
      icone: Icons.account_balance_rounded,
      titre: 'Revenu des licences de tutelle',
      sousTitre: actives.isEmpty
          ? 'Aucune licence active'
          : '${actives.length} marché${actives.length > 1 ? 's' : ''} en cours',
      couleur: kListPurple,
      total: d.mrrLicencesXaf,
      totalLabel: 'Total mensuel',
      corps: _LignesLicences(licences: d.licences, soldeDu: d.soldeDuXaf),
    ),
  );
}

void _ouvrirDetailCouts(BuildContext context, EconomieData d) {
  final actifs = [
    for (final c in d.couts)
      if (c.isActive) c,
  ]..sort((a, b) => b.mensuelXaf.compareTo(a.mensuelXaf));
  showDialog<void>(
    context: context,
    builder: (_) => _KpiDetail(
      icone: Icons.dns_rounded,
      titre: 'Coût d’exploitation',
      sousTitre: 'Postes actifs, ramenés au mois',
      couleur: kListOrange,
      total: d.coutMensuelXaf,
      totalLabel: 'Total mensuel',
      corps: _LignesCouts(couts: actifs, total: d.coutMensuelXaf),
    ),
  );
}

void _ouvrirDetailMarge(BuildContext context, EconomieData d) {
  showDialog<void>(
    context: context,
    builder: (_) => _KpiDetail(
      icone: d.margeMensuelleXaf >= 0
          ? Icons.trending_up_rounded
          : Icons.trending_down_rounded,
      titre: 'Marge mensuelle',
      sousTitre: 'Ce qui rentre, moins ce qui sort',
      couleur: d.margeMensuelleXaf >= 0 ? kGreen : kRed,
      total: d.margeMensuelleXaf,
      totalLabel: 'Écart mensuel',
      corps: _LignesMarge(data: d),
    ),
  );
}

// ─── La coquille commune ────────────────────────────────────────────────────
class _KpiDetail extends StatelessWidget {
  const _KpiDetail({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.couleur,
    required this.total,
    required this.totalLabel,
    required this.corps,
  });

  final IconData icone;
  final String titre, sousTitre, totalLabel;
  final Color couleur;
  final int total;
  final Widget corps;

  @override
  Widget build(BuildContext context) => AdminFormDialog(
        icon: icone,
        title: titre,
        subtitle: sousTitre,
        accent: couleur,
        width: 560,
        // Le total reste visible pendant qu'on parcourt les lignes : c'est
        // LUI qu'on vérifie, et le perdre en défilant fait recommencer.
        hero: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.06),
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            Text(totalLabel.toUpperCase(),
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: kTextMuted)),
            const Spacer(),
            Text(fmtXaf(total),
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: total < 0 ? kRed : kTextPrimary)),
          ]),
        ),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
          child: Row(children: [
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fermer', style: TextStyle(color: kTextMuted)),
            ),
          ]),
        ),
        body: corps,
      );
}

// ─── Abonnements ────────────────────────────────────────────────────────────
class _ExplicationAbonnements extends StatelessWidget {
  const _ExplicationAbonnements();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Note(
            'Somme des tarifs des groupes dont l’abonnement est ACTIF, chacun '
            'ramené au mois. Un plan annuel de 2 500 000 F pèse 208 333 F de '
            'revenu mensuel, pas 2 500 000.',
          ),
          SizedBox(height: 12),
          _Note(
            '⚠️ Le tarif suit le nombre d’écoles facturées (grille dégressive, '
            'migration 0159), et un tarif négocié le remplace quand il existe. '
            'Le détail par groupe se lit sur la page Abonnements.',
          ),
          SizedBox(height: 12),
          _Note(
            'Les deux ministères n’y sont PAS : depuis 0182 ils portent le plan '
            '« Licence de tutelle » à 0 F. Leurs montants réels comptent dans '
            'la carte voisine — les additionner ici les compterait deux fois.',
          ),
        ],
      );
}

// ─── Licences ───────────────────────────────────────────────────────────────
class _LignesLicences extends StatelessWidget {
  const _LignesLicences({required this.licences, required this.soldeDu});

  final List<LicenceTutelle> licences;
  final int soldeDu;

  @override
  Widget build(BuildContext context) {
    if (licences.isEmpty) {
      return const _Note(
        'Aucune licence enregistrée. Tant qu’un marché n’est pas saisi ET '
        'activé, le revenu de licence est ZÉRO — pas un montant « prévu ».',
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final l in licences) ...[
        _LigneMontant(
          titre: l.groupeNom,
          sousTitre: '${l.intitule} · ${libelleStatutLicenceOuTiret(l.statut)}',
          montant: l.mensuelCompte,
          couleur: couleurStatutLicence(l.statut),
          // ⚠️ Une licence non active pèse ZÉRO. On la montre quand même, avec
          // son montant barré : une ligne absente se lit comme un oubli de
          // saisie, une ligne à zéro se lit comme une décision.
          barre: !l.estActive ? fmtXaf(l.mensuelXaf) : null,
        ),
        const SizedBox(height: 8),
      ],
      if (soldeDu > 0) ...[
        const SizedBox(height: 6),
        _Note('Reste à encaisser sur les marchés actifs : ${fmtXaf(soldeDu)}. '
            'Ce n’est pas du revenu mensuel — c’est de la trésorerie attendue.'),
      ],
    ]);
  }
}

// ─── Coûts ──────────────────────────────────────────────────────────────────
class _LignesCouts extends StatelessWidget {
  const _LignesCouts({required this.couts, required this.total});

  final List<CoutPlateforme> couts;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (couts.isEmpty) {
      return const _Note('Aucun coût saisi. La marge affichée est alors le '
          'revenu brut — un chiffre qui flatte et n’apprend rien.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final c in couts) ...[
        _LigneMontant(
          titre: c.label,
          sousTitre: [
            if (c.fournisseur != null) c.fournisseur!,
            billingPeriodLabel(c.periodicite),
            if (c.montantOrigine != null && c.deviseOrigine != null)
              '${c.montantOrigine!.toStringAsFixed(0)} ${c.deviseOrigine}',
          ].join(' · '),
          montant: c.mensuelXaf,
          couleur: kListOrange,
          part: total <= 0 ? null : c.mensuelXaf / total,
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 6),
      const _Note(
        '⚠️ Le poste qui surprend : les CLIENTS SIMULTANÉS. Chaque appareil du '
        'personnel qui a l’application ouverte en compte un — le coût suit le '
        'nombre d’appareils, pas le nombre d’élèves.',
      ),
    ]);
  }
}

// ─── Marge ──────────────────────────────────────────────────────────────────
class _LignesMarge extends StatelessWidget {
  const _LignesMarge({required this.data});

  final EconomieData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final seuil = d.seuilEnGroupes(30000);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _LigneMontant(
          titre: 'Abonnements',
          sousTitre: 'groupes actifs',
          montant: d.mrrAbonnementsXaf,
          couleur: kNavy),
      const SizedBox(height: 8),
      _LigneMontant(
          titre: 'Licences de tutelle',
          sousTitre: 'marchés actifs, ramenés au mois',
          montant: d.mrrLicencesXaf,
          couleur: kListPurple),
      const SizedBox(height: 8),
      _LigneMontant(
          titre: 'Coût d’exploitation',
          sousTitre: 'postes actifs',
          montant: -d.coutMensuelXaf,
          couleur: kListOrange),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(children: [
          Icon(Icons.flag_rounded, size: 16, color: kTextMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              // Le nombre le plus parlant du tableau : le seuil de survie.
              '$seuil groupe${seuil > 1 ? 's' : ''} mono-école au plan Standard '
              'couvre${seuil > 1 ? 'nt' : ''} l’infrastructure. Ce n’est pas '
              'une projection, c’est le seuil de survie.',
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.45),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ─── Pièces ─────────────────────────────────────────────────────────────────
class _LigneMontant extends StatelessWidget {
  const _LigneMontant({
    required this.titre,
    required this.sousTitre,
    required this.montant,
    required this.couleur,
    this.part,
    this.barre,
  });

  final String titre, sousTitre;
  final int montant;
  final Color couleur;

  /// Part du total, 0..1 — la barre sous la ligne.
  final double? part;

  /// Montant théorique affiché barré (ligne qui ne compte pas).
  final String? barre;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: couleur, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                    Text(sousTitre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: kTextMuted)),
                  ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtXaf(montant),
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: montant < 0 ? kListOrange : kTextPrimary)),
              if (barre != null)
                Text(barre!,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: kTextMuted,
                      decoration: TextDecoration.lineThrough,
                    )),
            ]),
          ]),
          if (part != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: part!.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: couleur.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation(couleur),
              ),
            ),
          ],
        ]),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Text(texte,
      style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.5));
}
