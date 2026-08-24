part of 'inscriptions_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ENTÊTE DE LA PAGE INSCRIPTIONS — bandeau d'explication du circuit et
//  cartes KPI.
//
//  Issu de la découpe d'inscriptions_page_parts.dart (694 lignes). Les trois
//  bandeaux de la page — entête, filtres, résultats — se superposent sans rien
//  partager : ni état, ni widget commun. La coupe suit cette couture-là, pas un
//  compte de lignes.
//
//  Le graphe du rythme vivait ici, en copie mot pour mot de
//  `widgets/monthly_evolution_card.dart` : mêmes séries, mêmes couleurs, même
//  légende, à deux pixels près. Deux exemplaires d'un graphique, c'est deux
//  corrections à faire à chaque fois — et une seule qui sera faite. La page
//  utilise désormais le widget partagé, comme la page Élèves.
// ════════════════════════════════════════════════════════════════════════════

class _PipelineNotice extends StatelessWidget {
  const _PipelineNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kNavy.withValues(alpha: 0.16)),
        ),
        child: Row(children: [
          Icon(Icons.inbox_rounded, size: 17, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cette page est le guichet des admissions : elle ne liste que les '
              'dossiers encore à traiter — en attente, rejetés ou sortis. Dès '
              'qu\'une inscription est validée, l\'élève rejoint la page Élèves.',
              style: TextStyle(
                  fontSize: 12.5, color: kTextMuted, height: 1.45),
            ),
          ),
        ]),
      );
}

// ─── Section KPI générale (cartes pleine taille, comme le Tableau de bord) ────
class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.st, required this.year});
  final InscriptionStats st;
  final YearInscriptionTotals year;

  @override
  Widget build(BuildContext context) {
    // ⚠️ DEUX SOURCES, ET C'EST VOULU.
    // `st` décrit le GUICHET : les dossiers encore à traiter (la liste du bas).
    // `year` décrit l'ANNÉE ENTIÈRE, inscriptions validées comprises.
    //
    // Les quatre cartes de droite lisaient `st` : « Nouvelles » affichait 0
    // dans une école qui avait inscrit trente élèves, parce que ces trente-là
    // étaient validés donc absents du guichet. Un compteur d'activité qui
    // retombe à zéro à mesure que le travail est fait ne mesure pas le travail.
    final cards = <Widget>[
      AdminStatCard(
        label: 'Inscrits',
        value: '${year.enrolled}',
        icon: Icons.groups_rounded,
        color: kGreen,
        subtitle: 'Effectif de l\'année',
      ),
      AdminStatCard(
        label: 'En attente',
        value: '${st.pending}',
        icon: Icons.hourglass_top_rounded,
        color: kAccent,
        subtitle: 'À valider',
      ),
      AdminStatCard(
        label: 'Rejetées',
        value: '${st.rejected}',
        icon: Icons.cancel_outlined,
        color: kRed,
        subtitle: 'Dossiers refusés',
      ),
      AdminStatCard(
        label: 'Nouvelles',
        value: '${year.newCount}',
        icon: Icons.fiber_new_rounded,
        color: kNavy,
        subtitle: 'Premières inscriptions',
      ),
      AdminStatCard(
        label: 'Réinscriptions',
        value: '${year.reinscription}',
        icon: Icons.autorenew_rounded,
        color: _kBlue,
        subtitle: 'Élèves de retour',
      ),
      AdminStatCard(
        label: 'Redoublants',
        value: '${year.repeating}',
        icon: Icons.replay_rounded,
        color: const Color(0xFF7C3AED),
        subtitle: 'Recommencent leur niveau',
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1180
          ? 6
          : c.maxWidth >= 920
              ? 4
              : c.maxWidth >= 600
                  ? 3
                  : c.maxWidth >= 380
                      ? 2
                      : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 168,
        ),
        itemBuilder: (_, i) => cards[i],
      );
    });
  }
}
