import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../data/models/subject_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/academic_structure_provider.dart';
import '../providers/subjects_provider.dart';

part 'subjects_parts.dart';

const _kSlug = 'matieres';

// Couleur dérivée du nom (stable) — repère visuel par matière.
const _palette = <Color>[
  kNavy,
  kGreen,
  Color(0xFF0EA5E9),
  Color(0xFF8B5CF6),
  Color(0xFFF59E0B),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFEF4444),
];
Color _subjectColor(String slug) =>
    _palette[slug.codeUnits.fold(0, (s, c) => s + c) % _palette.length];

String _pl(int n, String s, String p) => '$n ${n <= 1 ? s : p}';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE MATIÈRES — design plateforme (comme Inscriptions / Classes) : KPI →
//  répartition par poids (coefficient) → filtres (recherche + tri + bascule
//  table/cartes + « Nouvelle matière ») → table / cartes. Offline-first.
// ════════════════════════════════════════════════════════════════════════════
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Matières',
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
  bool _isTable = true;
  String _sort = 'name'; // name | coef
  bool _sortAsc = true;
  String? _levelFilter; // code niveau, ou '__tronc__', ou null
  final Set<String> _selected = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String id, bool sel) => setState(() {
        if (sel) {
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      });
  void _toggleAll(List<SubjectModel> rows, bool sel) => setState(() {
        if (sel) {
          _selected.addAll(rows.map((s) => s.id));
        } else {
          _selected.removeAll(rows.map((s) => s.id));
        }
      });
  void _clearSel() => setState(_selected.clear);

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  Future<void> _bulkArchive(List<SubjectModel> rows) async {
    final targets = rows.where((s) => _selected.contains(s.id)).toList();
    if (targets.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Archiver ${targets.length} matière(s) ?'),
        content: const Text(
            'Elles ne seront plus proposées. Les notes existantes sont conservées.'),
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
    for (final s in targets) {
      try {
        await archiveSubject(s.id);
        n++;
      } catch (_) {}
    }
    _clearSel();
    _snack('$n matière(s) archivée(s)', kGreen);
  }

  Future<void> _bulkExport(List<SubjectModel> rows) async {
    final targets = rows.where((s) => _selected.contains(s.id)).toList();
    final list = targets.isEmpty ? rows : targets;
    if (list.isEmpty) return;
    try {
      final path = await exportSubjectsCsv(list);
      _snack('Export CSV : ${list.length} ligne(s) → $path', kGreen);
    } catch (e) {
      _snack('Erreur export : $e', kRed);
    }
  }

  List<SubjectModel> _apply(List<SubjectModel> all) {
    final q = _search.text.trim().toLowerCase();
    final out = all.where((s) {
      if (_levelFilter == '__tronc__' && !s.isTronc) return false;
      if (_levelFilter != null &&
          _levelFilter != '__tronc__' &&
          (s.levelCode ?? '') != _levelFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.levelLabel.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final c = _sort == 'coef'
            ? a.coefficient.compareTo(b.coefficient)
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return _sortAsc ? c : -c;
      });
    return out;
  }

  void _openForm({SubjectModel? existing}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SubjectForm(existing: existing),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(subjectsProvider);
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
        final filtered = _apply(all);
        // Total de coefficient par niveau (pour le poids relatif).
        final coefByLevel = <String, int>{};
        for (final s in all) {
          final k = s.isTronc ? '__tronc__' : (s.levelCode ?? '');
          coefByLevel[k] = (coefByLevel[k] ?? 0) + s.coefficient;
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(subjects: all),
              if (all.isNotEmpty) ...[
                const SizedBox(height: 22),
                _NiveauBreakdown(
                  subjects: all,
                  active: _levelFilter,
                  onPick: (k) => setState(
                      () => _levelFilter = _levelFilter == k ? null : k),
                ),
              ],
              const SizedBox(height: 22),
              _SubjectFilterBar(
                searchCtrl: _search,
                isTable: _isTable,
                sort: _sort,
                sortAsc: _sortAsc,
                levelFilter: _levelFilter,
                levelsPresent: {
                  if (all.any((s) => s.isTronc)) '__tronc__': 'Tronc commun',
                  for (final e in (all.where((s) => !s.isTronc).toList()
                        ..sort((a, b) => a.levelOrder.compareTo(b.levelOrder))))
                    (e.levelCode ?? ''): (e.levelCode ?? ''),
                },
                onSearch: (_) => setState(() {}),
                onSort: (s) => setState(() {
                  if (_sort == s) {
                    _sortAsc = !_sortAsc;
                  } else {
                    _sort = s;
                    _sortAsc = true;
                  }
                }),
                onLevel: (v) => setState(() => _levelFilter = v),
                onToggleView: () => setState(() => _isTable = !_isTable),
                onAdd: () => _openForm(),
              ),
              const SizedBox(height: 16),
              if (_selected.isNotEmpty)
                _SubjectBulkBar(
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
                    icon: Icons.menu_book_outlined,
                    title: 'Aucune matière',
                    message:
                        'Ajoutez les matières enseignées et leurs coefficients '
                        'pour préparer les évaluations et bulletins.',
                    actionLabel: 'Nouvelle matière',
                    onAction: () => _openForm(),
                  ),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun résultat',
                    message: 'Ajustez la recherche.',
                  ),
                )
              else if (_isTable)
                _SubjectTable(
                  rows: filtered,
                  coefByLevel: coefByLevel,
                  sort: _sort,
                  sortAsc: _sortAsc,
                  selected: _selected,
                  onSelect: _toggle,
                  onSelectAll: (v) => _toggleAll(filtered, v),
                  onSort: (s) => setState(() {
                    if (_sort == s) {
                      _sortAsc = !_sortAsc;
                    } else {
                      _sort = s;
                      _sortAsc = true;
                    }
                  }),
                  onEdit: (s) => _openForm(existing: s),
                  onArchive: _archive,
                )
              else
                _SubjectCards(
                  rows: filtered,
                  coefByLevel: coefByLevel,
                  onEdit: (s) => _openForm(existing: s),
                  onArchive: _archive,
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _archive(SubjectModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Archiver cette matière ?'),
        content: Text('« ${s.name} » ne sera plus proposée. '
            'Les notes existantes sont conservées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runModuleWrite(context, () => archiveSubject(s.id),
        success: 'Matière archivée');
  }
}

// ─── KPIs ─────────────────────────────────────────────────────────────────────
class _Kpis extends StatelessWidget {
  const _Kpis({required this.subjects});
  final List<SubjectModel> subjects;

  @override
  Widget build(BuildContext context) {
    final n = subjects.length;
    final totalCoef = subjects.fold<int>(0, (s, e) => s + e.coefficient);
    final avg = n == 0 ? 0.0 : totalCoef / n;
    final niveaux = subjects.where((e) => !e.isTronc).map((e) => e.levelCode).toSet().length;
    final tronc = subjects.where((e) => e.isTronc).length;
    final fond = subjects.where((e) => e.coefficient >= 4).length; // « fondamentales »
    final items = <(IconData, String, String, Color, String?)>[
      (Icons.menu_book_outlined, 'Matières', '$n', kNavy,
          'définitions niveau × matière'),
      (Icons.stairs_outlined, 'Niveaux couverts', '$niveaux',
          const Color(0xFF0EA5E9), null),
      (Icons.public_outlined, 'Tronc commun', '$tronc', kGreen,
          'toutes classes'),
      (Icons.functions_rounded, 'Coef. moyen', avg.toStringAsFixed(1),
          const Color(0xFFF59E0B), null),
      (Icons.workspace_premium_outlined, 'Fondamentales', '$fond',
          const Color(0xFF8B5CF6), 'coef. ≥ 4'),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1100 ? 5 : (w >= 720 ? 3 : (w >= 460 ? 2 : 1));
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: cols == 1 ? 4.6 : 2.4,
        children: [
          for (final (icon, label, value, color, sub) in items)
            AdminStatCard(
                label: label,
                value: value,
                icon: icon,
                color: color,
                subtitle: sub),
        ],
      );
    });
  }
}
