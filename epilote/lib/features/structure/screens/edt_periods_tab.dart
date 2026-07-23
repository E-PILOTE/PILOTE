part of 'edt_settings_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ONGLET TRAME HORAIRE — la grille de créneaux de l'école (séances / récré /
//  pause). Vide → bouton « Installer la trame standard ». Sinon timeline
//  chronologique éditable. C'est l'ossature des futures grilles d'emploi du temps.
// ════════════════════════════════════════════════════════════════════════════

Color _kindColor(String kind) => switch (kind) {
      'recreation' => const Color(0xFF0EA5E9),
      'pause_meridienne' => const Color(0xFFF59E0B),
      _ => kNavy,
    };

IconData _kindIcon(String kind) => switch (kind) {
      'recreation' => Icons.sports_handball_outlined,
      'pause_meridienne' => Icons.restaurant_outlined,
      _ => Icons.menu_book_outlined,
    };

class _PeriodsTab extends ConsumerStatefulWidget {
  const _PeriodsTab();
  @override
  ConsumerState<_PeriodsTab> createState() => _PeriodsTabState();
}

class _PeriodsTabState extends ConsumerState<_PeriodsTab> {
  String? _cycle; // cycle sélectionné (la trame est PROPRE à chaque cycle)

  void _openForm(BuildContext context,
          {SchoolPeriod? period, int nextIndex = 0, String? cycleCode}) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _PeriodForm(period: period, nextIndex: nextIndex, cycleCode: cycleCode),
      );

  Future<void> _delete(BuildContext context, SchoolPeriod p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer ce créneau de la trame ?'),
        content: Text('« ${p.label} » (${p.timeLabel}) sera retiré de la trame.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runModuleWrite(context, () => deleteSchoolPeriod(p.id),
        success: 'Créneau retiré');
  }

  Future<void> _seed(BuildContext context, String? cycleCode) async {
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final missing = missingWriteIds(
        groupId: profile?.groupId,
        schoolId: profile?.schoolId,
        actorId: profile?.id);
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(writeIdentityMessage(missing)), backgroundColor: kRed));
      return;
    }
    await runModuleWrite(
      context,
      () => seedStandardPeriods(
        groupId: profile!.groupId!,
        schoolId: profile.schoolId!,
        cycleCode: cycleCode,
      ),
      success: 'Trame standard installée',
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(schoolPeriodsProvider);
    final structure =
        ref.watch(academicStructureProvider).valueOrNull ?? AcademicStructure.empty;
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canUpdate = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));

    // Cycles RÉELS configurés pour l'école (chaque cycle a sa propre trame).
    final cycles = structure.cycles;
    if (cycles.isNotEmpty &&
        (_cycle == null || !cycles.any((c) => c.code == _cycle))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _cycle = cycles.first.code);
      });
    }

    if (cycles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: AdminEmptyState(
          icon: Icons.account_tree_outlined,
          title: 'Aucun cycle configuré',
          message:
              'Configurez d\'abord les cycles de l\'établissement (page Structure) '
              'avant de définir leurs trames horaires.',
        ),
      );
    }

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (allPeriods) {
        // Trame du cycle sélectionné uniquement.
        final periods =
            allPeriods.where((p) => p.cycleCode == _cycle).toList();
        final courses = periods.where((p) => p.isCourse).length;
        final totalCourseMin = periods
            .where((p) => p.isCourse)
            .fold<int>(0, (s, p) => s + p.durationMinutes);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Sélecteur de cycle : la trame est propre à chaque cycle.
            _CycleSelector(
              cycles: cycles,
              selected: _cycle,
              periodsByCycle: {
                for (final c in cycles)
                  c.code: allPeriods.where((p) => p.cycleCode == c.code).length,
              },
              onSelect: (code) => setState(() => _cycle = code),
            ),
            const SizedBox(height: 18),
            // KPI compacts.
            LayoutBuilder(builder: (ctx, cns) {
              final cols = cns.maxWidth >= 720 ? 3 : (cns.maxWidth >= 460 ? 2 : 1);
              final items = <(IconData, String, String, Color)>[
                (Icons.view_timeline_outlined, 'Créneaux', '${periods.length}',
                    kNavy),
                (Icons.menu_book_outlined, 'Séances de cours', '$courses',
                    kGreen),
                (Icons.timelapse_rounded, 'Amplitude cours',
                    totalCourseMin > 0
                        ? '${(totalCourseMin / 60).toStringAsFixed(1).replaceAll('.', ',')} h'
                        : '—',
                    const Color(0xFF8B5CF6)),
              ];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 160,
                ),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final (icon, label, value, color) = items[i];
                  return AdminStatCard(
                      label: label, value: value, icon: icon, color: color);
                },
              );
            }),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: AdminSectionTitle('Trame · ${scopeCycleName(_cycle)}',
                    icon: Icons.schedule_rounded,
                    subtitle:
                        'Journée-type du cycle : séances, récréations et pause'),
              ),
              if (canCreate && periods.isNotEmpty)
                AdminActionButton(
                    label: 'Ajouter',
                    icon: Icons.add_rounded,
                    onPressed: () => _openForm(context,
                        nextIndex: periods.length, cycleCode: _cycle)),
            ]),
            const SizedBox(height: 16),
            if (periods.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 26),
                child: Column(children: [
                  AdminEmptyState(
                    icon: Icons.schedule_rounded,
                    title: 'Aucune trame pour ce cycle',
                    message:
                        'Installez la trame standard adaptée au cycle '
                        '${scopeCycleName(_cycle)} puis ajustez-la, ou composez '
                        'la vôtre créneau par créneau.',
                  ),
                  if (canCreate) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        AdminActionButton(
                            label: 'Installer la trame standard',
                            icon: Icons.auto_fix_high_rounded,
                            onPressed: () => _seed(context, _cycle)),
                        AdminActionButton(
                            label: 'Créneau personnalisé',
                            icon: Icons.add_rounded,
                            filled: false,
                            onPressed: () =>
                                _openForm(context, cycleCode: _cycle)),
                      ],
                    ),
                  ],
                ]),
              )
            else
              AdminCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final p in periods)
                      _PeriodRow(
                        period: p,
                        onEdit:
                            canUpdate ? () => _openForm(context, period: p) : null,
                        onDelete: canDelete ? () => _delete(context, p) : null,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period, this.onEdit, this.onDelete});
  final SchoolPeriod period;
  final VoidCallback? onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final color = _kindColor(period.kind);
    final isBreak = !period.isCourse;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(period.timeLabel,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: kTextPrimary)),
        ),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isBreak ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_kindIcon(period.kind), size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(period.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isBreak ? color : kTextPrimary)),
            Text('${periodKindLabel(period.kind)} · ${period.durationMinutes} min',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ]),
        ),
        if (onEdit != null)
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 17, color: kTextMuted),
            onPressed: onEdit,
            tooltip: 'Modifier',
          ),
        if (onDelete != null)
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 17, color: kRed),
            onPressed: onDelete,
            tooltip: 'Supprimer',
          ),
      ]),
    );
  }
}

// ─── Sélecteur de cycle (la trame est PROPRE à chaque cycle) ─────────────────
class _CycleSelector extends StatelessWidget {
  const _CycleSelector({
    required this.cycles,
    required this.selected,
    required this.periodsByCycle,
    required this.onSelect,
  });
  final List<StructCycle> cycles;
  final String? selected;
  final Map<String, int> periodsByCycle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in cycles)
          () {
            final on = c.code == selected;
            final color = scopeCycleColor(c.code);
            final count = periodsByCycle[c.code] ?? 0;
            return InkWell(
              onTap: () => onSelect(c.code),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: on ? color.withValues(alpha: 0.12) : kCardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: on ? color : kBorder, width: on ? 1.5 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(c.name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: on ? color : kTextPrimary)),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: on
                          ? color.withValues(alpha: 0.18)
                          : kSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      count > 0 ? '$count' : '—',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: on ? color : kTextMuted),
                    ),
                  ),
                ]),
              ),
            );
          }(),
      ],
    );
  }
}
