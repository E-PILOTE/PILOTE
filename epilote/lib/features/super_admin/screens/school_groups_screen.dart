import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FileOptions, SupabaseClient;

import '../../../core/widgets/app_shell.dart';
import '../../../core/utils/media_compression.dart';
import '../providers/comptes_admin_provider.dart';
import '../providers/school_groups_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animated_button/flutter_animated_button.dart';
import '../services/group_pdf_service.dart';
import '../widgets/plan_change_notice.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/constants/caractere_groupe.dart';
import '../../../core/constants/tutelle.dart';
import '../../../core/widgets/badge_ministere.dart';
import '../../../core/providers/identite_etablissement.dart';

part 'groups/group_delete_dialog.dart';
part 'groups/group_detail_modal.dart';
part 'groups/group_detail_tabs.dart';
part 'groups/group_logo_box.dart';
part 'groups/group_print_preview.dart';
part 'groups/group_save_button.dart';
part 'groups/groups_badges.dart';
part 'groups/groups_cards.dart';
part 'groups/groups_detail_bits.dart';
part 'groups/groups_filter_bar.dart';
part 'groups/groups_form_bits.dart';
part 'groups/groups_info_grid.dart';
part 'groups/groups_kpis.dart';
part 'groups/groups_table.dart';

// Le formulaire de groupe vit dans ses propres fichiers : cet écran dépassait
// 3 600 lignes et le modal en pesait 511 à lui seul. `part` plutôt que des
// fichiers autonomes parce qu'ils s'appuient sur les jetons et les petits
// widgets privés (`_FormLabel`, `_LogoUploadBox`, `_inputDeco`) déclarés ici.
part 'groups/group_form_modal.dart';
part 'groups/group_form_layout.dart';
part 'groups/group_tutelle_selector.dart';
part 'groups/group_tutelle_role.dart';
part 'groups/group_logo_upload.dart';
part 'groups/group_form_footer.dart';
part 'groups/group_agrement_fields.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
const _kOrange  = Color(0xFFFF6B35);
const _kPurple  = Color(0xFF7C3AED);
const _kRed     = Color(0xFFEF4444);
Color get _kSurface => kSurface;
Color get _kBg => kCardBg;
Color get _kBorder => kBorder;
Color get _kText => kTextPrimary;
Color get _kMuted => kTextMuted;

// ─── Écran principal ──────────────────────────────────────────────────────────

class SchoolGroupsScreen extends ConsumerWidget {
  const SchoolGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Groupes Scolaires',
      child: _GroupsBody(),
    );
  }
}

// ─── Body avec state ──────────────────────────────────────────────────────────

class _GroupsBody extends ConsumerStatefulWidget {
  const _GroupsBody();
  @override
  ConsumerState<_GroupsBody> createState() => _GroupsBodyState();
}

class _GroupsBodyState extends ConsumerState<_GroupsBody> {
  // Filtres
  final _searchCtrl  = TextEditingController();
  String  _filterStatus = 'tous';
  String  _filterType   = 'tous';
  String  _filterPlan   = 'tous';
  String  _filterDept   = 'tous';
  // Vue
  bool    _isTableView  = true;
  // Tri (table)
  String  _sortField    = 'createdAt';
  bool    _sortAsc      = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GroupDetail> _applyFilters(List<GroupDetail> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((g) {
      if (q.isNotEmpty) {
        final match = g.name.toLowerCase().contains(q)
            || g.adminEmail.toLowerCase().contains(q)
            || (g.department?.toLowerCase().contains(q) ?? false)
            || g.planName.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_filterStatus != 'tous' && g.subscriptionStatus != _filterStatus) return false;
      if (_filterType   != 'tous' && g.groupType          != _filterType  ) return false;
      if (_filterPlan   != 'tous' && g.planName           != _filterPlan  ) return false;
      if (_filterDept   != 'tous' && (g.department ?? '') != _filterDept  ) return false;
      return true;
    }).toList()..sort((a, b) {
      int c;
      switch (_sortField) {
        case 'name':       c = a.name.compareTo(b.name);                 break;
        case 'status':     c = a.subscriptionStatus.compareTo(b.subscriptionStatus); break;
        case 'plan':       c = a.planName.compareTo(b.planName);         break;
        case 'schools':    c = a.schoolCount.compareTo(b.schoolCount);   break;
        case 'endDate':
          final ae = a.subscriptionEnd, be = b.subscriptionEnd;
          if (ae == null && be == null) {
            c = 0;
          } else if (ae == null) {
            c = 1;
          } else if (be == null) {
            c = -1;
          } else {
            c = ae.compareTo(be);
          }
          break;
        default:           c = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAsc ? c : -c;
    });
  }

  void _openCreate(SchoolGroupsData data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GroupFormModal(
        plans: data.plans,
        groupes: data.groups,
        onSaved: () => ref.invalidate(schoolGroupsProvider),
      ),
    );
  }

  void _openDetail(GroupDetail g, SchoolGroupsData data) {
    showDialog(
      context: context,
      builder: (_) => _GroupDetailModal(
        group: g,
        plans: data.plans,
        onEdit: () {
          Navigator.pop(context);
          _openEdit(g, data);
        },
        onToggleActive: () async {
          await _toggleActive(g);
          if (mounted) Navigator.pop(context);
        },
        onDelete: () async {
          Navigator.pop(context);
          await _confirmDelete(g);
        },
        onPrint: () => _printGroup(g),
      ),
    );
  }

  void _openEdit(GroupDetail g, SchoolGroupsData data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GroupFormModal(
        plans:    data.plans,
        groupes:  data.groups,
        existing: g,
        onSaved:  () => ref.invalidate(schoolGroupsProvider),
      ),
    );
  }

  Future<void> _toggleActive(GroupDetail g) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('school_groups')
          .update({'is_active': !g.isActive}).eq('id', g.id);
      ref.invalidate(schoolGroupsProvider);
    } catch (e) {
      if (mounted) _showError(messageErreur(e));
    }
  }

  Future<void> _confirmDelete(GroupDetail g) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DeleteConfirmDialog(group: g),
    );
    if (ok != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('delete_school_group', params: {'p_group_id': g.id});
      ref.invalidate(schoolGroupsProvider);
      if (mounted) _showSuccess('Groupe "${g.name}" supprimé définitivement.');
    } catch (e) {
      if (mounted) _showError(messageErreur(e));
    }
  }

  void _printGroup(GroupDetail g) {
    showDialog(
      context: context,
      builder: (_) => _PrintPreviewModal(group: g),
    );
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(schoolGroupsProvider);

    return async.when(
      skipLoadingOnReload:  true,
      skipLoadingOnRefresh: true,
      loading: () => const _ShimmerSkeleton(),
      error:   (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: _kMuted),
          const SizedBox(height: 12),
          Text(messageErreur(e), style: TextStyle(color: _kMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(schoolGroupsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) => _buildContent(data),
    );
  }

  Widget _buildContent(SchoolGroupsData data) {
    final filtered = _applyFilters(data.groups);

    return LayoutBuilder(builder: (context, constraints) {
      // Garantir une largeur finie même si le parent donne des contraintes
      // non bornées lors d'une transition d'état Riverpod.
      final double w = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width - 300;

      return SingleChildScrollView(
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ── KPI premium grid ───────────────────────────────────────────
              _KpiGrid(data: data),
              const SizedBox(height: 20),

              // ── Barre de filtres ────────────────────────────────────────────
              _FilterBar(
                contentWidth:   w - 48,
                searchCtrl:     _searchCtrl,
                filterStatus:   _filterStatus,
                filterType:     _filterType,
                filterPlan:     _filterPlan,
                filterDept:     _filterDept,
                departments:    data.departments,
                planNames:      data.plans.map((p) => p.name).toList(),
                isTableView:    _isTableView,
                onSearchChange: (_) => setState(() {}),
                onStatus:       (v) => setState(() => _filterStatus = v),
                onType:         (v) => setState(() => _filterType   = v),
                onPlan:         (v) => setState(() => _filterPlan   = v),
                onDept:         (v) => setState(() => _filterDept   = v),
                onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterStatus = _filterType = _filterPlan = _filterDept = 'tous';
                }),
                onAdd: () => _openCreate(data),
              ),
              const SizedBox(height: 16),

              // ── Résultat ────────────────────────────────────────────────────
              _ResultHeader(total: data.total, filtered: filtered.length),
              const SizedBox(height: 12),

              // ── Vue principale ──────────────────────────────────────────────
              if (_isTableView)
                _TableView(
                  groups:    filtered,
                  sortField: _sortField,
                  sortAsc:   _sortAsc,
                  onSort: (f) => setState(() {
                    if (_sortField == f) {
                      _sortAsc = !_sortAsc;
                    } else {
                      _sortField = f;
                      _sortAsc = true;
                    }
                  }),
                  onDetail: (g) => _openDetail(g, data),
                  onEdit:   (g) => _openEdit(g, data),
                  onDelete: (g) => _confirmDelete(g),
                  onPrint:  (g) => _printGroup(g),
                )
              else
                _CardGrid(
                  groups:   filtered,
                  onDetail: (g) => _openDetail(g, data),
                  onEdit:   (g) => _openEdit(g, data),
                  onDelete: (g) => _confirmDelete(g),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

// ─── KPI Grid premium — 6 cartes en grille 3×2 ───────────────────────────────
