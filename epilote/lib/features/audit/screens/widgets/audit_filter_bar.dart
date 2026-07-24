import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../../admin_groupe/providers/admin_users_provider.dart' show roleLabel;
import '../../providers/audit_data.dart';
import 'audit_date_range_dialog.dart';
import 'audit_export_dialog.dart';

/// Barre de filtres du journal : presets de période, recherche, action, entité,
/// rôle, école (périmètre groupe seulement — auto-masquée si `schools` vide),
/// période personnalisée, export CSV.
class AuditFilterBar extends ConsumerStatefulWidget {
  const AuditFilterBar({
    super.key,
    required this.filters,
    required this.scope,
    required this.tables,
    required this.roles,
    required this.schools,
  });
  final AuditFilters filters;
  final AuditScope scope;
  final List<String> tables;
  final List<String> roles;
  final List<({String id, String name})> schools;

  @override
  ConsumerState<AuditFilterBar> createState() => _AuditFilterBarState();
}

class _AuditFilterBarState extends ConsumerState<AuditFilterBar> {
  late final TextEditingController _searchCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.filters.query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _update(AuditFilters next) {
    ref.read(auditFiltersProvider.notifier).state = next.copyWith(page: 0);
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _update(widget.filters.copyWith(query: value));
    });
  }

  Future<void> _pickRange() async {
    final result = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AuditDateRangeDialog(
        initialFrom: widget.filters.dateFrom,
        initialTo: widget.filters.dateTo,
      ),
    );
    if (result != null && mounted) {
      _update(widget.filters
          .copyWith(dateFrom: result.start, dateTo: result.end));
    }
  }

  void _applyPreset(int days) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    _update(widget.filters.copyWith(dateFrom: from, dateTo: now));
  }

  void _clearDate() =>
      _update(widget.filters.copyWith(dateFrom: null, dateTo: null));

  void _openExportDialog(AuditPage? page) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AuditExportDialog(
        filters: widget.filters,
        scope: widget.scope,
        currentPageEntries: page?.entries ?? const [],
        totalCount: page?.totalCount ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filters;
    final pageAsync = ref.watch(auditPageProvider(f));

    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Presets rapides
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PresetChip(
                  label: 'Auj.',
                  active: _isPreset(f, 1),
                  onTap: () => _applyPreset(1)),
              _PresetChip(
                  label: '7 j',
                  active: _isPreset(f, 7),
                  onTap: () => _applyPreset(7)),
              _PresetChip(
                  label: '30 j',
                  active: _isPreset(f, 30),
                  onTap: () => _applyPreset(30)),
              _PresetChip(
                  label: '3 mois',
                  active: _isPreset(f, 90),
                  onTap: () => _applyPreset(90)),
            ],
          ),
          const SizedBox(height: 10),

          // Filtres principaux
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 230,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: adminInputDecoration('Rechercher',
                      icon: Icons.search_rounded, hint: 'Entité, utilisateur…'),
                ),
              ),
              SizedBox(
                width: 175,
                child: DropdownButtonFormField<String>(
                  initialValue: f.action,
                  isExpanded: true,
                  decoration:
                      adminInputDecoration('Action', icon: Icons.bolt_rounded),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Toutes les')),
                    DropdownMenuItem(value: 'INSERT', child: Text('Créations')),
                    DropdownMenuItem(
                        value: 'UPDATE', child: Text('Modifications')),
                    DropdownMenuItem(
                        value: 'DELETE', child: Text('Suppressions')),
                  ],
                  onChanged: (v) => _update(f.copyWith(action: v ?? 'all')),
                ),
              ),
              SizedBox(
                width: 195,
                child: DropdownButtonFormField<String>(
                  initialValue:
                      widget.tables.contains(f.table) ? f.table : 'all',
                  isExpanded: true,
                  decoration: adminInputDecoration('Entité',
                      icon: Icons.table_rows_rounded),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('Toutes les entités')),
                    ...widget.tables.map((t) => DropdownMenuItem(
                        value: t, child: Text(auditEntityLabel(t)))),
                  ],
                  onChanged: (v) => _update(f.copyWith(table: v ?? 'all')),
                ),
              ),
              SizedBox(
                width: 185,
                child: DropdownButtonFormField<String>(
                  initialValue: widget.roles.contains(f.role) ? f.role : 'all',
                  isExpanded: true,
                  decoration:
                      adminInputDecoration('Rôle', icon: Icons.badge_outlined),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('Tous les rôles')),
                    ...widget.roles.map((r) =>
                        DropdownMenuItem(value: r, child: Text(roleLabel(r)))),
                  ],
                  onChanged: (v) => _update(f.copyWith(role: v ?? 'all')),
                ),
              ),
              // Filtre « École » : périmètre groupe uniquement (liste vide en
              // périmètre école → masqué automatiquement).
              if (widget.schools.isNotEmpty)
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.schools.any((s) => s.id == f.schoolId)
                        ? f.schoolId
                        : 'all',
                    isExpanded: true,
                    decoration: adminInputDecoration('École',
                        icon: Icons.school_outlined),
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('Toutes les écoles')),
                      ...widget.schools.map((s) => DropdownMenuItem(
                          value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) => _update(f.copyWith(schoolId: v ?? 'all')),
                  ),
                ),
              _DateRangeSelector(
                dateFrom: f.dateFrom,
                dateTo: f.dateTo,
                onPick: _pickRange,
                onClear: _clearDate,
              ),
              _ExportButton(
                onPressed: () => _openExportDialog(pageAsync.valueOrNull),
                totalCount: pageAsync.valueOrNull?.totalCount ?? 0,
              ),
            ],
          ),
          if (f.hasActiveFilters) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _debounce?.cancel();
                  _searchCtrl.clear();
                  ref.read(auditFiltersProvider.notifier).state =
                      const AuditFilters();
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Réinitialiser'),
                style: TextButton.styleFrom(foregroundColor: kTextMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isPreset(AuditFilters f, int days) {
    if (f.dateFrom == null || f.dateTo == null) return false;
    final now = DateTime.now();
    final expected = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    return f.dateFrom!.year == expected.year &&
        f.dateFrom!.month == expected.month &&
        f.dateFrom!.day == expected.day;
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active ? kNavy : kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? kNavy : kBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : kTextMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateRangeSelector extends StatelessWidget {
  const _DateRangeSelector({
    required this.dateFrom,
    required this.dateTo,
    required this.onPick,
    required this.onClear,
  });
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasRange = dateFrom != null && dateTo != null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: hasRange ? kNavy.withValues(alpha: 0.05) : kCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasRange ? kNavy : kBorder,
              width: hasRange ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 15, color: hasRange ? kNavy : kTextMuted),
              const SizedBox(width: 8),
              if (!hasRange)
                Text('Période personnalisée',
                    style: TextStyle(fontSize: 13, color: kTextMuted))
              else ...[
                _DateChip(label: 'DU', date: dateFrom!),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 13, color: kNavy.withValues(alpha: 0.45)),
                ),
                _DateChip(label: 'AU', date: dateTo!),
                const SizedBox(width: 10),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onClear,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: kNavy.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 12, color: kNavy.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.date});
  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: kNavy.withValues(alpha: 0.55),
                letterSpacing: 0.6)),
        Text(
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}',
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: kNavy),
        ),
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onPressed, required this.totalCount});
  final VoidCallback onPressed;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_file_rounded, size: 15, color: kNavy),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exporter',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kNavy)),
                  if (totalCount > 0)
                    Text('$totalCount événements',
                        style: TextStyle(fontSize: 10, color: kTextMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
