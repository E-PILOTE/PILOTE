import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/academic_year_model.dart';
import '../../features/structure/providers/academic_year_context.dart';
import '../../features/structure/providers/academic_year_provider.dart';
import 'admin_ui.dart';

// ─── Statut → libellé + couleur ────────────────────────────────────────────────
({String label, Color color}) _statusStyle(YearStatus s) => switch (s) {
      YearStatus.current => (label: 'En cours', color: kGreen),
      YearStatus.upcoming => (label: 'À venir', color: kNavy),
      YearStatus.archived => (label: 'Archivée', color: kTextMuted),
      YearStatus.locked => (label: 'Archivée', color: kAccent),
      YearStatus.none => (label: '—', color: kTextMuted),
    };

/// Sélecteur d'année scolaire (header). Bascule la lentille globale
/// [selectedYearIdProvider] → re-scope instantané de toutes les pages.
class YearSelector extends ConsumerWidget {
  const YearSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeYearProvider);
    final years = ref.watch(academicYearsProvider).valueOrNull ?? const [];
    if (active == null && years.isEmpty) return const SizedBox.shrink();

    final st = _statusStyle(yearStatusOf(active));

    // Tri : en cours / à venir d'abord, archivées ensuite (par date desc).
    final sorted = [...years]..sort((a, b) => b.startDate.compareTo(a.startDate));
    final live = sorted.where((y) => !y.isLocked).toList();
    final archived = sorted.where((y) => y.isLocked).toList();

    return PopupMenuButton<String>(
      tooltip: 'Changer d\'année scolaire',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (id) =>
          ref.read(selectedYearIdProvider.notifier).select(id),
      itemBuilder: (_) => [
        for (final y in live) _item(y, active),
        if (archived.isNotEmpty && live.isNotEmpty)
          const PopupMenuDivider(),
        if (archived.isNotEmpty)
          PopupMenuItem<String>(
            enabled: false,
            height: 28,
            child: Text('ARCHIVES',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: kTextMuted,
                    letterSpacing: 0.8)),
          ),
        for (final y in archived) _item(y, active),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_rounded, size: 15, color: st.color),
            const SizedBox(width: 7),
            Text(
              active?.label ?? '—',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: st.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(st.label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: st.color)),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 16, color: kTextMuted),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(AcademicYearModel y, AcademicYearModel? active) {
    final st = _statusStyle(yearStatusOf(y));
    final selected = y.id == active?.id;
    return PopupMenuItem<String>(
      value: y.id,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.calendar_today_rounded,
            size: 16,
            color: selected ? kNavy : kTextMuted,
          ),
          const SizedBox(width: 10),
          Text(y.label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: kTextPrimary)),
          const SizedBox(width: 10),
          AdminBadge(st.label, color: st.color),
        ],
      ),
    );
  }
}

/// Bandeau « lecture seule » affiché sous le header quand l'année active est
/// archivée / verrouillée / non-courante.
class ReadOnlyYearBanner extends ConsumerWidget {
  const ReadOnlyYearBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readOnly = ref.watch(yearReadOnlyProvider);
    final year = ref.watch(activeYearProvider);
    if (!readOnly || year == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      color: kAccent.withValues(alpha: 0.14),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded, size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Année ${year.label} — consultation seule. '
              'Repassez sur l\'année en cours pour modifier les données.',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}
