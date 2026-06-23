import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../data/models/class_model.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../widgets/inscription_form_kit.dart';
import '../providers/inscriptions_data_provider.dart';
import '../providers/students_provider.dart';
import '../providers/student_documents_provider.dart';
import '../providers/student_tutors_provider.dart';
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
  String? _cycle;
  String? _filiere;
  String? _type;
  String _status = 'all'; // all | active | pending_validation | rejected
  bool _isTable = true;
  _SortBy _sort = _SortBy.nom;
  bool _sortAsc = true;
  String _dim = 'niveau'; // dimension de la répartition : cycle|niveau|filiere
  final Set<String> _selected = {}; // ids d'inscriptions sélectionnées (actions groupées)

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<InscriptionRow> _apply(List<InscriptionRow> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final out = all.where((r) {
      if (_cycle != null && r.cycle.code != _cycle) return false;
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
        _cycle = _filiere = _type = null;
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

  // Tiroir latéral droit (Classe / Filière) — protège la hauteur de la page
  // principale quand ces répartitions deviennent nombreuses (école technique).
  void _openBreakdownDrawer(String dim, {String? levelCode}) => showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fermer',
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => Align(
          alignment: Alignment.centerRight,
          child: _BreakdownDrawer(dim: dim, levelCode: levelCode),
        ),
        transitionBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
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
                  const Icon(Icons.meeting_room_outlined,
                      size: 18, color: kNavy),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.name)),
                  Text('${c.studentCount ?? 0}'
                      '${c.capacity != null ? '/${c.capacity}' : ''}',
                      style: const TextStyle(
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
          child: Text('Erreur : $e', style: const TextStyle(color: kRed)),
        ),
      ),
      data: (all) {
        final st = ref.watch(inscriptionStatsProvider);
        final filtered = _apply(all);
        final cyclesPresent = <String, String>{
          for (final r in all) r.cycle.code: r.cycle.label,
        };
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
                  _BreakdownCard(
                    st: st,
                    dim: _dim,
                    classCountByLevel: {
                      for (final c in st.byClass)
                        (c.levelCode ?? '—'):
                            (st.byClass.where((x) => x.levelCode == c.levelCode).length),
                    },
                    onDim: (d) {
                      setState(() => _dim = d);
                      // Filière (potentiellement nombreuse) → tiroir droit.
                      if (d == 'filiere') _openBreakdownDrawer('filiere');
                    },
                    onOpenDrawer: _openBreakdownDrawer,
                    onOpenLevel: (code) =>
                        _openBreakdownDrawer('classe', levelCode: code),
                  ),
                  const SizedBox(height: 26),
                  if (st.evolution.length >= 2) ...[
                    const AdminSectionTitle('Rythme des inscriptions',
                        icon: Icons.show_chart_rounded,
                        subtitle:
                            'Nouvelles inscriptions par mois (barres) et effectif cumulé (courbe)'),
                    const SizedBox(height: 12),
                    _EvolutionCard(points: st.evolution),
                    const SizedBox(height: 22),
                  ],
                  _FilterBar(
                    width: w - 48,
                    searchCtrl: _searchCtrl,
                    cycle: _cycle,
                    filiere: _filiere,
                    type: _type,
                    status: _status,
                    isTable: _isTable,
                    readOnly: readOnly,
                    cyclesPresent: cyclesPresent,
                    filieresPresent: filieresPresent,
                    onSearch: (_) => setState(() {}),
                    onCycle: (v) => setState(() => _cycle = v),
                    onFiliere: (v) => setState(() => _filiere = v),
                    onType: (v) => setState(() => _type = v),
                    onStatus: (v) => setState(() => _status = v),
                    onToggleView: () => setState(() => _isTable = !_isTable),
                    onReset: _resetFilters,
                    onAdd: _openAdd,
                    onExport: () => _export(filtered),
                  ),
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
        label: 'Taux de remplissage',
        value: st.capacityTotal > 0
            ? '${(st.fillRatio * 100).round()} %'
            : '—',
        icon: Icons.donut_large_rounded,
        color: const Color(0xFF7C3AED),
        subtitle: st.capacityTotal > 0
            ? '${st.total} / ${st.capacityTotal} places'
            : 'Capacités non définies',
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

// ─── Carte « Répartition des effectifs » (1 seule, dimension au choix) ───────
// Au lieu d'empiler 4 grilles identiques (cycle/niveau/classe/filière) — qui
// rendaient la distinction illisible — une SEULE carte avec un sélecteur de
// dimension. C'est la MÊME donnée vue à des granularités différentes :
//   Cycle ⊃ Niveau ⊃ Classe   (la filière = spécialité du lycée/FP).
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard(
      {required this.st,
      required this.dim,
      required this.onDim,
      required this.onOpenDrawer,
      required this.onOpenLevel,
      required this.classCountByLevel});
  final InscriptionStats st;
  final String dim;
  final ValueChanged<String> onDim;
  final ValueChanged<String> onOpenDrawer;   // filiere → tiroir
  final ValueChanged<String> onOpenLevel;    // niveau → tiroir des classes du niveau
  final Map<String, int> classCountByLevel;

  static const _help = <String, String>{
    'cycle':
        'Grands ensembles pédagogiques de l\'école (préscolaire, primaire, collège, lycée, formation pro.).',
    'niveau':
        'Le niveau = l\'année d\'études (6ᵉ, CP1, Tle…). Cliquez un niveau pour voir ses classes (sections : 6ᵉ A, 6ᵉ B…).',
    'filiere':
        'Spécialités du lycée / formation professionnelle (séries, métiers).',
  };

  @override
  Widget build(BuildContext context) {
    final hasFiliere = st.byProgram.isNotEmpty;
    // dimension effective (garde-fous : classe n'est plus une dimension à part
    // — c'est le détail d'un niveau ; filière masquée si aucune).
    final d = dim == 'classe'
        ? 'niveau'
        : (dim == 'filiere' && !hasFiliere)
            ? 'cycle'
            : dim;

    Widget content() {
      switch (d) {
        case 'niveau':
          return st.byLevel.isEmpty
              ? const _BreakdownEmpty(
                  'Aucun niveau défini',
                  'Les niveaux apparaîtront dès qu\'une classe sera rattachée à un niveau.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LevelSection(
                      byLevel: st.byLevel,
                      classCountByLevel: classCountByLevel,
                      onOpenLevel: onOpenLevel,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _TextLink(
                        label:
                            'Voir toutes les classes (${st.byClass.length}) →',
                        onTap: () => onOpenDrawer('classe'),
                      ),
                    ),
                  ],
                );
        case 'filiere':
          return _BreakdownSummary(
              dim: 'filiere', st: st, onOpen: () => onOpenDrawer('filiere'));
        default:
          return st.byCycle.isEmpty
              ? const _BreakdownEmpty('Aucun cycle',
                  'Les cycles apparaissent dès qu\'une classe existe pour l\'école.')
              : _CycleSection(byCycle: st.byCycle);
      }
    }

    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 720;
            const title = Row(children: [
              Icon(Icons.insights_rounded, size: 20, color: kNavy),
              SizedBox(width: 8),
              Text('Répartition des effectifs',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ]);
            final toggle = _DimToggle(
              dim: d,
              hasFiliere: hasFiliere,
              counts: {
                'cycle': st.byCycle.length,
                'niveau': st.byLevel.length,
                'filiere': st.byProgram.length,
              },
              onDim: onDim,
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal, child: toggle),
                ],
              );
            }
            return Row(children: [
              const Expanded(child: title),
              toggle,
            ]);
          }),
          const SizedBox(height: 10),
          Text(_help[d] ?? '',
              style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
          const SizedBox(height: 18),
          content(),
        ],
      ),
    );
  }
}

class _BreakdownEmpty extends StatelessWidget {
  const _BreakdownEmpty(this.title, this.message);
  final String title, message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          const Icon(Icons.inbox_rounded, size: 30, color: kTextMuted),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Text(label,
              style: const TextStyle(
                  color: kNavy, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      );
}

// Résumé compact (Filière) affiché dans la carte ; le détail complet
// s'ouvre dans le tiroir droit (via onOpen).
class _BreakdownSummary extends StatelessWidget {
  const _BreakdownSummary(
      {required this.dim, required this.st, required this.onOpen});
  final String dim;
  final InscriptionStats st;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isClasse = dim == 'classe';
    final count = isClasse ? st.byClass.length : st.byProgram.length;
    final inscrits = (isClasse ? st.byClass : st.byProgram)
        .fold<int>(0, (s, e) => s + (e is ClassCount ? e.total : (e as ProgramCount).total));
    final nbNiveaux =
        st.byClass.map((c) => c.levelCode ?? '—').toSet().length;

    final chips = <(IconData, String)>[
      (isClasse ? Icons.meeting_room_rounded : Icons.workspaces_rounded,
          '$count ${isClasse ? (count > 1 ? 'classes' : 'classe') : (count > 1 ? 'filières' : 'filière')}'),
      if (isClasse) (Icons.layers_rounded, '$nbNiveaux niveau${nbNiveaux > 1 ? 'x' : ''}'),
      (Icons.groups_rounded, '$inscrits inscrit${inscrits > 1 ? 's' : ''}'),
      if (isClasse && st.capacityTotal > 0)
        (Icons.donut_large_rounded, '${(st.fillRatio * 100).round()} % remplissage'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              for (final ch in chips)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(ch.$1, size: 16, color: kNavy),
                  const SizedBox(width: 6),
                  Text(ch.$2,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                ]),
            ],
          ),
        ),
        const SizedBox(width: 14),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onOpen,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kNavyDark, kNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Voir le détail',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// Tiroir latéral droit : détail complet d'une répartition (classe / filière),
// scrollable + recherche. Live (watch du provider).
class _BreakdownDrawer extends ConsumerStatefulWidget {
  const _BreakdownDrawer({required this.dim, this.levelCode});
  final String dim;
  final String? levelCode; // si fourni : classes d'un seul niveau (drill-down)
  @override
  ConsumerState<_BreakdownDrawer> createState() => _BreakdownDrawerState();
}

class _BreakdownDrawerState extends ConsumerState<_BreakdownDrawer> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isClasse = widget.dim == 'classe';
    final lvl = widget.levelCode;
    final st = ref.watch(inscriptionStatsProvider);
    final screenW = MediaQuery.of(context).size.width;
    // Plus large pour bien voir les effectifs (3–4 colonnes de cartes).
    final width = (screenW * 0.5).clamp(420.0, 920.0);

    final byClass = isClasse
        ? st.byClass
            .where((c) =>
                (lvl == null || c.levelCode == lvl) &&
                c.name.toLowerCase().contains(_q.toLowerCase()))
            .toList()
        : const <ClassCount>[];
    final byProgram = !isClasse
        ? st.byProgram
            .where((p) => p.label.toLowerCase().contains(_q.toLowerCase()))
            .toList()
        : const <ProgramCount>[];
    final total = isClasse
        ? (lvl == null
            ? st.byClass.length
            : st.byClass.where((c) => c.levelCode == lvl).length)
        : st.byProgram.length;
    final shown = isClasse ? byClass.length : byProgram.length;
    final headerTitle = !isClasse
        ? 'Effectifs par filière'
        : (lvl == null ? 'Effectifs par classe' : 'Classes du niveau $lvl');
    final headerSub = !isClasse
        ? '$total filière${total > 1 ? 's' : ''} (séries, métiers)'
        : (lvl == null
            ? '$total classe${total > 1 ? 's' : ''} · groupées par niveau'
            : '$total section${total > 1 ? 's' : ''} du niveau $lvl');

    return Material(
      color: kCardBg,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête (style plateforme léger : blanc + accent navy)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: const BoxDecoration(
                  color: kCardBg,
                  border: Border(bottom: BorderSide(color: kBorder)),
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kNavy.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                        isClasse
                            ? Icons.meeting_room_rounded
                            : Icons.workspaces_rounded,
                        color: kNavy,
                        size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(headerTitle,
                            style: const TextStyle(
                                color: kTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        Text(headerSub,
                            style: const TextStyle(
                                color: kTextMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  AdminModalIconBtn(
                    icon: Icons.close_rounded,
                    color: kTextMuted,
                    tooltip: 'Fermer',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ]),
              ),
              // Recherche
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: isClasse
                        ? 'Rechercher une classe…'
                        : 'Rechercher une filière…',
                    hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: kTextMuted, size: 20),
                    suffixIcon: _q.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: kTextMuted),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _q = '');
                            })
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
              if (_q.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('$shown résultat${shown > 1 ? 's' : ''} sur $total',
                        style: const TextStyle(fontSize: 12, color: kTextMuted)),
                  ),
                ),
              // Contenu
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: (isClasse ? byClass.isEmpty : byProgram.isEmpty)
                      ? const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: _BreakdownEmpty(
                              'Aucun résultat', 'Ajustez la recherche.'),
                        )
                      : isClasse
                          ? _ClassSection(byClass: byClass)
                          : _ProgramSection(byProgram: byProgram),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DimToggle extends StatelessWidget {
  const _DimToggle({
    required this.dim,
    required this.hasFiliere,
    required this.counts,
    required this.onDim,
  });
  final String dim;
  final bool hasFiliere;
  final Map<String, int> counts;
  final ValueChanged<String> onDim;

  @override
  Widget build(BuildContext context) {
    Widget seg(String key, IconData icon, String label) {
      final sel = dim == key;
      final n = counts[key] ?? 0;
      return GestureDetector(
        onTap: () => onDim(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: sel ? Colors.white : kTextMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : kTextMuted)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: sel
                    ? Colors.white.withValues(alpha: 0.22)
                    : kTextMuted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$n',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : kTextMuted)),
            ),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('cycle', Icons.account_tree_rounded, 'Cycle'),
        seg('niveau', Icons.layers_rounded, 'Niveau'),
        if (hasFiliere) seg('filiere', Icons.workspaces_rounded, 'Filière'),
      ]),
    );
  }
}

// ─── Grille de répartition (même taille que les KPI généraux) ────────────────
// Palette de couleurs distinctes : chaque niveau / classe / filière reçoit sa
// propre couleur (index → couleur), pour les différencier d'un coup d'œil.
const _distribPalette = <Color>[
  Color(0xFF1E3A5F), // navy
  Color(0xFF009A44), // vert
  Color(0xFF0EA5E9), // bleu ciel
  Color(0xFFEC4899), // rose
  Color(0xFFB8860B), // or
  Color(0xFF7C3AED), // violet
  Color(0xFF0D9488), // sarcelle
  Color(0xFFEA580C), // orange
  Color(0xFF4F46E5), // indigo
  Color(0xFF65A30D), // lime
  Color(0xFFDB2777), // magenta
  Color(0xFF0891B2), // cyan
];
Color _distribColor(int i) => _distribPalette[i % _distribPalette.length];

/// Grille responsive identique à celle des KPI généraux (1→6 colonnes,
/// hauteur fixe 168) : toutes les cartes de répartition ont la MÊME taille.
class _DistribGrid extends StatelessWidget {
  const _DistribGrid({required this.cards});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
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

/// Carte de répartition unifiée (cycle / niveau / classe / filière) — même
/// gabarit que `AdminStatCard`, couleur propre, barre de progression + filles/
/// garçons. `infoLabel` = ligne de contexte (% du total ou « X/Y places »).
class _DistribCard extends StatelessWidget {
  const _DistribCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.title,
    required this.girls,
    required this.boys,
    required this.ratio,
    this.infoLabel,
    this.over = false,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final int value, girls, boys;
  final String title;
  final double ratio;
  final String? infoLabel;
  final bool over;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final barColor = over ? kRed : color;
    return AdminCard(
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const Spacer(),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.chevron_right_rounded,
                    size: 18, color: Colors.grey.shade400),
              ),
            Text('$value',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 12),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.04, 1),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            if (infoLabel != null)
              Flexible(
                child: Text(infoLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: over ? kRed : kTextMuted)),
              ),
            const Spacer(),
            const Icon(Icons.female_rounded, size: 13, color: _kPink),
            const SizedBox(width: 2),
            Text('$girls',
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: _kPink)),
            const SizedBox(width: 9),
            const Icon(Icons.male_rounded, size: 13, color: _kBlue),
            const SizedBox(width: 2),
            Text('$boys',
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: _kBlue)),
          ]),
        ],
      ),
    );
  }
}

String _pctLabel(int part, int whole) =>
    whole > 0 ? '${(part * 100 / whole).round()} % du total' : '—';

// ─── Section cycles (couleur sémantique par cycle) ───────────────────────────
class _CycleSection extends StatelessWidget {
  const _CycleSection({required this.byCycle});
  final List<CycleCount> byCycle;

  @override
  Widget build(BuildContext context) {
    final grand = byCycle.fold<int>(0, (s, c) => s + c.total);
    return _DistribGrid(cards: [
      for (final c in byCycle)
        _DistribCard(
          icon: Icons.school_rounded,
          color: _cycleColor(c.cycle.code),
          value: c.total,
          title: c.cycle.label,
          girls: c.girls,
          boys: c.boys,
          ratio: grand > 0 ? c.total / grand : 0,
          infoLabel: _pctLabel(c.total, grand),
        ),
    ]);
  }
}

// ─── Section niveaux (6e, 5e, 4e… — couleur distincte par niveau) ────────────
class _LevelSection extends StatelessWidget {
  const _LevelSection({
    required this.byLevel,
    required this.classCountByLevel,
    required this.onOpenLevel,
  });
  final List<LevelCount> byLevel;
  final Map<String, int> classCountByLevel; // code niveau → nb classes
  final ValueChanged<String> onOpenLevel;

  @override
  Widget build(BuildContext context) {
    final grand = byLevel.fold<int>(0, (s, l) => s + l.total);
    return _DistribGrid(cards: [
      for (var i = 0; i < byLevel.length; i++)
        () {
          final l = byLevel[i];
          final nbClasses = classCountByLevel[l.code] ?? 0;
          return _DistribCard(
            icon: Icons.layers_rounded,
            color: _distribColor(i),
            value: l.total,
            title: l.code,
            girls: l.girls,
            boys: l.boys,
            ratio: grand > 0 ? l.total / grand : 0,
            infoLabel: '$nbClasses classe${nbClasses > 1 ? 's' : ''}',
            onTap: nbClasses > 0 ? () => onOpenLevel(l.code) : null,
          );
        }(),
    ]);
  }
}

// ─── Section filières (lycée / FP — couleur distincte par filière) ───────────
class _ProgramSection extends StatelessWidget {
  const _ProgramSection({required this.byProgram});
  final List<ProgramCount> byProgram;

  @override
  Widget build(BuildContext context) {
    final grand = byProgram.fold<int>(0, (s, p) => s + p.total);
    return _DistribGrid(cards: [
      for (var i = 0; i < byProgram.length; i++)
        _DistribCard(
          icon: Icons.workspaces_rounded,
          // décalage de teinte pour distinguer des niveaux
          color: _distribColor(i + 4),
          value: byProgram[i].total,
          title: byProgram[i].label,
          girls: byProgram[i].girls,
          boys: byProgram[i].boys,
          ratio: grand > 0 ? byProgram[i].total / grand : 0,
          infoLabel: _pctLabel(byProgram[i].total, grand),
        ),
    ]);
  }
}

// ─── Section classes (couleur distincte par classe + taux de remplissage) ────
// Vue « Classe » GROUPÉE PAR NIVEAU : un en-tête de niveau (6ᵉ, CP1…) puis ses
// classes. Rend explicite la hiérarchie Niveau ⊃ Classes (lève la confusion
// niveau/classe). Toutes les classes d'un même niveau partagent sa couleur.
class _ClassGroup {
  _ClassGroup(this.levelCode, this.cycleCode);
  final String levelCode, cycleCode;
  final List<ClassCount> items = [];
  int get total => items.fold(0, (s, c) => s + c.total);
  int get capacity => items.fold(0, (s, c) => s + c.capacity);
}

class _ClassSection extends StatelessWidget {
  const _ClassSection({required this.byClass});
  final List<ClassCount> byClass;

  @override
  Widget build(BuildContext context) {
    final groups = <_ClassGroup>[];
    for (final c in byClass) {
      final key = c.levelCode ?? '—';
      if (groups.isEmpty || groups.last.levelCode != key) {
        groups.add(_ClassGroup(key, c.cycleCode));
      }
      groups.last.items.add(c);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var g = 0; g < groups.length; g++) ...[
          if (g > 0) const SizedBox(height: 20),
          _LevelGroupHeader(group: groups[g], color: _distribColor(g)),
          const SizedBox(height: 10),
          _DistribGrid(cards: [
            for (final c in groups[g].items)
              _DistribCard(
                icon: Icons.meeting_room_rounded,
                color: _distribColor(g),
                value: c.total,
                title: c.name,
                girls: c.girls,
                boys: c.boys,
                ratio: c.capacity > 0 ? c.fillRatio : 0,
                over: c.fillRatio > 1,
                infoLabel: c.capacity > 0
                    ? '${c.total}/${c.capacity} places'
                    : 'Capacité non définie',
              ),
          ]),
        ],
      ],
    );
  }
}

class _LevelGroupHeader extends StatelessWidget {
  const _LevelGroupHeader({required this.group, required this.color});
  final _ClassGroup group;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final n = group.items.length;
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          group.levelCode == '—' ? 'Sans niveau' : 'Niveau ${group.levelCode}',
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
        ),
      ),
      const SizedBox(width: 10),
      Text('$n classe${n > 1 ? 's' : ''}',
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextMuted)),
      const SizedBox(width: 6),
      const Text('·', style: TextStyle(color: kTextMuted)),
      const SizedBox(width: 6),
      Text('${group.total} inscrit${group.total > 1 ? 's' : ''}',
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextMuted)),
      const Spacer(),
      if (group.capacity > 0)
        Text('${group.total}/${group.capacity} places',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: group.total > group.capacity ? kRed : kTextMuted)),
    ]);
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
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 6),
            child: Row(children: [
              _LegendDot(color: kNavy, label: 'Inscriptions du mois'),
              SizedBox(width: 16),
              _LegendDot(color: kGreen, label: 'Effectif cumulé', line: true),
            ]),
          ),
          SizedBox(
            height: 220,
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
              axes: const <ChartAxis>[
                NumericAxis(
                  name: 'cumul',
                  opposedPosition: true,
                  axisLine: AxisLine(width: 0),
                  majorGridLines: MajorGridLines(width: 0),
                  majorTickLines: MajorTickLines(size: 0),
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
            style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: kTextMuted)),
      ]);
}

// ─── Barre de filtres (style plateforme) ─────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.width,
    required this.searchCtrl,
    required this.cycle,
    required this.filiere,
    required this.type,
    required this.status,
    required this.isTable,
    required this.readOnly,
    required this.cyclesPresent,
    required this.filieresPresent,
    required this.onSearch,
    required this.onCycle,
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
  final String? cycle, filiere, type;
  final String status;
  final bool isTable, readOnly;
  final Map<String, String> cyclesPresent;
  final List<String> filieresPresent;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCycle, onFiliere, onType;
  final ValueChanged<String> onStatus;
  final VoidCallback onToggleView, onReset, onAdd, onExport;

  bool get _hasFilters =>
      cycle != null || filiere != null || type != null || status != 'all';

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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
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
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.filter_alt_off_rounded, size: 13, color: kRed),
                      SizedBox(width: 4),
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
