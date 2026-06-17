import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/staff_ui.dart';
import '../../../data/models/academic_year_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/academic_year_context.dart';
import '../providers/academic_year_provider.dart';

part 'calendar_detail.dart';
part 'calendar_rollover.dart';

final _fmtDate = DateFormat('dd MMM yyyy', 'fr_FR');

/// Rôles autorisés à VOIR le calendrier (config direction/secrétariat).
const _kViewRoles = {'proviseur', 'directeur', 'directeur_etudes', 'secretaire'};
/// Rôles autorisés à ÉDITER (chefs d'établissement uniquement).
const _kEditRoles = {'proviseur', 'directeur'};

/// Année sélectionnée dans la colonne de gauche.
final _selectedYearProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Calendrier scolaire — config NATIVE réservée à la direction (hors catalogue).
/// Années → Trimestres → Séquences. Offline-first, une seule courante par niveau.
class SchoolCalendarScreen extends ConsumerWidget {
  const SchoolCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authNotifierProvider).valueOrNull?.role ?? '';
    return AppShell(
      title: 'Calendrier scolaire',
      child: _kViewRoles.contains(role)
          ? _Body(canEdit: _kEditRoles.contains(role))
          : const _Denied(),
    );
  }
}

class _Denied extends StatelessWidget {
  const _Denied();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: kTextMuted),
            SizedBox(height: 16),
            Text('Réservé à la direction',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kNavy)),
            SizedBox(height: 8),
            Text('La gestion du calendrier scolaire est réservée au chef d\'établissement.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextMuted)),
          ]),
        ),
      );
}

class _Body extends ConsumerWidget {
  const _Body({required this.canEdit});
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearsAsync = ref.watch(academicYearsProvider);
    return yearsAsync.when(
      loading: () => const SplitSkeleton(),
      error: (e, _) => Center(child: Text('Erreur : $e', style: const TextStyle(color: kRed))),
      data: (years) {
        final selected = ref.watch(_selectedYearProvider);
        final current = years.where((y) => y.isCurrent).toList();
        final effId = selected ??
            (current.isNotEmpty ? current.first.id : (years.isNotEmpty ? years.first.id : null));
        final matches = years.where((y) => y.id == effId);
        final selectedYear = matches.isEmpty ? null : matches.first;

        return Row(children: [
          SizedBox(
            width: 340,
            child: _YearsColumn(years: years, selectedId: effId, canEdit: canEdit),
          ),
          Container(width: 1, color: kBorder),
          Expanded(
            child: selectedYear == null
                ? const _EmptyDetail()
                : _YearDetail(year: selectedYear),
          ),
        ]);
      },
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_note_rounded, size: 56, color: kTextMuted),
          SizedBox(height: 12),
          Text('Aucune année scolaire',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kNavy)),
          SizedBox(height: 4),
          Text('Les années sont définies par le groupe et héritées par votre '
              'école. Aucune n\'est encore disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kTextMuted)),
        ]),
      );
}

// ─── Colonne des années ───────────────────────────────────────────────────────
class _YearsColumn extends ConsumerWidget {
  const _YearsColumn({required this.years, required this.selectedId, required this.canEdit});
  final List<AcademicYearModel> years;
  final String? selectedId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 12, 10),
        child: Row(children: [
          Expanded(
            child: Text('Années scolaires',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
          ),
          Tooltip(
            message: 'Les années sont définies par le groupe et héritées par votre école',
            child: Icon(Icons.cloud_done_outlined, size: 17, color: kTextMuted),
          ),
        ]),
      ),
      const Divider(height: 1, color: kBorder),
      Expanded(
        child: years.isEmpty
            ? const Center(child: Text('—', style: TextStyle(color: kTextMuted)))
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: years.length,
                itemBuilder: (_, i) => _YearTile(
                  year: years[i],
                  years: years,
                  selected: years[i].id == selectedId,
                  canEdit: canEdit,
                ),
              ),
      ),
    ]);
  }
}

class _YearTile extends ConsumerWidget {
  const _YearTile({
    required this.year,
    required this.years,
    required this.selected,
    required this.canEdit,
  });
  final AcademicYearModel year;
  final List<AcademicYearModel> years;
  final bool selected, canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(yearContentCountProvider(year.id)).valueOrNull;
    return InkWell(
      onTap: () => ref.read(_selectedYearProvider.notifier).state = year.id,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? kNavy.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? kNavy : kBorder, width: selected ? 1.4 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(year.label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kNavy)),
            ),
            if (year.isCurrent) const _Tag(text: 'Courante', color: kGreen),
            if (year.isLocked) ...[const SizedBox(width: 4), const _Tag(text: 'Archivée', color: kAccent)],
          ]),
          const SizedBox(height: 4),
          Text('${_fmtDate.format(year.startDate)} → ${_fmtDate.format(year.endDate)}',
              style: const TextStyle(fontSize: 11, color: kTextMuted)),
          const SizedBox(height: 6),
          // Contenu de l'année
          Row(children: [
            _CountChip(icon: Icons.class_rounded, value: counts?.classes, label: 'classes'),
            const SizedBox(width: 8),
            _CountChip(icon: Icons.people_rounded, value: counts?.eleves, label: 'élèves'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _MiniBtn(
              label: 'Consulter',
              icon: Icons.visibility_outlined,
              color: kGreen,
              onTap: () {
                ref.read(selectedYearIdProvider.notifier).state = year.id;
                context.go(Routes.userDashboard);
              },
            ),
            const Spacer(),
            if (canEdit && !year.isLocked)
              _MiniBtn(
                label: 'Préparer mes classes',
                icon: Icons.move_up_rounded,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      _PrepClassesDialog(targetYear: year, years: years),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Petite puce « N classes / N élèves » (contenu d'une année).
class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.value, required this.label});
  final IconData icon;
  final int? value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: kTextMuted),
          const SizedBox(width: 4),
          Text('${value ?? '…'} $label',
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: kTextMuted)),
        ]),
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      );
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = kNavy,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );
}
