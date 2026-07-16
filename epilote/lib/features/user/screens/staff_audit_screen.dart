import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/staff_ui.dart';
import '../providers/staff_audit_provider.dart';

/// Journal d'audit de l'école — outil natif de direction (online, school-scopé).
/// Lecture seule. Voir [staffAuditProvider] pour l'exception « online ».
class StaffAuditScreen extends ConsumerWidget {
  const StaffAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const AppShell(title: "Journal d'audit", child: _Body());
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async  = ref.watch(staffAuditProvider);
    final filter = ref.watch(staffAuditActionFilterProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(staffAuditProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const StaffPageHeader(
            icon: Icons.fact_check_outlined,
            title: "Journal d'audit",
            subtitle:
                'Traçabilité des actions sur les données de votre établissement',
          ),
          const SizedBox(height: 14),
          _FilterBar(selected: filter),
          const SizedBox(height: 14),
          async.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const FeedSkeleton(),
            error: (_, _) => const _Empty(
              icon: Icons.wifi_off_rounded,
              title: 'Consultation indisponible',
              message:
                  "Le journal d'audit nécessite une connexion internet "
                  '(donnée de gouvernance, non synchronisée hors-ligne).',
            ),
            data: (all) {
              final rows = filter == 'all'
                  ? all
                  : all.where((e) => e.action == filter).toList();
              if (rows.isEmpty) {
                return const _Empty(
                  icon: Icons.history_rounded,
                  title: 'Aucune activité',
                  message: 'Aucune action enregistrée pour ce filtre.',
                );
              }
              return Column(
                children: [for (final e in rows) _AuditCard(entry: e)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.selected});
  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const opts = [
      ('all', 'Tout'),
      ('INSERT', 'Créations'),
      ('UPDATE', 'Modifications'),
      ('DELETE', 'Suppressions'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in opts)
          _Chip(
            label: label,
            active: selected == value,
            onTap: () =>
                ref.read(staffAuditActionFilterProvider.notifier).state = value,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? kNavy : kCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? kNavy : kBorder),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : kTextMuted)),
        ),
      );
}

class _AuditCard extends StatefulWidget {
  const _AuditCard({required this.entry});
  final StaffAuditEntry entry;

  @override
  State<_AuditCard> createState() => _AuditCardState();
}

class _AuditCardState extends State<_AuditCard> {
  bool _open = false;

  Color get _sevColor => switch (widget.entry.severity) {
        StaffAuditSeverity.high => kRed,
        StaffAuditSeverity.medium => const Color(0xFFF59E0B),
        StaffAuditSeverity.low => kGreen,
      };

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final fields = e.changedFields;
    final hasDetail = fields.isNotEmpty;
    final dateStr = e.createdAt != null
        ? DateFormat('dd/MM/yyyy · HH:mm', 'fr').format(e.createdAt!.toLocal())
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: hasDetail ? () => setState(() => _open = !_open) : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration:
                        BoxDecoration(color: _sevColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6, runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('${e.actionLabel} · ${e.entityLabel}',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: kTextPrimary)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text('${e.actorName} (${e.roleLabelStr})',
                            style: TextStyle(
                                fontSize: 12, color: kTextMuted)),
                        if (hasDetail) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${fields.length} champ${fields.length > 1 ? 's' : ''} '
                            'concerné${fields.length > 1 ? 's' : ''}',
                            style: TextStyle(
                                fontSize: 11, color: kTextMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(dateStr,
                          style: TextStyle(
                              fontSize: 11, color: kTextMuted)),
                      if (hasDetail)
                        Icon(_open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                            size: 18, color: kTextMuted),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_open && hasDetail) _Diff(entry: e),
        ],
      ),
    );
  }
}

class _Diff extends StatelessWidget {
  const _Diff({required this.entry});
  final StaffAuditEntry entry;

  String _fmt(Object? v) {
    if (v == null) return '∅';
    final s = v.toString();
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }

  @override
  Widget build(BuildContext context) {
    final oldV = entry.oldValues ?? const {};
    final newV = entry.newValues ?? const {};
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(36, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final k in entry.changedFields)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (entry.action == 'UPDATE') ...[
                        Flexible(
                          child: Text(_fmt(oldV[k]),
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: kRed,
                                  decoration: TextDecoration.lineThrough)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded,
                              size: 12, color: kTextMuted),
                        ),
                      ],
                      Flexible(
                        child: Text(
                            _fmt(entry.action == 'DELETE' ? oldV[k] : newV[k]),
                            style: TextStyle(
                                fontSize: 11.5,
                                color: entry.action == 'DELETE'
                                    ? kRed
                                    : kGreen)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(
      {required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title, message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(icon, size: 44, color: kTextMuted.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ],
        ),
      );
}
