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
//  ── CE QUI A CHANGÉ ───────────────────────────────────────────────────────
//  Ces fiches sont devenues des `FicheDetail` — la même donnée à l'écran et
//  sur le papier. Trois conséquences :
//   • elles S'IMPRIMENT, avec aperçu avant impression, comme celles du
//     ministère ;
//   • elles se cherchent et n'ont plus de plafond de longueur ;
//   • ⚠️ le revenu des abonnements MONTRE ENFIN SES GROUPES. La fiche la plus
//     ancienne était la seule à ne décomposer rien du tout : elle expliquait
//     le calcul en trois paragraphes sans nommer un seul payeur. Ce n'était
//     pas un justificatif, c'était une note de bas de page.
// ════════════════════════════════════════════════════════════════════════════

void _ouvrirDetailRevenu(BuildContext context, EconomieData d) {
  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: 'Revenu des abonnements',
      sousTitre: 'Groupes actifs, tarif ramené au mois',
      icone: Icons.school_rounded,
      couleur: kNavy,
      total: fmtXaf(d.mrrAbonnementsXaf),
      totalLabel: 'Total mensuel',
      nomFichier: 'Economie_Revenu_abonnements',
      chiffres: [
        ('groupes actifs', '${d.abonnements.length}'),
        if (d.groupesInactifs > 0) ('inactifs', '${d.groupesInactifs}'),
        ('à l’année', fmtXaf(d.mrrAbonnementsXaf * 12)),
      ],
      sections: [
        SectionFiche(
          titre: 'Par groupe scolaire',
          enTetes: const ['Groupe', 'Écoles', 'Par mois'],
          flex: const [5, 2, 3],
          lignes: [
            for (final a in d.abonnements)
              LigneFiche(
                titre: a.nom,
                sousTitre: [
                  billingPeriodLabel(a.periode),
                  if (a.negocie) 'tarif négocié',
                ].join(' · '),
                colonnes: ['${a.ecoles}'],
                valeur: fmtXaf(a.mensuelXaf),
              ),
          ],
          note: 'Somme : ${fmtXaf(d.mrrAbonnementsXaf)} par mois.',
          videLabel: 'Aucun groupe en abonnement actif. Le revenu '
              'd’abonnement est ZÉRO — pas un montant « prévu ».',
        ),
      ],
      notes: [
        'Chaque tarif est ramené au mois : un plan annuel de 2 500 000 F pèse '
            '208 333 F de revenu mensuel, pas 2 500 000.',
        '⚠️ Le tarif suit le nombre d’écoles facturées (grille dégressive, '
            'migration 0159), et un tarif négocié le remplace quand il existe.',
        'Les deux ministères n’y sont PAS : depuis 0182 ils portent le plan '
            '« Licence de tutelle » à 0 F. Leurs montants réels comptent dans '
            'la carte voisine — les additionner ici les compterait deux fois.',
        if (d.groupesInactifs > 0)
          '${d.groupesInactifs} groupe(s) hors abonnement actif ne figurent '
              'pas dans cette liste : ils pèsent zéro.',
      ],
    ),
  );
}

void _ouvrirDetailLicences(BuildContext context, EconomieData d) {
  final actives = [
    for (final l in d.licences)
      if (l.estActive) l,
  ];

  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: 'Revenu des licences de tutelle',
      sousTitre: actives.isEmpty
          ? 'Aucune licence active'
          : '${actives.length} marché${actives.length > 1 ? 's' : ''} en cours',
      icone: Icons.account_balance_rounded,
      couleur: kListPurple,
      total: fmtXaf(d.mrrLicencesXaf),
      totalLabel: 'Total mensuel',
      nomFichier: 'Economie_Revenu_licences',
      chiffres: [
        ('marchés actifs', '${actives.length}'),
        if (d.soldeDuXaf > 0) ('reste à encaisser', fmtXaf(d.soldeDuXaf)),
      ],
      sections: [
        SectionFiche(
          titre: 'Par marché',
          enTetes: const ['Ministère', 'Marché', 'Compté / mois'],
          flex: const [4, 3, 3],
          lignes: [
            for (final l in d.licences)
              LigneFiche(
                titre: l.groupeNom,
                sousTitre: '${l.intitule} · '
                    '${libelleStatutLicenceOuTiret(l.statut)}'
                    // ⚠️ Une licence non active pèse ZÉRO. On la montre quand
                    // même, avec son montant théorique : une ligne absente se
                    // lit comme un oubli de saisie, une ligne à zéro se lit
                    // comme une décision.
                    '${l.estActive ? '' : ' · théorique ${fmtXaf(l.mensuelXaf)}'}',
                colonnes: [fmtXaf(l.montantXaf)],
                valeur: fmtXaf(l.mensuelCompte),
              ),
          ],
          note: 'Somme : ${fmtXaf(d.mrrLicencesXaf)} par mois.',
          videLabel: 'Aucune licence enregistrée. Tant qu’un marché n’est pas '
              'saisi ET activé, le revenu de licence est ZÉRO.',
        ),
      ],
      notes: [
        if (d.soldeDuXaf > 0)
          'Reste à encaisser sur les marchés actifs : ${fmtXaf(d.soldeDuXaf)}. '
              'Ce n’est pas du revenu mensuel — c’est de la trésorerie '
              'attendue.',
        'Seules les licences ACTIVES comptent dans le revenu mensuel.',
      ],
    ),
  );
}

void _ouvrirDetailCouts(BuildContext context, EconomieData d) {
  final actifs = [
    for (final c in d.couts)
      if (c.isActive) c,
  ]..sort((a, b) => b.mensuelXaf.compareTo(a.mensuelXaf));
  final total = d.coutMensuelXaf;

  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: 'Coût d’exploitation',
      sousTitre: 'Postes actifs, ramenés au mois',
      icone: Icons.dns_rounded,
      couleur: kListOrange,
      total: fmtXaf(total),
      totalLabel: 'Total mensuel',
      nomFichier: 'Economie_Couts',
      chiffres: [
        ('postes actifs', '${actifs.length}'),
        ('à l’année', fmtXaf(total * 12)),
      ],
      sections: [
        SectionFiche(
          titre: 'Par poste',
          enTetes: const ['Poste', 'Part', 'Par mois'],
          flex: const [5, 2, 3],
          lignes: [
            for (final c in actifs)
              LigneFiche(
                titre: c.label,
                sousTitre: [
                  if (c.fournisseur != null) c.fournisseur!,
                  billingPeriodLabel(c.periodicite),
                  if (c.montantOrigine != null && c.deviseOrigine != null)
                    '${c.montantOrigine!.toStringAsFixed(0)} ${c.deviseOrigine}',
                ].join(' · '),
                colonnes: [
                  total <= 0 ? '—' : '${(c.mensuelXaf * 100 / total).round()} %'
                ],
                valeur: fmtXaf(c.mensuelXaf),
              ),
          ],
          note: 'Somme : ${fmtXaf(total)} par mois.',
          videLabel: 'Aucun coût saisi. La marge affichée est alors le revenu '
              'brut — un chiffre qui flatte et n’apprend rien.',
        ),
      ],
      notes: const [
        '⚠️ Le poste qui surprend : les CLIENTS SIMULTANÉS. Chaque appareil du '
            'personnel qui a l’application ouverte en compte un — le coût suit '
            'le nombre d’appareils, pas le nombre d’élèves.',
      ],
    ),
  );
}

void _ouvrirDetailMarge(BuildContext context, EconomieData d) {
  final seuil = d.seuilEnGroupes(30000);
  final positive = d.margeMensuelleXaf >= 0;

  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: 'Marge mensuelle',
      sousTitre: 'Ce qui rentre, moins ce qui sort',
      icone: positive
          ? Icons.trending_up_rounded
          : Icons.trending_down_rounded,
      couleur: positive ? kGreen : kRed,
      total: fmtXaf(d.margeMensuelleXaf),
      totalLabel: 'Écart mensuel',
      nomFichier: 'Economie_Marge',
      chiffres: [
        ('recettes', fmtXaf(d.mrrTotalXaf)),
        ('charges', fmtXaf(d.coutMensuelXaf)),
        if (d.tauxMarge != null) ('taux', '${d.tauxMarge!.round()} %'),
      ],
      sections: [
        SectionFiche(
          titre: 'Le calcul',
          enTetes: const ['Poste', 'Par mois'],
          flex: const [5, 3],
          lignes: [
            LigneFiche(
                titre: 'Abonnements',
                sousTitre: '${d.abonnements.length} groupe(s) actif(s)',
                valeur: fmtXaf(d.mrrAbonnementsXaf)),
            LigneFiche(
                titre: 'Licences de tutelle',
                sousTitre: 'marchés actifs, ramenés au mois',
                valeur: fmtXaf(d.mrrLicencesXaf)),
            LigneFiche(
                titre: 'Coût d’exploitation',
                sousTitre: 'postes actifs',
                valeur: '- ${fmtXaf(d.coutMensuelXaf)}'),
            LigneFiche(
                titre: 'Marge',
                sousTitre: 'ce qui reste chaque mois',
                valeur: fmtXaf(d.margeMensuelleXaf)),
          ],
        ),
      ],
      notes: [
        // Le nombre le plus parlant du tableau : le seuil de survie.
        '$seuil groupe${seuil > 1 ? 's' : ''} mono-école au plan Standard '
            'couvre${seuil > 1 ? 'nt' : ''} l’infrastructure. Ce n’est pas une '
            'projection, c’est le seuil de survie.',
      ],
    ),
  );
}
