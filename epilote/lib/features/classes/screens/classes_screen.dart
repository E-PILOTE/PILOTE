import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../data/models/class_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_structure_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/class_provider.dart';

part 'classes_parts.dart';

// ─── Accents par cycle (cohérents avec Inscriptions / Structure) ─────────────
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
  'prescolaire': 1,
  'primaire': 2,
  'college': 3,
  'lycee': 4,
  'formation_pro': 5,
  'fp': 5,
};
Color _cycColor(String? c) => _cycleColors[c ?? ''] ?? kTextMuted;
String _cycName(String? c) => _cycleNames[c ?? ''] ?? 'Non classé';
int _cycOrder(String? c) => _cycleOrder[c ?? ''] ?? 9;

String _pl(int n, String s, String p) => '$n ${n <= 1 ? s : p}';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE CLASSES — design plateforme (comme Inscriptions) : KPI → filtres
//  (recherche + cycle + niveau + filière + bascule table/cartes + « Nouvelle
//  classe ») → table / cartes. Création câblée sur `createStructuredClass`
//  (cycle ▸ niveau) → pose level_id + dénormalisés → KPI cohérents partout.
// ════════════════════════════════════════════════════════════════════════════
class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: 'classes',
        title: 'Classes',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _search = TextEditingController();
  String? _cycle;
  String? _level;
  String? _filiere;
  bool _isTable = true;
  bool _sortAsc = true;
  final Set<String> _selected = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() => setState(() {
        _search.clear();
        _cycle = _level = _filiere = null;
      });

  void _toggle(String id, bool sel) => setState(() {
        if (sel) {
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      });
  void _toggleAll(List<ClassModel> rows, bool sel) => setState(() {
        if (sel) {
          _selected.addAll(rows.map((c) => c.id));
        } else {
          _selected.removeAll(rows.map((c) => c.id));
        }
      });
  void _clearSel() => setState(_selected.clear);

  Future<void> _bulkArchive(List<ClassModel> rows) async {
    final targets = rows.where((c) => _selected.contains(c.id)).toList();
    if (targets.isEmpty) return;
    final withStudents = targets.where((c) => (c.studentCount ?? 0) > 0).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Archiver ${targets.length} classe(s) ?'),
        content: Text(withStudents > 0
            ? '$withStudents classe(s) contiennent encore des élèves. '
                'Les inscriptions sont conservées mais la classe sera masquée.'
            : 'Les classes sélectionnées seront masquées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Retour')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var n = 0;
    for (final c in targets) {
      try {
        await archiveClass(c.id);
        n++;
      } catch (_) {}
    }
    _clearSel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$n classe(s) archivée(s)'), backgroundColor: kGreen));
    }
  }

  Future<void> _bulkExport(List<ClassModel> rows) async {
    final targets = rows.where((c) => _selected.contains(c.id)).toList();
    final list = targets.isEmpty ? rows : targets;
    if (list.isEmpty) return;
    try {
      final path = await exportClassesCsv(list);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Export CSV : ${list.length} ligne(s) → $path'),
            backgroundColor: kGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur export : $e'), backgroundColor: kRed));
      }
    }
  }

  List<ClassModel> _apply(List<ClassModel> all, Map<String, String> teachers) {
    final q = _search.text.trim().toLowerCase();
    final out = all.where((c) {
      if (_cycle != null && (c.cycleCode ?? '') != _cycle) return false;
      if (_level != null && (c.levelCode ?? '') != _level) return false;
      if (_filiere != null && c.filiereLabel != _filiere) return false;
      if (q.isEmpty) return true;
      final t = (teachers[c.mainTeacherId] ?? '').toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          (c.room ?? '').toLowerCase().contains(q) ||
          t.contains(q);
    }).toList()
      ..sort((a, b) {
        final co = _cycOrder(a.cycleCode).compareTo(_cycOrder(b.cycleCode));
        if (co != 0) return _sortAsc ? co : -co;
        final lo = (a.levelOrder ?? 999).compareTo(b.levelOrder ?? 999);
        if (lo != 0) return _sortAsc ? lo : -lo;
        final n = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return _sortAsc ? n : -n;
      });
    return out;
  }

  void _openForm({ClassModel? existing}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ClassFormSheet(existing: existing),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(classesProvider);
    final readOnly = ref.watch(yearReadOnlyProvider);
    final teachers = {
      for (final t in ref.watch(schoolTeachersProvider).valueOrNull ??
          const <SchoolTeacher>[])
        t.id: t.fullName,
    };

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $e', style: const TextStyle(color: kRed)),
        ),
      ),
      data: (all) {
        final filtered = _apply(all, teachers);
        final cyclesPresent = <String, String>{
          for (final c in all) (c.cycleCode ?? ''): _cycName(c.cycleCode),
        };
        final levelsPresent = <String, int>{
          for (final c in all.where(
              (c) => _cycle == null || (c.cycleCode ?? '') == _cycle))
            (c.levelCode ?? ''): (c.levelOrder ?? 999),
        }..remove('');
        final levelCodes = levelsPresent.keys.toList()
          ..sort((a, b) => levelsPresent[a]!.compareTo(levelsPresent[b]!));
        final filieresPresent = {
          for (final c in all)
            if (c.filiereLabel != null) c.filiereLabel!,
        }.toList()
          ..sort();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(classes: all),
              if (all.isNotEmpty) ...[
                const SizedBox(height: 22),
                _ClassCharts(classes: all),
              ],
              const SizedBox(height: 22),
              _ClassFilterBar(
                searchCtrl: _search,
                cycle: _cycle,
                level: _level,
                filiere: _filiere,
                isTable: _isTable,
                readOnly: readOnly,
                cyclesPresent: cyclesPresent,
                levelCodes: levelCodes,
                filieresPresent: filieresPresent,
                onSearch: (_) => setState(() {}),
                onCycle: (v) => setState(() {
                  _cycle = v;
                  _level = null;
                }),
                onLevel: (v) => setState(() => _level = v),
                onFiliere: (v) => setState(() => _filiere = v),
                onToggleView: () => setState(() => _isTable = !_isTable),
                onReset: _resetFilters,
                onAdd: () => _openForm(),
              ),
              const SizedBox(height: 16),
              if (_selected.isNotEmpty && !readOnly)
                _ClassBulkBar(
                  count: _selected.length,
                  onArchive: () => _bulkArchive(filtered),
                  onExport: () => _bulkExport(filtered),
                  onClear: _clearSel,
                )
              else
                _ResultHeader(total: all.length, filtered: filtered.length),
              const SizedBox(height: 12),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.class_outlined,
                    title: 'Aucune classe cette année',
                    message:
                        'Créez la première classe pour structurer les effectifs '
                        'et démarrer les inscriptions.',
                    actionLabel: readOnly ? null : 'Nouvelle classe',
                    onAction: readOnly ? null : () => _openForm(),
                  ),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun résultat',
                    message: 'Ajustez la recherche ou les filtres.',
                  ),
                )
              else if (_isTable)
                _ClassTable(
                  rows: filtered,
                  teachers: teachers,
                  sortAsc: _sortAsc,
                  readOnly: readOnly,
                  selected: _selected,
                  onSelect: _toggle,
                  onSelectAll: (v) => _toggleAll(filtered, v),
                  onSort: () => setState(() => _sortAsc = !_sortAsc),
                  onView: (c) => context.push(
                      Routes.classeDetail.replaceFirst(':id', c.id)),
                  onEdit: (c) => _openForm(existing: c),
                )
              else
                _ClassCards(
                  rows: filtered,
                  teachers: teachers,
                  readOnly: readOnly,
                  onView: (c) => context.push(
                      Routes.classeDetail.replaceFirst(':id', c.id)),
                  onEdit: (c) => _openForm(existing: c),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ─── KPIs ─────────────────────────────────────────────────────────────────────
class _Kpis extends StatelessWidget {
  const _Kpis({required this.classes});
  final List<ClassModel> classes;

  @override
  Widget build(BuildContext context) {
    final eleves = classes.fold<int>(0, (s, c) => s + (c.studentCount ?? 0));
    final capacite = classes.fold<int>(0, (s, c) => s + (c.capacity ?? 0));
    final niveaux = {
      for (final c in classes)
        if ((c.levelCode ?? '').isNotEmpty) c.levelCode,
    }.length;
    final occ = capacite == 0 ? '—' : '${(eleves / capacite * 100).round()} %';
    final items = <(IconData, String, String, Color, String?)>[
      (Icons.class_outlined, 'Classes', '${classes.length}', kNavy, null),
      (Icons.stairs_outlined, 'Niveaux', '$niveaux',
          const Color(0xFF0EA5E9), null),
      (Icons.groups_outlined, 'Élèves', '$eleves', kGreen, null),
      (Icons.event_seat_outlined, 'Capacité', '$capacite',
          const Color(0xFFF59E0B), null),
      (Icons.pie_chart_outline_rounded, 'Occupation', occ,
          const Color(0xFF8B5CF6), capacite == 0 ? null : '$capacite places'),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1100 ? 5 : (w >= 720 ? 3 : (w >= 460 ? 2 : 1));
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 176,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final (icon, label, value, color, sub) = items[i];
          return AdminStatCard(
              label: label,
              value: value,
              icon: icon,
              color: color,
              subtitle: sub);
        },
      );
    });
  }
}
