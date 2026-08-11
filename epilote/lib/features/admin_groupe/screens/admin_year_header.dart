part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  EN-TÊTE DE PAGE — identité, rafraîchissement, exports, actions d'année.
// ════════════════════════════════════════════════════════════════════════════

// ─── En-tête + actions ─────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.years, this.selected});
  final List<AdminYear> years;
  final AdminYear? selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.event_note_rounded, color: kNavy, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Années scolaires du groupe',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(height: 3),
              Text(
                "Pilotage national du calendrier : l'année est définie ici puis "
                'héritée par toutes les écoles (synchro progressive).',
                style: TextStyle(fontSize: 12.5, color: kTextMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const _RefreshButton(),
        const SizedBox(width: 8),
        if (selected != null) ...[
          _ExportMenu(year: selected!, years: years),
          const SizedBox(width: 10),
        ],
        if (years.isNotEmpty) ...[
          AdminActionButton(
            label: "Passage d'année",
            icon: Icons.move_up_rounded,
            color: kGreen,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _RolloverDialog(years: years),
            ),
          ),
          const SizedBox(width: 10),
        ],
        AdminActionButton(
          label: 'Nouvelle année',
          icon: Icons.add_rounded,
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _YearDialog(),
          ),
        ),
      ],
    );
  }
}

// ─── Rafraîchir ────────────────────────────────────────────────────────────────
//  Les providers ne sont plus `keepAlive` — mais rien ne prévient d'un
//  changement fait depuis un autre poste. Un bouton explicite reste le seul
//  moyen honnête de dire « ce que je vois date de quand ? ».
class _RefreshButton extends ConsumerWidget {
  const _RefreshButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargement = ref.watch(adminAcademicYearsProvider).isLoading;
    return IconButton(
      tooltip: 'Actualiser',
      onPressed: chargement
          ? null
          : () {
              ref.invalidate(adminAcademicYearsProvider);
              final sel = ref.read(selectedAdminYearIdProvider);
              if (sel != null) {
                ref.invalidate(adminYearAnalyticsProvider(sel));
                ref.invalidate(adminYearCalendarProvider(sel));
                ref.invalidate(adminYearHolidaysProvider(sel));
              }
            },
      icon: chargement
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.refresh_rounded, size: 21, color: kNavy),
    );
  }
}

// ─── Exports : le document ET la matière première ──────────────────────────────
//  Le PDF se signe et se dépose ; le CSV se recroise dans un tableur. La
//  direction des statistiques réclamait le second, la hiérarchie le premier.
enum _ExportKind { pdfBilan, csvBilan, csvComparatif }

class _ExportMenu extends ConsumerStatefulWidget {
  const _ExportMenu({required this.year, required this.years});
  final AdminYear year;
  final List<AdminYear> years;
  @override
  ConsumerState<_ExportMenu> createState() => _ExportMenuState();
}

class _ExportMenuState extends ConsumerState<_ExportMenu> {
  bool _busy = false;

  Future<void> _export(_ExportKind kind) async {
    setState(() => _busy = true);
    try {
      // Analytics fraîches garanties : un export ne doit jamais figer un cache.
      final analytics =
          await ref.read(adminYearAnalyticsProvider(widget.year.id).future);
      switch (kind) {
        case _ExportKind.pdfBilan:
          await AcademicYearPdfService.printReport(
            year: widget.year,
            analytics: analytics,
            allYears: widget.years,
          );
        case _ExportKind.csvBilan:
          await AcademicYearCsvService.downloadYearReport(
            year: widget.year,
            analytics: analytics,
          );
        case _ExportKind.csvComparatif:
          await AcademicYearCsvService.downloadYearsOverview(widget.years);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kRed,
            content: Text(messageErreur(e, contexte: 'Export'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ExportKind>(
      enabled: !_busy,
      tooltip: 'Exporter',
      onSelected: _export,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ExportKind.pdfBilan,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.picture_as_pdf_rounded, size: 19),
            title: Text('Bilan de l\'année (PDF)'),
            subtitle: Text('Document officiel, en-tête République'),
          ),
        ),
        PopupMenuItem(
          value: _ExportKind.csvBilan,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.table_view_rounded, size: 19),
            title: Text('Bilan de l\'année (CSV)'),
            subtitle: Text('Une ligne par établissement'),
          ),
        ),
        PopupMenuItem(
          value: _ExportKind.csvComparatif,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.compare_arrows_rounded, size: 19),
            title: Text('Comparatif pluriannuel (CSV)'),
            subtitle: Text('Toutes les années du groupe'),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_busy)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(Icons.download_rounded, size: 18, color: kNavy),
          const SizedBox(width: 8),
          Text(_busy ? 'Génération…' : 'Exporter',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: kNavy)),
          Icon(Icons.arrow_drop_down_rounded, size: 20, color: kNavy),
        ]),
      ),
    );
  }
}

