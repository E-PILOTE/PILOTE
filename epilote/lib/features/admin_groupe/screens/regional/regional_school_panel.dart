part of '../admin_regional_view.dart';

// ─── Panneau détail école GPS ────────────────────────────────────────────────
class _GpsSchoolDetailPanel extends ConsumerWidget {
  const _GpsSchoolDetailPanel({required this.school});
  final AdminSchoolPin school;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColorForPin(school.type);
    return Container(
      color: kCardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.85), color],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.school_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(school.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w800),
                      maxLines: 2),
                  Text(_typeLabel(school.type),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 18),
                onPressed: () => ref.read(_selectionProv.notifier).state =
                    const SelectionNone(),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              _MiniChip(
                  label: school.isActive ? 'Active' : 'Inactive',
                  color: school.isActive ? kGreen : kRed),
              _MiniChip(
                  label: _locationSourceLabel(school.locationSource),
                  color: _locationSourceColor(school.locationSource)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // KPIs
            Row(children: [
              _DetailKpi(
                  value: '${school.students}', label: 'Élèves', color: kNavy),
              const SizedBox(width: 8),
              _DetailKpi(
                  value: school.department ?? '—',
                  label: 'Département', color: _kBlue),
            ]),
            const SizedBox(height: 14),
            // Coordonnées
            Text('COORDONNÉES GPS',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: kTextMuted, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kSurface, borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                _CoordRow(label: 'Latitude',
                    value: school.latitude!.toStringAsFixed(6)),
                const SizedBox(height: 4),
                _CoordRow(label: 'Longitude',
                    value: school.longitude!.toStringAsFixed(6)),
                if (school.locationCapturedAt != null) ...[
                  const SizedBox(height: 4),
                  _CoordRow(
                      label: 'Capturé le',
                      value: _fmtDate(school.locationCapturedAt)),
                ],
              ]),
            ),
            if (school.city != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.location_city_rounded,
                    size: 13, color: kTextMuted),
                const SizedBox(width: 6),
                Text(school.city!,
                    style: TextStyle(
                        fontSize: 12, color: kTextPrimary,
                        fontWeight: FontWeight.w500)),
              ]),
            ],
            // ── Vue satellite datée (objective, sans intervention terrain) ──
            const SizedBox(height: 14),
            Text('VUE SATELLITE',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: kTextMuted, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            SchoolSatelliteView(center: school.gpsCoords!, title: school.name),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  barrierColor: Colors.black54,
                  builder: (_) => _SchoolGpsDialog(
                    school: school,
                    onSaved: () {
                      ref.invalidate(adminRegionalProvider);
                      // La sélection contient un instantané (anciennes coords) :
                      // on la vide pour que la carte rafraîchie reflète la
                      // nouvelle position sans afficher un panneau périmé.
                      ref.read(_selectionProv.notifier).state =
                          const SelectionNone();
                    },
                  ),
                ),
                icon: const Icon(Icons.edit_location_alt_rounded, size: 15),
                label: const Text('Corriger la position'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kNavy,
                  side: BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Pont vers la fiche complète (page Écoles) : la carte ne duplique
            // pas la gestion de l'école, elle y renvoie.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final all = ref.read(adminSchoolsProvider).valueOrNull;
                  final detail = all?.schools
                      .where((s) => s.id == school.id)
                      .firstOrNull;
                  if (detail == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Fiche en cours de chargement…')));
                    return;
                  }
                  openSchoolDetailDialog(context, ref, detail);
                },
                icon: const Icon(Icons.open_in_full_rounded, size: 15),
                label: const Text('Ouvrir la fiche complète'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CoordRow extends StatelessWidget {
  const _CoordRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: TextStyle(fontSize: 10, color: kTextMuted)),
        ),
        Expanded(
          child: SelectableText(value,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  fontFamily: 'monospace')),
        ),
        GestureDetector(
          onTap: () =>
              Clipboard.setData(ClipboardData(text: value)),
          child: Icon(Icons.copy_rounded, size: 12, color: kTextMuted),
        ),
      ]);
}

