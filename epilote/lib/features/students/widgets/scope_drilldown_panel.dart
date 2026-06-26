import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PANNEAU DRILL-DOWN Cycle › Niveau › Classe (partagé, scope-aware).
//  On descend en cascade : cliquer un cycle affiche ses niveaux, puis un niveau
//  affiche ses classes. À chaque cran, le widget émet le SCOPE courant
//  (`ScopeSel`) au parent, qui filtre sa liste. La barre montre un TAUX (vert)
//  d'unités « ok » du groupe (dossiers complets, élèves avec contact…) →
//  repérer les groupes en retard. Réutilisé par Documents, Annuaire, etc.
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

/// Scope sélectionné (cran le plus profond actif).
class ScopeSel {
  const ScopeSel({this.cycle, this.level, this.classId, this.label = ''});
  final String? cycle, level, classId;
  final String label;
  bool get active => cycle != null;
}

class ScopeDrilldownPanel extends StatefulWidget {
  const ScopeDrilldownPanel({
    super.key,
    required this.units,
    required this.title,
    required this.greenHint,
    required this.onChanged,
  });
  final List<ScopeUnit> units;
  final String title;

  /// Fin de la phrase d'aide (« part de dossiers complets », « part d'élèves
  /// avec contact »…).
  final String greenHint;
  final ValueChanged<ScopeSel> onChanged;

  @override
  State<ScopeDrilldownPanel> createState() => _ScopeDrilldownPanelState();
}

class _ScopeDrilldownPanelState extends State<ScopeDrilldownPanel> {
  String? _cycle, _level, _classId;

  int get _depth => _level != null ? 2 : (_cycle != null ? 1 : 0);

  void _emit() {
    final label = _classId != null
        ? 'Classe : ${_classLabel(_classId!)}'
        : _level != null
            ? 'Niveau : $_level'
            : _cycle != null
                ? 'Cycle : ${scopeCycleName(_cycle)}'
                : '';
    widget.onChanged(ScopeSel(
        cycle: _cycle, level: _level, classId: _classId, label: label));
  }

  String _classLabel(String id) => widget.units
      .firstWhere((u) => u.classId == id,
          orElse: () => const ScopeUnit(ok: false))
      .className ??
      '—';

  void _drillCycle(String c) {
    setState(() {
      _cycle = c;
      _level = _classId = null;
    });
    _emit();
  }

  void _drillLevel(String l) {
    setState(() {
      _level = l;
      _classId = null;
    });
    _emit();
  }

  void _pickClass(String id) {
    setState(() => _classId = _classId == id ? null : id);
    _emit();
  }

  void _crumbTo(int depth) {
    setState(() {
      if (depth < 1) _cycle = null;
      if (depth < 2) _level = null;
      _classId = null;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final hint = switch (_depth) {
      0 => 'Cliquez un cycle pour voir ses niveaux et filtrer la liste.',
      1 => 'Cliquez un niveau pour voir ses classes.',
      _ => 'Cliquez une classe pour cibler son effectif.',
    };
    final groups = switch (_depth) {
      0 => _groupCycles(),
      1 => _groupLevels(_cycle!),
      _ => _groupClasses(_level!),
    };
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
          _Crumbs(
            cycleLabel: _cycle != null ? scopeCycleName(_cycle) : null,
            levelLabel: _level,
            onCrumb: _crumbTo,
          ),
        ]),
        const SizedBox(height: 4),
        Text('$hint · barre verte = ${widget.greenHint}.',
            style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const SizedBox(
              height: 48,
              child:
                  Center(child: Text('—', style: TextStyle(color: kTextMuted))))
        else
          Column(children: [
            for (final g in groups)
              _ScopeBar(
                g: g,
                onTap: switch (_depth) {
                  0 => _drillCycle,
                  1 => _drillLevel,
                  _ => _pickClass,
                },
              ),
          ]),
      ]),
    );
  }

  List<_ScopeGroup> _groupCycles() {
    final map = <String, ({int total, int ok})>{};
    for (final u in widget.units) {
      final k = u.cycleCode ?? '';
      if (k.isEmpty) continue;
      final c = map[k];
      map[k] = (total: (c?.total ?? 0) + 1, ok: (c?.ok ?? 0) + (u.ok ? 1 : 0));
    }
    return [
      for (final e in map.entries)
        _ScopeGroup(
            key: e.key,
            label: scopeCycleName(e.key),
            total: e.value.total,
            ok: e.value.ok,
            color: scopeCycleColor(e.key),
            sort: scopeCycleOrder(e.key),
            drillable: true)
    ]..sort((a, b) => a.sort.compareTo(b.sort));
  }

  List<_ScopeGroup> _groupLevels(String cycle) {
    final map = <String, ({int total, int ok, int order})>{};
    for (final u in widget.units) {
      if (u.cycleCode != cycle) continue;
      final k = u.levelCode ?? '';
      if (k.isEmpty) continue;
      final c = map[k];
      map[k] = (
        total: (c?.total ?? 0) + 1,
        ok: (c?.ok ?? 0) + (u.ok ? 1 : 0),
        order: u.levelOrder,
      );
    }
    return [
      for (final e in map.entries)
        _ScopeGroup(
            key: e.key,
            label: e.key,
            total: e.value.total,
            ok: e.value.ok,
            color: scopeCycleColor(cycle),
            sort: e.value.order,
            drillable: true)
    ]..sort((a, b) => a.sort.compareTo(b.sort));
  }

  List<_ScopeGroup> _groupClasses(String level) {
    final map = <String, ({int total, int ok, String name, String cycle})>{};
    for (final u in widget.units) {
      if (u.levelCode != level) continue;
      final id = u.classId;
      if (id == null) continue;
      final c = map[id];
      map[id] = (
        total: (c?.total ?? 0) + 1,
        ok: (c?.ok ?? 0) + (u.ok ? 1 : 0),
        name: u.className ?? '—',
        cycle: u.cycleCode ?? '',
      );
    }
    return [
      for (final e in map.entries)
        _ScopeGroup(
            key: e.key,
            label: e.value.name,
            total: e.value.total,
            ok: e.value.ok,
            color: scopeCycleColor(e.value.cycle),
            sort: 0,
            picked: _classId == e.key,
            drillable: false)
    ]..sort((a, b) => a.label.compareTo(b.label));
  }
}

class _ScopeGroup {
  const _ScopeGroup({
    required this.key,
    required this.label,
    required this.total,
    required this.ok,
    required this.color,
    required this.sort,
    this.picked = false,
    this.drillable = false,
  });
  final String key, label;
  final int total, ok, sort;
  final Color color;
  final bool picked, drillable;
  double get ratio => total == 0 ? 0 : ok / total;
  int get pct => total == 0 ? 0 : (ok * 100 / total).round();
}

class _ScopeBar extends StatelessWidget {
  const _ScopeBar({required this.g, required this.onTap});
  final _ScopeGroup g;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) {
    final full = g.ok == g.total && g.total > 0;
    final barColor =
        full ? kGreen : (g.pct == 0 ? kRed : const Color(0xFFF59E0B));
    return InkWell(
      onTap: () => onTap(g.key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: g.picked ? kNavy.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  g.picked ? kNavy.withValues(alpha: 0.35) : Colors.transparent),
        ),
        child: Row(children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: g.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 92,
            child: Text(g.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: g.ratio.clamp(0.0, 1.0),
                minHeight: 15,
                backgroundColor: kSurface,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text('${g.ok}/${g.total}',
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
          SizedBox(
            width: 44,
            child: Text('${g.pct} %',
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: full ? kGreen : kTextMuted)),
          ),
          Icon(
              g.picked
                  ? Icons.filter_alt_rounded
                  : (g.drillable
                      ? Icons.chevron_right_rounded
                      : Icons.radio_button_unchecked_rounded),
              size: 17,
              color: g.picked ? kNavy : kTextMuted),
        ]),
      ),
    );
  }
}

// Fil d'Ariane Tous › Cycle › Niveau.
class _Crumbs extends StatelessWidget {
  const _Crumbs(
      {required this.cycleLabel,
      required this.levelLabel,
      required this.onCrumb});
  final String? cycleLabel, levelLabel;
  final ValueChanged<int> onCrumb;
  @override
  Widget build(BuildContext context) {
    Widget crumb(String label, int depth, {required bool active}) => InkWell(
          onTap: active ? null : () => onCrumb(depth),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? kTextMuted : kNavy)),
          ),
        );
    const sep = Icon(Icons.chevron_right_rounded, size: 15, color: kTextMuted);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration:
          BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        crumb('Tous', 0, active: cycleLabel == null),
        if (cycleLabel != null) ...[
          sep,
          crumb(cycleLabel!, 1, active: levelLabel == null),
        ],
        if (levelLabel != null) ...[sep, crumb(levelLabel!, 2, active: true)],
      ]),
    );
  }
}
