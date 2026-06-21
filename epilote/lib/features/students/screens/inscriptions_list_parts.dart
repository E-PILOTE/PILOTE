part of 'inscriptions_screen.dart';

// ─── Vue TABLE (style plateforme) ────────────────────────────────────────────
class _InscritsTable extends StatelessWidget {
  const _InscritsTable({
    required this.rows,
    required this.sort,
    required this.sortAsc,
    required this.onSort,
    required this.onView,
    required this.onValidate,
    required this.onReject,
    required this.readOnly,
  });
  final List<InscriptionRow> rows;
  final _SortBy sort;
  final bool sortAsc, readOnly;
  final ValueChanged<_SortBy> onSort;
  final ValueChanged<InscriptionRow> onView;
  final Future<void> Function(InscriptionRow) onValidate;
  final Future<void> Function(InscriptionRow) onReject;

  int? get _sortIdx => switch (sort) {
        _SortBy.nom => 0,
        _SortBy.classe => 2,
        _SortBy.date => 6,
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
              headingRowColor:
                  WidgetStatePropertyAll(kNavy.withValues(alpha: 0.04)),
              headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 12, color: kNavy),
              dividerThickness: 0.6,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 60,
              columns: [
                DataColumn(
                    label: const Text('ÉLÈVE'),
                    onSort: (_, _) => onSort(_SortBy.nom)),
                const DataColumn(label: Text('MATRICULE')),
                DataColumn(
                    label: const Text('CLASSE'),
                    onSort: (_, _) => onSort(_SortBy.classe)),
                const DataColumn(label: Text('CYCLE')),
                const DataColumn(label: Text('TYPE')),
                const DataColumn(label: Text('STATUT')),
                DataColumn(
                    label: const Text('DATE'),
                    onSort: (_, _) => onSort(_SortBy.date)),
                const DataColumn(label: Text('')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(
                      Row(children: [
                        _Avatar(row: r, size: 32),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(r.lastFirst,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, color: kTextPrimary)),
                        ),
                      ]),
                      onTap: () => onView(r),
                    ),
                    DataCell(Text(r.matricule,
                        style: const TextStyle(
                            fontSize: 12, color: kTextMuted, fontFamily: 'monospace'))),
                    DataCell(Text(r.className)),
                    DataCell(Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: _cycleColor(r.cycle.code),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(r.cycle.label,
                          style: const TextStyle(fontSize: 12, color: kTextMuted)),
                    ])),
                    DataCell(_TypeBadge(type: r.inscriptionType)),
                    DataCell(_StatusBadge(status: r.status)),
                    DataCell(Text(
                        r.enrollmentDate?.toIso8601String().substring(0, 10) ?? '—',
                        style: const TextStyle(fontSize: 11.5, color: kTextMuted))),
                    DataCell(_RowActions(
                      row: r,
                      readOnly: readOnly,
                      onView: () => onView(r),
                      onValidate: () => onValidate(r),
                      onReject: () => onReject(r),
                    )),
                  ]),
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

// ─── Vue CARTES ──────────────────────────────────────────────────────────────
class _InscritsCards extends StatelessWidget {
  const _InscritsCards({required this.rows, required this.onView});
  final List<InscriptionRow> rows;
  final ValueChanged<InscriptionRow> onView;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 1200
          ? 4
          : c.maxWidth >= 860
              ? 3
              : c.maxWidth >= 560
                  ? 2
                  : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 96,
        ),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final r = rows[i];
          return AdminCard(
            padding: const EdgeInsets.all(12),
            onTap: () => onView(r),
            child: Row(children: [
              _Avatar(row: r, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(r.lastFirst,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: kTextPrimary)),
                    const SizedBox(height: 3),
                    Text('${r.className} · ${r.matricule}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
                    const SizedBox(height: 5),
                    Row(children: [
                      _StatusBadge(status: r.status),
                      const SizedBox(width: 6),
                      Flexible(child: _TypeBadge(type: r.inscriptionType)),
                    ]),
                  ],
                ),
              ),
            ]),
          );
        },
      );
    });
  }
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

// ─── Fiche détail (modal) ────────────────────────────────────────────────────
class _InscriptionDetailModal extends StatelessWidget {
  const _InscriptionDetailModal({
    required this.row,
    required this.onOpenStudent,
    this.onValidate,
    this.onReject,
  });
  final InscriptionRow row;
  final VoidCallback onOpenStudent;
  final VoidCallback? onValidate, onReject;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kNavyDark, kNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              _Avatar(row: row, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    _StatusBadge(status: row.status),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          // Corps
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const AdminModalSectionTitle('Dossier d\'inscription'),
              const SizedBox(height: 10),
              AdminDetailCard([
                AdminDetailRow(Icons.badge_outlined, 'Matricule', row.matricule,
                    mono: true),
                AdminDetailRow(Icons.class_outlined, 'Classe', row.className),
                AdminDetailRow(
                    Icons.account_tree_outlined, 'Cycle', row.cycle.label),
                AdminDetailRow(Icons.category_outlined, 'Type', row.typeLabel),
                AdminDetailRow(
                    Icons.wc_rounded,
                    'Sexe',
                    row.gender == 'F'
                        ? 'Féminin'
                        : row.gender == 'M'
                            ? 'Masculin'
                            : '—'),
                AdminDetailRow(Icons.replay_rounded, 'Redoublant',
                    row.isRepeating ? 'Oui' : 'Non'),
                AdminDetailRow(
                    Icons.event_outlined,
                    'Date d\'inscription',
                    row.enrollmentDate?.toIso8601String().substring(0, 10) ?? '—',
                    last: true),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                if (onValidate != null) ...[
                  Expanded(
                    child: AdminPrimaryButton(
                      label: 'Valider',
                      icon: Icons.check_rounded,
                      color: kGreen,
                      onTap: onValidate!,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (onReject != null) ...[
                  _OutlineBtn(
                    label: 'Rejeter',
                    icon: Icons.close_rounded,
                    color: kRed,
                    onTap: onReject!,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: AdminPrimaryButton(
                    label: 'Dossier élève',
                    icon: Icons.folder_open_rounded,
                    color: kNavy,
                    onTap: onOpenStudent,
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}
