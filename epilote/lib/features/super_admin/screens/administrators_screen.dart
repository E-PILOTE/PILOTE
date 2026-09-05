import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/capture_webcam.dart';
import '../../staff/services/agent_photo_service.dart' show kAvatarExtensions;

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/utils/media_compression.dart';
import '../providers/administrators_provider.dart';
import '../services/admin_pdf_service.dart';
import '../../../core/utils/message_erreur.dart';

part 'admins/admin_avatar_upload.dart';
part 'admins/admin_delete_dialog.dart';
part 'admins/admin_detail_modal.dart';
part 'admins/admin_detail_tabs.dart';
part 'admins/admin_form_bits.dart';
part 'admins/admin_form_layout.dart';
part 'admins/admin_form_modal.dart';
part 'admins/admin_print_preview.dart';
part 'admins/admins_cards.dart';
part 'admins/admins_dates.dart';
part 'admins/admins_filter_bar.dart';
part 'admins/admins_kpis.dart';
part 'admins/admins_table.dart';

// ─── Design tokens (identiques à school_groups_screen) ───────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
const _kOrange  = Color(0xFFFF6B35);
const _kPurple  = Color(0xFF7C3AED);
const _kBlue    = Color(0xFF0EA5E9);
const _kRed     = Color(0xFFEF4444);
Color get _kSurface => kSurface;
Color get _kBg => kCardBg;
Color get _kBorder => kBorder;
Color get _kText => kTextPrimary;
Color get _kMuted => kTextMuted;

// ─── Helpers rôles ────────────────────────────────────────────────────────────
Color _roleColor(String role) => switch (role) {
  'super_admin'  => _kNavy,
  'admin_groupe' => _kGold,
  _              => _kMuted,
};

IconData _roleIcon(String role) => switch (role) {
  'super_admin'  => Icons.shield_rounded,
  'admin_groupe' => Icons.business_rounded,
  _              => Icons.person_rounded,
};

// ─── Écran principal ──────────────────────────────────────────────────────────

class AdministratorsScreen extends ConsumerWidget {
  const AdministratorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Administrateurs',
      child: _AdminsBody(),
    );
  }
}

// ─── Body avec state ──────────────────────────────────────────────────────────

class _AdminsBody extends ConsumerStatefulWidget {
  const _AdminsBody();
  @override
  ConsumerState<_AdminsBody> createState() => _AdminsBodyState();
}

class _AdminsBodyState extends ConsumerState<_AdminsBody> {
  final _searchCtrl   = TextEditingController();
  String _filterRole   = 'tous';
  String _filterStatus = 'tous';
  String _sort         = 'recent';
  bool   _isTableView  = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminDetail> _applyFilters(List<AdminDetail> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((a) {
      if (q.isNotEmpty) {
        final match = a.fullName.toLowerCase().contains(q)
            || a.email.toLowerCase().contains(q)
            || (a.groupName?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_filterRole   != 'tous' && a.role != _filterRole) return false;
      if (_filterStatus == 'actif'   && !a.isActive) return false;
      if (_filterStatus == 'inactif' &&  a.isActive) return false;
      return true;
    }).toList()..sort((a, b) => switch (_sort) {
      'az'      => a.fullName.compareTo(b.fullName),
      'za'      => b.fullName.compareTo(a.fullName),
      'recents' => b.lastLogin != null && a.lastLogin != null
          ? b.lastLogin!.compareTo(a.lastLogin!)
          : (b.lastLogin != null ? 1 : -1),
      _         => b.createdAt.compareTo(a.createdAt),
    });
  }

  void _openForm({AdminDetail? editing}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierDismissible: false,
      builder: (_) => _AdminFormModal(editing: editing),
    ).then((_) => ref.invalidate(administratorsProvider));
  }

  void _openDetail(AdminDetail a) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _AdminDetailModal(
        admin: a,
        onEdit:   () { Navigator.pop(context); _openForm(editing: a); },
        onToggle: () { Navigator.pop(context); _toggleActive(a); },
        onReset:  () { Navigator.pop(context); _resetPassword(a); },
        onDelete: () { Navigator.pop(context); _confirmDelete(a); },
        onPrint:  () => _printAdmin(a),
      ),
    );
  }

  void _printAdmin(AdminDetail a) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _AdminPrintPreviewModal(admin: a),
    );
  }

  Future<void> _toggleActive(AdminDetail a) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('profiles')
          .update({'is_active': !a.isActive, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', a.id);
      ref.invalidate(administratorsProvider);
    } catch (e) {
      if (mounted) _showError(messageErreur(e));
    }
  }

  Future<void> _resetPassword(AdminDetail a) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.resetPasswordForEmail(a.email);
      if (mounted) _showSuccess('Email de réinitialisation envoyé à ${a.email}');
    } catch (e) {
      if (mounted) _showError(messageErreur(e));
    }
  }

  Future<void> _confirmDelete(AdminDetail a) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DeleteConfirmDialog(admin: a),
    );
    if (ok != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('delete_admin_user', params: {'p_user_id': a.id});
      ref.invalidate(administratorsProvider);
      if (mounted) _showSuccess('Compte "${a.fullName}" supprimé définitivement.');
    } catch (e) {
      if (mounted) _showError(messageErreur(e));
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(administratorsProvider);

    return async.when(
      skipLoadingOnReload:  true,
      skipLoadingOnRefresh: true,
      loading: () => const _ShimmerSkeleton(),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: _kMuted),
          const SizedBox(height: 12),
          Text(messageErreur(e), style: TextStyle(color: _kMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(administratorsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) => _buildContent(data),
    );
  }

  Widget _buildContent(AdminsData data) {
    final filtered = _applyFilters(data.admins);

    return LayoutBuilder(builder: (context, constraints) {
      final double w = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width - 300;

      return SingleChildScrollView(
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ── KPI grid ───────────────────────────────────────────────
              _KpiGrid(data: data),
              const SizedBox(height: 20),

              // ── Barre de filtres ────────────────────────────────────────
              _FilterBar(
                contentWidth:   w - 48,
                searchCtrl:     _searchCtrl,
                filterRole:     _filterRole,
                filterStatus:   _filterStatus,
                sort:           _sort,
                isTableView:    _isTableView,
                onSearchChange: (_) => setState(() {}),
                onRole:         (v) => setState(() => _filterRole   = v),
                onStatus:       (v) => setState(() => _filterStatus = v),
                onSort:         (v) => setState(() => _sort         = v),
                onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterRole = _filterStatus = 'tous';
                  _sort = 'recent';
                }),
                onAdd: () => _openForm(),
              ),
              const SizedBox(height: 16),

              // ── Résultat ────────────────────────────────────────────────
              _ResultHeader(total: data.total, filtered: filtered.length),
              const SizedBox(height: 12),

              // ── Vue principale ──────────────────────────────────────────
              if (_isTableView)
                _TableView(
                  admins:   filtered,
                  onView:   _openDetail,
                  onEdit:   (a) => _openForm(editing: a),
                  onDelete: _confirmDelete,
                  onToggle: _toggleActive,
                  onReset:  _resetPassword,
                )
              else
                _CardGrid(
                  admins:   filtered,
                  onView:   _openDetail,
                  onEdit:   (a) => _openForm(editing: a),
                  onDelete: _confirmDelete,
                  onToggle: _toggleActive,
                ),
            ]),
          ),
        ),
      );
    });
  }
}

// ─── KPI Grid — 6 cartes 3×2 ─────────────────────────────────────────────────
