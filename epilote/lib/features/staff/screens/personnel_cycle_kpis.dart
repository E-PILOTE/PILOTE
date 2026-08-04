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

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const VsSectionLabel(
          icon: Icons.school_rounded, text: 'Enseignants par cycle'),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final c in r.cycles)
          _CycleCard(
            label: c.label,
            n: c.n,
            couleur: staffSegColor(c.cle, StaffAxis.cycle),
            selected: selected == c.cle,
            onTap: () => onSelect(c.cle),
          ),
        if (r.sansClasse > 0)
          _CycleCard(
            label: 'Sans classe affectée',
            n: r.sansClasse,
            couleur: kAccent,
            selected: selected == kCycleNonAffecte,
            onTap: () => onSelect(kCycleNonAffecte),
            aide: 'Leur cycle se déduira de leur emploi du temps.',
          ),
      ]),
    ]);
  }
}

class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.label,
    required this.n,
    required this.couleur,
    required this.selected,
    required this.onTap,
    this.aide,
  });

  final String label;
  final int n;
  final Color couleur;
  final bool selected;
  final VoidCallback onTap;
  final String? aide;

  @override
  Widget build(BuildContext context) {
    final carte = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 186,
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            color: selected ? couleur.withValues(alpha: 0.10) : kCardBg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: selected ? couleur : kBorder, width: selected ? 1.5 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: couleur, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$n',
                  style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: couleur,
                      height: 1)),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('enseignant${n > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 10.5, color: kTextMuted)),
              ),
            ]),
          ]),
        ),
      ),
    );
    return aide == null ? carte : Tooltip(message: aide!, child: carte);
  }
}
