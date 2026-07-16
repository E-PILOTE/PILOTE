import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_shell.dart';
import '../providers/national_map_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
Color get _kCard => kCardBg;
Color get _kText => kTextPrimary;
Color get _kSub => kTextMuted;
Color get _kBg => kSurface;

// ─── Selected dept state ─────────────────────────────────────────────────────
final _selectedDeptProv = StateProvider.autoDispose<DeptMapEntry?>((ref) => null);

// ─── Screen ───────────────────────────────────────────────────────────────────

class NationalMapScreen extends ConsumerWidget {
  const NationalMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Vue Nationale de Pilotage',
      child: NationalMapView(),
    );
  }
}

/// Corps de la vue nationale, réutilisable hors AppShell (ex. onglet du
/// Tableau de bord). Doit être placé dans un parent à hauteur bornée.
class NationalMapView extends ConsumerWidget {
  const NationalMapView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nationalMapProvider);

    return async.when(
      skipLoadingOnReload: true, skipLoadingOnRefresh: true,
      loading: () => const _Loading(),
      error:   (e, _) => _Err(error: e.toString(), onRetry: () => ref.invalidate(nationalMapProvider)),
      data:    (data) => _MapLayout(data: data),
    );
  }
}

// ─── Layout ───────────────────────────────────────────────────────────────────

class _MapLayout extends ConsumerWidget {
  const _MapLayout({required this.data});
  final NationalMapData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedDeptProv);

    return Row(
      children: [
        // ── Panneau gauche (stats + liste depts) ──────────────────────
        SizedBox(
          width: 300,
          child: Container(
            color: _kCard,
            child: Column(
              children: [
                _GlobalStats(data: data),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(child: _DeptList(data: data)),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),

        // ── Carte centrale ────────────────────────────────────────────
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              _OsmMap(data: data),
              // Bouton actualiser
              Positioned(
                top: 12, right: 12,
                child: FloatingActionButton.small(
                  heroTag: 'refresh_map',
                  backgroundColor: _kNavy,
                  tooltip: 'Actualiser',
                  onPressed: () => ref.invalidate(nationalMapProvider),
                  child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),

        // ── Panneau droit (détail département / analytics nationales) ─
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          width: 300,
          child: selected != null
              ? SingleChildScrollView(child: _DeptDetail(dept: selected))
              : SingleChildScrollView(child: _NationalAnalytics(data: data)),
        ),
      ],
    );
  }
}

// ─── Global stats strip ───────────────────────────────────────────────────────

class _GlobalStats extends StatelessWidget {
  const _GlobalStats({required this.data});
  final NationalMapData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kNavy, const Color(0xFF2A4F7A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONGO-BRAZZAVILLE', style: TextStyle(
            color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          const Text('Vue Nationale', style: TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            _StatPill(value: '${data.coveredDepts}', label: 'Départ.', icon: Icons.map_rounded),
            const SizedBox(width: 8),
            _StatPill(value: '${data.totalGroups}', label: 'Groupes', icon: Icons.school_rounded),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _StatPill(value: '${data.totalSchools}',  label: 'Écoles',   icon: Icons.business_rounded),
            const SizedBox(width: 8),
            _StatPill(value: '${data.totalStudents}', label: 'Élèves',   icon: Icons.people_rounded),
          ]),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.value, required this.label, required this.icon});
  final String value; final String label; final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: _kGold),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        ]),
      ]),
    ),
  );
}

// ─── Department list ──────────────────────────────────────────────────────────

class _DeptList extends ConsumerWidget {
  const _DeptList({required this.data});
  final NationalMapData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedDeptProv);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: data.depts.length,
      itemBuilder: (_, i) {
        final dept = data.depts[i];
        final isSelected = selected?.dept == dept.dept;
        final rate = dept.groupCount > 0
            ? dept.activeGroups / dept.groupCount : 0.0;

        return InkWell(
          onTap: () {
            ref.read(_selectedDeptProv.notifier).state = isSelected ? null : dept;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            color: isSelected ? _kNavy.withValues(alpha: 0.06) : Colors.transparent,
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: i < 3 ? _kGold.withValues(alpha: 0.15) : _kBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(child: Text('${i + 1}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: i < 3 ? const Color(0xFFB45309) : _kSub))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dept.dept,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      LinearProgressIndicator(
                        value: rate.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: _kBg,
                        valueColor: AlwaysStoppedAnimation(rate > 0.6 ? _kGreen : _kGold),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 2),
                      Text('${dept.groupCount} groupes · ${dept.schoolCount} écoles · ${dept.studentCount} élèves',
                          style: TextStyle(fontSize: 9, color: _kSub)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${dept.activeGroups} actifs',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _kGreen)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── OSM Map ──────────────────────────────────────────────────────────────────

class _OsmMap extends ConsumerStatefulWidget {
  const _OsmMap({required this.data});
  final NationalMapData data;

  @override
  ConsumerState<_OsmMap> createState() => _OsmMapState();
}

class _OsmMapState extends ConsumerState<_OsmMap> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(_selectedDeptProv);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: congoCenter,
        initialZoom:   5.5,
        minZoom: 4,
        maxZoom: 12,
        onTap: (_, _) => ref.read(_selectedDeptProv.notifier).state = null,
      ),
      children: [
        // OSM tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.epilote.congo',
          maxZoom: 18,
        ),

        // Department markers
        MarkerLayer(
          markers: widget.data.depts.map((dept) {
            final isSelected  = selected?.dept == dept.dept;
            final isUrgent    = dept.activeGroups == 0 && dept.groupCount > 0;
            final markerColor = isUrgent
                ? const Color(0xFFEF4444)
                : isSelected
                    ? _kGold
                    : _kNavy;

            return Marker(
              point: dept.coords,
              width: isSelected ? 140 : 100,
              height: isSelected ? 64 : 54,
              child: GestureDetector(
                onTap: () {
                  ref.read(_selectedDeptProv.notifier).state =
                      isSelected ? null : dept;
                  // Fly to marker
                  _mapController.move(dept.coords, 7.0);
                },
                child: Column(
                  children: [
                    // Bubble
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: markerColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(
                          color: markerColor.withValues(alpha: 0.35),
                          blurRadius: 8, offset: const Offset(0, 3),
                        )],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(dept.dept,
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (isSelected) ...[
                            const SizedBox(height: 2),
                            Text('${dept.groupCount} groupes · ${dept.schoolCount} écoles',
                                style: const TextStyle(color: Colors.white70, fontSize: 8)),
                          ] else
                            Text('${dept.groupCount} gr.',
                                style: const TextStyle(color: Colors.white70, fontSize: 8)),
                        ],
                      ),
                    ),
                    // Arrow pointer
                    CustomPaint(
                      size: const Size(12, 8),
                      painter: _ArrowPainter(color: markerColor),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // Attribution
        const RichAttributionWidget(attributions: [
          TextSourceAttribution('OpenStreetMap contributors'),
        ]),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = ui.Paint()..color = color;
    final path  = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}

// ─── Department detail panel ──────────────────────────────────────────────────

class _DeptDetail extends ConsumerWidget {
  const _DeptDetail({required this.dept});
  final DeptMapEntry dept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = dept.groupCount > 0
        ? dept.activeGroups / dept.groupCount : 0.0;

    return Container(
      color: _kCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kNavy, const Color(0xFF2A4F7A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(dept.dept,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                    onPressed: () => ref.read(_selectedDeptProv.notifier).state = null,
                  ),
                ]),
                const SizedBox(height: 8),
                const Text('Département · République du Congo',
                    style: TextStyle(color: Colors.white60, fontSize: 10)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI grid
                Row(children: [
                  _DetailKpi(value: '${dept.groupCount}', label: 'Groupes',      color: _kNavy),
                  const SizedBox(width: 8),
                  _DetailKpi(value: '${dept.schoolCount}', label: 'Écoles',      color: _kGreen),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _DetailKpi(value: '${dept.studentCount}', label: 'Élèves',     color: const Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  _DetailKpi(value: '${dept.activeGroups}',  label: 'Actifs',    color: _kGold.withValues(alpha: 1.0)),
                ]),

                const SizedBox(height: 16),

                // Activation rate
                Text('Taux d\'activation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kText)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: LinearProgressIndicator(
                    value: rate.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: _kBg,
                    valueColor: AlwaysStoppedAnimation(rate > 0.6 ? _kGreen : _kGold),
                    borderRadius: BorderRadius.circular(4),
                  )),
                  const SizedBox(width: 8),
                  Text('${(rate * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: rate > 0.6 ? _kGreen : _kGold)),
                ]),

                if (dept.groups.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Groupes scolaires', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kText)),
                  const SizedBox(height: 8),
                  ...dept.groups.map((g) => _GroupRow(group: g)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailKpi extends StatelessWidget {
  const _DetailKpi({required this.value, required this.label, required this.color});
  final String value; final String label; final Color color;

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
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: _kSub)),
      ]),
    ),
  );
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group});
  final dynamic group;

  @override
  Widget build(BuildContext context) {
    final status = group.status as String;
    final isActive = status == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: isActive ? _kGreen : const Color(0xFFF59E0B),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(group.name as String,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kText),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(group.planName as String,
                style: TextStyle(fontSize: 9, color: _kSub),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

// ─── Panneau analytique national (affiché quand aucun dept sélectionné) ────────

class _NationalAnalytics extends StatelessWidget {
  const _NationalAnalytics({required this.data});
  final NationalMapData data;

  @override
  Widget build(BuildContext context) {
    final totalActive = data.depts.fold<int>(0, (s, d) => s + d.activeGroups);
    final activationRate = data.totalGroups > 0
        ? (totalActive / data.totalGroups * 100).toStringAsFixed(0) : '0';
    final avgSchools = data.totalGroups > 0
        ? (data.totalSchools / data.totalGroups).toStringAsFixed(1) : '0';

    // Top depts sorted by group count
    final topDepts = [...data.depts]
      ..sort((a, b) => b.groupCount.compareTo(a.groupCount));

    // Alert depts (0 groups or 0 active)
    final alertDepts = data.depts.where((d) => d.groupCount == 0 || d.activeGroups == 0).toList();

    return Container(
      color: _kCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kNavy, const Color(0xFF2A4F7A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.analytics_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Analyse Nationale', style: TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
                SizedBox(height: 4),
                Text('Statistiques en temps réel',
                    style: TextStyle(color: Colors.white60, fontSize: 10)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPIs nationaux
                Text('INDICATEURS CLÉS', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 1.0)),
                const SizedBox(height: 10),
                Row(children: [
                  _AnalyticKpi(label: "Taux d'activation", value: '$activationRate%', color: _kGreen),
                  const SizedBox(width: 8),
                  _AnalyticKpi(label: 'Écoles/Groupe', value: avgSchools, color: _kNavy),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _AnalyticKpi(label: 'Depts couverts', value: '${data.coveredDepts}/12', color: _kGold),
                  const SizedBox(width: 8),
                  _AnalyticKpi(label: 'Total élèves', value: '${data.totalStudents}', color: const Color(0xFF7C3AED)),
                ]),

                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),

                // Classement départements
                Text('CLASSEMENT PAR GROUPES', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 1.0)),
                const SizedBox(height: 10),
                ...topDepts.take(6).toList().asMap().entries.map((e) {
                  final i = e.key; final d = e.value;
                  final max = topDepts.first.groupCount;
                  final rate = max > 0 ? d.groupCount / max : 0.0;
                  final rankColor = i == 0 ? const Color(0xFFB45309)
                      : i == 1 ? _kSub
                      : i == 2 ? const Color(0xFFB45309).withValues(alpha: 0.6)
                      : _kNavy;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: (i < 3 ? _kGold : _kBg).withValues(alpha: i < 3 ? 0.2 : 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(child: Text('${i + 1}', style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w800, color: rankColor))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(d.dept, style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: _kText),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text('${d.groupCount}', style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: _kNavy)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const SizedBox(width: 28),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: rate.clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: _kBg,
                                valueColor: AlwaysStoppedAnimation(
                                  d.activeGroups == 0 ? const Color(0xFFEF4444) : _kGreen),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${d.activeGroups} actifs', style: TextStyle(fontSize: 9, color: _kSub)),
                        ]),
                      ],
                    ),
                  );
                }),

                if (alertDepts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  const Text('ALERTES', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFEF4444), letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  ...alertDepts.map((d) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.dept, style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: _kText)),
                          Text(d.groupCount == 0
                              ? 'Aucun groupe enregistré'
                              : 'Aucun groupe actif (${d.groupCount} inactif${d.groupCount > 1 ? "s" : ""})',
                              style: const TextStyle(fontSize: 9, color: Color(0xFFEF4444))),
                        ],
                      )),
                    ]),
                  )),
                ],

                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kNavy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COUVERTURE NATIONALE', style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 1.0)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: data.coveredDepts / 15,
                          minHeight: 10,
                          backgroundColor: _kBg,
                          valueColor: AlwaysStoppedAnimation(_kGreen),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${data.coveredDepts} / 15 départements couverts (${(data.coveredDepts / 15 * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kNavy)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticKpi extends StatelessWidget {
  const _AnalyticKpi({required this.label, required this.value, required this.color});
  final String label; final String value; final Color color;

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
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: _kSub), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ─── Loading / Error ──────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: _kNavy),
      const SizedBox(height: 16),
      Text('Chargement de la carte nationale…', style: TextStyle(fontSize: 13, color: _kSub)),
    ]),
  );
}

class _Err extends StatelessWidget {
  const _Err({required this.error, required this.onRetry});
  final String error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
    const SizedBox(height: 12),
    Text(error, style: TextStyle(fontSize: 12, color: _kSub), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Réessayer')),
  ]));
}
