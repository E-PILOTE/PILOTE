part of '../admin_regional_view.dart';

// ─── Widgets utilitaires locaux ──────────────────────────────────────────────
class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: Colors.white)),
      );
}

class _DetailKpi extends StatelessWidget {
  const _DetailKpi(
      {required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: color),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label,
                style: TextStyle(fontSize: 9, color: kTextMuted),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _TypeMix extends StatelessWidget {
  const _TypeMix({required this.schools});
  final List<AdminSchoolPin> schools;

  @override
  Widget build(BuildContext context) {
    if (schools.isEmpty) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final s in schools) {
      counts[s.type] = (counts[s.type] ?? 0) + 1;
    }
    const order = ['public', 'prive'];
    final present = [
      ...order.where((t) => (counts[t] ?? 0) > 0),
      ...counts.keys.where((k) => !order.contains(k)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("TYPES D'ÉTABLISSEMENT",
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: kTextMuted, letterSpacing: 0.8)),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(children: [
          for (final t in present)
            Expanded(
              flex: counts[t]!,
              child: Container(height: 8, color: _typeColor(t)),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 4, children: [
        for (final t in present)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: _typeColor(t), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('${_typeLabel(t)} · ${counts[t]}',
                style: TextStyle(
                    fontSize: 10, color: kTextPrimary)),
          ]),
      ]),
    ]);
  }
}

class _AnalyticKpi extends StatelessWidget {
  const _AnalyticKpi(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: TextStyle(fontSize: 9, color: kTextMuted),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ─── Fonctions utilitaires ───────────────────────────────────────────────────
String _typeLabel(String t) => switch (t) {
      'public' => 'Public',
      'prive'  => 'Privé',
      _        => t,
    };

Color _typeColor(String t) => switch (t) {
      'public' => _kBlue,
      'prive'  => kGreen,
      _        => kTextMuted,
    };

Color _typeColorForPin(String t) => switch (t) {
      'public' => _kBlue,
      'prive'  => kGreen,
      _        => kNavy,
    };

String _projectStatusLabel(String s) => switch (s) {
      'etude'         => 'Étude',
      'validation'    => 'Validation',
      'budgetisation' => 'Budgétisation',
      'construction'  => 'Construction',
      'acheve'        => 'Achevé',
      _               => s,
    };

Color _projectStatusColor(String s) => switch (s) {
      'etude'         => kTextMuted,
      'validation'    => kAccent,
      'budgetisation' => _kOrange,
      'construction'  => _kBlue,
      'acheve'        => kGreen,
      _               => kTextMuted,
    };

IconData _projectStatusIcon(String s) => switch (s) {
      'etude'         => Icons.search_rounded,
      'validation'    => Icons.fact_check_rounded,
      'budgetisation' => Icons.account_balance_rounded,
      'construction'  => Icons.construction_rounded,
      'acheve'        => Icons.check_circle_rounded,
      _               => Icons.circle_outlined,
    };

String _locationSourceLabel(String? s) => switch (s) {
      'gps'      => 'GPS terrain',
      'geocoded' => 'Géocodé',
      'manual'   => 'Manuel',
      _          => 'Source inconnue',
    };

Color _locationSourceColor(String? s) => switch (s) {
      'gps'      => kGreen,
      'geocoded' => kAccent,
      'manual'   => _kBlue,
      _          => kTextMuted,
    };

String _priorityLabel(String p) => switch (p) {
      'haute'   => 'Priorité haute',
      'moyenne' => 'Priorité moyenne',
      'basse'   => 'Priorité basse',
      _         => p,
    };

Color _priorityColor(String p) => switch (p) {
      'haute'   => kRed,
      'moyenne' => _kOrange,
      'basse'   => kGreen,
      _         => kTextMuted,
    };

String _fmtDate(DateTime? dt) {
  if (dt == null) return '—';
  return '${dt.day.toString().padLeft(2, '0')} '
      '${_months[dt.month - 1]} ${dt.year}';
}

const _months = [
  'janv.', 'févr.', 'mars', 'avr.',
  'mai', 'juin', 'juil.', 'août',
  'sept.', 'oct.', 'nov.', 'déc.',
];

String _truncate(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}…';

/// Diamètre bulle départementale proportionnel à l'effectif (échelle √).
double _bubbleDiameter(int students, int maxStudents) {
  if (maxStudents <= 0) return 30;
  final r = (students / maxStudents).clamp(0.0, 1.0);
  return 30 + 30 * math.sqrt(r);
}

// ─── Analyse territoriale — distances réelles (Haversine via latlong2) ────────
// AUCUNE donnée inventée : ne calcule que sur des coordonnées GPS réelles
// (écoles géolocalisées) et les villes/bourgs réels OpenStreetMap.
const Distance _kGeo = Distance();

class _IsolationStat {
  const _IsolationStat({
    required this.school,
    required this.nearestSchool,
    required this.nearestSchoolKm,
    required this.nearestCity,
    required this.nearestCityKm,
  });
  final AdminSchoolPin school;
  final AdminSchoolPin? nearestSchool;
  final double? nearestSchoolKm; // null si < 2 écoles géolocalisées
  final String nearestCity;
  final double nearestCityKm;
}

class _TerritorialReport {
  const _TerritorialReport({
    required this.gpsSchools,
    required this.totalSchools,
    required this.stats,
    required this.avgNearestKm,
    required this.avgCityKm,
  });
  final int gpsSchools;
  final int totalSchools;
  final List<_IsolationStat> stats; // trié : plus isolé d'abord
  final double? avgNearestKm;
  final double? avgCityKm;

  bool get hasAny => gpsSchools >= 1;
  bool get hasPairwise => gpsSchools >= 2;
}

_TerritorialReport _buildTerritorialReport(
  AdminRegionalData data,
  List<GeoPlace> agglomerations,
) {
  final gps = data.gpsSchools.where((s) => s.hasGps).toList();
  final stats = <_IsolationStat>[];
  double sumNearest = 0;
  int countNearest = 0;
  double sumCity = 0;
  int countCity = 0;

  // Agglomérations de référence : villes & bourgs réels (OpenStreetMap).
  // Repli sur les chefs-lieux départementaux tant que la couche localités
  // n'est pas chargée — aucune coordonnée inventée dans les deux cas.
  final aggloList = agglomerations.isNotEmpty
      ? [for (final p in agglomerations) (p.name, p.coords)]
      : [for (final e in adminMajorAgglomerations.entries) (e.key, e.value)];

  for (final s in gps) {
    final sc = s.gpsCoords!;

    AdminSchoolPin? near;
    double? nearKm;
    for (final o in gps) {
      if (identical(o, s)) continue;
      final km = _kGeo.as(LengthUnit.Kilometer, sc, o.gpsCoords!);
      if (nearKm == null || km < nearKm) {
        nearKm = km;
        near = o;
      }
    }
    if (nearKm != null) {
      sumNearest += nearKm;
      countNearest++;
    }

    String city = '—';
    double cityKm = double.infinity;
    for (final (name, coord) in aggloList) {
      final km = _kGeo.as(LengthUnit.Kilometer, sc, coord);
      if (km < cityKm) {
        cityKm = km;
        city = name;
      }
    }
    if (cityKm.isFinite) {
      sumCity += cityKm;
      countCity++;
    }

    stats.add(_IsolationStat(
      school: s,
      nearestSchool: near,
      nearestSchoolKm: nearKm,
      nearestCity: city,
      nearestCityKm: cityKm.isFinite ? cityKm : 0,
    ));
  }

  stats.sort((a, b) {
    final ax = a.nearestSchoolKm ?? a.nearestCityKm;
    final bx = b.nearestSchoolKm ?? b.nearestCityKm;
    return bx.compareTo(ax);
  });

  return _TerritorialReport(
    gpsSchools: gps.length,
    totalSchools: data.totalSchools,
    stats: stats,
    avgNearestKm: countNearest > 0 ? sumNearest / countNearest : null,
    avgCityKm: countCity > 0 ? sumCity / countCity : null,
  );
}

String _fmtKm(double? km) {
  if (km == null) return '—';
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}
