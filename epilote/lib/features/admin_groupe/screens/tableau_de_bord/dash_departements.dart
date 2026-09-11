part of '../admin_dashboard_screen.dart';

// Répartition par département.

class _DeptSection extends StatefulWidget {
  const _DeptSection({required this.data});
  final AdminDashboardData data;

  @override
  State<_DeptSection> createState() => _DeptSectionState();
}

class _DeptSectionState extends State<_DeptSection> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final entries = d.schoolsByDept.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxV =
        entries.isEmpty ? 0 : entries.map((e) => e.value).reduce(math.max);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            'Couverture territoriale',
            icon: Icons.location_city_rounded,
            subtitle: '${d.coveredDepts} département(s) · ${d.ecolesTotal} école(s)',
            trailing: AdminBadge(
              entries.isEmpty ? 'Aucune donnée' : 'Données réelles',
              color: entries.isEmpty ? kTextMuted : kGreen,
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const _InlineEmpty(
                message:
                    'Renseignez le département de vos écoles pour suivre votre couverture.')
          else
            for (final e in entries)
              _DeptBar(
                name: e.key,
                schools: e.value,
                students: d.studentsByDept[e.key] ?? 0,
                maxV: maxV,
                selected: _sel == e.key,
                onTap: () =>
                    setState(() => _sel = _sel == e.key ? null : e.key),
              ),
          if (_sel != null) _DeptSchools(data: d, dept: _sel!),
        ],
      ),
    );
  }
}

class _DeptBar extends StatelessWidget {
  const _DeptBar({
    required this.name,
    required this.schools,
    required this.students,
    required this.maxV,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final int schools;
  final int students;
  final int maxV;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? kNavy.withValues(alpha: 0.05) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color:
                      selected ? kNavy.withValues(alpha: 0.25) : Colors.transparent),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 180),
                      turns: selected ? 0.25 : 0,
                      child: Icon(Icons.chevron_right_rounded,
                          size: 16, color: kTextMuted),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary)),
                    ),
                    Text('$schools école${schools > 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kNavy)),
                    const SizedBox(width: 10),
                    Text('$students élève${students > 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 11.5, color: kTextMuted)),
                  ],
                ),
                const SizedBox(height: 8),
                AdminProgressBar(
                    value: schools, max: maxV <= 0 ? 1 : maxV, height: 7, color: kNavy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeptSchools extends StatelessWidget {
  const _DeptSchools({required this.data, required this.dept});
  final AdminDashboardData data;
  final String dept;

  @override
  Widget build(BuildContext context) {
    final list = data.schools.where((s) => _deptKeyOf(s) == dept).toList();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Écoles · $dept',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: kTextMuted)),
          const SizedBox(height: 8),
          for (final s in list)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Text('🏫', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: kTextPrimary)),
                  ),
                  _TypeChip(s.type),
                  const SizedBox(width: 8),
                  Text('${s.students} él.',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: kTextMuted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.type);
  final String type;

  @override
  Widget build(BuildContext context) {
    final c = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(_typeLabel(type),
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

// ─── Centre de gouvernance ──────────────────────────────────────────────────
class _Alert {
  const _Alert(this.icon, this.color, this.text, [this.route]);
  final IconData icon;
  final Color color;
  final String text;
  final String? route;
}

class _Check {
  const _Check(this.label, this.ok);
  final String label;
  final bool ok;
}
