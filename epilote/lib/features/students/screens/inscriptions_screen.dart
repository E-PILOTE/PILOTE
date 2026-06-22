import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../providers/inscriptions_data_provider.dart';
import 'add_inscription_screen.dart';

part 'inscriptions_list_parts.dart';

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
  String? _cycle;
  String? _type;
  String _status = 'all'; // all | active | pending_validation | rejected
  bool _isTable = true;
  _SortBy _sort = _SortBy.nom;
  bool _sortAsc = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<InscriptionRow> _apply(List<InscriptionRow> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final out = all.where((r) {
      if (_cycle != null && r.cycle.code != _cycle) return false;
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
        _cycle = _type = null;
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

  void _openDetail(InscriptionRow r) => showDialog(
        context: context,
        builder: (_) => _InscriptionDetailModal(
          row: r,
          onOpenStudent: () {
            Navigator.of(context).pop();
            context.push(Routes.eleveDetail.replaceFirst(':id', r.studentId));
          },
          onValidate: r.status == 'pending_validation'
              ? () { Navigator.of(context).pop(); _validate(r); }
              : null,
          onReject: r.status == 'pending_validation'
              ? () { Navigator.of(context).pop(); _reject(r); }
              : null,
        ),
      );

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

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inscriptionsDataProvider);
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
        final st = ref.watch(inscriptionStatsProvider);
        final filtered = _apply(all);
        final cyclesPresent = <String, String>{
          for (final r in all) r.cycle.code: r.cycle.label,
        };

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
                  if (st.byCycle.isNotEmpty) ...[
                    const AdminSectionTitle('Répartition par cycle',
                        icon: Icons.account_tree_rounded,
                        subtitle:
                            'Cycles hérités de la configuration de l\'école'),
                    const SizedBox(height: 12),
                    _CycleSection(byCycle: st.byCycle),
                    const SizedBox(height: 26),
                  ],
                  if (st.byLevel.isNotEmpty) ...[
                    AdminSectionTitle('Répartition par niveau',
                        icon: Icons.layers_rounded,
                        subtitle:
                            '${st.byLevel.length} niveau${st.byLevel.length > 1 ? 'x' : ''} (6ᵉ, 5ᵉ…) selon les cycles'),
                    const SizedBox(height: 12),
                    _LevelSection(byLevel: st.byLevel),
                    const SizedBox(height: 26),
                  ],
                  if (st.byProgram.isNotEmpty) ...[
                    AdminSectionTitle('Répartition par filière',
                        icon: Icons.workspaces_rounded,
                        subtitle:
                            '${st.byProgram.length} filière${st.byProgram.length > 1 ? 's' : ''} (lycée / formation pro.)'),
                    const SizedBox(height: 12),
                    _ProgramSection(byProgram: st.byProgram),
                    const SizedBox(height: 26),
                  ],
                  if (st.byClass.isNotEmpty) ...[
                    AdminSectionTitle('Effectifs par classe',
                        icon: Icons.meeting_room_rounded,
                        subtitle:
                            '${st.byClass.length} classe${st.byClass.length > 1 ? 's' : ''} · effectif et taux de remplissage'),
                    const SizedBox(height: 12),
                    _ClassSection(byClass: st.byClass),
                    const SizedBox(height: 26),
                  ],
                  if (st.evolution.length >= 2) ...[
                    const AdminSectionTitle('Évolution des inscriptions',
                        icon: Icons.show_chart_rounded),
                    const SizedBox(height: 12),
                    _EvolutionCard(points: st.evolution),
                    const SizedBox(height: 22),
                  ],
                  _FilterBar(
                    width: w - 48,
                    searchCtrl: _searchCtrl,
                    cycle: _cycle,
                    type: _type,
                    status: _status,
                    isTable: _isTable,
                    readOnly: readOnly,
                    cyclesPresent: cyclesPresent,
                    onSearch: (_) => setState(() {}),
                    onCycle: (v) => setState(() => _cycle = v),
                    onType: (v) => setState(() => _type = v),
                    onStatus: (v) => setState(() => _status = v),
                    onToggleView: () => setState(() => _isTable = !_isTable),
                    onReset: _resetFilters,
                    onAdd: _openAdd,
                    onExport: () => _export(filtered),
                  ),
                  const SizedBox(height: 16),
                  _ResultHeader(total: all.length, filtered: filtered.length),
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
    final tot = st.boys + st.girls;
    final cards = <Widget>[
      AdminStatCard(
        label: 'Total inscrits',
        value: '${st.total}',
        icon: Icons.groups_rounded,
        color: kNavy,
        subtitle: 'Dossiers vivants',
      ),
      AdminStatCard(
        label: 'Validées',
        value: '${st.active}',
        icon: Icons.verified_rounded,
        color: kGreen,
        subtitle: st.total > 0
            ? '${(st.active * 100 / st.total).round()} % du total'
            : '—',
      ),
      AdminStatCard(
        label: 'En attente',
        value: '${st.pending}',
        icon: Icons.hourglass_top_rounded,
        color: kAccent,
        subtitle: 'À valider',
      ),
      AdminStatCard(
        label: 'Filles',
        value: '${st.girls}',
        icon: Icons.female_rounded,
        color: _kPink,
        subtitle: tot > 0 ? '${(st.girls * 100 / tot).round()} % des effectifs' : '—',
      ),
      AdminStatCard(
        label: 'Garçons',
        value: '${st.boys}',
        icon: Icons.male_rounded,
        color: _kBlue,
        subtitle: tot > 0 ? '${(st.boys * 100 / tot).round()} % des effectifs' : '—',
      ),
      AdminStatCard(
        label: 'Redoublants',
        value: '${st.repeating}',
        icon: Icons.replay_rounded,
        color: kRed,
        subtitle: st.total > 0
            ? '${(st.repeating * 100 / st.total).round()} % des inscrits'
            : '—',
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

// ─── Section cycles ──────────────────────────────────────────────────────────
class _CycleSection extends StatelessWidget {
  const _CycleSection({required this.byCycle});
  final List<CycleCount> byCycle;

  @override
  Widget build(BuildContext context) {
    final maxTotal =
        byCycle.fold<int>(1, (m, c) => c.total > m ? c.total : m);
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final c in byCycle)
          SizedBox(
            width: 250,
            child: AdminCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _cycleColor(c.cycle.code).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.school_rounded,
                          size: 18, color: _cycleColor(c.cycle.code)),
                    ),
                    const Spacer(),
                    Text('${c.total}',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _cycleColor(c.cycle.code))),
                  ]),
                  const SizedBox(height: 10),
                  Text(c.cycle.label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (c.total / maxTotal).clamp(0.04, 1),
                      minHeight: 6,
                      backgroundColor:
                          _cycleColor(c.cycle.code).withValues(alpha: 0.10),
                      valueColor:
                          AlwaysStoppedAnimation(_cycleColor(c.cycle.code)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    AdminBadge('${c.girls} filles', color: _kPink),
                    const SizedBox(width: 6),
                    AdminBadge('${c.boys} garçons', color: kNavy),
                  ]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Section niveaux (6e, 5e, 4e…) ───────────────────────────────────────────
class _LevelSection extends StatelessWidget {
  const _LevelSection({required this.byLevel});
  final List<LevelCount> byLevel;

  @override
  Widget build(BuildContext context) {
    final maxTotal = byLevel.fold<int>(1, (m, l) => l.total > m ? l.total : m);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final l in byLevel)
          SizedBox(
              width: 152,
              child: _LevelMini(level: l, ratio: l.total / maxTotal)),
      ],
    );
  }
}

class _LevelMini extends StatelessWidget {
  const _LevelMini({required this.level, required this.ratio});
  final LevelCount level;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final color = _cycleColor(level.cycleCode);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(level.code,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
          ),
          const Spacer(),
          Text('${level.total}',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.05, 1),
            minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.female_rounded, size: 13, color: _kPink),
          const SizedBox(width: 2),
          Text('${level.girls}',
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: _kPink)),
          const SizedBox(width: 10),
          const Icon(Icons.male_rounded, size: 13, color: _kBlue),
          const SizedBox(width: 2),
          Text('${level.boys}',
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: _kBlue)),
        ]),
      ]),
    );
  }
}

// ─── Section filières (lycée / FP — accent doré) ─────────────────────────────
class _ProgramSection extends StatelessWidget {
  const _ProgramSection({required this.byProgram});
  final List<ProgramCount> byProgram;

  @override
  Widget build(BuildContext context) {
    final maxTotal = byProgram.fold<int>(1, (m, p) => p.total > m ? p.total : m);
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final p in byProgram)
          SizedBox(
            width: 250,
            child: AdminCard(
              padding: const EdgeInsets.all(16),
              accent: kAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.workspaces_rounded,
                          size: 18, color: Color(0xFFB8860B)),
                    ),
                    const Spacer(),
                    Text('${p.total}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB8860B))),
                  ]),
                  const SizedBox(height: 10),
                  Text(p.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (p.total / maxTotal).clamp(0.04, 1),
                      minHeight: 6,
                      backgroundColor: kAccent.withValues(alpha: 0.14),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFB8860B)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    AdminBadge('${p.girls} filles', color: _kPink),
                    const SizedBox(width: 6),
                    AdminBadge('${p.boys} garçons', color: kNavy),
                  ]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Section classes (effectif + taux de remplissage) ────────────────────────
class _ClassSection extends StatelessWidget {
  const _ClassSection({required this.byClass});
  final List<ClassCount> byClass;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in byClass)
          SizedBox(width: 218, child: _ClassMini(c: c)),
      ],
    );
  }
}

class _ClassMini extends StatelessWidget {
  const _ClassMini({required this.c});
  final ClassCount c;

  @override
  Widget build(BuildContext context) {
    final color = _cycleColor(c.cycleCode);
    final hasCap = c.capacity > 0;
    final fill = c.fillRatio.clamp(0.0, 1.0);
    final over = c.fillRatio > 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.meeting_room_rounded, size: 16, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
          Text('${c.total}',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: hasCap ? fill : 0.04,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation(over ? kRed : color),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          if (hasCap)
            Text('${c.total}/${c.capacity} places',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: over ? kRed : kTextMuted))
          else
            const Text('Capacité non définie',
                style: TextStyle(fontSize: 11, color: kTextMuted)),
          const Spacer(),
          const Icon(Icons.female_rounded, size: 12, color: _kPink),
          const SizedBox(width: 2),
          Text('${c.girls}',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _kPink)),
          const SizedBox(width: 8),
          const Icon(Icons.male_rounded, size: 12, color: _kBlue),
          const SizedBox(width: 2),
          Text('${c.boys}',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _kBlue)),
        ]),
      ]),
    );
  }
}

// ─── Évolution ───────────────────────────────────────────────────────────────
class _EvolutionCard extends StatelessWidget {
  const _EvolutionCard({required this.points});
  final List<(String, int)> points;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 8),
      child: SizedBox(
        height: 230,
        child: SfCartesianChart(
          margin: EdgeInsets.zero,
          primaryXAxis: const CategoryAxis(
            majorGridLines: MajorGridLines(width: 0),
            labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
          ),
          primaryYAxis: const NumericAxis(
            axisLine: AxisLine(width: 0),
            majorTickLines: MajorTickLines(size: 0),
            labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries<(String, int), String>>[
            SplineAreaSeries<(String, int), String>(
              dataSource: points,
              xValueMapper: (p, _) => p.$1,
              yValueMapper: (p, _) => p.$2,
              borderColor: kGreen,
              borderWidth: 2.5,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kGreen.withValues(alpha: 0.28),
                  kGreen.withValues(alpha: 0.02),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Barre de filtres (style plateforme) ─────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.width,
    required this.searchCtrl,
    required this.cycle,
    required this.type,
    required this.status,
    required this.isTable,
    required this.readOnly,
    required this.cyclesPresent,
    required this.onSearch,
    required this.onCycle,
    required this.onType,
    required this.onStatus,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
    required this.onExport,
  });
  final double width;
  final TextEditingController searchCtrl;
  final String? cycle, type;
  final String status;
  final bool isTable, readOnly;
  final Map<String, String> cyclesPresent;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCycle, onType;
  final ValueChanged<String> onStatus;
  final VoidCallback onToggleView, onReset, onAdd, onExport;

  bool get _hasFilters => cycle != null || type != null || status != 'all';

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
                hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: kTextMuted, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
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
        Row(children: [
          _FilterDropdown<String?>(
            icon: Icons.account_tree_outlined,
            value: cycle,
            active: cycle != null,
            items: [
              const DropdownMenuItem(value: null, child: Text('Tous les cycles')),
              for (final e in cyclesPresent.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: onCycle,
          ),
          const SizedBox(width: 8),
          _FilterDropdown<String?>(
            icon: Icons.category_outlined,
            value: type,
            active: type != null,
            items: const [
              DropdownMenuItem(value: null, child: Text('Tous les types')),
              DropdownMenuItem(value: 'new', child: Text('Nouvelles')),
              DropdownMenuItem(value: 'reinscription', child: Text('Réinscriptions')),
              DropdownMenuItem(value: 'transfer', child: Text('Transferts')),
            ],
            onChanged: onType,
          ),
          const SizedBox(width: 8),
          _StatusSegment(value: status, onChanged: onStatus),
          const Spacer(),
          if (_hasFilters)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onReset,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: kRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kRed.withValues(alpha: 0.25)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.filter_alt_off_rounded, size: 13, color: kRed),
                    SizedBox(width: 4),
                    Text('Réinitialiser',
                        style: TextStyle(
                            color: kRed, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
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
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_clock_rounded, size: 15, color: kAccent),
          SizedBox(width: 6),
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
              gradient: const LinearGradient(
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
        seg('active', 'Validées'),
        seg('pending_validation', 'En attente'),
        seg('rejected', 'Rejetées'),
      ]),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;
  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$filtered inscrit${filtered > 1 ? 's' : ''}',
            style: const TextStyle(
                color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        if (filtered < total) ...[
          const SizedBox(width: 8),
          Text('sur $total',
              style: const TextStyle(color: kTextMuted, fontSize: 13)),
        ],
      ]);
}
