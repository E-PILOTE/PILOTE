part of '../admin_reports_screen.dart';

// Barre de contrôle : export, période, périmètre.

class _ControlBar extends ConsumerStatefulWidget {
  const _ControlBar({required this.data});
  final ReportData data;

  @override
  ConsumerState<_ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends ConsumerState<_ControlBar> {
  bool _busy = false;

  ReportFilter get _filter => ref.read(reportFilterProvider);
  void _set(ReportFilter f) =>
      ref.read(reportFilterProvider.notifier).state = f;

  void _setPeriodKind(ReportPeriodKind kind) {
    if (kind == ReportPeriodKind.custom) {
      _pickCustomRange();
      return;
    }
    _set(_filter.copyWith(period: ReportPeriod(kind: kind)));
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final cur = _filter.period;
    final initStart = cur.customStart ?? DateTime(now.year, now.month, 1);
    final initEnd = cur.customEnd ?? now;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: initStart, end: initEnd),
      helpText: 'Période personnalisée',
      saveText: 'Valider',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: kNavy),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      _set(_filter.copyWith(
        period: ReportPeriod(
          kind: ReportPeriodKind.custom,
          customStart: range.start,
          customEnd: range.end,
        ),
      ));
    }
  }

  void _setSchool(String? id) => _set(_filter.copyWith(schoolId: id));

  // « Imprimer » passe par l'APERÇU PARTAGÉ, pas par `Printing.layoutPdf`.
  //  Ce dernier ouvre sous Windows la boîte de choix d'imprimante (`PrintDlg`)
  //  avec `hwndOwner = nullptr` : elle peut s'afficher DERRIÈRE l'application,
  //  et son annulation ne remonte aucune erreur — l'agent voit un bouton qui ne
  //  fait rien. L'aperçu montre le document, puis laisse imprimer ou enregistrer.
  Future<void> _export({required bool download}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (download) {
        final path = await ReportsPdfService.downloadReport(data: widget.data);
        messenger.showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(path == null
              ? 'PDF généré.'
              : 'PDF enregistré : $path'),
        ));
      } else {
        // Construit UNE FOIS : les octets affichés sont ceux qu'on enregistre,
        // donc avec la même heure d'édition et la même référence.
        final octets = await ReportsPdfService.buildPdf(data: widget.data);
        if (!mounted) return;
        await showPdfPreviewDialog(
          context,
          title: 'Rapport analytique',
          subtitle: '${widget.data.groupName} · ${widget.data.periodLabel} · '
              '${widget.data.scopeLabel}',
          pdfFileName: 'Rapport_analytique.pdf',
          build: (_) async => octets,
          onDownload: () => ReportsPdfService.downloadReport(
              data: widget.data, bytes: octets),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(messageErreur(e, contexte: 'Export')),
          backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(reportFilterProvider);
    final d = widget.data;
    final scoped = filter.schoolId != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête : identité groupe + export ──────────────────────────
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [const Color(0xFF1A2F5A), kNavy]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.groupName,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    AdminBadge('Plan ${d.planName}',
                        color: planColor(d.planName.toLowerCase()),
                        icon: Icons.workspace_premium_rounded),
                    AdminBadge(
                        '${d.periodLabel} · ${_fmtD(d.periodStart)} – ${_fmtD(d.periodEnd)}',
                        color: kNavy,
                        icon: Icons.event_rounded),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ExportControls(busy: _busy, onExport: _export),
          ]),
          const SizedBox(height: 14),
          Divider(height: 1, color: kBorder),
          const SizedBox(height: 14),
          // ── Filtres : période + école ───────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PeriodSelector(
                period: filter.period,
                onChanged: _setPeriodKind,
              ),
              _SchoolSelector(
                schools: d.allSchools,
                selectedId: filter.schoolId,
                onChanged: _setSchool,
              ),
              if (scoped)
                _ScopeChip(
                  label: d.scopeLabel,
                  onClear: () => _setSchool(null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Boutons d'export (imprimer + télécharger) ──────────────────────────────
class _ExportControls extends StatelessWidget {
  const _ExportControls({required this.busy, required this.onExport});
  final bool busy;
  final Future<void> Function({required bool download}) onExport;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      MouseRegion(
        cursor: busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: busy ? null : () => onExport(download: false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFF1A2F5A), kNavy]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded,
                      size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(busy ? 'Génération…' : 'Imprimer / PDF',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Tooltip(
        message: 'Télécharger le PDF',
        child: MouseRegion(
          cursor: busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: busy ? null : () => onExport(download: true),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Icon(Icons.download_rounded, size: 18, color: kNavy),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─── Sélecteur de période (segmenté + perso) ────────────────────────────────
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});
  final ReportPeriod period;
  final ValueChanged<ReportPeriodKind> onChanged;

  @override
  Widget build(BuildContext context) {
    const entries = <(ReportPeriodKind, String)>[
      (ReportPeriodKind.year, 'Année'),
      (ReportPeriodKind.trimester1, 'T1'),
      (ReportPeriodKind.trimester2, 'T2'),
      (ReportPeriodKind.trimester3, 'T3'),
      (ReportPeriodKind.custom, 'Perso.'),
    ];

    Widget seg((ReportPeriodKind, String) e) {
      final sel = period.kind == e.$1;
      return GestureDetector(
        onTap: () => onChanged(e.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (e.$1 == ReportPeriodKind.custom)
              Icon(Icons.tune_rounded,
                  size: 13, color: sel ? Colors.white : kTextMuted),
            if (e.$1 == ReportPeriodKind.custom) const SizedBox(width: 4),
            Text(e.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : kTextMuted,
                )),
          ]),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.date_range_rounded, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min, children: entries.map(seg).toList()),
      ),
    ]);
  }
}

// ─── Sélecteur d'établissement ──────────────────────────────────────────────
class _SchoolSelector extends StatelessWidget {
  const _SchoolSelector({
    required this.schools,
    required this.selectedId,
    required this.onChanged,
  });
  final List<ReportSchoolRow> schools;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected =
        selectedId == null ? null : schools.where((s) => s.id == selectedId);
    final label = (selected == null || selected.isEmpty)
        ? 'Toutes les écoles'
        : selected.first.name;

    return PopupMenuButton<String?>(
      tooltip: 'Filtrer par établissement',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (v) => onChanged(v == '__all__' ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: '__all__',
          child: _menuRow(
              Icons.public_rounded, 'Toutes les écoles', selectedId == null),
        ),
        const PopupMenuDivider(),
        ...schools.map((s) => PopupMenuItem<String?>(
              value: s.id,
              child: _menuRow(Icons.account_balance_rounded, s.name,
                  s.id == selectedId,
                  sub: '${s.students} élèves'),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_rounded, size: 16, color: kNavy),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
          ),
          const SizedBox(width: 6),
          Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
        ]),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label, bool selected, {String? sub}) =>
      Row(children: [
        Icon(icon, size: 16, color: selected ? kNavy : kTextMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? kNavy : kTextPrimary)),
              if (sub != null)
                Text(sub,
                    style: TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ),
        ),
        if (selected)
          Icon(Icons.check_rounded, size: 16, color: kNavy),
      ]);
}

// ─── Chip de scope actif (école sélectionnée) ───────────────────────────────
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kNavy.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.filter_alt_rounded, size: 14, color: kNavy),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: kNavy)),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 15, color: kNavy),
            ),
          ),
        ]),
      );
}

// ─── Onglets de section ─────────────────────────────────────────────────────
