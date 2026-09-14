import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/app_shell.dart';
import '../providers/admin_access_provider.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/utils/message_erreur.dart';

part 'acces/acces_cards.dart';
part 'acces/acces_delete_dialogs.dart';
part 'acces/acces_filter_bar.dart';
part 'acces/acces_kpis.dart';
part 'acces/acces_matrice.dart';
part 'acces/acces_referentiel.dart';
part 'acces/acces_table.dart';
part 'acces/profil_detail_modal.dart';
part 'acces/profil_detail_tabs.dart';
part 'acces/profil_wizard.dart';
part 'acces/profil_wizard_panneaux.dart';

// ─── Couleurs locales ─────────────────────────────────────────────────────────
const _kPurple = Color(0xFF7C3AED);
const _kBlue   = Color(0xFF0EA5E9);
const _kOrange = Color(0xFFFF6B35);

// ─── Normalisation des messages d'erreur ──────────────────────────────────────
/// Transforme une exception (souvent un PostgrestException ou Exception
/// applicative) en message lisible par l'utilisateur.
String _friendlyError(Object e) {
  var msg = e.toString();
  // « Exception: ... » → on enlève le préfixe technique.
  if (msg.startsWith('Exception: ')) msg = msg.substring(11);
  final lower = msg.toLowerCase();
  // Violation de clé étrangère (profil encore attribué à des membres).
  if (lower.contains('foreign key') ||
      lower.contains('violates') ||
      lower.contains('fk_profiles_access_profile')) {
    return 'Suppression impossible : ce profil est encore attribué à des '
        'membres. Réattribuez-les depuis la page Utilisateurs, puis réessayez.';
  }
  // Droits insuffisants côté RLS / RPC.
  if (lower.contains('accès refusé') ||
      lower.contains('row-level security') ||
      lower.contains('permission denied')) {
    return "Action refusée : vous n'avez pas les droits requis pour cette "
        'opération.';
  }
  return msg;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminAccessScreen extends ConsumerWidget {
  const AdminAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: "Profils d'accès",
      child: ref.watch(adminAccessProvider).when(
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
              onPressed: () => ref.invalidate(adminAccessProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (d) => _AccessBody(data: d),
      ),
    );
  }
}

// ─── Body (état filtres + tri + vue) ─────────────────────────────────────────

class _AccessBody extends ConsumerStatefulWidget {
  const _AccessBody({required this.data});
  final AdminAccessData data;

  @override
  ConsumerState<_AccessBody> createState() => _AccessBodyState();
}

class _AccessBodyState extends ConsumerState<_AccessBody> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // all | active | inactive
  bool   _isTableView  = true;
  String _sortField    = 'name';
  bool   _sortAsc      = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AccessProfile> _applyFilters(List<AccessProfile> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return all.where((p) {
      if (_statusFilter == 'active'   && !p.isActive) return false;
      if (_statusFilter == 'inactive' &&  p.isActive) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q)
          || (p.description?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) {
        int c;
        switch (_sortField) {
          case 'members': c = a.memberCount.compareTo(b.memberCount); break;
          case 'modules': c = a.moduleCount.compareTo(b.moduleCount); break;
          case 'status':  c = (a.isActive ? 0 : 1).compareTo(b.isActive ? 0 : 1); break;
          default:        c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        return _sortAsc ? c : -c;
      });
  }

  void _openCreate() => showDialog(
        context: context,
        builder: (_) => ProfileWizardDialog(categories: widget.data.categories),
      );

  void _openEdit(AccessProfile p) => showDialog(
        context: context,
        builder: (_) =>
            ProfileWizardDialog(profile: p, categories: widget.data.categories),
      );

  void _openPermissions(AccessProfile p) => showDialog(
        context: context,
        builder: (_) => ProfileWizardDialog(
            profile: p, categories: widget.data.categories, initialStep: 1),
      );

  void _openDetail(AccessProfile p) => showDialog(
        context: context,
        builder: (_) => _ProfileDetailModal(
          profile: p,
          categories: widget.data.categories,
          onEdit:        () { Navigator.of(context).pop(); _openEdit(p); },
          onPermissions: () { Navigator.of(context).pop(); _openPermissions(p); },
          onToggle:      () { Navigator.of(context).pop(); _toggleActive(p); },
          onDelete:      () { Navigator.of(context).pop(); _confirmDelete(p); },
        ),
      );

  Future<void> _toggleActive(AccessProfile p) async {
    try {
      await ref.read(adminAccessServiceProvider).setActive(p.id, !p.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(p.isActive ? 'Profil désactivé' : 'Profil activé'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text(messageErreur(e))));
      }
    }
  }

  Future<void> _confirmDelete(AccessProfile p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteProfileDialog(profile: p),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(adminAccessServiceProvider).deleteProfile(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text('Profil « ${p.name} » supprimé'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kRed,
          content: Text(_friendlyError(e)),
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data     = widget.data;
    final filtered = _applyFilters(data.profiles);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminAccessProvider.future),
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
                _KpiGrid(data: data),
                const SizedBox(height: 20),
                _FilterBar(
                  contentWidth: w - 48,
                  searchCtrl:   _searchCtrl,
                  statusFilter: _statusFilter,
                  isTableView:  _isTableView,
                  onSearchChange: (_) => setState(() {}),
                  onStatus:     (v) => setState(() => _statusFilter = v),
                  onToggleView: ()  => setState(() => _isTableView = !_isTableView),
                  onReset: () => setState(() {
                    _searchCtrl.clear();
                    _statusFilter = 'all';
                  }),
                  onAdd: _openCreate,
                ),
                const SizedBox(height: 16),
                _ResultHeader(total: data.profiles.length, filtered: filtered.length),
                const SizedBox(height: 12),
                if (data.profiles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: AdminEmptyState(
                      icon: Icons.shield_outlined,
                      title: "Aucun profil d'accès",
                      message:
                          'Créez des profils (ex. « Enseignant », « Comptable ») pour contrôler finement ce que chaque membre du personnel peut voir et modifier.',
                      actionLabel: 'Créer un profil',
                      onAction: _openCreate,
                    ),
                  )
                else if (_isTableView)
                  _TableView(
                    profiles:  filtered,
                    sortField: _sortField,
                    sortAsc:   _sortAsc,
                    onSort: (f) => setState(() {
                      if (_sortField == f) { _sortAsc = !_sortAsc; }
                      else { _sortField = f; _sortAsc = true; }
                    }),
                    onView:        _openDetail,
                    onEdit:        _openEdit,
                    onPermissions: _openPermissions,
                    onToggle:      _toggleActive,
                    onDelete:      _confirmDelete,
                  )
                else
                  _CardGrid(
                    profiles:      filtered,
                    onView:        _openDetail,
                    onEdit:        _openEdit,
                    onPermissions: _openPermissions,
                    onToggle:      _toggleActive,
                    onDelete:      _confirmDelete,
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

// ─── KPI Grid ─────────────────────────────────────────────────────────────────
