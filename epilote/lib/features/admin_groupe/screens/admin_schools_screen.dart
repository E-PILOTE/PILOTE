import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/media_compression.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_regional_provider.dart' show adminProjectServiceProvider;
import '../providers/admin_schools_provider.dart';
import '../providers/admin_users_provider.dart' show roleLabel;
import '../providers/school_geocoder_provider.dart';
import '../providers/subscription_access_provider.dart';
import '../providers/education_provider.dart';
import '../providers/institution_types_provider.dart';
import '../providers/structure_modeles.dart';
// Reconnaître qu'un niveau créé ici double une entrée nationale : « 6ème » et
// « Sixième (6e) » ne se ressemblent pas mais désignent la même année.
import '../services/rang_niveau.dart';
import '../widgets/school_location_picker.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/constants/tutelle.dart';

part 'schools/schools_kpi.dart';
part 'schools/schools_filters.dart';
part 'schools/schools_views.dart';
part 'schools/school_detail_dialog.dart';
part 'schools/school_detail_tabs.dart';
part 'schools/school_form_dialog.dart';
part 'schools/school_locality_field.dart';
part 'schools/school_contact_section.dart';
part 'schools/school_education_section.dart';
part 'schools/school_form_widgets.dart';
part 'schools/school_institution_type_field.dart';

// ─── Couleurs locales (complètent admin_ui.dart) ─────────────────────────────
const _kPurple = Color(0xFF7C3AED);
const _kBlue   = Color(0xFF0EA5E9);
const _kOrange = Color(0xFFFF6B35);
Color get _kGold => kAccent;

// 15 départements — réforme territoriale du 8 octobre 2024
const _kDepartements = [
  'Bouenza', 'Brazzaville', 'Congo-Oubangui', 'Cuvette', 'Cuvette-Ouest',
  'Djoué-Léfini', 'Kouilou', 'Lékoumou', 'Likouala', 'Niari',
  'Nkéni-Alima', 'Plateaux', 'Pointe-Noire', 'Pool', 'Sangha',
];

// ─── Avatar école (logo si présent, sinon icône) ─────────────────────────────
class _SchoolAvatar extends StatelessWidget {
  _SchoolAvatar({
    required this.logoUrl,
    this.size = 46,
    this.radius = 11,
    Color? iconColor,
    this.iconSize,
  }) : iconColor = iconColor ?? kNavy;
  final String? logoUrl;
  final double  size;
  final double  radius;
  final Color   iconColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.startsWith('http');
    final icon = Icon(Icons.account_balance_rounded,
        color: iconColor, size: iconSize ?? size * 0.43);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: logoUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => Center(child: icon),
              errorWidget: (_, _, _) => Center(child: icon),
            )
          : Center(child: icon),
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminSchoolsScreen extends ConsumerWidget {
  const AdminSchoolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Mes Écoles',
      child: ref.watch(adminSchoolsProvider).when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const _ShimmerSkeleton(),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: kTextMuted),
            const SizedBox(height: 12),
            Text(messageErreur(e), style: TextStyle(color: kTextMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(adminSchoolsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (d) => _SchoolsBody(data: d),
      ),
    );
  }
}

// ─── Body (état filtres + tri + vue) ─────────────────────────────────────────

class _SchoolsBody extends ConsumerStatefulWidget {
  const _SchoolsBody({required this.data});
  final AdminSchoolsData data;

  @override
  ConsumerState<_SchoolsBody> createState() => _SchoolsBodyState();
}

class _SchoolsBodyState extends ConsumerState<_SchoolsBody> {
  final _searchCtrl  = TextEditingController();
  String _filterType   = 'tous';
  String _filterStatus = 'tous';
  String _filterDept   = 'tous';
  bool   _isTableView  = true;
  String _sortField    = 'name';
  bool   _sortAsc      = true;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SchoolDetail> _applyFilters(List<SchoolDetail> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return all.where((s) {
      if (q.isNotEmpty) {
        final ok = s.name.toLowerCase().contains(q)
            || (s.code?.toLowerCase().contains(q) ?? false)
            || (s.city?.toLowerCase().contains(q) ?? false)
            || (s.department?.toLowerCase().contains(q) ?? false);
        if (!ok) return false;
      }
      if (_filterType   != 'tous' && s.type != _filterType) return false;
      if (_filterStatus == 'active'   && !s.isActive) return false;
      if (_filterStatus == 'inactive' &&  s.isActive) return false;
      if (_filterDept   != 'tous' && (s.department ?? '') != _filterDept) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        int c;
        switch (_sortField) {
          case 'students': c = a.students.compareTo(b.students); break;
          case 'staff':    c = a.staff.compareTo(b.staff);       break;
          case 'classes':  c = a.classes.compareTo(b.classes);   break;
          case 'dept':     c = (a.department ?? '').compareTo(b.department ?? ''); break;
          default:         c = a.name.compareTo(b.name);
        }
        return _sortAsc ? c : -c;
      });
  }

  void _openCreate() {
    if (!ensureSubscriptionWritable(ref, context)) return;
    final d = widget.data;
    if (d.quotaReached) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kRed,
        content: Text('Quota atteint : plan ${d.planName} limité à ${d.maxSchools} école(s).'),
      ));
      return;
    }
    showDialog(context: context, builder: (_) => const SchoolFormDialog());
  }

  void _openEdit(SchoolDetail s) =>
      showDialog(context: context, builder: (_) => SchoolFormDialog(school: s));

  void _openDetail(SchoolDetail s) => showDialog(
        context: context,
        builder: (_) => _SchoolDetailModal(
          school: s,
          onEdit: () { Navigator.of(context).pop(); _openEdit(s); },
          onToggle: () { Navigator.of(context).pop(); _toggleActive(s); },
        ),
      );

  Future<void> _toggleActive(SchoolDetail s) async {
    try {
      await ref.read(adminSchoolsServiceProvider).setActive(s.id, !s.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(s.isActive ? 'École désactivée' : 'École activée'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text(messageErreur(e))));
      }
    }
  }

  Future<void> _bulkSetActive(List<SchoolDetail> selected, bool active) async {
    final ids = selected.where((s) => s.isActive != active).map((s) => s.id).toList();
    if (ids.isEmpty) {
      setState(_selectedIds.clear);
      return;
    }
    try {
      await ref.read(adminSchoolsServiceProvider).setActiveBulk(ids, active);
      if (mounted) {
        setState(_selectedIds.clear);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(
              '${ids.length} école(s) ${active ? 'activée(s)' : 'désactivée(s)'}'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text(messageErreur(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data        = widget.data;
    final filtered    = _applyFilters(data.schools);
    final selected    = filtered.where((s) => _selectedIds.contains(s.id)).toList();
    final allSelected = filtered.isNotEmpty && selected.length == filtered.length;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminSchoolsProvider.future),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final double w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(ctx).size.width - 80;

        return SingleChildScrollView(
          child: SizedBox(
            width: w,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── KPIs ─────────────────────────────────────────────────────
                _KpiGrid(data: data),
                const SizedBox(height: 20),
                // ── Filtres ──────────────────────────────────────────────────
                _FilterBar(
                  contentWidth:   w - 48,
                  searchCtrl:     _searchCtrl,
                  filterType:     _filterType,
                  filterStatus:   _filterStatus,
                  filterDept:     _filterDept,
                  isTableView:    _isTableView,
                  quotaReached:   data.quotaReached,
                  onSearchChange: (_) => setState(() {}),
                  onType:         (v) => setState(() => _filterType   = v),
                  onStatus:       (v) => setState(() => _filterStatus = v),
                  onDept:         (v) => setState(() => _filterDept   = v),
                  onToggleView:   ()  => setState(() {
                    _isTableView = !_isTableView;
                    _selectedIds.clear();
                  }),
                  onReset: () => setState(() {
                    _searchCtrl.clear();
                    _filterType = _filterStatus = _filterDept = 'tous';
                  }),
                  onAdd: _openCreate,
                ),
                const SizedBox(height: 16),
                // ── Résultat ─────────────────────────────────────────────────
                _ResultHeader(total: data.schools.length, filtered: filtered.length),
                const SizedBox(height: 12),
                // ── Vue principale ───────────────────────────────────────────
                if (data.schools.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: AdminEmptyState(
                      icon: Icons.school_rounded,
                      title: 'Aucune école',
                      message: 'Ajoutez votre première école pour commencer à gérer les élèves, le personnel et les classes.',
                      actionLabel: 'Ajouter une école',
                      onAction: _openCreate,
                    ),
                  )
                else if (_isTableView)
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (selected.isNotEmpty) ...[
                      _BulkActionBar(
                        count: selected.length,
                        activeCount: selected.where((s) => s.isActive).length,
                        onActivate: () => _bulkSetActive(selected, true),
                        onDeactivate: () => _bulkSetActive(selected, false),
                        onClear: () => setState(_selectedIds.clear),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _TableView(
                      schools:     filtered,
                      sortField:   _sortField,
                      sortAsc:     _sortAsc,
                      selectedIds: _selectedIds,
                      allSelected: allSelected,
                      onToggleAll: () => setState(() {
                        if (allSelected) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(filtered.map((s) => s.id));
                        }
                      }),
                      onToggleSelect: (id) => setState(() {
                        if (!_selectedIds.remove(id)) _selectedIds.add(id);
                      }),
                      onSort: (f) => setState(() {
                        if (_sortField == f) { _sortAsc = !_sortAsc; }
                        else { _sortField = f; _sortAsc = true; }
                      }),
                      onView:   _openDetail,
                      onEdit:   _openEdit,
                      onToggle: _toggleActive,
                    ),
                  ])
                else
                  _CardGrid(
                    schools:  filtered,
                    onView:   _openDetail,
                    onEdit:   _openEdit,
                    onToggle: _toggleActive,
                  ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

