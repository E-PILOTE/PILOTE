import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../providers/staff_attendance_provider.dart';
import '../providers/staff_directory_provider.dart';
import '../widgets/staff_kit.dart';

const _kSlug = 'presences-personnel';

// ════════════════════════════════════════════════════════════════════════════
//  PRÉSENCES DU PERSONNEL — pointage quotidien des agents. Sélecteur de date →
//  KPI hero (présents / retards / absents / non pointés) → feuille d'appel des
//  agents (recherche scalable, statut P/R/A en un tap). 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class PresencesPersonnelScreen extends ConsumerWidget {
  const PresencesPersonnelScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Présences personnel',
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
  final _search = TextEditingController();
  String _q = '';
  StaffAxis _axis = StaffAxis.categorie;
  String? _seg; // segment sélectionné (filtre)

  String get _key => _date.toIso8601String().substring(0, 10);
  bool get _isToday => _key == todayKey();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _mark(String staffId, String status) async {
    final p = ref.read(authNotifierProvider).valueOrNull;
    await runModuleWrite(
      context,
      () => setStaffAttendance(
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        staffId: staffId,
        dateKey: _key,
        status: status,
        recordedBy: p?.id ?? '',
      ),
      success: null,
    );
  }

  /// Action groupée : pointer une liste d'agents (présents par défaut). Si
  /// `overwrite` faux, ne touche pas ceux déjà pointés.
  Future<void> _markBulk(List<StaffMember> agents, String status,
      {bool overwrite = false}) async {
    final ids = [for (final a in agents) a.id];
    if (ids.isEmpty) return;
    final p = ref.read(authNotifierProvider).valueOrNull;
    await runModuleWrite(
      context,
      () => setStaffAttendanceBulk(
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        staffIds: ids,
        dateKey: _key,
        status: status,
        recordedBy: p?.id ?? '',
        overwrite: overwrite,
      ),
      success: 'Pointage appliqué à ${ids.length} agent'
          '${ids.length > 1 ? 's' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffDirectoryProvider);
    final marks = ref.watch(staffAttendanceForDateProvider(_key));
    final canMark = ref.watch(canProvider((slug: _kSlug, action: 'create')));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        VsHeader(
          title: 'Pointage du personnel',
          subtitle: _isToday ? 'Aujourd\'hui — ${_fmt(_date)}' : _fmt(_date),
          trailing: _DateBtn(label: _fmt(_date), onTap: _pickDate),
        ),
        const SizedBox(height: 20),
        staff.when(
          loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text('Erreur : $e'))),
          data: (agents) =>
              _content(agents, marks.valueOrNull ?? const {}, canMark),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _content(
      List<StaffMember> agents, Map<String, AttendanceMark> marks, bool canMark) {
    if (agents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: AdminEmptyState(
          icon: Icons.groups_outlined,
          title: 'Aucun agent',
          message: 'Aucun membre du personnel synchronisé dans votre périmètre.',
        ),
      );
    }
    var present = 0, late = 0, absent = 0;
    for (final m in marks.values) {
      switch (m.status) {
        case 'present':
          present++;
        case 'late':
          late++;
        case 'absent':
          absent++;
      }
    }
    final marked = marks.length;
    final notMarked = agents.length - marked;
    final rate = agents.isEmpty ? 0 : (present + late) * 100 ~/ agents.length;

    // Segments selon l'axe (métrique = présents/retards = "pointés présents").
    final segs = staffSegments(agents, _axis,
        okOf: (a) => marks[a.id]?.status == 'present' || marks[a.id]?.status == 'late');

    // Filtrage : segment sélectionné + recherche.
    final q = _q.trim().toLowerCase();
    final filtered = [
      for (final a in agents)
        if ((_seg == null || staffSegKey(a, _axis) == _seg) &&
            (q.isEmpty || a.searchBlob.contains(q)))
          a
    ];
    final unmarkedVisible =
        [for (final a in filtered) if (marks[a.id] == null) a];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VsHeroKpis(cards: [
        (Icons.check_circle_rounded, 'Présents', '$present', kGreen, 'agents'),
        (Icons.timelapse_rounded, 'Retards', '$late',
            late == 0 ? kTextMuted : const Color(0xFFF59E0B), 'agents'),
        (Icons.cancel_rounded, 'Absents', '$absent',
            absent == 0 ? kTextMuted : kRed, 'agents'),
        (Icons.how_to_reg_rounded, 'Pointés', '$marked/${agents.length}',
            const Color(0xFF0EA5E9), '$rate% présents'),
      ]),
      const SizedBox(height: 18),
      // Distinction : axe + segments cliquables (couverture par segment)
      Row(children: [
        Text('Répartir par',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextMuted)),
        const SizedBox(width: 10),
        StaffAxisToggle(
            axis: _axis,
            onChanged: (a) => setState(() {
                  _axis = a;
                  _seg = null;
                })),
      ]),
      const SizedBox(height: 12),
      StaffSegmentBar(
        segments: segs,
        selected: _seg,
        onSelect: (s) => setState(() => _seg = s),
        metricLabel: 'présents',
      ),
      const SizedBox(height: 14),
      // Actions groupées (sur la sélection visible)
      if (canMark)
        Wrap(spacing: 10, runSpacing: 8, children: [
          StaffBulkButton(
            icon: Icons.done_all_rounded,
            label: _seg == null
                ? 'Tous présents (${unmarkedVisible.length} restants)'
                : 'Segment présent (${unmarkedVisible.length})',
            color: kGreen,
            onTap: unmarkedVisible.isEmpty
                ? null
                : () => _markBulk(unmarkedVisible, 'present'),
          ),
          StaffBulkButton(
            icon: Icons.refresh_rounded,
            label: 'Réinitialiser le pointage',
            color: const Color(0xFFF59E0B),
            onTap: filtered.isEmpty
                ? null
                : () => _markBulk(filtered, 'present', overwrite: true),
          ),
        ]),
      const SizedBox(height: 14),
      if (notMarked > 0)
        VsSectionLabel(
            icon: Icons.info_outline_rounded,
            text: '$notMarked agent${notMarked > 1 ? 's' : ''} non pointé'
                '${notMarked > 1 ? 's' : ''} au total'),
      const SizedBox(height: 10),
      if (agents.length > 8) ...[
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Rechercher un agent parmi ${agents.length}…',
            hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
            prefixIcon:
                Icon(Icons.search_rounded, size: 19, color: kTextMuted),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: kBorder),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
              child: Text('Aucun agent trouvé',
                  style: TextStyle(color: kTextMuted))),
        )
      else
        for (final a in filtered)
          _AgentRow(
            agent: a,
            status: marks[a.id]?.status,
            canMark: canMark,
            onSet: (s) => _mark(a.id, s),
          ),
    ]);
  }
}

// ─── Ligne agent : nom + sélecteur P/R/A ─────────────────────────────────────
class _AgentRow extends StatelessWidget {
  const _AgentRow({
    required this.agent,
    required this.status,
    required this.canMark,
    required this.onSet,
  });
  final StaffMember agent;
  final String? status;
  final bool canMark;
  final ValueChanged<String> onSet;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(agent.lastFirst,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
            Text(staffCategoryLabel(staffCategory(agent.role)),
                style: TextStyle(fontSize: 11, color: kTextMuted)),
          ]),
        ),
        const SizedBox(width: 8),
        for (final (slug, label) in kStaffAttStatuses)
          _StatusChip(
            label: label,
            slug: slug,
            selected: status == slug,
            enabled: canMark,
            onTap: () => onSet(slug),
          ),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.slug,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String label, slug;
  final bool selected, enabled;
  final VoidCallback onTap;

  Color get _color => switch (slug) {
        'present' => kGreen,
        'late' => const Color(0xFFF59E0B),
        'absent' => kRed,
        _ => kTextMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? _color : _color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: selected ? _color : _color.withValues(alpha: 0.25)),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : _color)),
          ),
        ),
      ),
    );
  }
}

class _DateBtn extends StatelessWidget {
  const _DateBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today_rounded, size: 15, color: kNavy),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: kNavy)),
            ]),
          ),
        ),
      );
}
