part of '../admin_regional_view.dart';

// ─── Couverture territoriale ─────────────────────────────────────────────────
// Vue d'ÉQUITÉ, pas un registre d'écoles : total réel par département (écoles
// GPS + agrégées) classé pour repérer où le réseau est dense vs sous-doté.
class _DeptCoverage {
  _DeptCoverage(this.dept);
  final String dept;
  int total = 0;
  int active = 0;
  int students = 0;
  LatLng? sumCoords;
  int coordCount = 0;
  final List<AdminSchoolPin> gpsSchools = [];
  AdminDeptEntry? aggregated; // entrée non-GPS d'origine (pour sélection)

  void addGps(AdminSchoolPin s) {
    total += 1;
    if (s.isActive) active += 1;
    students += s.students;
    gpsSchools.add(s);
  }
}

class _CoveragePanel extends ConsumerWidget {
  const _CoveragePanel({required this.data});
  final AdminRegionalData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectionProv).deptOrNull;

    // Fusion : départements agrégés (non-GPS) + écoles GPS regroupées.
    final map = <String, _DeptCoverage>{};
    for (final d in data.depts) {
      final c = map.putIfAbsent(d.dept, () => _DeptCoverage(d.dept));
      c.total += d.schoolCount;
      c.active += d.activeCount;
      c.students += d.studentCount;
      c.aggregated = d;
    }
    for (final s in data.gpsSchools) {
      final key = (s.department == null || s.department!.isEmpty)
          ? 'Sans département'
          : s.department!;
      map.putIfAbsent(key, () => _DeptCoverage(key)).addGps(s);
    }
    final covs = map.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    if (covs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('Aucun établissement\npour ce filtre',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ),
      );
    }

    final maxTotal = covs.first.total == 0 ? 1 : covs.first.total;

    final items = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Row(children: [
          Icon(Icons.travel_explore_rounded, size: 12, color: kNavy),
          const SizedBox(width: 6),
          Expanded(
            child: Text('COUVERTURE TERRITORIALE',
                style: TextStyle(
                    fontSize: 9.5, fontWeight: FontWeight.w800,
                    color: kTextMuted, letterSpacing: 0.8)),
          ),
          Text('${covs.length} dépt.',
              style: TextStyle(fontSize: 9, color: kTextMuted)),
        ]),
      ),
    ];

    for (var i = 0; i < covs.length; i++) {
      final c = covs[i];
      final isSel = selected?.dept == c.dept;
      final density = (c.total / maxTotal).clamp(0.0, 1.0);
      // Sous-dotation visuelle : barre orange si dans le dernier tiers du réseau.
      final low = density < 0.34;
      final barColor = low ? _kOrange : kNavy;
      items.add(InkWell(
        onTap: () {
          final entry = c.aggregated ??
              (c.coordCount == 0 && c.gpsSchools.isEmpty
                  ? null
                  : AdminDeptEntry(
                      dept: c.dept,
                      coords: c.gpsSchools.isNotEmpty
                          ? c.gpsSchools.first.gpsCoords!
                          : const LatLng(-0.7, 15.0),
                      schoolCount: c.total,
                      studentCount: c.students,
                      activeCount: c.active,
                      schools: c.gpsSchools,
                    ));
          ref.read(_selectionProv.notifier).state = (isSel || entry == null)
              ? const SelectionNone()
              : SelectionDept(entry);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: isSel ? kNavy.withValues(alpha: 0.06) : Colors.transparent,
          child: Row(children: [
            SizedBox(
              width: 18,
              child: Text('${i + 1}',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: kTextMuted)),
            ),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(c.dept,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: kTextPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (low)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: _kOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('sous-doté',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: _kOrange)),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: density,
                        minHeight: 4,
                        backgroundColor: kSurface,
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('${c.total} écoles · ${c.students} élèves',
                        style:
                            TextStyle(fontSize: 9, color: kTextMuted)),
                  ]),
            ),
          ]),
        ),
      ));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: items);
  }
}

// ─── Panneau détail département ─────────────────────────────────────────────
class _DeptDetail extends ConsumerWidget {
  const _DeptDetail({required this.dept});
  final AdminDeptEntry dept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate =
        dept.schoolCount > 0 ? dept.activeCount / dept.schoolCount : 0.0;
    return Container(
      color: kCardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kNavyDark, kNavy],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(dept.dept,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.w800))),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 18),
                onPressed: () => ref.read(_selectionProv.notifier).state =
                    const SelectionNone(),
              ),
            ]),
            const Text('Département · République du Congo',
                style: TextStyle(color: Colors.white60, fontSize: 10)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _DetailKpi(value: '${dept.schoolCount}', label: 'Écoles', color: kNavy),
                  const SizedBox(width: 8),
                  _DetailKpi(value: '${dept.activeCount}', label: 'Actives', color: kGreen),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _DetailKpi(value: '${dept.studentCount}', label: 'Élèves', color: _kPurple),
                  const SizedBox(width: 8),
                  _DetailKpi(
                      value: '${(rate * 100).round()}%',
                      label: 'Tx actif',
                      color: rate > 0.6 ? kGreen : kAccent),
                ]),
                const SizedBox(height: 16),
                _TypeMix(schools: dept.schools),
                const SizedBox(height: 14),
                Row(children: [
                  Text('Établissements',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  const Spacer(),
                  Text('${dept.schoolCount}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kNavy)),
                ]),
                const SizedBox(height: 8),
                ...([...dept.schools]
                      ..sort((a, b) => b.students.compareTo(a.students)))
                    .map((s) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(6)),
                          child: Row(children: [
                            Container(
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                color: s.isActive ? kGreen : kTextMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: kTextPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                        [if (s.city != null) s.city!, _typeLabel(s.type)]
                                            .join(' · '),
                                        style: TextStyle(
                                            fontSize: 9, color: kTextMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ]),
                            ),
                            const SizedBox(width: 6),
                            Text('${s.students}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: kNavy)),
                            Text(' él.',
                                style: TextStyle(
                                    fontSize: 8.5, color: kTextMuted)),
                          ]),
                        )),
              ]),
        ),
      ]),
    );
  }
}

