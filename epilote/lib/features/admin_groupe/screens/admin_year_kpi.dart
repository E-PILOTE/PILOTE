part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHAPITRES, TÊTES DE CARTE, INDICATEURS — le vocabulaire visuel de la page.
//
//  La page empilait une douzaine de cartes blanches strictement identiques,
//  séparées par des espacements pris au hasard (18, 22, 16, 26). Résultat : un
//  mur pâle où rien n'annonce ce qu'on lit, et où l'œil ne sait pas où
//  commencer. Trois briques y répondent :
//
//   • `_ChapterTitle` découpe la page en trois temps — ce qu'on regarde, ce
//     qu'on analyse, ce qu'on administre — sans ajouter une carte de plus ;
//   • `_CardHead` donne à chaque carte une pastille d'icône colorée : la
//     couleur devient un repère de navigation, pas une décoration ;
//   • `_YearKpiCard` remplace le sous-titre gris par une pastille de variation
//     lisible d'un coup d'œil, et anime le chiffre quand on change d'année —
//     c'est ce mouvement qui dit « ces chiffres viennent de changer ».
// ════════════════════════════════════════════════════════════════════════════

/// Séparateur de chapitre : un filet, un libellé, rien qui pèse.
class _ChapterTitle extends StatelessWidget {
  const _ChapterTitle(this.label, {required this.icon, this.trailing});
  final String label;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: kNavy),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: kTextMuted,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Container(height: 1, color: kBorder)),
        if (trailing != null) ...[
          const SizedBox(width: 14),
          trailing!,
        ],
      ],
    );
  }
}

/// Tête de carte : pastille d'icône teintée + titre + sous-titre + action.
///
/// Remplace `AdminSectionTitle` sur cette page uniquement — l'icône nue de la
/// version partagée se perdait contre le blanc de la carte.
class _CardHead extends StatelessWidget {
  const _CardHead(
    this.title, {
    required this.icon,
    required this.tint,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Color tint;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: tint),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style:
                      TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

// ─── Pastille de variation ────────────────────────────────────────────────────
class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte d'indicateur ───────────────────────────────────────────────────────
class _YearKpiCard extends StatelessWidget {
  const _YearKpiCard({
    required this.label,
    required this.icon,
    required this.color,
    this.compte,
    this.texte,
    this.note,
    this.delta,
    this.progression,
    this.inconnu = false,
  });

  final String label;
  final IconData icon;
  final Color color;

  /// Valeur numérique — animée à chaque changement d'année.
  final int? compte;

  /// Valeur composite (« 37/1010 ») : affichée telle quelle.
  final String? texte;

  /// Ligne grise sous le libellé, quand il n'y a pas de variation à montrer.
  final String? note;
  final ({String text, Color color, IconData icon})? delta;

  /// 0 → 1 : barre fine sous le libellé (taux d'adoption).
  final double? progression;

  /// La donnée n'a pas pu être chargée : « — », jamais zéro.
  final bool inconnu;

  @override
  Widget build(BuildContext context) {
    final valeur = inconnu
        ? '—'
        : texte ?? (compte == null ? '—' : fmtInt(compte!));

    return AdminCard(
      padding: const EdgeInsets.all(16),
      hoverable: true,
      // Même garde que `AdminStatCard` : quand la hauteur est bornée par la
      // grille, on la REND au texte pour qu'il se tronque plutôt que de
      // déborder — un libellé sur deux lignes suffit sinon à faire apparaître
      // la barre jaune de débordement.
      child: LayoutBuilder(
        builder: (context, c) {
          final borne = c.maxHeight.isFinite;

          final libelle = Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: kTextMuted,
            ),
          );

          final Widget chiffre = inconnu || texte != null || compte == null
              ? Text(
                  valeur,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: inconnu ? kTextMuted : color,
                  ),
                )
              : TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: compte!.toDouble()),
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(
                    fmtInt(v),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 12),
              chiffre,
              const SizedBox(height: 3),
              if (borne) Flexible(child: libelle) else libelle,
              const SizedBox(height: 8),
              // Emplacement de hauteur constante : sans lui, une carte à
              // pastille et une carte à simple note ne s'alignent pas.
              //
              // ⚠️ 32 px, PAS 24. La carte « Écoles préparées » y loge une
              // barre (6) + son écart (5) + sa légende (~16) = 27 : à 24 px,
              // le « 100 % d'adoption » se faisait rogner. La fente doit tenir
              // le plus haut des trois contenus possibles, pas le plus court.
              SizedBox(
                height: 32,
                // `width: infinity` : sans elle, la barre d'adoption n'était
                // large que de sa légende — une jauge tronquée est pire qu'une
                // absence de jauge, elle donne une échelle fausse.
                width: double.infinity,
                child: progression != null
                    ? _KpiProgress(
                        value: progression!, note: note, color: color)
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: delta != null
                            ? _DeltaPill(
                                text: delta!.text,
                                color: delta!.color,
                                icon: delta!.icon,
                              )
                            : Text(
                                note ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: inconnu ? kAccent : kTextMuted,
                                ),
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiProgress extends StatelessWidget {
  const _KpiProgress({required this.value, required this.color, this.note});
  final double value;
  final Color color;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => AdminProgressBar(
            value: v,
            max: 1,
            height: 6,
            color: color,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 5),
          Text(
            note!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextMuted,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── La ligne d'indicateurs ───────────────────────────────────────────────────
class _KpiRow extends ConsumerWidget {
  const _KpiRow({required this.selected, required this.prev});
  final AdminYear selected;
  final AdminYear? prev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminYearAnalyticsProvider(selected.id));
    final analytics = async.valueOrNull;
    // ⚠️ L'ERREUR AVANT LE VIDE — doctrine de la page. « Départements couverts »
    // lisait `?? 0` : une RPC en échec annonçait ZÉRO département couvert, avec
    // l'aplomb d'un chiffre rond, sur un réseau qui en couvre douze.
    final deptInconnu = async.hasError;

    final st = _status(selected);
    final dEleves = _delta(selected.eleves, prev?.eleves);
    final dClasses = _delta(selected.classes, prev?.classes);
    final moy = analytics?.moyenneElevesParClasse ?? 0;
    final adoption = selected.schoolsTotal == 0
        ? 0.0
        : selected.schoolsAdopted / selected.schoolsTotal;

    final cards = <Widget>[
      _YearKpiCard(
        label: 'Élèves inscrits',
        icon: Icons.people_rounded,
        color: kGreen,
        compte: selected.eleves,
        delta: dEleves,
        note: 'Année ${st.label.toLowerCase()}',
      ),
      _YearKpiCard(
        label: 'Classes ouvertes',
        icon: Icons.class_rounded,
        color: kNavy,
        compte: selected.classes,
        delta: dClasses,
        note: moy > 0 ? '${moy.toStringAsFixed(1)} élèves par classe' : null,
      ),
      _YearKpiCard(
        label: 'Écoles préparées',
        icon: Icons.account_balance_rounded,
        color: kAccent,
        texte: '${fmtInt(selected.schoolsAdopted)}/'
            '${fmtInt(selected.schoolsTotal)}',
        progression: adoption,
        note: "${(adoption * 100).round()} % d'adoption",
      ),
      _YearKpiCard(
        label: 'Départements couverts',
        icon: Icons.map_rounded,
        color: const Color(0xFF7C3AED),
        compte: deptInconnu ? null : analytics?.departementsCouverts,
        inconnu: deptInconnu,
        note: deptInconnu
            ? 'Chiffre non chargé'
            : analytics == null
                ? '…'
                : 'sur ${analytics.byDepartment.length} présents',
      ),
    ];

    // ⚠️ SEUIL À 740, PAS À 900 — chiffre MESURÉ, pas choisi.
    //  Un poste de ministère tourne couramment à 150 % d'agrandissement
    //  Windows. Sur la machine de livraison, une fenêtre de 1 650 px physiques
    //  laisse 804 px logiques de contenu, soit 756 une fois la marge de la page
    //  retirée : sous l'ancien seuil de 900, les quatre indicateurs se
    //  rangeaient en DEUX colonnes de 371 px, dont l'essentiel restait blanc —
    //  c'est cela qu'on lit comme une page terne. À 740, quatre colonnes de
    //  178 px logent le libellé le plus long (« Départements couverts »), la
    //  pastille de variation et la barre d'adoption sans les couper.
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 740 ? 4 : (c.maxWidth >= 470 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 190,
          ),
          itemBuilder: (_, i) => cards[i],
        );
      },
    );
  }
}
