part of 'inscriptions_screen.dart';

// ─── Barre d'actions groupées ────────────────────────────────────────────────
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.onValidate,
    required this.onReject,
    required this.onExport,
    required this.onClear,
  });
  final int count;
  final VoidCallback onValidate, onReject, onExport, onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kNavy.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
              color: kNavy, borderRadius: BorderRadius.circular(20)),
          child: Text('$count',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        const Text('sélectionné(s)',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
        const Spacer(),
        Wrap(spacing: 8, children: [
          _BulkBtn(
              icon: Icons.check_rounded,
              label: 'Valider',
              color: kGreen,
              onTap: onValidate),
          _BulkBtn(
              icon: Icons.close_rounded,
              label: 'Rejeter',
              color: kRed,
              onTap: onReject),
          _BulkBtn(
              icon: Icons.download_rounded,
              label: 'Exporter',
              color: kNavy,
              onTap: onExport),
          _BulkBtn(
              icon: Icons.clear_all_rounded,
              label: 'Désélectionner',
              color: kTextMuted,
              onTap: onClear),
        ]),
      ]),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// ─── Vue TABLE (style plateforme, colonnes resserrées + sélection) ───────────
class _InscritsTable extends StatelessWidget {
  const _InscritsTable({
    required this.rows,
    required this.sort,
    required this.sortAsc,
    required this.selected,
    required this.onSelect,
    required this.onSelectAll,
    required this.onSort,
    required this.onView,
    required this.onValidate,
    required this.onReject,
    required this.readOnly,
  });
  final List<InscriptionRow> rows;
  final _SortBy sort;
  final bool sortAsc, readOnly;
  final Set<String> selected;
  final void Function(String id, bool sel) onSelect;
  final ValueChanged<bool> onSelectAll;
  final ValueChanged<_SortBy> onSort;
  final ValueChanged<InscriptionRow> onView;
  final Future<void> Function(InscriptionRow) onValidate;
  final Future<void> Function(InscriptionRow) onReject;

  int? get _sortIdx => switch (sort) {
        _SortBy.nom => 0,
        _SortBy.classe => 1,
        _SortBy.date => 4,
      };

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 96),
            child: DataTable(
              sortColumnIndex: _sortIdx,
              sortAscending: sortAsc,
              showCheckboxColumn: true,
              onSelectAll: (v) => onSelectAll(v ?? false),
              headingRowColor:
                  WidgetStatePropertyAll(kNavy.withValues(alpha: 0.04)),
              headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 12, color: kNavy),
              dividerThickness: 0.6,
              columnSpacing: 26,
              dataRowMinHeight: 54,
              dataRowMaxHeight: 64,
              columns: [
                DataColumn(
                    label: const Text('ÉLÈVE'),
                    onSort: (_, _) => onSort(_SortBy.nom)),
                DataColumn(
                    label: const Text('CLASSE'),
                    onSort: (_, _) => onSort(_SortBy.classe)),
                const DataColumn(label: Text('TYPE')),
                const DataColumn(label: Text('STATUT')),
                DataColumn(
                    label: const Text('DATE'),
                    onSort: (_, _) => onSort(_SortBy.date)),
                const DataColumn(label: Text('')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    selected: selected.contains(r.id),
                    onSelectChanged: (v) => onSelect(r.id, v ?? false),
                    cells: [
                      DataCell(
                        Row(children: [
                          _Avatar(row: r, size: 34),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(r.lastFirst,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: kTextPrimary)),
                                Text(r.matricule,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: kTextMuted,
                                        fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                        ]),
                        onTap: () => onView(r),
                      ),
                      DataCell(Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: _cycleColor(r.cycle.code),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 7),
                        Text(r.className),
                      ])),
                      DataCell(_TypeBadge(type: r.inscriptionType)),
                      DataCell(_StatusBadge(status: r.status)),
                      DataCell(Text(
                          r.enrollmentDate?.toIso8601String().substring(0, 10) ??
                              '—',
                          style: const TextStyle(
                              fontSize: 11.5, color: kTextMuted))),
                      DataCell(_RowActions(
                        row: r,
                        readOnly: readOnly,
                        onView: () => onView(r),
                        onValidate: () => onValidate(r),
                        onReject: () => onReject(r),
                      )),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.row,
    required this.readOnly,
    required this.onView,
    required this.onValidate,
    required this.onReject,
  });
  final InscriptionRow row;
  final bool readOnly;
  final VoidCallback onView, onValidate, onReject;

  @override
  Widget build(BuildContext context) {
    final pending = row.status == 'pending_validation';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (pending && !readOnly) ...[
        AdminModalIconBtn(
            icon: Icons.check_rounded,
            color: kGreen,
            tooltip: 'Valider',
            onTap: onValidate),
        const SizedBox(width: 6),
        AdminModalIconBtn(
            icon: Icons.close_rounded,
            color: kRed,
            tooltip: 'Rejeter',
            onTap: onReject),
        const SizedBox(width: 6),
      ],
      AdminModalIconBtn(
          icon: Icons.visibility_outlined,
          color: kNavy,
          tooltip: 'Détails',
          onTap: onView),
    ]);
  }
}

// ─── Vue CARTES (enrichie + sélection) ───────────────────────────────────────
class _InscritsCards extends StatelessWidget {
  const _InscritsCards({
    required this.rows,
    required this.selected,
    required this.onSelect,
    required this.onView,
  });
  final List<InscriptionRow> rows;
  final Set<String> selected;
  final void Function(String id, bool sel) onSelect;
  final ValueChanged<InscriptionRow> onView;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 1280
          ? 4
          : c.maxWidth >= 900
              ? 3
              : c.maxWidth >= 580
                  ? 2
                  : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 132,
        ),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final r = rows[i];
          final sel = selected.contains(r.id);
          final sub = <String>[
            r.cycle.label,
            if (r.age != null) '${r.age} ans',
            if (r.gender == 'F') 'Fille' else if (r.gender == 'M') 'Garçon',
          ].join(' · ');
          return AdminCard(
            padding: const EdgeInsets.all(12),
            accent: sel ? kNavy : null,
            onTap: () => onView(r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _Avatar(row: r, size: 42),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.lastFirst,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: kTextPrimary)),
                        const SizedBox(height: 2),
                        Text(r.matricule,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                color: kTextMuted,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  _SelectCircle(
                      selected: sel, onTap: () => onSelect(r.id, !sel)),
                ]),
                const SizedBox(height: 9),
                Row(children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: _cycleColor(r.cycle.code),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${r.className} · $sub',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _StatusBadge(status: r.status),
                  const SizedBox(width: 6),
                  Flexible(child: _TypeBadge(type: r.inscriptionType)),
                  if (r.isRepeating) ...[
                    const SizedBox(width: 6),
                    const AdminBadge('Redoublant',
                        color: kRed, icon: Icons.replay_rounded),
                  ],
                ]),
              ],
            ),
          );
        },
      );
    });
  }
}

class _SelectCircle extends StatelessWidget {
  const _SelectCircle({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: selected ? kNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: selected ? kNavy : kBorder, width: 1.6),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null,
          ),
        ),
      );
}

// ─── Avatar élève ────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.row, required this.size});
  final InscriptionRow row;
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = row.gender == 'F' ? _kPink : kNavy;
    final initials = (row.firstName.isNotEmpty ? row.firstName[0] : '') +
        (row.lastName.isNotEmpty ? row.lastName[0] : '');
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color.withValues(alpha: 0.12),
      foregroundImage: (row.photoUrl != null && row.photoUrl!.isNotEmpty)
          ? CachedNetworkImageProvider(row.photoUrl!)
          : null,
      child: Text(initials.toUpperCase(),
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: size * 0.34)),
    );
  }
}

// ─── Badges ──────────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'new' => ('Nouvelle', kGreen),
      'reinscription' => ('Réinscription', kNavy),
      'transfer' => ('Transfert', kAccent),
      _ => (type, kTextMuted),
    };
    return AdminBadge(label, color: color);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'active' => ('Validée', kGreen, Icons.check_circle_rounded),
      'pending_validation' => ('En attente', kAccent, Icons.hourglass_top_rounded),
      'rejected' => ('Rejetée', kRed, Icons.cancel_rounded),
      _ => (status, kTextMuted, Icons.help_outline_rounded),
    };
    return AdminBadge(label, color: color, icon: icon);
  }
}

// Helper partagé : tiret si vide (utilisé par les fiches/modals).
String _orDash(String? v) => (v == null || v.trim().isEmpty) ? '—' : v.trim();
