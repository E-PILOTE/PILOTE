import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/presences_provider.dart';
import '../widgets/vs_kit.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/utils/date_scolaire.dart';

part 'presences_roll.dart';

const _kSlug = kSlugPresences;

// ════════════════════════════════════════════════════════════════════════════
//  PRÉSENCES ÉLÈVES — appel quotidien. En-tête (date + période AM/PM) → KPI hero
//  (présents / absents / retards / classes faites) → panneau Cycle ▸ Niveau ▸
//  Classe (couverture de l'appel) → couverture par classe ; ouvrir une classe =
//  feuille d'appel (présent/absent/retard, heure, justification, finaliser).
// ════════════════════════════════════════════════════════════════════════════
class PresencesScreen extends ConsumerWidget {
  const PresencesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Présences',
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
  String _period = 'AM';
  ScopeSel _scope = const ScopeSel();
  String? _openClassId;

  String get _dateKey => _date.toIso8601String().substring(0, 10);
  String get _dateLabel =>
      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
  AttendanceDay get _day => (date: _dateKey, period: _period);

  String? get _activeClassId => _openClassId ?? _scope.classId;

  Future<void> _pickDate() async {
    final picked = await choisirDateScolaire(context, ref,
        initiale: _date, plafond: DateTime.now().add(const Duration(days: 1)));
    if (picked != null) {
      setState(() {
        _date = picked;
        _scope = const ScopeSel();
        _openClassId = null;
      });
    }
  }

  void _openRoll(VsCoverageRow r) {
    // ⚠️ POINTER, C'EST INSÉRER PUIS METTRE À JOUR. Le premier appui sur un
    // élève non pointé fait un INSERT, que la base réserve au verbe `create`
    // (RLS). Garder l'écran sur le seul `update` laissait un profil doté
    // d'`update` sans `create` voir une feuille active, appuyer, et recevoir un
    // 42501 — code FATAL pour le connecteur : le LOT ENTIER en attente est
    // jeté. Les deux moitiés doivent bouger ensemble.
    final readOnly = ref.read(yearReadOnlyProvider);
    final canEdit = ref.read(canProvider((slug: _kSlug, action: 'create'))) &&
        ref.read(canProvider((slug: _kSlug, action: 'update'))) &&
        !readOnly;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RollSheet(
        args: (classId: r.classId, date: _dateKey, period: _period),
        className: r.className,
        breadcrumb: vsCrumb(r.cycleCode, r.levelCode),
        dateLabel: '$_dateLabel · ${_period == 'AM' ? 'Matin' : 'Après-midi'}',
        canEdit: canEdit,
        onChanged: () => ref.invalidate(attendanceOverviewProvider(_day)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(attendanceOverviewProvider(_day));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        VsHeader(
          title: 'Appel du jour',
          subtitle: 'Présences par cycle, niveau et classe',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            VsPickerBox(
              icon: Icons.event_rounded,
              width: 180,
              onTap: _pickDate,
              child: Text(_dateLabel,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
            const SizedBox(width: 10),
            _PeriodToggle(
              period: _period,
              onChange: (p) => setState(() {
                _period = p;
                _scope = const ScopeSel();
                _openClassId = null;
              }),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        overview.when(
          loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text(messageErreur(e)))),
          data: _content,
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _content(AttendanceOverview ov) {
    if (ov.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: AdminEmptyState(
          icon: Icons.fact_check_outlined,
          title: 'Aucune classe',
          message: 'Aucune classe active dans votre périmètre cette année.',
        ),
      );
    }
    final rate = ov.recorded == 0
        ? 0
        : (ov.present + ov.late) * 100 ~/ ov.recorded;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VsHeroKpis(cards: [
        (Icons.how_to_reg_rounded, 'Présents', '${ov.present}', kGreen,
            '$rate% des pointés'),
        (Icons.person_off_rounded, 'Absents', '${ov.absent}',
            ov.absent == 0 ? kTextMuted : kRed, 'à justifier'),
        (Icons.timelapse_rounded, 'Retards', '${ov.late}',
            ov.late == 0 ? kTextMuted : const Color(0xFFF59E0B), null),
        (Icons.checklist_rounded, 'Appels faits',
            '${ov.classesDone}/${ov.classesTotal}', kNavy, 'classes finalisées'),
      ]),
      const SizedBox(height: 16),
      ScopeDrilldownPanel(
        title: 'Couverture de l\'appel',
        metricLabel: 'Pointés',
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
      VsSectionLabel(
          icon: Icons.touch_app_rounded,
          text: _activeClassId == null
              ? 'Ouvrez une classe pour faire l\'appel'
              : 'Appel — ${_nameOf(ov, _activeClassId!)}'),
      const SizedBox(height: 12),
      VsCoverageList(
        rows: vsFilterScope(ov.rows, _scope),
        metricLabel: 'pointés',
        openLabel: 'Faire l\'appel',
        onOpen: _openRoll,
      ),
    ]);
  }

  String _nameOf(AttendanceOverview ov, String classId) => ov.rows
      .where((r) => r.classId == classId)
      .map((r) => r.className)
      .firstOrNull ??
      '';
}

// ─── Bascule AM / PM ─────────────────────────────────────────────────────────
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChange});
  final String period;
  final ValueChanged<String> onChange;
  @override
  Widget build(BuildContext context) {
    Widget seg(String code, String label) {
      final sel = period == code;
      return InkWell(
        onTap: () => onChange(code),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : kTextMuted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('AM', 'Matin'),
        seg('PM', 'Après-midi'),
      ]),
    );
  }
}
