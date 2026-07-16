import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../../data/models/class_model.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../widgets/inscription_form_kit.dart';
import '../widgets/scope_drilldown_panel.dart';
import '../providers/inscriptions_data_provider.dart';
import '../providers/students_provider.dart';
import '../providers/student_documents_provider.dart';
import '../providers/student_tutors_provider.dart';
import '../services/inscriptions_pdf_service.dart';
import 'add_inscription_screen.dart';

part 'inscriptions_list_parts.dart';
part 'inscriptions_modals.dart';

// ─── Accents de cycle ─────────────────────────────────────────────────────────
const _kBlue = Color(0xFF0EA5E9);
const _kPink = Color(0xFFEC4899);

Color _cycleColor(String code) => switch (code) {
      'prescolaire' => _kPink,
      'primaire' => _kBlue,
      'college' => kGreen,
      'lycee' => kNavy,
      'fp' => kAccent,
      _ => kTextMuted,
    };

enum _SortBy { nom, classe, date }

// ════════════════════════════════════════════════════════════════════════════
//  PAGE INSCRIPTIONS — une seule page (design plateforme admin_groupe) :
//  KPI → cycles → évolution → filtres (avec « Inscrire ») → table / cartes.
//  Le statut « En attente » est un FILTRE (pas un onglet) ; validation/rejet
//  via les actions de ligne et la fiche détail.
// ════════════════════════════════════════════════════════════════════════════
class InscriptionsScreen extends ConsumerWidget {
  const InscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ModuleScaffold(
      slug: 'inscriptions',
      title: 'Inscriptions',
      child: _InscriptionsBody(),
    );
  }
}

class _InscriptionsBody extends ConsumerStatefulWidget {
  const _InscriptionsBody();
  @override
  ConsumerState<_InscriptionsBody> createState() => _InscriptionsBodyState();
}

class _InscriptionsBodyState extends ConsumerState<_InscriptionsBody> {
  final _searchCtrl = TextEditingController();
  ScopeSel _scope = const ScopeSel(); // cycle/niveau/classe (panneau répartition)
  String? _filiere;
  String? _type;
  String _status = 'all'; // all | active | pending_validation | rejected
  bool _isTable = true;
  _SortBy _sort = _SortBy.nom;
  bool _sortAsc = true;
  final Set<String> _selected = {}; // ids d'inscriptions sélectionnées (actions groupées)

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<InscriptionRow> _apply(List<InscriptionRow> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final out = all.where((r) {
      if (_scope.cycle != null && r.cycle.code != _scope.cycle) return false;
      if (_scope.level != null && (r.levelCode ?? '') != _scope.level) {
        return false;
      }
      if (_scope.classId != null && r.classId != _scope.classId) return false;
      if (_filiere != null && r.filiereLabel != _filiere) return false;
      if (_type != null && r.inscriptionType != _type) return false;
      if (_status != 'all' && r.status != _status) return false;
      if (q.isEmpty) return true;
      return r.fullName.toLowerCase().contains(q) ||
          r.matricule.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final c = switch (_sort) {
          _SortBy.nom => a.lastFirst.toLowerCase().compareTo(b.lastFirst.toLowerCase()),
          _SortBy.classe => a.className.compareTo(b.className),
          _SortBy.date => (a.enrollmentDate ?? DateTime(2000))
              .compareTo(b.enrollmentDate ?? DateTime(2000)),
        };
        return _sortAsc ? c : -c;
      });
    return out;
  }

  void _resetFilters() => setState(() {
        _searchCtrl.clear();
        _scope = const ScopeSel();
        _filiere = _type = null;
        _status = 'all';
      });

  void _openAdd() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: AddInscriptionScreen(),
        ),
      );

  void _openDetail(InscriptionRow r) {
    final readOnly = ref.read(yearReadOnlyProvider);
    showDialog(
      context: context,
      builder: (_) => _InscriptionDetailModal(
        row: r,
        readOnly: readOnly,
        onEdit: () {
          Navigator.of(context).pop();
          _openEdit(r);
        },
        onValidate: r.status == 'pending_validation' && !readOnly
            ? () { Navigator.of(context).pop(); _validate(r); }
            : null,
        onReject: r.status == 'pending_validation' && !readOnly
            ? () { Navigator.of(context).pop(); _reject(r); }
            : null,
        onChangeClass: readOnly
            ? null
            : () { Navigator.of(context).pop(); _changeClass(r); },
        onWithdraw: readOnly
            ? null
            : () { Navigator.of(context).pop(); _withdraw(r); },
        onDelete: readOnly
            ? null
            : () { Navigator.of(context).pop(); _delete(r); },
      ),
    );
  }

  void _openEdit(InscriptionRow r) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditStudentModal(row: r),
      );

  Future<void> _changeClass(InscriptionRow r) async {
    final classes = ref.read(classesProvider).valueOrNull ?? const <ClassModel>[];
    final others = classes.where((c) => c.id != r.classId).toList();
    if (others.isEmpty) {
      _snack('Aucune autre classe disponible.', kTextMuted);
      return;
    }
    final picked = await showDialog<ClassModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Réaffecter ${r.fullName}'),
        children: [
          for (final c in others)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(Icons.meeting_room_outlined,
                      size: 18, color: kNavy),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.name)),
                  Text('${c.studentCount ?? 0}'
                      '${c.capacity != null ? '/${c.capacity}' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: kTextMuted)),
                ]),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    try {
      await changeEnrollmentClass(enrollmentId: r.id, newClassId: picked.id);
      _snack('Élève réaffecté dans ${picked.name}', kGreen);
    } catch (e) {
      _snack('Erreur : $e', kRed);
    }
  }

  Future<void> _withdraw(InscriptionRow r) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Retirer de la classe'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motif du retrait',
            hintText: 'Ex. : Déménagement, transfert…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true) { ctrl.dispose(); return; }
    try {
      await withdrawStudent(
        enrollmentId: r.id,
        reason: ctrl.text.trim().isEmpty ? 'Aucun motif précisé' : ctrl.text.trim(),
      );
      _snack('Élève retiré de la classe', kTextMuted);
    } catch (e) {
      _snack('Erreur : $e', kRed);
    }
    ctrl.dispose();
  }

  Future<void> _delete(InscriptionRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer l\'inscription ?'),
        content: Text(
            'L\'inscription de ${r.fullName} pour cette année sera définitivement '
            'supprimée. La fiche élève (identité, tuteurs) est conservée.'),
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
    try {
      await deleteEnrollment(r.id);
      _snack('Inscription supprimée', kTextMuted);
    } catch (e) {
      _snack('Erreur : $e', kRed);
    }
  }

  Future<void> _validate(InscriptionRow r) async {
    final me = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    try {
      await validateEnrollment(enrollmentId: r.id, validatedBy: me);
      _snack('Inscription validée', kGreen);
    } catch (e) {
      _snack('Erreur : $e', kRed);
    }
  }

  Future<void> _reject(InscriptionRow r) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Rejeter l\'inscription'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            hintText: 'Ex. : Dossier incomplet, quota atteint…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (ok != true) { ctrl.dispose(); return; }
    final me = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    try {
      await rejectEnrollment(
        enrollmentId: r.id,
        rejectionReason:
            ctrl.text.trim().isEmpty ? 'Aucun motif précisé' : ctrl.text.trim(),
        validatedBy: me,
      );
      _snack('Inscription rejetée', kTextMuted);
    } catch (e) {
      _snack('Erreur : $e', kRed);
    }
    ctrl.dispose();
  }

  Future<void> _export(List<InscriptionRow> rows) async {
    if (rows.isEmpty) return;
    try {
      final path = await exportInscriptionsCsv(rows);
      _snack('Export CSV : ${rows.length} ligne(s) → $path', kGreen);
    } catch (e) {
      _snack('Erreur export : $e', kRed);
    }
  }

  void _previewPdf(List<InscriptionRow> rows) {
    if (rows.isEmpty) return;
    final year = ref.read(activeYearProvider)?.label;
    showPdfPreviewDialog(
      context,
      title: 'Inscriptions',
      subtitle: '${rows.length} inscription${rows.length > 1 ? 's' : ''}'
          '${year != null ? ' · $year' : ''}',
      pdfFileName: 'Inscriptions.pdf',
      build: (format) =>
          InscriptionsPdfService.buildPdf(rows: rows, yearLabel: year),
      onDownload: () =>
          InscriptionsPdfService.downloadDoc(rows: rows, yearLabel: year),
    );
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  // ── Sélection / actions groupées ───────────────────────────────────────────
  void _toggleSelect(String id, bool sel) => setState(() {
        if (sel) {
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      });

  void _toggleSelectAll(List<InscriptionRow> rows, bool sel) => setState(() {
        if (sel) {
          _selected.addAll(rows.map((r) => r.id));
        } else {
          _selected.removeAll(rows.map((r) => r.id));
        }
      });

  void _clearSelection() => setState(_selected.clear);

  Future<void> _bulkValidate(List<InscriptionRow> rows) async {
    final me = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    final targets = rows
        .where((r) => _selected.contains(r.id) && r.status == 'pending_validation')
        .toList();
    if (targets.isEmpty) {
      _snack('Aucune inscription « en attente » dans la sélection', kTextMuted);
      return;
    }
    var ok = 0;
    for (final r in targets) {
      try {
        await validateEnrollment(enrollmentId: r.id, validatedBy: me);
        ok++;
      } catch (_) {}
    }
    if (mounted) setState(() => _selected.clear());
    _snack('$ok inscription(s) validée(s)', kGreen);
  }

  Future<void> _bulkReject(List<InscriptionRow> rows) async {
    final targets = rows
        .where((r) => _selected.contains(r.id) && r.status == 'pending_validation')
        .toList();
    if (targets.isEmpty) {
      _snack('Aucune inscription « en attente » dans la sélection', kTextMuted);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Rejeter ${targets.length} inscription(s) ?'),
        content: const Text(
            'Les dossiers « en attente » sélectionnés seront rejetés (motif générique).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final me = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    var n = 0;
    for (final r in targets) {
      try {
        await rejectEnrollment(
            enrollmentId: r.id,
            rejectionReason: 'Rejet groupé',
            validatedBy: me);
        n++;
      } catch (_) {}
    }
    if (mounted) setState(() => _selected.clear());
    _snack('$n inscription(s) rejetée(s)', kTextMuted);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inscriptionsDataProvider);
    final readOnly = ref.watch(yearReadOnlyProvider);

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const _InscriptionsSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $e', style: TextStyle(color: kRed)),
        ),
      ),
      data: (all) {
        final st = ref.watch(inscriptionStatsProvider);
        final filtered = _apply(all);
        // Filières OFFERTES par l'école (depuis la structure, même à 0 inscrit)
        // → le filtre est visible pour toute école technique/professionnelle.
        final filieresPresent = [for (final p in st.byProgram) p.label]..sort();

        return LayoutBuilder(builder: (ctx, cns) {
          final w = cns.maxWidth.isFinite
              ? cns.maxWidth
              : MediaQuery.of(ctx).size.width;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KpiSection(st: st),
                  const SizedBox(height: 26),
                  // L'effectif VALIDÉ (cycle/niveau/classe) vit dans la page
                  // Élèves. Ici = guichet des admissions : rythme global +
                  // pipeline par dimension (dossiers en cours). Zéro doublon.
                  if (st.evolution.length >= 2) ...[
                    const AdminSectionTitle('Rythme des inscriptions',
                        icon: Icons.show_chart_rounded,
                        subtitle:
                            'Nouvelles inscriptions par mois (barres) et effectif cumulé (courbe)'),
                    const SizedBox(height: 12),
                    _EvolutionCard(points: st.evolution),
                    const SizedBox(height: 22),
                  ],
                  if (all.isNotEmpty)
                    ScopeDrilldownPanel(
                      title: 'Répartition des dossiers',
                      metricLabel: '',
                      selected: _scope,
                      onSelect: (s) => setState(() => _scope = s),
                      units: [
                        for (final r in all)
                          ScopeUnit(
                            cycleCode: r.cycle.code,
                            levelCode: r.levelCode,
                            levelOrder: r.levelOrder,
                            classId: r.classId,
                            className: r.className,
                            ok: false,
                          ),
                      ],
                    ),
                  const SizedBox(height: 22),
                  _FilterBar(
                    width: w - 48,
                    searchCtrl: _searchCtrl,
                    filiere: _filiere,
                    type: _type,
                    status: _status,
                    isTable: _isTable,
                    readOnly: readOnly,
                    filieresPresent: filieresPresent,
                    onSearch: (_) => setState(() {}),
                    onFiliere: (v) => setState(() => _filiere = v),
                    onType: (v) => setState(() => _type = v),
                    onStatus: (v) => setState(() => _status = v),
                    onToggleView: () => setState(() => _isTable = !_isTable),
                    onReset: _resetFilters,
                    onAdd: _openAdd,
                    onExport: () => _export(filtered),
                  ),
                  if (_scope.active) ...[
                    const SizedBox(height: 12),
                    _ScopeChip(
                      label: _scope.label,
                      onClear: () =>
                          setState(() => _scope = const ScopeSel()),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_selected.isNotEmpty)
                    _BulkBar(
                      count: _selected.length,
                      onValidate: () => _bulkValidate(filtered),
                      onReject: () => _bulkReject(filtered),
                      onExport: () {
                        _export(filtered
                            .where((r) => _selected.contains(r.id))
                            .toList());
                      },
                      onClear: _clearSelection,
                    )
                  else
                    _ResultHeader(
                      total: all.length,
                      filtered: filtered.length,
                      onExportPdf: filtered.isEmpty
                          ? null
                          : () => _previewPdf(filtered),
                    ),
                  const SizedBox(height: 12),
                  if (all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: AdminEmptyState(
                        icon: Icons.how_to_reg_outlined,
                        title: 'Aucune inscription cette année',
                        message:
                            'Inscrivez le premier élève pour démarrer le suivi des effectifs.',
                        actionLabel: readOnly ? null : 'Inscrire un élève',
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
                    _InscritsTable(
                      rows: filtered,
                      sort: _sort,
                      sortAsc: _sortAsc,
                      selected: _selected,
                      onSelect: _toggleSelect,
                      onSelectAll: (v) => _toggleSelectAll(filtered, v),
                      onSort: (f) => setState(() {
                        if (_sort == f) {
                          _sortAsc = !_sortAsc;
                        } else {
                          _sort = f;
                          _sortAsc = true;
                        }
                      }),
                      onView: _openDetail,
                      onValidate: _validate,
                      onReject: _reject,
                      readOnly: readOnly,
                    )
                  else
                    _InscritsCards(
                      rows: filtered,
                      selected: _selected,
                      onSelect: _toggleSelect,
                      onView: _openDetail,
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

// ─── Section KPI générale (cartes pleine taille, comme le Tableau de bord) ────
class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.st});
  final InscriptionStats st;

  @override
  Widget build(BuildContext context) {
    // Page = guichet des admissions (les inscriptions VALIDÉES passent dans la
    // page Élèves). KPI centrés sur le pipeline à traiter.
    final cards = <Widget>[
      AdminStatCard(
        label: 'En attente',
        value: '${st.pending}',
        icon: Icons.hourglass_top_rounded,
        color: kAccent,
        subtitle: 'À valider',
      ),
      AdminStatCard(
        label: 'Rejetées',
        value: '${st.rejected}',
        icon: Icons.cancel_outlined,
        color: kRed,
        subtitle: 'Dossiers refusés',
      ),
      AdminStatCard(
        label: 'Nouvelles',
        value: '${st.typeNew}',
        icon: Icons.fiber_new_rounded,
        color: kGreen,
        subtitle: 'Premières inscriptions',
      ),
      AdminStatCard(
        label: 'Réinscriptions',
        value: '${st.reinscription}',
        icon: Icons.autorenew_rounded,
        color: kNavy,
        subtitle: 'Élèves de retour',
      ),
      AdminStatCard(
        label: 'Transferts',
        value: '${st.transfer}',
        icon: Icons.swap_horiz_rounded,
        color: _kBlue,
        subtitle: 'Venus d\'une autre école',
      ),
      AdminStatCard(
        label: 'Redoublants',
        value: '${st.repeating}',
        icon: Icons.replay_rounded,
        color: const Color(0xFF7C3AED),
        subtitle: 'Dans le pipeline',
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1180
          ? 6
          : c.maxWidth >= 920
              ? 4
              : c.maxWidth >= 600
                  ? 3
                  : c.maxWidth >= 380
                      ? 2
                      : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 168,
        ),
        itemBuilder: (_, i) => cards[i],
      );
    });
  }
}


// ─── Rythme des inscriptions ─────────────────────────────────────────────────
// Sens RÉEL du graphe : combien d'élèves s'inscrivent CHAQUE mois (barres =
// rythme de la campagne) et comment l'effectif se REMPLIT (courbe = cumul).
class _EvolutionCard extends StatelessWidget {
  const _EvolutionCard({required this.points});
  final List<EnrollPoint> points;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Row(children: [
              _LegendDot(color: kNavy, label: 'Inscriptions du mois'),
              const SizedBox(width: 16),
              _LegendDot(color: kGreen, label: 'Effectif cumulé', line: true),
            ]),
          ),
          SizedBox(
            height: 220,
            child: SfCartesianChart(
              margin: EdgeInsets.zero,
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
              ),
              primaryYAxis: NumericAxis(
                axisLine: const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
                labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
              ),
              axes: <ChartAxis>[
                NumericAxis(
                  name: 'cumul',
                  opposedPosition: true,
                  axisLine: const AxisLine(width: 0),
                  majorGridLines: const MajorGridLines(width: 0),
                  majorTickLines: const MajorTickLines(size: 0),
                  labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
                ),
              ],
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries<EnrollPoint, String>>[
                ColumnSeries<EnrollPoint, String>(
                  name: 'Inscriptions',
                  dataSource: points,
                  xValueMapper: (p, _) => p.label,
                  yValueMapper: (p, _) => p.count,
                  color: kNavy.withValues(alpha: 0.85),
                  width: 0.55,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                SplineSeries<EnrollPoint, String>(
                  name: 'Cumulé',
                  dataSource: points,
                  xValueMapper: (p, _) => p.label,
                  yValueMapper: (p, _) => p.cumul,
                  yAxisName: 'cumul',
                  color: kGreen,
                  width: 2.5,
                  markerSettings: const MarkerSettings(
                      isVisible: true, height: 5, width: 5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, this.line = false});
  final Color color;
  final String label;
  final bool line;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: line ? 14 : 10,
          height: line ? 3 : 10,
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(line ? 2 : 3)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: kTextMuted)),
      ]);
}

// ─── Barre de filtres (style plateforme) ─────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.width,
    required this.searchCtrl,
    required this.filiere,
    required this.type,
    required this.status,
    required this.isTable,
    required this.readOnly,
    required this.filieresPresent,
    required this.onSearch,
    required this.onFiliere,
    required this.onType,
    required this.onStatus,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
    required this.onExport,
  });
  final double width;
  final TextEditingController searchCtrl;
  final String? filiere, type;
  final String status;
  final bool isTable, readOnly;
  final List<String> filieresPresent;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onFiliere, onType;
  final ValueChanged<String> onStatus;
  final VoidCallback onToggleView, onReset, onAdd, onExport;

  bool get _hasFilters =>
      filiere != null || type != null || status != 'all';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, matricule)…',
                hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search_rounded, color: kTextMuted, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: kTextMuted),
                        onPressed: () { searchCtrl.clear(); onSearch(''); })
                    : null,
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _IconBtn(
            icon: isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
            tooltip: isTable ? 'Vue en cartes' : 'Vue en tableau',
            color: kNavy,
            onTap: onToggleView,
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.download_rounded,
            tooltip: 'Exporter en CSV',
            color: kGreen,
            onTap: onExport,
          ),
          const SizedBox(width: 12),
          _AddButton(readOnly: readOnly, onAdd: onAdd),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (filieresPresent.isNotEmpty)
              _FilterDropdown<String?>(
                icon: Icons.workspaces_outlined,
                value: filiere,
                active: filiere != null,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Toutes les filières')),
                  for (final f in filieresPresent)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: onFiliere,
              ),
            _FilterDropdown<String?>(
              icon: Icons.category_outlined,
              value: type,
              active: type != null,
              items: const [
                DropdownMenuItem(value: null, child: Text('Tous les types')),
                DropdownMenuItem(value: 'new', child: Text('Nouvelles')),
                DropdownMenuItem(
                    value: 'reinscription', child: Text('Réinscriptions')),
                DropdownMenuItem(value: 'transfer', child: Text('Transferts')),
              ],
              onChanged: onType,
            ),
            _StatusSegment(value: status, onChanged: onStatus),
            if (_hasFilters)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onReset,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: kRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kRed.withValues(alpha: 0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.filter_alt_off_rounded, size: 13, color: kRed),
                      const SizedBox(width: 4),
                      Text('Réinitialiser',
                          style: TextStyle(
                              color: kRed,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

// Bandeau de filtre actif (scope choisi dans le panneau de répartition).
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kNavy.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_alt_rounded, size: 14, color: kNavy),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(width: 2),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 15, color: kNavy),
              ),
            ),
          ]),
        ),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.readOnly, required this.onAdd});
  final bool readOnly;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kAccent.withValues(alpha: 0.30)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_clock_rounded, size: 15, color: kAccent),
          const SizedBox(width: 6),
          Text('Année verrouillée',
              style: TextStyle(
                  color: kAccent, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );
    }
    return PermissionGate(
      slug: 'inscriptions',
      action: 'create',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kNavyDark, kNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: kNavy.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_add_rounded, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text('Inscrire',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      );
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.active,
  });
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        constraints: const BoxConstraints(minWidth: 170, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? kNavy.withValues(alpha: 0.06) : kSurface,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: active ? kNavy.withValues(alpha: 0.35) : kBorder),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: active ? kNavy : kTextMuted),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                icon: Icon(Icons.expand_more_rounded,
                    size: 14, color: active ? kNavy : kTextMuted),
                isExpanded: true,
                style: TextStyle(
                  color: active ? kNavy : kTextPrimary,
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ]),
      );
}

class _StatusSegment extends StatelessWidget {
  const _StatusSegment({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String v, String label) {
      final sel = value == v;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : kTextMuted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('all', 'Tous'),
        seg('pending_validation', 'En attente'),
        seg('rejected', 'Rejetées'),
        seg('withdrawn', 'Sorties'),
      ]),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader(
      {required this.total, required this.filtered, this.onExportPdf});
  final int total, filtered;
  final VoidCallback? onExportPdf;
  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$filtered inscrit${filtered > 1 ? 's' : ''}',
            style: TextStyle(
                color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        if (filtered < total) ...[
          const SizedBox(width: 8),
          Text('sur $total',
              style: TextStyle(color: kTextMuted, fontSize: 13)),
        ],
        const Spacer(),
        if (onExportPdf != null) AdminPdfButton(onTap: onExportPdf!),
      ]);
}

// ─── Skeleton de chargement (shimmer, calqué sur la vraie page) ──────────────
class _InscriptionsSkeleton extends StatelessWidget {
  const _InscriptionsSkeleton();

  Widget _box(double w, double h, {double r = 12}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(r)),
      );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8ECF0),
      highlightColor: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero KPI (6 cartes responsives)
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 1180
                  ? 6
                  : c.maxWidth >= 920
                      ? 4
                      : c.maxWidth >= 600
                          ? 3
                          : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 168,
                ),
                itemBuilder: (_, _) =>
                    _box(double.infinity, double.infinity, r: 12),
              );
            }),
            const SizedBox(height: 26),
            // Carte « Répartition » (en-tête + grille)
            _box(double.infinity, 320, r: 12),
            const SizedBox(height: 26),
            // Évolution
            _box(180, 16, r: 6),
            const SizedBox(height: 12),
            _box(double.infinity, 230, r: 12),
            const SizedBox(height: 22),
            // Barre de filtres
            _box(double.infinity, 110, r: 8),
            const SizedBox(height: 18),
            // Quelques lignes de tableau
            for (var i = 0; i < 6; i++) ...[
              _box(double.infinity, 52, r: 10),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
