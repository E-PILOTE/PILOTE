import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../../data/models/class_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/inscriptions_data_provider.dart';
import '../providers/student_documents_provider.dart';
import '../providers/student_tutors_provider.dart';
import '../providers/students_provider.dart';
import '../providers/students_registry_provider.dart';
import '../services/students_pdf_service.dart';
import '../widgets/inscription_form_kit.dart';
import 'add_inscription_screen.dart';

part 'eleves_parts.dart';
part 'eleves_drawer.dart';
part 'eleves_edit.dart';

// ─── Référentiel cycles (couleur / nom / ordre) ──────────────────────────────
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
Color _cycColor(String? code) => _cycleColors[code ?? ''] ?? kTextMuted;
String _cycName(String? code) => _cycleNames[code ?? ''] ?? 'Non classé';
int _cycOrder(String? code) => _cycleOrder[code ?? ''] ?? 9;

String _pl(int n, String s, String p) => '$n ${n <= 1 ? s : p}';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE ÉLÈVES — l'effectif VALIDÉ de l'école (inscriptions actives ; les
//  dossiers en attente restent dans Inscriptions). Design plateforme : KPI →
//  graphes (cycle/niveau) → filtres → table/cartes (sélection + actions
//  groupées) → tiroir détail (dossier + cycle de vie : changer de classe,
//  annuler l'inscription, transférer/radier, désactiver). Offline-first.
// ════════════════════════════════════════════════════════════════════════════
class ElevesScreen extends ConsumerWidget {
  const ElevesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: 'eleves',
        title: 'Élèves',
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
  String? _gender; // M | F
  String? _cycle;
  String? _level;
  String _dim = 'niveau'; // dimension de la répartition : cycle|niveau|classe
  bool _isTable = true;
  bool _sortAsc = true;
  final Set<String> _selected = {}; // ids d'élèves (= enrollmentId) sélectionnés

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() => setState(() {
        _search.clear();
        _gender = _cycle = _level = null;
      });

  List<StudentRow> _apply(List<StudentRow> all) {
    final q = _search.text.trim().toLowerCase();
    final out = all.where((s) {
      if (_gender != null && s.gender != _gender) return false;
      if (_cycle != null && (s.cycleCode ?? '') != _cycle) return false;
      if (_level != null && (s.levelCode ?? '') != _level) return false;
      if (q.isEmpty) return true;
      return s.fullName.toLowerCase().contains(q) ||
          s.matricule.toLowerCase().contains(q) ||
          (s.className ?? '').toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final c = a.lastFirst.toLowerCase().compareTo(b.lastFirst.toLowerCase());
        return _sortAsc ? c : -c;
      });
    return out;
  }

  // ── Sélection ──────────────────────────────────────────────────────────────
  void _toggle(String id, bool sel) => setState(() {
        if (sel) {
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      });
  void _toggleAll(List<StudentRow> rows, bool sel) => setState(() {
        if (sel) {
          _selected.addAll(rows.map((r) => r.enrollmentId!));
        } else {
          _selected.removeAll(rows.map((r) => r.enrollmentId!));
        }
      });
  void _clearSel() => setState(_selected.clear);

  void _openAdd() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: AddInscriptionScreen(),
        ),
      );

  void _openDrawer(StudentRow s) => showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fermer',
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => Align(
          alignment: Alignment.centerRight,
          child: _StudentDrawer(row: s),
        ),
        transitionBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );

  // ── Actions groupées ───────────────────────────────────────────────────────
  Future<void> _bulkChangeClass(List<StudentRow> rows) async {
    final targets =
        rows.where((r) => _selected.contains(r.enrollmentId)).toList();
    if (targets.isEmpty) return;
    final classId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClassChooserDialog(
          title: 'Changer de classe',
          subtitle: '${targets.length} élève(s) sélectionné(s)'),
    );
    if (classId == null || !mounted) return;
    var n = 0;
    for (final r in targets) {
      try {
        await changeEnrollmentClass(
            enrollmentId: r.enrollmentId!, newClassId: classId);
        n++;
      } catch (_) {}
    }
    ref.invalidate(studentsRegistryProvider);
    _clearSel();
    _snack('$n élève(s) réaffecté(s)', kGreen);
  }

  Future<void> _bulkRevert(List<StudentRow> rows) async {
    final targets =
        rows.where((r) => _selected.contains(r.enrollmentId)).toList();
    if (targets.isEmpty) return;
    final ok = await _confirm(
      'Annuler l\'inscription de ${targets.length} élève(s) ?',
      'Ils repartiront dans la page Inscriptions (statut « en attente »).',
      'Annuler l\'inscription',
      kAccent,
    );
    if (ok != true) return;
    var n = 0;
    for (final r in targets) {
      try {
        await revertEnrollmentToValidation(r.enrollmentId!);
        n++;
      } catch (_) {}
    }
    ref.invalidate(studentsRegistryProvider);
    _clearSel();
    _snack('$n inscription(s) renvoyée(s) au pipeline', kAccent);
  }

  Future<void> _bulkExport(List<StudentRow> rows) async {
    final targets =
        rows.where((r) => _selected.contains(r.enrollmentId)).toList();
    final list = targets.isEmpty ? rows : targets;
    if (list.isEmpty) return;
    try {
      final path = await exportStudentsCsv(list);
      _snack('Export CSV : ${list.length} ligne(s) → $path', kGreen);
    } catch (e) {
      _snack('Erreur export : $e', kRed);
    }
  }

  void _previewPdf(List<StudentRow> rows) {
    if (rows.isEmpty) return;
    final year = ref.read(activeYearProvider)?.label;
    showPdfPreviewDialog(
      context,
      title: 'Effectif élèves',
      subtitle: '${rows.length} élève${rows.length > 1 ? 's' : ''}'
          '${year != null ? ' · $year' : ''}',
      pdfFileName: 'Eleves.pdf',
      build: (format) =>
          StudentsPdfService.buildPdf(rows: rows, yearLabel: year),
      onDownload: () =>
          StudentsPdfService.downloadDoc(rows: rows, yearLabel: year),
    );
  }

  Future<bool?> _confirm(String title, String body, String ok, Color c) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Retour')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ok),
            ),
          ],
        ),
      );

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studentsRegistryProvider);
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
        final filtered = _apply(all);
        final cyclesPresent = <String, String>{
          for (final s in all) (s.cycleCode ?? ''): _cycName(s.cycleCode),
        };
        final levelsPresent = <String, int>{
          for (final s in all.where(
              (s) => _cycle == null || (s.cycleCode ?? '') == _cycle))
            (s.levelCode ?? ''): s.levelOrder,
        }..remove('');
        final levelCodes = levelsPresent.keys.toList()
          ..sort((a, b) => levelsPresent[a]!.compareTo(levelsPresent[b]!));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(students: all),
              if (all.isNotEmpty) ...[
                const SizedBox(height: 22),
                _ElevesBreakdown(
                  students: all,
                  dim: _dim,
                  activeCycle: _cycle,
                  activeLevel: _level,
                  onDim: (d) => setState(() => _dim = d),
                  onPickCycle: (c) => setState(() {
                    _cycle = _cycle == c ? null : c;
                    _level = null;
                  }),
                  onPickLevel: (l) => setState(() => _level = _level == l ? null : l),
                  onOpenClass: (id) =>
                      context.push(Routes.classeDetail.replaceFirst(':id', id)),
                  onOpenStructure: () => context.push(Routes.structure),
                ),
              ],
              const SizedBox(height: 22),
              _ElevesFilterBar(
                searchCtrl: _search,
                gender: _gender,
                cycle: _cycle,
                level: _level,
                isTable: _isTable,
                readOnly: readOnly,
                cyclesPresent: cyclesPresent,
                levelCodes: levelCodes,
                onSearch: (_) => setState(() {}),
                onGender: (v) => setState(() => _gender = v),
                onCycle: (v) => setState(() {
                  _cycle = v;
                  _level = null;
                }),
                onLevel: (v) => setState(() => _level = v),
                onToggleView: () => setState(() => _isTable = !_isTable),
                onReset: _resetFilters,
                onAdd: _openAdd,
              ),
              const SizedBox(height: 16),
              if (_selected.isNotEmpty && !readOnly)
                _BulkBar(
                  count: _selected.length,
                  onChangeClass: () => _bulkChangeClass(filtered),
                  onRevert: () => _bulkRevert(filtered),
                  onExport: () => _bulkExport(filtered),
                  onClear: _clearSel,
                )
              else
                _ResultHeader(
                  total: all.length,
                  filtered: filtered.length,
                  onExportPdf:
                      filtered.isEmpty ? null : () => _previewPdf(filtered),
                ),
              const SizedBox(height: 12),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Aucun élève dans l\'effectif',
                    message:
                        'Les élèves apparaissent ici une fois leur inscription '
                        'VALIDÉE (depuis la page Inscriptions).',
                    actionLabel: readOnly ? null : 'Nouvel élève',
                    onAction: readOnly ? null : _openAdd,
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
                _StudentTable(
                  rows: filtered,
                  sortAsc: _sortAsc,
                  selected: _selected,
                  readOnly: readOnly,
                  onSort: () => setState(() => _sortAsc = !_sortAsc),
                  onSelect: _toggle,
                  onSelectAll: (v) => _toggleAll(filtered, v),
                  onOpen: _openDrawer,
                )
              else
                _StudentCards(
                  rows: filtered,
                  selected: _selected,
                  readOnly: readOnly,
                  onSelect: _toggle,
                  onOpen: _openDrawer,
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ─── KPIs (démographie de l'effectif) ────────────────────────────────────────
class _Kpis extends StatelessWidget {
  const _Kpis({required this.students});
  final List<StudentRow> students;
  @override
  Widget build(BuildContext context) {
    final filles = students.where((s) => s.gender == 'F').length;
    final garcons = students.where((s) => s.gender == 'M').length;
    final internes = students.where((s) => s.isBoarder).length;
    final boursiers =
        students.where((s) => s.hasScholarship || s.hasSocialAid).length;
    final items = <(IconData, String, String, Color, String?)>[
      (Icons.groups_rounded, 'Effectif', '${students.length}', kNavy,
          'élèves validés'),
      (Icons.female_rounded, 'Filles', '$filles', const Color(0xFFEC4899), null),
      (Icons.male_rounded, 'Garçons', '$garcons', const Color(0xFF0EA5E9), null),
      (Icons.night_shelter_outlined, 'Internes', '$internes',
          const Color(0xFF8B5CF6), null),
      (Icons.volunteer_activism_outlined, 'Boursiers / aidés', '$boursiers',
          const Color(0xFFF59E0B), null),
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
