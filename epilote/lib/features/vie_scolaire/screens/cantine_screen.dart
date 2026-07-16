import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/cantine_provider.dart';
import '../widgets/vs_kit.dart';

part 'cantine_roll.dart';

const _kSlug = 'cantine';

// ════════════════════════════════════════════════════════════════════════════
//  CANTINE — pointage des repas. En-tête (date + type de repas) → KPI hero
//  (servis / absents / taux / classes) → panneau Cycle ▸ Niveau ▸ Classe
//  (fréquentation) → couverture par classe ; ouvrir = pointage repas.
// ════════════════════════════════════════════════════════════════════════════
class CantineScreen extends ConsumerWidget {
  const CantineScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Cantine',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  DateTime _date = DateTime.now();
  String _meal = 'dejeuner';
  ScopeSel _scope = const ScopeSel();
  String? _openClassId;

  String get _dateKey => _date.toIso8601String().substring(0, 10);
  String get _dateLabel =>
      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
  MealDay get _day => (date: _dateKey, meal: _meal);
  String? get _activeClassId => _openClassId ?? _scope.classId;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: ColorScheme.light(primary: kNavy)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _scope = const ScopeSel();
        _openClassId = null;
      });
    }
  }

  void _openMeal(VsCoverageRow r) {
    final readOnly = ref.read(yearReadOnlyProvider);
    final canEdit =
        ref.read(canProvider((slug: _kSlug, action: 'update'))) && !readOnly;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealSheet(
        args: (classId: r.classId, date: _dateKey, meal: _meal),
        className: r.className,
        breadcrumb: vsCrumb(r.cycleCode, r.levelCode),
        subtitle: '$_dateLabel · ${mealLabel(_meal)}',
        canEdit: canEdit,
        onChanged: () => ref.invalidate(canteenOverviewProvider(_day)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(canteenOverviewProvider(_day));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        VsHeader(
          title: 'Service de cantine',
          subtitle: 'Fréquentation des repas par cycle, niveau et classe',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            VsPickerBox(
              icon: Icons.event_rounded,
              width: 175,
              onTap: _pickDate,
              child: Text(_dateLabel,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
            const SizedBox(width: 10),
            _MealPicker(
                meal: _meal,
                onChange: (m) => setState(() {
                      _meal = m;
                      _scope = const ScopeSel();
                      _openClassId = null;
                    })),
          ]),
        ),
        const SizedBox(height: 20),
        overview.when(
          loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text('Erreur : $e'))),
          data: _content,
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _content(CanteenOverview ov) {
    if (ov.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: AdminEmptyState(
          icon: Icons.restaurant_outlined,
          title: 'Aucune classe',
          message: 'Aucune classe active dans votre périmètre cette année.',
        ),
      );
    }
    final rate = ov.students == 0 ? 0 : ov.served * 100 ~/ ov.students;
    final notPointed = ov.students - ov.served - ov.absent;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VsHeroKpis(cards: [
        (Icons.restaurant_rounded, 'Repas servis', '${ov.served}', kGreen,
            '$rate% de l\'effectif'),
        (Icons.no_meals_rounded, 'Absents', '${ov.absent}',
            ov.absent == 0 ? kTextMuted : const Color(0xFFF59E0B), 'pointés absents'),
        (Icons.pending_actions_rounded, 'Non pointés', '$notPointed',
            notPointed <= 0 ? kTextMuted : const Color(0xFF0EA5E9),
            'sur ${ov.students} élèves'),
        (Icons.groups_2_rounded, 'Classes', '${ov.classesTotal}', kNavy,
            'au service'),
      ]),
      const SizedBox(height: 16),
      ScopeDrilldownPanel(
        title: 'Fréquentation de la cantine',
        metricLabel: 'Servis',
        unitNoun: 'élèves',
        selected: _scope,
        onSelect: (s) => setState(() {
          _scope = s;
          _openClassId = null;
        }),
        units: vsScopeUnits(ov.rows),
      ),
      if (_scope.active || _openClassId != null) ...[
        const SizedBox(height: 12),
        VsScopeChip(
          label: _activeClassId != null
              ? 'Classe : ${_nameOf(ov, _activeClassId!)}'
              : _scope.label,
          onClear: () => setState(() {
            _scope = const ScopeSel();
            _openClassId = null;
          }),
        ),
      ],
      const SizedBox(height: 18),
      const VsSectionLabel(
          icon: Icons.touch_app_rounded,
          text: 'Ouvrez une classe pour pointer le repas'),
      const SizedBox(height: 12),
      VsCoverageList(
        rows: vsFilterScope(ov.rows, _scope),
        metricLabel: 'servis',
        openLabel: 'Pointer',
        onOpen: _openMeal,
      ),
    ]);
  }

  String _nameOf(CanteenOverview ov, String classId) => ov.rows
          .where((r) => r.classId == classId)
          .map((r) => r.className)
          .firstOrNull ??
      '';
}

class _MealPicker extends StatelessWidget {
  const _MealPicker({required this.meal, required this.onChange});
  final String meal;
  final ValueChanged<String> onChange;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (code, label) in kMealTypes)
          InkWell(
            onTap: () => onChange(code),
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: meal == code ? kNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: meal == code ? Colors.white : kTextMuted)),
            ),
          ),
      ]),
    );
  }
}
