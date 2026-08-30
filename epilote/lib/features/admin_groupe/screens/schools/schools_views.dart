part of '../admin_schools_screen.dart';

// Vues Tableau et Cartes

// ─── Vue Tableau ──────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({
    required this.schools, required this.sortField, required this.sortAsc,
    required this.onSort, required this.onView, required this.onEdit, required this.onToggle,
    required this.selectedIds, required this.allSelected,
    required this.onToggleAll, required this.onToggleSelect,
  });
  final List<SchoolDetail> schools;
  final String sortField;
  final bool   sortAsc;
  final Set<String> selectedIds;
  final bool allSelected;
  final VoidCallback onToggleAll;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String>      onSort;
  final ValueChanged<SchoolDetail> onView;
  final ValueChanged<SchoolDetail> onEdit;
  final ValueChanged<SchoolDetail> onToggle;

  @override
  Widget build(BuildContext context) {
    if (schools.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucune école ne correspond à vos filtres.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          _TableHeader(sortField: sortField, sortAsc: sortAsc, onSort: onSort,
              allSelected: allSelected, onToggleAll: onToggleAll),
          ...schools.asMap().entries.map((e) => _TableRow(
            school:   e.value,
            isOdd:    e.key.isOdd,
            selected: selectedIds.contains(e.value.id),
            onToggleSelect: () => onToggleSelect(e.value.id),
            onView:   () => onView(e.value),
            onEdit:   () => onEdit(e.value),
            onToggle: () => onToggle(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.sortField, required this.sortAsc, required this.onSort,
    required this.allSelected, required this.onToggleAll,
  });
  final String sortField;
  final bool   sortAsc;
  final ValueChanged<String> onSort;
  final bool allSelected;
  final VoidCallback onToggleAll;

  Widget _col(String label, String field, {int flex = 1}) => Expanded(
    flex: flex,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSort(field),
        child: Row(children: [
          Flexible(child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
          const SizedBox(width: 3),
          Icon(
            sortField == field
                ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 12,
            color: sortField == field ? kNavy : kTextMuted,
          ),
        ]),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: kSurface,
    child: Row(children: [
      SizedBox(width: 36, child: Align(
        alignment: Alignment.centerLeft,
        child: _CheckSquare(checked: allSelected, onTap: onToggleAll),
      )),
      const SizedBox(width: 8),
      const SizedBox(width: 46),
      const SizedBox(width: 12),
      _col('NOM DE L\'ÉCOLE', 'name', flex: 3),
      _col('TYPE',            'type'),
      _col('DÉPARTEMENT',     'dept'),
      _col('ÉLÈVES',          'students'),
      _col('PERSONNEL',       'staff'),
      _col('CLASSES',         'classes'),
      SizedBox(width: 32,
          child: Text('ÉTAT',
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
      SizedBox(width: 110,
          child: Text('ACTIONS', textAlign: TextAlign.end,
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
    ]),
  );
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.school, required this.isOdd,
    required this.selected, required this.onToggleSelect,
    required this.onView, required this.onEdit, required this.onToggle,
  });
  final SchoolDetail school;
  final bool isOdd;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onView, onEdit, onToggle;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.school;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: widget.selected
              ? kNavy.withValues(alpha: 0.07)
              : _hov
                  ? kNavy.withValues(alpha: 0.04)
                  : widget.isOdd
                      ? kSurface.withValues(alpha: 0.5)
                      : kCardBg,
          border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          SizedBox(width: 36, child: Align(
            alignment: Alignment.centerLeft,
            child: _CheckSquare(checked: widget.selected, onTap: widget.onToggleSelect),
          )),
          const SizedBox(width: 8),
          _SchoolAvatar(
            logoUrl: s.logoUrl,
            size: 46, radius: 11, iconSize: 20,
            iconColor: s.isActive ? kNavy : kTextMuted,
          ),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name,
                style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
            // Le type d'établissement passe AVANT le code : « CET » se lit,
            // un code administratif se vérifie. Et sans lui, deux écoles d'un
            // même groupe se ressemblent dans une liste de trente.
            if (s.institutionTypeShort != null || s.code != null)
              Text(
                [
                  if (s.institutionTypeShort != null) s.institutionTypeShort!,
                  if (s.code != null) 'code ${s.code}',
                ].join(' · '),
                style: TextStyle(color: kTextMuted, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
          ])),
          Expanded(child: _TypeBadge(type: s.type)),
          Expanded(child: Text(s.department ?? '—',
              style: TextStyle(color: kTextPrimary, fontSize: 12.5),
              overflow: TextOverflow.ellipsis)),
          Expanded(child: Text('${s.students}',
              style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
          Expanded(child: Text('${s.staff}',
              style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
          Expanded(child: Text('${s.classes}',
              style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
          SizedBox(
            width: 32,
            child: Icon(
              s.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 18, color: s.isActive ? kGreen : kRed,
            ),
          ),
          SizedBox(
            width: 110,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _ActionBtn(icon: Icons.visibility_outlined, color: _kBlue,
                  tooltip: 'Voir les détails', onTap: widget.onView),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.edit_rounded, color: kNavy,
                  tooltip: 'Modifier', onTap: widget.onEdit),
              const SizedBox(width: 4),
              _ActionBtn(
                icon: s.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                color: s.isActive ? kRed : kGreen,
                tooltip: s.isActive ? 'Désactiver' : 'Activer',
                onTap: widget.onToggle,
              ),
            ]),
          ),
        ]),
      ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon, required this.color,
    required this.tooltip, required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'public' => ('Public', _kBlue),
      _        => ('Privé',  _kGold),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.schools, required this.onView, required this.onEdit, required this.onToggle});
  final List<SchoolDetail> schools;
  final ValueChanged<SchoolDetail> onView;
  final ValueChanged<SchoolDetail> onEdit;
  final ValueChanged<SchoolDetail> onToggle;

  @override
  Widget build(BuildContext context) {
    if (schools.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucune école ne correspond à vos filtres.',
      );
    }
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 700 ? 2 : 1;
      const gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap, runSpacing: gap,
        children: schools.map((s) => SizedBox(width: w,
          child: _SchoolCard(s: s, onView: () => onView(s), onEdit: () => onEdit(s), onToggle: () => onToggle(s)))).toList(),
      );
    });
  }
}

class _SchoolCard extends StatefulWidget {
  const _SchoolCard({required this.s, required this.onView, required this.onEdit, required this.onToggle});
  final SchoolDetail s;
  final VoidCallback onView, onEdit, onToggle;

  @override
  State<_SchoolCard> createState() => _SchoolCardState();
}

class _SchoolCardState extends State<_SchoolCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hov ? kNavy.withValues(alpha: 0.3) : kBorder),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
            blurRadius: _hov ? 12 : 4,
            offset: Offset(0, _hov ? 4 : 2),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                s.isActive ? kNavy : kTextMuted,
                (s.isActive ? kNavy : kTextMuted).withValues(alpha: 0.4),
              ]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _SchoolAvatar(
                  logoUrl: s.logoUrl,
                  size: 46, radius: 11, iconSize: 22,
                  iconColor: s.isActive ? kNavy : kTextMuted,
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary)),
                  if (s.code != null)
                    Text('Code : ${s.code}', style: TextStyle(fontSize: 11, color: kTextMuted)),
                ])),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: kTextMuted, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (v) {
                    if (v == 'view') { widget.onView(); }
                    else if (v == 'edit') { widget.onEdit(); }
                    else if (v == 'toggle') { widget.onToggle(); }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'view', child: Row(children: [
                      Icon(Icons.visibility_outlined, size: 18, color: _kBlue),
                      SizedBox(width: 10), Text('Voir les détails'),
                    ])),
                    PopupMenuItem(value: 'edit', child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18, color: kNavy),
                      const SizedBox(width: 10), const Text('Modifier'),
                    ])),
                    PopupMenuItem(value: 'toggle', child: Row(children: [
                      Icon(s.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                          size: 18, color: s.isActive ? kRed : kGreen),
                      const SizedBox(width: 10),
                      Text(s.isActive ? 'Désactiver' : 'Activer'),
                    ])),
                  ],
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _TypeBadge(type: s.type),
                if (s.institutionTypeShort != null)
                  AdminBadge(s.institutionTypeShort!,
                      color: _kPurple, icon: Icons.school_outlined),
                if (s.city != null) AdminBadge(s.city!, color: kTextMuted, icon: Icons.location_on_outlined),
                if (!s.isActive) AdminBadge('Inactive', color: kRed, icon: Icons.block_rounded),
              ]),
              Divider(height: 26, color: kBorder),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _Stat(icon: Icons.groups_rounded,  label: 'Élèves',    value: s.students, color: _kPurple),
                _Stat(icon: Icons.badge_rounded,   label: 'Personnel', value: s.staff,    color: _kBlue),
                _Stat(icon: Icons.class_rounded,   label: 'Classes',   value: s.classes,  color: kGreen),
              ]),
            ]),
          ),
        ]),
      ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(height: 4),
    Text('$value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
    Text(label, style: TextStyle(fontSize: 11, color: kTextMuted)),
  ]);
}

