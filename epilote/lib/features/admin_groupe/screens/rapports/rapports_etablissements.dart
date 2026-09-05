part of '../admin_reports_screen.dart';

// Section Établissements et tableau des écoles.

class _EtablissementsSection extends ConsumerWidget {
  const _EtablissementsSection({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = data;
    if (d.schoolRows.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.school_outlined,
        title: 'Aucun établissement',
        message: 'Ajoutez des écoles depuis la page Mes Écoles.',
      );
    }

    void drill(String id) {
      final f = ref.read(reportFilterProvider);
      ref.read(reportFilterProvider.notifier).state = f.copyWith(schoolId: id);
      ref.read(_sectionProvider.notifier).state = _Section.synthese;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(
            child: AdminSectionTitle('Détail par établissement',
                icon: Icons.account_tree_rounded,
                subtitle: 'Cliquez une ligne pour analyser une école'),
          ),
          Text('${d.schoolRows.length} école(s)',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
        const SizedBox(height: 12),
        _SchoolsTable(rows: d.schoolRows, onTap: drill),
        const SizedBox(height: 20),
        _DistributionBars(
          title: 'Établissements par département',
          subtitle: 'Couverture géographique',
          icon: Icons.map_rounded,
          data: d.schoolsByDept,
          emptyMessage: 'Aucune donnée géographique.',
        ),
      ],
    );
  }
}

class _SchoolsTable extends StatelessWidget {
  const _SchoolsTable({required this.rows, required this.onTap});
  final List<ReportSchoolRow> rows;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final table = Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: kSurface,
            child: Row(children: [
              Expanded(flex: 5, child: Text('ÉTABLISSEMENT', style: _kHeaderSt)),
              Expanded(flex: 2, child: Text('TYPE', style: _kHeaderSt)),
              Expanded(
                  flex: 3,
                  child: Text('ÉLÈVES (F/G)',
                      style: _kHeaderSt, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('PERSONNEL',
                      style: _kHeaderSt, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('CLASSES',
                      style: _kHeaderSt, textAlign: TextAlign.right)),
              Expanded(
                  flex: 3,
                  child: Text('REVENUS',
                      style: _kHeaderSt, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('STATUT',
                      style: _kHeaderSt, textAlign: TextAlign.right)),
            ]),
          ),
          Divider(height: 1, color: kBorder),
          ...rows.asMap().entries.map((e) =>
              _SchoolRow(s: e.value, isOdd: e.key.isOdd, onTap: onTap)),
        ]),
      ),
    );

    // Sur petit écran : défilement horizontal pour préserver les colonnes.
    return LayoutBuilder(builder: (_, c) {
      if (c.maxWidth >= 760) return table;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: 760, child: table),
      );
    });
  }
}

TextStyle get _kHeaderSt =>
    TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextMuted);

class _SchoolRow extends StatefulWidget {
  const _SchoolRow({required this.s, required this.isOdd, required this.onTap});
  final ReportSchoolRow s;
  final bool isOdd;
  final ValueChanged<String> onTap;

  @override
  State<_SchoolRow> createState() => _SchoolRowState();
}

class _SchoolRowState extends State<_SchoolRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: () => widget.onTap(s.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _hov
                ? kNavy.withValues(alpha: 0.05)
                : widget.isOdd
                    ? kSurface.withValues(alpha: 0.5)
                    : kCardBg,
            border: Border(
                bottom: BorderSide(color: kBorder, width: 0.6)),
          ),
          child: Row(children: [
            Expanded(
              flex: 5,
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _typeColor(s.type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(Icons.account_balance_rounded,
                      size: 15, color: _typeColor(s.type)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      Text(s.city ?? s.department,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: kTextMuted)),
                    ],
                  ),
                ),
              ]),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AdminBadge(_typeLabel(s.type), color: _typeColor(s.type)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtInt(s.students),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  Text('${s.studentsF} F · ${s.studentsM} G',
                      style: TextStyle(fontSize: 11, color: kTextMuted)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(fmtInt(s.staff),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ),
            Expanded(
              flex: 2,
              child: Text(fmtInt(s.classes),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ),
            Expanded(
              flex: 3,
              child: Text(_compactXaf(s.revenue),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kGreen)),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: AdminBadge(s.isActive ? 'Active' : 'Inactive',
                    color: s.isActive ? kGreen : kTextMuted),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GRAPHE TENDANCE (lignes/aires Syncfusion)
// ════════════════════════════════════════════════════════════════════════════
