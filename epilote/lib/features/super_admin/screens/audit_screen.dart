import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/app_shell.dart';
import '../providers/audit_provider.dart';
import '../../../core/utils/message_erreur.dart';

part 'journal/journal_cartes.dart';
part 'journal/journal_detail.dart';
part 'journal/journal_filtres.dart';
part 'journal/journal_kpis.dart';
part 'journal/journal_table.dart';

// ─── Design tokens ───────────────────────────────────────────────────────────
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

// ─── Helpers action ───────────────────────────────────────────────────────────
Color _actionColor(String a) => switch (a) {
  'INSERT' => _kGreen,
  'UPDATE' => _kBlue,
  'DELETE' => _kRed,
  _        => _kMuted,
};

IconData _actionIcon(String a) => switch (a) {
  'INSERT' => Icons.add_circle_rounded,
  'UPDATE' => Icons.edit_rounded,
  'DELETE' => Icons.delete_rounded,
  _        => Icons.help_rounded,
};

Color _roleColor(String? r) => switch (r) {
  'super_admin'   => _kNavy,
  'admin_groupe'  => _kPurple,
  'directeur'     => _kBlue,
  'enseignant'    => _kGreen,
  _               => _kMuted,
};

// ─── Écran principal ──────────────────────────────────────────────────────────

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: "Journal d'Audit",
      child: _AuditBody(),
    );
  }
}

// ─── Body avec state ──────────────────────────────────────────────────────────

class _AuditBody extends ConsumerStatefulWidget {
  const _AuditBody();
  @override
  ConsumerState<_AuditBody> createState() => _AuditBodyState();
}

class _AuditBodyState extends ConsumerState<_AuditBody> {
  final _searchCtrl    = TextEditingController();
  String _filterAction = 'tous';
  String _filterRole   = 'tous';
  String _filterTable  = 'tous';
  String _sort         = 'recent';
  bool   _isTableView  = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AuditLog> _applyFilters(List<AuditLog> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((l) {
      if (q.isNotEmpty) {
        final match = l.tableName.toLowerCase().contains(q)
            || l.action.toLowerCase().contains(q)
            || (l.userEmail?.toLowerCase().contains(q) ?? false)
            || (l.userRole?.toLowerCase().contains(q) ?? false)
            || (l.recordId?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_filterAction != 'tous' && l.action != _filterAction) return false;
      if (_filterRole   != 'tous' && l.userRole != _filterRole) return false;
      if (_filterTable  != 'tous' && l.tableName != _filterTable) return false;
      return true;
    }).toList()..sort((a, b) => switch (_sort) {
      'az'    => a.tableName.compareTo(b.tableName),
      'action'=> a.action.compareTo(b.action),
      _       => b.createdAt.compareTo(a.createdAt),
    });
  }

  void _openDetail(AuditLog l) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _AuditDetailModal(log: l),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auditLogsProvider);
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
            onPressed: () => ref.invalidate(auditLogsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) => _buildContent(data),
    );
  }

  Widget _buildContent(AuditData data) {
    final filtered = _applyFilters(data.logs);
    final tables   = data.logs.map((l) => l.tableName).toSet().toList()..sort();

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
              _KpiGrid(data: data),
              const SizedBox(height: 20),
              _FilterBar(
                contentWidth:   w - 48,
                searchCtrl:     _searchCtrl,
                filterAction:   _filterAction,
                filterRole:     _filterRole,
                filterTable:    _filterTable,
                tables:         tables,
                sort:           _sort,
                isTableView:    _isTableView,
                onSearchChange: (_) => setState(() {}),
                onAction:       (v) => setState(() => _filterAction = v),
                onRole:         (v) => setState(() => _filterRole   = v),
                onTable:        (v) => setState(() => _filterTable  = v),
                onSort:         (v) => setState(() => _sort         = v),
                onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                onRefresh:      ()  => ref.invalidate(auditLogsProvider),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterAction = _filterRole = _filterTable = 'tous';
                  _sort = 'recent';
                }),
              ),
              const SizedBox(height: 16),
              _ResultHeader(total: data.total, filtered: filtered.length),
              const SizedBox(height: 12),
              if (_isTableView)
                _TableView(logs: filtered, onView: _openDetail)
              else
                _CardGrid(logs: filtered, onView: _openDetail),
            ]),
          ),
        ),
      );
    });
  }
}

// ─── KPI Grid — 6 cartes 3×2 ─────────────────────────────────────────────────
