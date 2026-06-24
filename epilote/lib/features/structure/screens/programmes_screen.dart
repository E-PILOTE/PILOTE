import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/academic_structure_provider.dart';
import '../providers/academic_year_context.dart';
import '../providers/programmes_provider.dart';
import '../providers/subjects_provider.dart';

part 'programmes_parts.dart';
part 'programmes_form.dart';

const _kSlug = 'programmes';

// Accents par cycle (cohérents avec Matières / Inscriptions).
const _cycleColors = <String, Color>{
  'prescolaire': Color(0xFFEC4899),
  'primaire': Color(0xFF0EA5E9),
  'college': kGreen,
  'lycee': kNavy,
  'formation_pro': Color(0xFFF59E0B),
  'fp': Color(0xFFF59E0B),
};
Color _cyc(String? c) => _cycleColors[c ?? ''] ?? kNavy;

// Ordre pédagogique des cycles (pour la vue groupée « Par cycle »).
const _cycleOrder = <String, int>{
  'prescolaire': 1,
  'primaire': 2,
  'college': 3,
  'lycee': 4,
  'formation_pro': 5,
  'fp': 5,
};
int _cycOrder(String? c) => _cycleOrder[c ?? ''] ?? 9;

const _cycleNames = <String, String>{
  'prescolaire': 'Préscolaire',
  'primaire': 'Primaire',
  'college': 'Collège',
  'lycee': 'Lycée',
  'formation_pro': 'Formation Pro.',
  'fp': 'Formation Pro.',
};
String _cycName(String? code, String? fallback) =>
    _cycleNames[code ?? ''] ??
    ((fallback?.trim().isNotEmpty ?? false) ? fallback!.trim() : 'Autres');

String _pl(int n, String s, String p) => '$n ${n <= 1 ? s : p}';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE PROGRAMMES — syllabus d'une matière à un niveau (par trimestre),
//  officiel ou personnalisé. Design plateforme (KPI → répartition → filtres →
//  table / cartes). Offline-first ; réutilise la matière CANONIQUE + structure.
// ════════════════════════════════════════════════════════════════════════════
class ProgrammesScreen extends ConsumerWidget {
  const ProgrammesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Programmes',
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
  String _view = 'table'; // table | cartes | cycle
  String? _subject; // subjectId
  String? _level; // levelCode
  String? _trimester; // 'all' geré par null ; valeur = numéro en String
  String _type = 'all'; // all | officiel | perso
  final Set<String> _selected = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  void _toggle(String id, bool sel) => setState(() {
        if (sel) {
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      });
  void _toggleAll(List<ProgrammeRow> rows, bool sel) => setState(() {
        if (sel) {
          _selected.addAll(rows.map((r) => r.id));
        } else {
          _selected.removeAll(rows.map((r) => r.id));
        }
      });
  void _clearSel() => setState(_selected.clear);

  void _resetFilters() => setState(() {
        _search.clear();
        _subject = _level = _trimester = null;
        _type = 'all';
      });

  List<ProgrammeRow> _apply(List<ProgrammeRow> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((p) {
      if (_subject != null && p.subjectId != _subject) return false;
      if (_level != null && (p.levelCode ?? '') != _level) return false;
      if (_trimester != null && '${p.trimesterNumber ?? 0}' != _trimester) {
        return false;
      }
      if (_type == 'officiel' && !p.isOfficial) return false;
      if (_type == 'perso' && p.isOfficial) return false;
      if (q.isEmpty) return true;
      return p.title.toLowerCase().contains(q) ||
          p.subjectName.toLowerCase().contains(q) ||
          (p.content ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _openForm({ProgrammeRow? existing}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ProgrammeForm(existing: existing),
      );

  void _openDetail(ProgrammeRow p) => showDialog(
        context: context,
        builder: (_) => _ProgrammeDetail(
          row: p,
          onEdit: p.isShared
              ? null
              : () {
                  Navigator.pop(context);
                  _openForm(existing: p);
                },
        ),
      );

  Future<void> _delete(ProgrammeRow p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer ce programme ?'),
        content: Text('« ${p.title} » (${p.subjectName} · ${p.levelLabel}) '
            'sera supprimé définitivement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runModuleWrite(context, () => deleteProgramme(p.id),
        success: 'Programme supprimé');
  }

  Future<void> _bulkDelete(List<ProgrammeRow> rows) async {
    final targets = rows
        .where((p) => _selected.contains(p.id) && !p.isShared)
        .toList();
    if (targets.isEmpty) {
      _snack('Aucun programme modifiable dans la sélection', kTextMuted);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Supprimer ${targets.length} programme(s) ?'),
        content: const Text('Action définitive.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var n = 0;
    for (final p in targets) {
      try {
        await deleteProgramme(p.id);
        n++;
      } catch (_) {}
    }
    _clearSel();
    _snack('$n programme(s) supprimé(s)', kGreen);
  }

  Future<void> _bulkExport(List<ProgrammeRow> rows) async {
    final targets = rows.where((p) => _selected.contains(p.id)).toList();
    final list = targets.isEmpty ? rows : targets;
    if (list.isEmpty) return;
    try {
      final path = await exportProgrammesCsv(list);
      _snack('Export CSV : ${list.length} ligne(s) → $path', kGreen);
    } catch (e) {
      _snack('Erreur export : $e', kRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(programmesProvider);
    final readOnly = ref.watch(yearReadOnlyProvider);
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
        final st = ref.watch(programmeStatsProvider);
        final filtered = _apply(all);
        // Valeurs présentes pour les filtres.
        final subjectsPresent = <String, String>{
          for (final p in all) p.subjectId: p.subjectName,
        };
        final levelsPresent = <String, int>{};
        for (final p in all) {
          if ((p.levelCode ?? '').isNotEmpty) {
            levelsPresent[p.levelCode!] = p.levelOrder;
          }
        }
        final trimestersPresent = <String, String>{
          for (final p in all)
            if (p.trimesterNumber != null)
              '${p.trimesterNumber}': p.trimesterLabelOrAll,
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(st: st),
              if (st.byLevel.isNotEmpty) ...[
                const SizedBox(height: 22),
                _LevelBreakdown(
                  byLevel: st.byLevel,
                  active: _level,
                  onPick: (code) => setState(
                      () => _level = _level == code ? null : code),
                ),
              ],
              const SizedBox(height: 22),
              _ProgFilterBar(
                searchCtrl: _search,
                view: _view,
                readOnly: readOnly,
                subject: _subject,
                level: _level,
                trimester: _trimester,
                type: _type,
                subjectsPresent: subjectsPresent,
                levelsPresent: levelsPresent,
                trimestersPresent: trimestersPresent,
                onSearch: (_) => setState(() {}),
                onSubject: (v) => setState(() => _subject = v),
                onLevel: (v) => setState(() => _level = v),
                onTrimester: (v) => setState(() => _trimester = v),
                onType: (v) => setState(() => _type = v),
                onView: (v) => setState(() => _view = v),
                onReset: _resetFilters,
                onAdd: () => _openForm(),
              ),
              const SizedBox(height: 16),
              if (_selected.isNotEmpty)
                _ProgBulkBar(
                  count: _selected.length,
                  onDelete: () => _bulkDelete(filtered),
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
                    icon: Icons.article_outlined,
                    title: 'Aucun programme',
                    message:
                        'Définissez le programme (syllabus) de chaque matière par '
                        'niveau et par trimestre — officiel ou propre à l\'école.',
                    actionLabel: readOnly ? null : 'Nouveau programme',
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
              else if (_view == 'cycle')
                _ProgByCycle(
                  rows: filtered,
                  onEdit: (p) => _openForm(existing: p),
                  onDelete: _delete,
                  onOpen: _openDetail,
                )
              else if (_view == 'table')
                _ProgTable(
                  rows: filtered,
                  selected: _selected,
                  onSelect: _toggle,
                  onSelectAll: (v) => _toggleAll(filtered, v),
                  onEdit: (p) => _openForm(existing: p),
                  onDelete: _delete,
                  onOpen: _openDetail,
                )
              else
                _ProgCards(
                  rows: filtered,
                  onEdit: (p) => _openForm(existing: p),
                  onDelete: _delete,
                  onOpen: _openDetail,
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
  const _Kpis({required this.st});
  final ProgrammeStats st;
  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Color, String?)>[
      (Icons.article_outlined, 'Programmes', '${st.total}', kNavy,
          'syllabus matière × niveau'),
      (Icons.verified_outlined, 'Officiels', '${st.official}', kGreen,
          'curriculum officiel'),
      (Icons.edit_note_rounded, 'Personnalisés', '${st.custom}',
          const Color(0xFFF59E0B), 'propres à l\'école'),
      (Icons.menu_book_outlined, 'Matières couvertes', '${st.subjectsCovered}',
          const Color(0xFF0EA5E9), null),
      (Icons.stairs_outlined, 'Niveaux couverts', '${st.levelsCovered}',
          const Color(0xFF8B5CF6), null),
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
