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

/// Calquée sur `_CycleCard` du panneau Élèves (`scope_drilldown_panel.dart`) :
/// 226 px de large, pastille d'icône de 34, chiffre en 32, barre de part.
/// Les deux pages parlent des mêmes cycles — elles doivent le dire pareil.
class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.label,
    required this.icone,
    required this.n,
    required this.total,
    required this.couleur,
    required this.selected,
    required this.onTap,
    this.aide,
  });

  final String label;
  final IconData icone;
  final int n, total;
  final Color couleur;
  final bool selected;
  final VoidCallback onTap;
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
                      child: Text('enseignant${n > 1 ? 's' : ''}',
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
              Text('$pct % du corps enseignant',
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
