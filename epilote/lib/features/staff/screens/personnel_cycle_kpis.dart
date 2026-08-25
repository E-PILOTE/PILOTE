part of 'personnel_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  COMBIEN D'ENSEIGNANTS PAR CYCLE
//
//  « Collège : 4 enseignants · Lycée : 15 » — la question qu'un chef
//  d'établissement se pose avant toutes les autres, parce qu'elle décide de ce
//  qu'il pourra ouvrir comme classes.
//
//  ⚠️ LE PIÈGE, ET POURQUOI ON L'AFFICHE AU LIEU DE LE TAIRE
//  Le cycle d'un enseignant n'est pas une propriété de sa fiche : il est DÉDUIT
//  des classes qu'il enseigne (professeur principal ou affectation matière).
//  Un enseignant fraîchement enregistré, ou dont l'emploi du temps n'est pas
//  encore fait, n'appartient donc à AUCUN cycle.
//
//  Si l'on se contentait des cartes par cycle, un établissement de trente
//  enseignants pourrait lire « Collège 4 · Lycée 15 » et conclure que le
//  compte est faux. C'est pourquoi les enseignants sans classe affectée ont
//  leur propre carte, nommée et cliquable : la somme se vérifie à l'œil, et
//  l'écart devient une TÂCHE (« affecter ces onze enseignants ») au lieu d'un
//  doute sur l'application.
// ════════════════════════════════════════════════════════════════════════════

/// Clé de la carte « sans classe affectée » — la même que celle utilisée par
/// `staffSegKey` pour l'axe cycle, pour que le filtre soit rigoureusement le
/// même quel que soit l'endroit d'où on le pose.
const String kCycleNonAffecte = '—';

/// Répartition des ENSEIGNANTS par cycle d'exercice.
///
/// Les non-enseignants sont hors sujet ici : un comptable n'appartient pas au
/// collège. Ils restent comptés dans l'effectif global, au-dessus.
({List<({String cle, String label, int n})> cycles, int sansClasse})
    enseignantsParCycle(List<StaffMember> agents) {
  final parCycle = <String, int>{};
  var sans = 0;
  for (final a in agents) {
    if (a.role != 'enseignant') continue;
    final c = a.teachingCycle;
    if (c == null || c.isEmpty) {
      sans++;
    } else {
      parCycle[c] = (parCycle[c] ?? 0) + 1;
    }
  }
  final cles = parCycle.keys.toList()
    ..sort((x, y) => scopeCycleOrder(x).compareTo(scopeCycleOrder(y)));
  return (
    cycles: [
      for (final c in cles) (cle: c, label: scopeCycleName(c), n: parCycle[c]!)
    ],
    sansClasse: sans,
  );
}

/// Icône du cycle — même vocabulaire que le panneau Élèves.
IconData _iconeCycle(String code) => switch (code) {
      'prescolaire' => Icons.child_care_rounded,
      'primaire' => Icons.abc_rounded,
      'college' => Icons.menu_book_rounded,
      'lycee' => Icons.school_rounded,
      kCycleNonAffecte => Icons.event_busy_rounded,
      _ => Icons.workspace_premium_rounded,
    };

class _EnseignantsParCycle extends StatelessWidget {
  const _EnseignantsParCycle({
    required this.agents,
    required this.selected,
    required this.onSelect,
  });

  final List<StaffMember> agents;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final r = enseignantsParCycle(agents);
    if (r.cycles.isEmpty && r.sansClasse == 0) return const SizedBox.shrink();

    // Le total sert de dénominateur aux barres : chaque carte dit sa PART du
    // corps enseignant, ce qui rend l'écart visible sans calcul mental.
    final total = r.cycles.fold(0, (a, c) => a + c.n) + r.sansClasse;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const VsSectionLabel(
          icon: Icons.school_rounded, text: 'Enseignants par cycle'),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final c in r.cycles)
          _CycleCard(
            label: c.label,
            icone: _iconeCycle(c.cle),
            n: c.n,
            total: total,
            couleur: staffSegColor(c.cle, StaffAxis.cycle),
            selected: selected == c.cle,
            onTap: () => onSelect(c.cle),
          ),
        if (r.sansClasse > 0)
          _CycleCard(
            label: 'Sans classe affectée',
            icone: _iconeCycle(kCycleNonAffecte),
            n: r.sansClasse,
            total: total,
            couleur: kAccent,
            selected: selected == kCycleNonAffecte,
            onTap: () => onSelect(kCycleNonAffecte),
            aide: 'Leur cycle se déduira de leur emploi du temps.',
          ),
      ]),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  QUI EST FONCTIONNAIRE, QUI NE L'EST PAS
//
//  Dans un lycée d'État congolais, deux populations cohabitent : les agents de
//  l'État — carrière, grade, échelon, mutation par arrêté — et ceux que
//  l'établissement engage lui-même, volontaires et bénévoles payés par l'APE,
//  vacataires à la tâche. Ce n'est pas une nuance de gestion : c'est ce qui
//  décide de qui paie, de qui mute, et de ce que le ministère peut demander.
//
//  Ce chiffre existait déjà derrière l'onglet « Répartir par ▸ Statut ». Mais
//  un onglet, ça se clique — donc ça ne se lit pas. Un chef d'établissement à
//  qui l'on demande combien de titulaires il a doit pouvoir répondre sans
//  chercher. La section est donc permanente, jumelle de celle des cycles.
//
//  ⚠️ « Statut à renseigner » a sa propre carte, et c'est essentiel : sans
//  elle, un établissement dont personne n'a saisi les statuts lirait
//  « Fonctionnaires 0 » et croirait le chiffre. Zéro et inconnu ne sont pas la
//  même chose — cf. le KPI d'en-tête, qui applique la même règle.
// ════════════════════════════════════════════════════════════════════════════

/// Clé de la carte « statut à renseigner » — la même que `staffSegKey` pose
/// pour l'axe statut, pour que le filtre soit rigoureusement le même quel que
/// soit l'endroit d'où on le pose.
const String kStatutNonRenseigne = '—';

/// Répartition de TOUT le personnel par statut d'emploi, dans l'ordre canonique
/// de l'énumération, les statuts absents omis, « à renseigner » en dernier.
List<({String cle, String label, int n})> personnelParStatut(
    List<StaffMember> agents) {
  final parStatut = <String, int>{};
  for (final a in agents) {
    final cle = (a.employmentStatus ?? '').isEmpty
        ? kStatutNonRenseigne
        : a.employmentStatus!;
    parStatut[cle] = (parStatut[cle] ?? 0) + 1;
  }
  return [
    for (final (code, _) in kEmploymentStatuses)
      if ((parStatut[code] ?? 0) > 0)
        (cle: code, label: employmentStatusLabel(code), n: parStatut[code]!),
    if ((parStatut[kStatutNonRenseigne] ?? 0) > 0)
      (
        cle: kStatutNonRenseigne,
        label: 'Statut à renseigner',
        n: parStatut[kStatutNonRenseigne]!,
      ),
  ];
}

class _PersonnelParStatut extends StatelessWidget {
  const _PersonnelParStatut({
    required this.agents,
    required this.selected,
    required this.onSelect,
  });

  final List<StaffMember> agents;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final statuts = personnelParStatut(agents);
    if (statuts.isEmpty) return const SizedBox.shrink();
    final total = statuts.fold(0, (a, s) => a + s.n);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const VsSectionLabel(
          icon: Icons.badge_rounded, text: 'Personnel par statut'),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final s in statuts)
          _CycleCard(
            label: s.label,
            icone: staffSegIcon(s.cle, StaffAxis.statut),
            n: s.n,
            total: total,
            unite: 'agent',
            legende: 'de l\'effectif',
            couleur: s.cle == kStatutNonRenseigne
                ? kAccent
                : staffSegColor(s.cle, StaffAxis.statut),
            selected: selected == s.cle,
            onTap: () => onSelect(s.cle),
            aide: s.cle == kStatutNonRenseigne
                ? 'Ouvrez la fiche de l\'agent pour le renseigner.'
                : null,
          ),
      ]),
    ]);
  }
}

/// Calquée sur `_CycleCard` du panneau Élèves (`scope_drilldown_panel.dart`) :
/// 226 px de large, pastille d'icône de 34, chiffre en 32, barre de part.
/// Les deux pages parlent des mêmes cycles — elles doivent le dire pareil.
/// Servie aussi par la section des statuts : mêmes cartes, mêmes proportions,
/// une seule géométrie à tenir.
class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.label,
    required this.icone,
    required this.n,
    required this.total,
    required this.couleur,
    required this.selected,
    required this.onTap,
    this.unite = 'enseignant',
    this.legende = 'du corps enseignant',
    this.aide,
  });

  final String label;
  final IconData icone;
  final int n, total;
  final Color couleur;
  final bool selected;
  final VoidCallback onTap;

  /// Ce qu'on compte : « 5 enseignants », « 10 agents ».
  final String unite;

  /// Ce dont le pourcentage est une part : « du corps enseignant »,
  /// « de l'effectif ».
  final String legende;
  final String? aide;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (n * 100 / total).round();
    final carte = SizedBox(
      width: 226,
      child: Material(
        color: selected ? couleur.withValues(alpha: 0.07) : kCardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? couleur : kBorder,
                  width: selected ? 1.6 : 1),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(icone, size: 18, color: couleur),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                          height: 1.15)),
                ),
                if (selected)
                  Icon(Icons.filter_alt_rounded, size: 16, color: couleur),
              ]),
              const SizedBox(height: 14),
              Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$n',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                            height: 1)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('$unite${n > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 12, color: kTextMuted)),
                    ),
                  ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : n / total,
                  minHeight: 6,
                  backgroundColor: kSurface,
                  valueColor: AlwaysStoppedAnimation(couleur),
                ),
              ),
              const SizedBox(height: 6),
              Text('$pct % $legende',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: couleur)),
            ]),
          ),
        ),
      ),
    );
    return aide == null ? carte : Tooltip(message: aide!, child: carte);
  }
}
