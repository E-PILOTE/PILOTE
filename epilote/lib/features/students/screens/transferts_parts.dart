part of 'transferts_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Transferts : barre de filtres, en-tête résultats, table,
//  cartes, badge de statut.
// ════════════════════════════════════════════════════════════════════════════

// ─── Barre de filtres ─────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchCtrl,
    required this.status,
    required this.isTable,
    required this.readOnly,
    required this.onSearch,
    required this.onStatus,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final String status;
  final bool isTable, readOnly;
  final ValueChanged<String> onSearch, onStatus;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: adminFilledInput('Rechercher (élève, école…)',
                      icon: Icons.search_rounded),
                ),
              ),
              _StatusSegment(value: status, onChanged: onStatus),
              if (status != 'all') _ResetChip(onTap: onReset),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _ViewToggle(isTable: isTable, onToggle: onToggleView),
        const SizedBox(width: 10),
        if (readOnly)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kAccent.withValues(alpha: 0.30)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_clock_rounded, size: 15, color: kAccent),
              const SizedBox(width: 6),
              Text('Année verrouillée',
                  style: TextStyle(
                      color: kAccent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ]),
          )
        else
          PermissionGate(
            slug: _kSlug,
            action: 'create',
            child: AdminPrimaryButton(
              label: 'Nouveau transfert',
              icon: Icons.add_rounded,
              color: kNavy,
              onTap: onAdd,
            ),
          ),
      ]),
    );
  }
}

class _StatusSegment extends StatelessWidget {
  const _StatusSegment({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    Widget seg(String v, String label) {
      final sel = value == v;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
              color: sel ? kNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(6)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : kTextMuted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('all', 'Tous'),
        seg('pending', 'En attente'),
        seg('approved', 'Approuvés'),
        seg('completed', 'Terminés'),
        seg('rejected', 'Rejetés'),
      ]),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isTable, required this.onToggle});
  final bool isTable;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    Widget seg(bool table, IconData icon, String label) {
      final sel = isTable == table;
      return GestureDetector(
        onTap: sel ? null : onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
              color: sel ? kNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: sel ? Colors.white : kTextMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : kTextMuted)),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg(true, Icons.table_rows_rounded, 'Table'),
        seg(false, Icons.grid_view_rounded, 'Cartes'),
      ]),
    );
  }
}

class _ResetChip extends StatelessWidget {
  const _ResetChip({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: kRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kRed.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.filter_alt_off_rounded, size: 14, color: kRed),
              const SizedBox(width: 5),
              Text('Réinitialiser',
                  style: TextStyle(
                      color: kRed, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

// ─── En-tête résultats ────────────────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader(
      {required this.total, required this.filtered, this.onExportPdf});
  final int total, filtered;
  final VoidCallback? onExportPdf;
  @override
  Widget build(BuildContext context) {
    final txt = filtered == total
        ? _pl(total, 'transfert', 'transferts')
        : '$filtered / ${_pl(total, 'transfert', 'transferts')}';
    return Row(children: [
      Icon(Icons.swap_horiz_rounded, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const Spacer(),
      if (onExportPdf != null) AdminPdfButton(onTap: onExportPdf!),
    ]);
  }
}

// ─── Badge de statut ──────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;
  @override
  Widget build(BuildContext context) =>
      AdminBadge(_statusLabel(status), color: _statusColor(status));
}

String _statusLabel(String s) => switch (s) {
      'pending' => 'En attente',
      'approved' => 'Approuvé',
      'rejected' => 'Rejeté',
      'completed' => 'Terminé',
      _ => s,
    };

// ─── Table ───────────────────────────────────────────────────────────────────
class _TransferTable extends StatelessWidget {
  const _TransferTable({required this.rows, required this.onOpen});
  final List<TransferRow> rows;
  final ValueChanged<TransferRow> onOpen;
  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(children: [
            _Th('ÉLÈVE', flex: 5),
            _Th('CLASSE', flex: 2),
            _Th('ÉCOLE DESTINATION', flex: 4),
            _Th('DATE', flex: 2),
            _Th('STATUT', flex: 2),
            SizedBox(width: 40),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _TransferRow(
            t: rows[i],
            last: i == rows.length - 1,
            onOpen: () => onOpen(rows[i]),
          ),
      ]),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.label, {required this.flex});
  final String label;
  final int flex;
  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
      );
}

class _TransferRow extends StatelessWidget {
  const _TransferRow(
      {required this.t, required this.last, required this.onOpen});
  final TransferRow t;
  final bool last;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final col = _statusColor(t.status);
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          Expanded(
            flex: 5,
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: col.withValues(alpha: 0.12),
                child: Text(
                  t.firstName.isNotEmpty ? t.firstName[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: col, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.lastFirst,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      Text(t.matricule,
                          style:
                              TextStyle(fontSize: 11.5, color: kTextMuted)),
                    ]),
              ),
            ]),
          ),
          Expanded(
            flex: 2,
            child: t.className != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: AdminBadge(t.className!, color: kNavy))
                : Text('—', style: TextStyle(color: kTextMuted)),
          ),
          Expanded(
            flex: 4,
            child: Text(t.toSchoolName ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(_fmtDate(t.transferDate),
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ),
          Expanded(
            flex: 2,
            child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusBadge(t.status)),
          ),
          SizedBox(
            width: 40,
            child: Icon(Icons.chevron_right_rounded,
                size: 18, color: kTextMuted),
          ),
        ]),
      ),
    );
  }
}

// ─── Cartes ──────────────────────────────────────────────────────────────────
class _TransferCards extends StatelessWidget {
  const _TransferCards({required this.rows, required this.onOpen});
  final List<TransferRow> rows;
  final ValueChanged<TransferRow> onOpen;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1180 ? 3 : (w >= 760 ? 2 : 1);
      const gap = 14.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final t in rows)
            SizedBox(width: cardW, child: _TransferCard(t: t, onOpen: () => onOpen(t))),
        ],
      );
    });
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.t, required this.onOpen});
  final TransferRow t;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final col = _statusColor(t.status);
    return AdminCard(
      padding: const EdgeInsets.all(16),
      accent: col,
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: col.withValues(alpha: 0.12),
            child: Text(
              t.firstName.isNotEmpty ? t.firstName[0].toUpperCase() : '?',
              style: TextStyle(
                  color: col, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.lastFirst,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  Text(t.matricule,
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ]),
          ),
          _StatusBadge(t.status),
        ]),
        const SizedBox(height: 12),
        _CardLine(Icons.school_outlined, t.toSchoolName ?? '—'),
        const SizedBox(height: 6),
        _CardLine(Icons.event_outlined, _fmtDate(t.transferDate)),
        if (t.className != null) ...[
          const SizedBox(height: 6),
          _CardLine(Icons.class_outlined, 'Classe : ${t.className}'),
        ],
      ]),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: kTextMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
        ),
      ]);
}

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
