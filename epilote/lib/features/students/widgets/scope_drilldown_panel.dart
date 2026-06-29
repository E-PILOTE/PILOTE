import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉPARTITION Cycle / Niveau / Classe — KPI PAR CYCLE + FILTRES EN CASCADE
//  (partagé, scope-aware). Conçu pour PASSER À L'ÉCHELLE (50+ niveaux, 60+
//  classes) : l'aperçu reste stable (≈ 5 cartes cycle) ; la navigation fine
//  passe par 2 déroulants Niveau/Classe dont chaque option PORTE SON EFFECTIF
//  → on retrouve les totaux par niveau et par classe sans surcharger l'écran.
//  Composant contrôlé : la sélection `selected` vit chez le parent (filtre +
//  bandeau actif). Colonne « ok » paramétrable (`metricLabel`).
//  Réutilisé par Documents, Annuaire, etc.
// ════════════════════════════════════════════════════════════════════════════

const _cycleColors = <String, Color>{
  'prescolaire': Color(0xFFEC4899),
  'primaire': Color(0xFF0EA5E9),
  'college': kGreen,
  'lycee': kNavy,
  'formation_pro': Color(0xFFF59E0B),
  'fp': Color(0xFFF59E0B),
};
const _cycleNames = <String, String>{
  'prescolaire': 'Préscolaire',
  'primaire': 'Primaire',
  'college': 'Collège',
  'lycee': 'Lycée',
  'formation_pro': 'Formation Pro.',
  'fp': 'Formation Pro.',
};
const _cycleOrder = <String, int>{
  'prescolaire': 1, 'primaire': 2, 'college': 3, 'lycee': 4,
  'formation_pro': 5, 'fp': 5,
};
Color scopeCycleColor(String? code) => _cycleColors[code ?? ''] ?? kTextMuted;
String scopeCycleName(String? code) => _cycleNames[code ?? ''] ?? 'Non classé';
int scopeCycleOrder(String? code) => _cycleOrder[code ?? ''] ?? 9;

/// Une unité de l'effectif (1 élève) projetée sur la hiérarchie + un drapeau
/// `ok` (la métrique : dossier complet, élève avec contact, etc.).
class ScopeUnit {
  const ScopeUnit({
    this.cycleCode,
    this.levelCode,
    this.levelOrder = 999,
    this.classId,
    this.className,
    required this.ok,
  });
  final String? cycleCode, levelCode, classId, className;
  final int levelOrder;
  final bool ok;
}

/// Scope sélectionné (filtre courant) — émis au parent.
class ScopeSel {
  const ScopeSel({this.cycle, this.level, this.classId, this.label = ''});
  final String? cycle, level, classId;
  final String label;
  bool get active => cycle != null || level != null || classId != null;
}

// ─── Agrégats internes ────────────────────────────────────────────────────────
class _Cls {
  _Cls(this.name, this.level);
  final String name;
  final String level;
  int total = 0, ok = 0, order = 999;
}

class _Lvl {
  _Lvl(this.order);
  int order;
  int total = 0, ok = 0;
  final Map<String, _Cls> classes = {};
}

class _Cyc {
  int total = 0, ok = 0;
  final Map<String, _Lvl> levels = {};
}

class ScopeDrilldownPanel extends StatelessWidget {
  const ScopeDrilldownPanel({
    super.key,
    required this.units,
    required this.title,
    required this.metricLabel,
    required this.selected,
    required this.onSelect,
    this.unitNoun = 'élèves',
  });
  final List<ScopeUnit> units;
  final String title;

  /// Libellé court de la métrique « ok » (ex. « Complets », « Avec contact »).
  final String metricLabel;

  /// Nom de l'unité comptée (« élèves », « classes », « séances »…).
  final String unitNoun;
  final ScopeSel selected;
  final ValueChanged<ScopeSel> onSelect;

  Map<String, _Cyc> _build() {
    final cycles = <String, _Cyc>{};
    for (final u in units) {
      final ck = u.cycleCode ?? '';
      if (ck.isEmpty) continue;
      final cyc = cycles.putIfAbsent(ck, () => _Cyc());
      cyc.total++;
      if (u.ok) cyc.ok++;
      final lk = u.levelCode ?? '';
      if (lk.isEmpty) continue;
      final lvl = cyc.levels.putIfAbsent(lk, () => _Lvl(u.levelOrder));
      if (u.levelOrder < lvl.order) lvl.order = u.levelOrder;
      lvl.total++;
      if (u.ok) lvl.ok++;
      final cid = u.classId;
      if (cid == null) continue;
      final cls = lvl.classes.putIfAbsent(cid, () => _Cls(u.className ?? '—', lk));
      cls.total++;
      if (u.ok) cls.ok++;
      if (u.levelOrder < cls.order) cls.order = u.levelOrder;
    }
    return cycles;
  }

  @override
  Widget build(BuildContext context) {
    final cycles = _build();
    final cycleKeys = cycles.keys.toList()
      ..sort((a, b) => scopeCycleOrder(a).compareTo(scopeCycleOrder(b)));
    final selCyc = selected.cycle;

    // Déroulants : niveaux du cycle sélectionné + classes (du niveau si choisi,
    // sinon tout le cycle). Chaque entrée porte son effectif.
    final levels = <({String key, String label, int total})>[];
    final classes = <({String key, String label, int total, String level})>[];
    if (selCyc != null && cycles[selCyc] != null) {
      final cyc = cycles[selCyc]!;
      final lvlKeys = cyc.levels.keys.toList()
        ..sort((a, b) => cyc.levels[a]!.order.compareTo(cyc.levels[b]!.order));
      for (final lk in lvlKeys) {
        levels.add((key: lk, label: lk, total: cyc.levels[lk]!.total));
      }
      // Classes : du niveau sélectionné, sinon de tout le cycle.
      final classEntries = <MapEntry<String, _Cls>>[];
      if (selected.level != null && cyc.levels[selected.level] != null) {
        classEntries.addAll(cyc.levels[selected.level]!.classes.entries);
      } else {
        for (final l in cyc.levels.values) {
          classEntries.addAll(l.classes.entries);
        }
      }
      classEntries.sort((a, b) {
        final o = a.value.order.compareTo(b.value.order);
        return o != 0 ? o : a.value.name.compareTo(b.value.name);
      });
      for (final e in classEntries) {
        classes.add((
          key: e.key,
          label: e.value.name,
          total: e.value.total,
          level: e.value.level
        ));
      }
    }

    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.donut_small_rounded, size: 16, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: kNavy)),
          ),
          const Text('Cliquez un cycle, affinez par niveau / classe',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
        const SizedBox(height: 12),
        // Cartes KPI par cycle (cliquables).
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final ck in cycleKeys)
              _CycleCard(
                code: ck,
                total: cycles[ck]!.total,
                ok: cycles[ck]!.ok,
                metricLabel: metricLabel,
                selected: selCyc == ck,
                unitNoun: unitNoun,
                onTap: () {
                  final isExactCycle = selCyc == ck &&
                      selected.level == null &&
                      selected.classId == null;
                  onSelect(isExactCycle
                      ? const ScopeSel()
                      : ScopeSel(
                          cycle: ck,
                          label: 'Cycle : ${scopeCycleName(ck)}'));
                },
              ),
          ],
        ),
        // Filtres en cascade (apparaissent quand un cycle est choisi).
        if (selCyc != null) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (ctx, cns) {
            final wide = cns.maxWidth >= 560;
            final niveau = _ScopeDropdown(
              label: 'Niveau',
              icon: Icons.stairs_rounded,
              hint: 'Tous les niveaux',
              value: selected.level,
              items: [for (final l in levels) (l.key, '${l.label} (${l.total})')],
              onChanged: (v) => onSelect(v == null
                  ? ScopeSel(
                      cycle: selCyc, label: 'Cycle : ${scopeCycleName(selCyc)}')
                  : ScopeSel(cycle: selCyc, level: v, label: 'Niveau : $v')),
            );
            final classe = _ScopeDropdown(
              label: 'Classe',
              icon: Icons.class_rounded,
              hint: 'Toutes les classes',
              value: selected.classId,
              items: [for (final c in classes) (c.key, '${c.label} (${c.total})')],
              onChanged: (v) {
                if (v == null) {
                  onSelect(selected.level == null
                      ? ScopeSel(
                          cycle: selCyc,
                          label: 'Cycle : ${scopeCycleName(selCyc)}')
                      : ScopeSel(
                          cycle: selCyc,
                          level: selected.level,
                          label: 'Niveau : ${selected.level}'));
                } else {
                  final cl = classes.firstWhere((c) => c.key == v);
                  onSelect(ScopeSel(
                      cycle: selCyc,
                      level: cl.level,
                      classId: v,
                      label: 'Classe : ${cl.label}'));
                }
              },
            );
            return wide
                ? Row(children: [
                    Expanded(child: niveau),
                    const SizedBox(width: 12),
                    Expanded(child: classe),
                  ])
                : Column(children: [
                    niveau,
                    const SizedBox(height: 12),
                    classe,
                  ]);
          }),
        ],
      ]),
    );
  }
}

// ─── Carte KPI cycle ──────────────────────────────────────────────────────────
class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.code,
    required this.total,
    required this.ok,
    required this.metricLabel,
    required this.selected,
    required this.onTap,
    this.unitNoun = 'élèves',
  });
  final String code, metricLabel, unitNoun;
  final int total, ok;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = scopeCycleColor(code);
    final pct = total == 0 ? 0 : (ok * 100 / total).round();
    final full = ok == total && total > 0;
    final metricColor =
        full ? kGreen : (pct == 0 ? kRed : const Color(0xFFF59E0B));
    return SizedBox(
      width: 226,
      child: Material(
        color: selected ? color.withValues(alpha: 0.07) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? color : kBorder,
                  width: selected ? 1.6 : 1),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9)),
                      child: Icon(_cycleIcon(code), size: 18, color: color),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(scopeCycleName(code),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary,
                              height: 1.15)),
                    ),
                    if (selected)
                      Icon(Icons.filter_alt_rounded, size: 16, color: color),
                  ]),
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$total',
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: kTextPrimary,
                                height: 1)),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(unitNoun,
                              style: const TextStyle(
                                  fontSize: 12, color: kTextMuted)),
                        ),
                      ]),
                  if (metricLabel.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : ok / total,
                        minHeight: 6,
                        backgroundColor: kSurface,
                        valueColor: AlwaysStoppedAnimation(metricColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$ok ${metricLabel.toLowerCase()} · $pct%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: metricColor)),
                  ],
                ]),
          ),
        ),
      ),
    );
  }
}

IconData _cycleIcon(String code) => switch (code) {
      'prescolaire' => Icons.child_care_rounded,
      'primaire' => Icons.abc_rounded,
      'college' => Icons.menu_book_rounded,
      'lycee' => Icons.school_rounded,
      'formation_pro' || 'fp' => Icons.engineering_rounded,
      _ => Icons.donut_small_rounded,
    };

// ─── Déroulant de scope (avec option « tout ») ────────────────────────────────
class _ScopeDropdown extends StatelessWidget {
  const _ScopeDropdown({
    required this.label,
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label, hint;
  final IconData icon;
  final String? value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = items.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: kTextMuted)),
      ),
      DropdownButtonFormField<String?>(
        // Composant CONTRÔLÉ : `initialValue` n'est lu qu'au 1er build par
        // FormField (pas de didUpdateWidget). On force la recréation de l'état
        // quand le parent change la sélection (clic cycle, reset, auto-pick).
        key: ValueKey('$label::${value ?? '∅'}'),
        initialValue: value,
        isExpanded: true,
        style: const TextStyle(fontSize: 13, color: kTextPrimary),
        icon: const Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
        decoration: adminFilledInput(hint, icon: icon),
        selectedItemBuilder: (context) => [
          Text(hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: kTextMuted)),
          for (final e in items)
            Text(e.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: kTextPrimary)),
        ],
        items: [
          DropdownMenuItem(value: null, child: Text(hint)),
          for (final e in items)
            DropdownMenuItem(
                value: e.$1,
                child:
                    Text(e.$2, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: enabled ? onChanged : null,
      ),
    ]);
  }
}
