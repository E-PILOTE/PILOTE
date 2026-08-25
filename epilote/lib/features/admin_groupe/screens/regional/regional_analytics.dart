part of '../admin_regional_view.dart';

// ─── Analyse régionale ───────────────────────────────────────────────────────
class _RegionalAnalytics extends ConsumerWidget {
  const _RegionalAnalytics({required this.data});
  final AdminRegionalData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(adminProjectsProvider);
    // Classement départemental : sur TOUTES les écoles (GPS incluses), sinon
    // le classement se vide dès que les écoles sont géolocalisées.
    final maxSchools    = data.allDepts.isEmpty
        ? 1
        : data.allDepts.fold(0, (m, d) => d.schoolCount > m ? d.schoolCount : m);
    final avgStudents   = data.totalSchools > 0
        ? (data.totalStudents / data.totalSchools).toStringAsFixed(1)
        : '0';
    final gpsPct = data.totalSchools > 0
        ? (data.gpsCount * 100 / data.totalSchools).round()
        : 0;

    return Container(
      color: kCardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kNavyDark, kNavy],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.analytics_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Analyse régionale',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
                SizedBox(height: 4),
                Text('Répartition des établissements',
                    style: TextStyle(color: Colors.white60, fontSize: 10)),
              ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GPS coverage
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kGreen.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kGreen.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.gps_fixed_rounded,
                        size: 16, color: kGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$gpsPct% géolocalisées',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kTextPrimary)),
                            Text('${data.gpsCount} / ${data.totalSchools} écoles avec GPS',
                                style: TextStyle(
                                    fontSize: 9, color: kTextMuted)),
                          ]),
                    ),
                    if (data.noGpsCount > 0)
                      Text('${data.noGpsCount} sans',
                          style: TextStyle(
                              fontSize: 10, color: kRed,
                              fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 12),
                // Projets summary
                projectsAsync.maybeWhen(
                  data: (projects) {
                    if (projects.isEmpty) return const SizedBox.shrink();
                    final inProgress = projects
                        .where((p) => p.status != 'acheve')
                        .length;
                    final done = projects
                        .where((p) => p.status == 'acheve')
                        .length;
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _kOrange.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.business_center_rounded,
                            size: 16, color: _kOrange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${projects.length} projet${projects.length > 1 ? 's' : ''}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: kTextPrimary)),
                                Text('$inProgress en cours · $done achevé${done > 1 ? 's' : ''}',
                                    style: TextStyle(
                                        fontSize: 9, color: kTextMuted)),
                              ]),
                        ),
                      ]),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                _TerritorialAnalysis(data: data),
                const SizedBox(height: 14),
                Text('INDICATEURS CLÉS',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: kTextMuted, letterSpacing: 1.0)),
                const SizedBox(height: 10),
                Row(children: [
                  _AnalyticKpi(
                      label: 'Élèves/École',
                      value: avgStudents, color: kNavy),
                  const SizedBox(width: 8),
                  _AnalyticKpi(
                      label: 'Départements',
                      value: '${data.coveredDepts}', color: kAccent),
                ]),
                const SizedBox(height: 16),
                _TypeMix(
                    schools: [
                  for (final d in data.depts) ...d.schools,
                  ...data.gpsSchools,
                ]),
                const SizedBox(height: 16),
                Divider(color: kBorder),
                const SizedBox(height: 12),
                const _CreationsTimeline(),
                const SizedBox(height: 16),
                Divider(color: kBorder),
                const SizedBox(height: 12),
                Text('CLASSEMENT PAR ÉCOLES',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: kTextMuted, letterSpacing: 1.0)),
                const SizedBox(height: 10),
                ...data.allDepts.take(8).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final d = e.value;
                  final ratio =
                      maxSchools > 0 ? d.schoolCount / maxSchools : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: (i < 3 ? kAccent : kSurface)
                                    .withValues(alpha: i < 3 ? 0.2 : 1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: i < 3
                                              ? const Color(0xFFB45309)
                                              : kTextMuted))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(d.dept,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: kTextPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                            Text('${d.schoolCount}',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: kNavy)),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            const SizedBox(width: 28),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: ratio.clamp(0.0, 1.0),
                                  minHeight: 5,
                                  backgroundColor: kSurface,
                                  valueColor: AlwaysStoppedAnimation(
                                      d.activeCount == 0 ? kRed : kGreen),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${d.studentCount} él.',
                                style: TextStyle(
                                    fontSize: 9, color: kTextMuted)),
                          ]),
                        ]),
                  );
                }),
                const SizedBox(height: 16),
                Divider(color: kBorder),
                const SizedBox(height: 12),
                const _DataGaps(),
              ]),
        ),
      ]),
    );
  }
}

// ─── Timeline des créations d'écoles (par année de fondation) ────────────────
// Lit `founded_year` via le provider du tableau (SchoolDetail) — donnée réelle
// issue de la création. Histogramme des dernières années + cumul.
class _CreationsTimeline extends ConsumerWidget {
  const _CreationsTimeline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(regionalTableRowsProvider).valueOrNull;
    if (rows == null) {
      return SizedBox(
        height: 60,
        child: Center(
            child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kNavy))),
      );
    }

    // Comptage par année de fondation (on ignore les valeurs nulles/aberrantes).
    final nowY = DateTime.now().year;
    final byYear = <int, int>{};
    var unknown = 0;
    for (final r in rows) {
      final y = r.school.foundedYear;
      if (y == null || y < 1950 || y > nowY) {
        unknown += 1;
      } else {
        byYear[y] = (byYear[y] ?? 0) + 1;
      }
    }

    final header = Text('CRÉATIONS PAR ANNÉE',
        style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: kTextMuted, letterSpacing: 1.0));

    if (byYear.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header,
        const SizedBox(height: 8),
        Text(
            unknown == 0
                ? 'Aucune école.'
                : "Année de fondation non renseignée ($unknown école${unknown > 1 ? 's' : ''}).",
            style: TextStyle(fontSize: 10.5, color: kTextMuted)),
      ]);
    }

    // 8 dernières années couvertes (de la plus ancienne présente à aujourd'hui),
    // bornées à un fenêtrage lisible.
    final years = byYear.keys.toList()..sort();
    final minY = math.max(years.first, nowY - 9);
    final span = [for (var y = minY; y <= nowY; y++) y];
    final maxCount =
        byYear.values.fold(0, (m, v) => v > m ? v : m).clamp(1, 1 << 30);
    final total = byYear.values.fold(0, (s, v) => s + v);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        header,
        const Spacer(),
        Text('$total au total',
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: kNavy)),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        height: 78,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final y in span)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(byYear[y] != null ? '${byYear[y]}' : '',
                          style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: kNavy)),
                      const SizedBox(height: 2),
                      Container(
                        height: 48 * (byYear[y] ?? 0) / maxCount + 2,
                        decoration: BoxDecoration(
                          color: y == nowY ? _kOrange : kNavy,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text("'${y % 100}",
                          style: TextStyle(
                              fontSize: 8, color: kTextMuted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      if (unknown > 0) ...[
        const SizedBox(height: 8),
        Text('$unknown sans année de fondation',
            style: TextStyle(fontSize: 9, color: kTextMuted)),
      ],
    ]);
  }
}

