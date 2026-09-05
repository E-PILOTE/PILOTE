part of '../admin_modules_screen.dart';

// Les quatre panneaux du graphique d’adoption.

extension _ChartParts on _ModuleAdoptionChart {
  Widget _buildSchoolsChart(
      List<MapEntry<String, String>> schools,
      Map<String, int> schoolModCount,
      ModuleAdoptionData data,
      double chartH,
      int totalMods) {
    if (schools.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Aucune école configurée.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
      );
    }

    // IDs des écoles utilisant le module filtré
    final moduleSchoolIds = filterModuleId != null
        ? (data.ranking
                .where((e) => e.moduleId == filterModuleId)
                .firstOrNull
                ?.schoolIds ??
            const <String>{})
        : null;

    final bars = schools.map((s) {
      final modCount = schoolModCount[s.key] ?? 0;
      final pct = totalMods > 0
          ? (modCount / totalMods * 100).clamp(0.0, 100.0)
          : 0.0;
      final baseColor = _barColor(pct);

      Color barColor;
      if (filterModuleId != null) {
        // Surligner les écoles qui utilisent ce module
        barColor = (moduleSchoolIds?.contains(s.key) ?? false)
            ? baseColor
            : kTextMuted.withValues(alpha: 0.22);
      } else if (filterSchoolId != null) {
        // Surligner l'école sélectionnée
        barColor = (s.key == filterSchoolId)
            ? baseColor
            : kTextMuted.withValues(alpha: 0.22);
      } else {
        barColor = baseColor;
      }

      final name =
          s.value.length > 16 ? '${s.value.substring(0, 14)}…' : s.value;
      return _AdoptData(
        label: name,
        pct: pct,
        color: barColor,
        detail: '$modCount/$totalMods',
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Modules adoptés par école',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: kTextMuted),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: chartH,
          child: SfCartesianChart(
            plotAreaBackgroundColor: Colors.transparent,
            borderWidth: 0,
            margin: const EdgeInsets.only(right: 8),
            primaryXAxis: CategoryAxis(
              majorGridLines: const MajorGridLines(width: 0),
              axisLine: const AxisLine(width: 0),
              labelStyle: TextStyle(
                  fontSize: 11,
                  color: kTextMuted,
                  fontWeight: FontWeight.w600),
            ),
            primaryYAxis: NumericAxis(
              minimum: 0,
              maximum: 100,
              labelFormat: '{value}%',
              majorGridLines: MajorGridLines(color: kBorder, width: 0.6),
              axisLine: const AxisLine(width: 0),
              labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
            ),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              format: 'point.x  •  point.y% des modules',
              color: kNavy,
              textStyle:
                  const TextStyle(color: Colors.white, fontSize: 11),
            ),
            series: <CartesianSeries>[
              BarSeries<_AdoptData, String>(
                dataSource: bars,
                xValueMapper: (d, _) => d.label,
                yValueMapper: (d, _) => d.pct,
                pointColorMapper: (d, _) => d.color,
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(6)),
                width: 0.5,
                animationDuration: 500,
                dataLabelSettings: DataLabelSettings(
                  isVisible: true,
                  labelAlignment: ChartDataLabelAlignment.outer,
                  textStyle: TextStyle(
                      fontSize: 10.5,
                      color: kTextPrimary,
                      fontWeight: FontWeight.w700),
                ),
                dataLabelMapper: (d, _) => d.detail,
              ),
              BarSeries<_AdoptData, String>(
                dataSource: bars,
                xValueMapper: (d, _) => d.label,
                yValueMapper: (d, _) => 100 - d.pct,
                pointColorMapper: (d, _) =>
                    d.color.withValues(alpha: 0.07),
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(6)),
                width: 0.5,
                animationDuration: 500,
                isVisibleInLegend: false,
                enableTooltip: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── panel droit : donut vue globale ───────────────────────────────────────

  Widget _buildDonutPanel(ModuleAdoptionData data) {
    double rate(ModuleAdoptionEntry e) =>
        data.totalSchools > 0 ? e.schoolCount / data.totalSchools : 0.0;

    final excellent = data.ranking.where((e) => rate(e) >= 0.8).length;
    final bon =
        data.ranking.where((e) => rate(e) >= 0.5 && rate(e) < 0.8).length;
    final faible =
        data.ranking.where((e) => rate(e) > 0 && rate(e) < 0.5).length;
    final inactif = data.ranking.where((e) => e.schoolCount == 0).length;
    final activeCount =
        data.ranking.where((e) => e.schoolCount > 0).length;

    final slices = [
      if (excellent > 0) _DonutSlice('Excellent ≥ 80 %', excellent, kGreen),
      if (bon > 0)       _DonutSlice('Bon ≥ 50 %',       bon,       kNavy),
      if (faible > 0)    _DonutSlice('Faible < 50 %',    faible,    kAccent),
      if (inactif > 0)   _DonutSlice('Inactif',          inactif,   kTextMuted),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Distribution globale',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: kTextMuted),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: slices.isEmpty
              ? Center(
                  child: Text('—', style: TextStyle(color: kTextMuted)))
              : SfCircularChart(
                  margin: EdgeInsets.zero,
                  annotations: <CircularChartAnnotation>[
                    CircularChartAnnotation(
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$activeCount',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: kNavy)),
                          Text(
                            activeCount == 1
                                ? 'module actif'
                                : 'modules actifs',
                            style: TextStyle(
                                fontSize: 10, color: kTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                  series: <CircularSeries>[
                    DoughnutSeries<_DonutSlice, String>(
                      dataSource: slices,
                      xValueMapper: (d, _) => d.label,
                      yValueMapper: (d, _) => d.count,
                      pointColorMapper: (d, _) => d.color,
                      innerRadius: '62%',
                      radius: '88%',
                      animationDuration: 700,
                      strokeColor: kCardBg,
                      strokeWidth: 2,
                      dataLabelSettings:
                          const DataLabelSettings(isVisible: false),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 4),
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.label,
                    style: TextStyle(
                        fontSize: 11.5, color: kTextMuted)),
              ),
              Text('${s.count}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ]),
          ),
      ],
    );
  }

  // ── panel droit : quelles écoles utilisent le module filtré ───────────────

  Widget _buildModuleBreakdown(ModuleAdoptionData data) {
    final entry = data.ranking
        .where((e) => e.moduleId == filterModuleId)
        .firstOrNull;
    if (entry == null) {
      return Text('Module non trouvé dans les données d\'adoption.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted));
    }
    final pct = data.totalSchools > 0
        ? entry.schoolCount / data.totalSchools
        : 0.0;
    final color = _barColor(pct * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (entry.icon != null) ...[
            Text(entry.icon!, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              entry.moduleName,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          '${entry.schoolCount} / ${data.totalSchools} '
          'école${data.totalSchools > 1 ? 's' : ''}',
          style: TextStyle(fontSize: 11.5, color: kTextMuted),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: kBorder,
            color: color,
          ),
        ),
        const SizedBox(height: 12),
        // Liste de toutes les écoles : ✅ utilisent / ○ n'utilisent pas
        ...data.schoolNames.entries.map((s) {
          final uses = entry.schoolIds.contains(s.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: uses ? color : Colors.transparent,
                  border:
                      Border.all(color: uses ? color : kBorder, width: 1.5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: uses ? kTextPrimary : kTextMuted,
                    fontWeight:
                        uses ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (uses) Icon(Icons.check_rounded, size: 13, color: color),
            ]),
          );
        }),
      ],
    );
  }

  // ── panel droit : modules actifs de l'école filtrée ──────────────────────

  Widget _buildSchoolDetail(
      Map<String, int> schoolModCount, ModuleAdoptionData data) {
    final schoolName  = data.schoolNames[filterSchoolId] ?? '—';
    final modCount    = schoolModCount[filterSchoolId] ?? 0;
    final total       = data.ranking.length;
    final pct         = total > 0 ? modCount / total : 0.0;
    final color       = _barColor(pct * 100);
    final usedModules = data.ranking
        .where((e) => e.schoolIds.contains(filterSchoolId))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          schoolName,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '$modCount / $total module${total > 1 ? 's' : ''} utilisé${modCount > 1 ? 's' : ''}',
          style: TextStyle(fontSize: 11.5, color: kTextMuted),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: kBorder,
            color: color,
          ),
        ),
        const SizedBox(height: 12),
        if (usedModules.isEmpty)
          Text(
            'Aucun module configuré pour cette école.',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          )
        else ...[
          Text('Modules actifs',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted)),
          const SizedBox(height: 6),
          ...usedModules.take(8).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(children: [
                  if (e.icon != null) ...[
                    Text(e.icon!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                  ] else ...[
                    Icon(Icons.widgets_outlined,
                        size: 13,
                        color: kNavy.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      e.moduleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: kTextPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.check_rounded, size: 13, color: color),
                ]),
              )),
          if (usedModules.length > 8)
            Text(
              '+ ${usedModules.length - 8} autres',
              style: TextStyle(fontSize: 11, color: kTextMuted),
            ),
        ],
      ],
    );
  }
}
