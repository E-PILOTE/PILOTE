import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉPARTITION Cycle ▸ Niveau ▸ Classe — TABLEAU HIÉRARCHIQUE dépliable
//  (partagé, scope-aware). Sous-totaux visibles à chaque niveau (pattern pivot /
//  breakdown) : on lit tous les effectifs d'un coup d'œil. Le chevron déplie /
//  replie ; cliquer une ligne FILTRE la liste (composant contrôlé : la sélection
//  `selected` vit chez le parent, qui filtre + affiche le bandeau actif).
//  Colonne « ok » paramétrable (dossiers complets, élèves avec contact…).
//  Réutilisé par Documents, Annuaire, etc.
// ════════════════════════════════════════════════════════════════════════════

// Référentiel cycles (couleur / nom / ordre) — partagé.
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
  _Cls(this.name, this.cycle, this.level);
  final String name;
  final String? cycle, level;
  int total = 0, ok = 0;
}

class _Lvl {
  _Lvl(this.order, this.cycle);
  final int order;
  final String? cycle;
  int total = 0, ok = 0;
  final Map<String, _Cls> classes = {};
}

class _Cyc {
  int total = 0, ok = 0;
  final Map<String, _Lvl> levels = {};
}

class ScopeDrilldownPanel extends StatefulWidget {
  const ScopeDrilldownPanel({
    super.key,
    required this.units,
    required this.title,
    required this.metricLabel,
    required this.selected,
    required this.onSelect,
  });
  final List<ScopeUnit> units;
  final String title;

  /// En-tête court de la colonne « ok » (ex. « Complets », « Avec contact »).
  final String metricLabel;

  /// Sélection courante (contrôlée par le parent).
  final ScopeSel selected;
  final ValueChanged<ScopeSel> onSelect;

  @override
  State<ScopeDrilldownPanel> createState() => _ScopeDrilldownPanelState();
}

class _ScopeDrilldownPanelState extends State<ScopeDrilldownPanel> {
  final Set<String> _expCycles = {};
  final Set<String> _expLevels = {};

  // Construit l'arbre agrégé à partir des unités.
  Map<String, _Cyc> _build() {
    final cycles = <String, _Cyc>{};
    for (final u in widget.units) {
      final ck = u.cycleCode ?? '';
      if (ck.isEmpty) continue;
      final cyc = cycles.putIfAbsent(ck, () => _Cyc());
      cyc.total++;
      if (u.ok) cyc.ok++;
      final lk = u.levelCode ?? '';
      if (lk.isEmpty) continue;
      final lvl = cyc.levels.putIfAbsent(lk, () => _Lvl(u.levelOrder, ck));
      lvl.total++;
      if (u.ok) lvl.ok++;
      final cid = u.classId;
      if (cid == null) continue;
      final cls = lvl.classes
          .putIfAbsent(cid, () => _Cls(u.className ?? '—', ck, lk));
      cls.total++;
      if (u.ok) cls.ok++;
    }
    return cycles;
  }

  void _tapRow(ScopeSel sel, {String? expandCycle, String? expandLevel}) {
    final s = widget.selected;
    final same = s.cycle == sel.cycle &&
        s.level == sel.level &&
        s.classId == sel.classId;
    if (same) {
      widget.onSelect(const ScopeSel()); // re-clic = effacer le filtre
    } else {
      widget.onSelect(sel);
      // Auto-déplier pour révéler les enfants.
      setState(() {
        if (expandCycle != null) _expCycles.add(expandCycle);
        if (expandLevel != null) _expLevels.add(expandLevel);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cycles = _build();
    final cycleKeys = cycles.keys.toList()
      ..sort((a, b) => scopeCycleOrder(a).compareTo(scopeCycleOrder(b)));
    final sel = widget.selected;
    int gTotal = 0, gOk = 0;
    for (final c in cycles.values) {
      gTotal += c.total;
      gOk += c.ok;
    }

    final rows = <Widget>[];
    for (final ck in cycleKeys) {
      final cyc = cycles[ck]!;
      final cExp = _expCycles.contains(ck);
      rows.add(_TreeRow(
        label: scopeCycleName(ck),
        color: scopeCycleColor(ck),
        depth: 0,
        total: cyc.total,
        ok: cyc.ok,
        metricLabel: widget.metricLabel,
        hasChildren: cyc.levels.isNotEmpty,
        expanded: cExp,
        selected: sel.cycle == ck && sel.level == null && sel.classId == null,
        onToggle: cyc.levels.isEmpty
            ? null
            : () => setState(() =>
                cExp ? _expCycles.remove(ck) : _expCycles.add(ck)),
        onTap: () => _tapRow(
            ScopeSel(cycle: ck, label: 'Cycle : ${scopeCycleName(ck)}'),
            expandCycle: ck),
      ));
      if (!cExp) continue;
      final levelKeys = cyc.levels.keys.toList()
        ..sort((a, b) =>
            cyc.levels[a]!.order.compareTo(cyc.levels[b]!.order));
      for (final lk in levelKeys) {
        final lvl = cyc.levels[lk]!;
        final lExp = _expLevels.contains(lk);
        rows.add(_TreeRow(
          label: lk,
          color: scopeCycleColor(ck),
          depth: 1,
          total: lvl.total,
          ok: lvl.ok,
          metricLabel: widget.metricLabel,
          hasChildren: lvl.classes.isNotEmpty,
          expanded: lExp,
          selected: sel.level == lk && sel.classId == null,
          onToggle: lvl.classes.isEmpty
              ? null
              : () => setState(() =>
                  lExp ? _expLevels.remove(lk) : _expLevels.add(lk)),
          onTap: () => _tapRow(
              ScopeSel(cycle: ck, level: lk, label: 'Niveau : $lk'),
              expandLevel: lk),
        ));
        if (!lExp) continue;
        final classEntries = lvl.classes.entries.toList()
          ..sort((a, b) => a.value.name.compareTo(b.value.name));
        for (final ce in classEntries) {
          rows.add(_TreeRow(
            label: ce.value.name,
            color: scopeCycleColor(ck),
            depth: 2,
            total: ce.value.total,
            ok: ce.value.ok,
            metricLabel: widget.metricLabel,
            hasChildren: false,
            expanded: false,
            selected: sel.classId == ce.key,
            onToggle: null,
            onTap: () => _tapRow(ScopeSel(
                cycle: ck,
                level: lk,
                classId: ce.key,
                label: 'Classe : ${ce.value.name}')),
          ));
        }
      }
    }

    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_tree_outlined, size: 16, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: kNavy)),
          ),
          const Text('Cliquez une ligne pour filtrer',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
        const SizedBox(height: 12),
        // En-tête de colonnes.
        _HeaderRow(metricLabel: widget.metricLabel),
        const Divider(height: 1, color: kBorder),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: Text('—', style: TextStyle(color: kTextMuted))),
          )
        else
          ...rows,
        const Divider(height: 1, color: kBorder),
        _TotalRow(
            total: gTotal, ok: gOk, metricLabel: widget.metricLabel),
      ]),
    );
  }
}

// Largeurs des colonnes numériques (alignées en-tête / lignes / total).
const double _wEff = 78, _wOk = 84, _wPct = 56;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.metricLabel});
  final String metricLabel;
  @override
  Widget build(BuildContext context) {
    Widget h(String t, double w) => SizedBox(
          width: w,
          child: Text(t,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: kTextMuted)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(children: [
        const Expanded(
          child: Text('CYCLE · NIVEAU · CLASSE',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: kTextMuted)),
        ),
        h('EFFECTIF', _wEff),
        h(metricLabel.toUpperCase(), _wOk),
        h('%', _wPct),
      ]),
    );
  }
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.label,
    required this.color,
    required this.depth,
    required this.total,
    required this.ok,
    required this.metricLabel,
    required this.hasChildren,
    required this.expanded,
    required this.selected,
    required this.onToggle,
    required this.onTap,
  });
  final String label, metricLabel;
  final Color color;
  final int depth, total, ok;
  final bool hasChildren, expanded, selected;
  final VoidCallback? onToggle, onTap;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (ok * 100 / total).round();
    final full = ok == total && total > 0;
    // Profondeur 0 = cycle (gras), 1 = niveau, 2 = classe (atténué).
    final weight = depth == 0
        ? FontWeight.w800
        : (depth == 1 ? FontWeight.w700 : FontWeight.w500);
    return Material(
      color: selected ? kNavy.withValues(alpha: 0.06) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: selected
              ? const BoxDecoration(
                  border: Border(left: BorderSide(color: kNavy, width: 2.5)))
              : null,
          padding: EdgeInsets.fromLTRB(8.0 + depth * 22, 9, 8, 9),
          child: Row(children: [
            // Chevron (déplie) ou puce (feuille).
            SizedBox(
              width: 24,
              child: hasChildren
                  ? InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(4),
                      child: Icon(
                          expanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.chevron_right_rounded,
                          size: 19,
                          color: kTextMuted),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                          width: 6,
                          height: 6,
                          decoration:
                              BoxDecoration(color: color, shape: BoxShape.circle)),
                    ),
            ),
            if (depth == 0) ...[
              Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: depth == 0 ? 13.5 : 12.8,
                      fontWeight: weight,
                      color: kTextPrimary)),
            ),
            SizedBox(
              width: _wEff,
              child: Text('$total',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            SizedBox(
              width: _wOk,
              child: Text('$ok',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: full ? kGreen : kTextPrimary)),
            ),
            SizedBox(
              width: _wPct,
              child: Text('$pct%',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: full
                          ? kGreen
                          : (pct == 0 ? kRed : const Color(0xFFF59E0B)))),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(
      {required this.total, required this.ok, required this.metricLabel});
  final int total, ok;
  final String metricLabel;
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (ok * 100 / total).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
      child: Row(children: [
        const Expanded(
          child: Text('TOTAL',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: kNavy)),
        ),
        SizedBox(
          width: _wEff,
          child: Text('$total',
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: kNavy)),
        ),
        SizedBox(
          width: _wOk,
          child: Text('$ok',
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: kNavy)),
        ),
        SizedBox(
          width: _wPct,
          child: Text('$pct%',
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: kNavy)),
        ),
      ]),
    );
  }
}
