import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../providers/audit_data.dart';
import 'audit_detail_dialog.dart';
import 'audit_filter_bar.dart';
import 'audit_row.dart';
import '../../../../core/utils/message_erreur.dart';

/// Onglet « Activité » : barre de filtres + liste paginée du journal.
class AuditActivityTab extends ConsumerWidget {
  const AuditActivityTab(
      {super.key, required this.facetsAsync, required this.scope});
  final AsyncValue<AuditFacets> facetsAsync;
  final AuditScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(auditFiltersProvider);
    final pageAsync = ref.watch(auditPageProvider(filters));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AuditFilterBar(
          filters: filters,
          scope: scope,
          tables: facetsAsync.valueOrNull?.tables ?? const [],
          roles: facetsAsync.valueOrNull?.roles ?? const [],
          schools: facetsAsync.valueOrNull?.schools ?? const [],
        ),
        const SizedBox(height: 16),
        pageAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator(color: kNavy)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 24),
            child: AdminErrorBanner(message: messageErreur(e)),
          ),
          data: (page) => _AuditList(filters: filters, page: page, scope: scope),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AuditList extends ConsumerWidget {
  const _AuditList(
      {required this.filters, required this.page, required this.scope});
  final AuditFilters filters;
  final AuditPage page;
  final AuditScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: AdminEmptyState(
          icon: Icons.history_toggle_off_rounded,
          title: filters.hasActiveFilters ? 'Aucun résultat' : 'Journal vide',
          message: filters.hasActiveFilters
              ? 'Aucun événement ne correspond à vos filtres.'
              : 'Le journal retrace chaque action sensible des utilisateurs. Il se remplira automatiquement dès la première opération.',
        ),
      );
    }

    final totalPages = (page.totalCount / kAuditPageSize).ceil();
    final from = filters.page * kAuditPageSize + 1;
    final to = filters.page * kAuditPageSize + page.entries.length;

    return Column(
      children: [
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < page.entries.length; i++) ...[
                AuditRow(
                  e: page.entries[i],
                  onTap: () => _showDetail(context, ref, page.entries[i]),
                ),
                if (i != page.entries.length - 1)
                  Divider(height: 1, color: kBorder),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Pager(
          from: from,
          to: to,
          total: page.totalCount,
          pageIndex: filters.page,
          totalPages: totalPages,
          onPrev: filters.page > 0
              ? () => ref.read(auditFiltersProvider.notifier).state =
                  filters.copyWith(page: filters.page - 1)
              : null,
          onNext: filters.page < totalPages - 1
              ? () => ref.read(auditFiltersProvider.notifier).state =
                  filters.copyWith(page: filters.page + 1)
              : null,
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, AuditEntry e) {
    showDialog(
      context: context,
      builder: (_) => AuditDetailDialog(
        entry: e,
        // « Filtrer cette école » n'a de sens qu'en périmètre groupe.
        onFilterSchool: scope.showSchoolDimension && e.schoolId != null
            ? () {
                ref.read(auditFiltersProvider.notifier).state =
                    const AuditFilters().copyWith(schoolId: e.schoolId);
                Navigator.of(context).pop();
              }
            : null,
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.from,
    required this.to,
    required this.total,
    required this.pageIndex,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });
  final int from, to, total, pageIndex, totalPages;
  final VoidCallback? onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$from–$to sur $total événements',
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
        Row(
          children: [
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded),
              color: kNavy,
              disabledColor: kBorder,
              tooltip: 'Précédent',
            ),
            Text('${pageIndex + 1} / ${totalPages == 0 ? 1 : totalPages}',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              color: kNavy,
              disabledColor: kBorder,
              tooltip: 'Suivant',
            ),
          ],
        ),
      ],
    );
  }
}
