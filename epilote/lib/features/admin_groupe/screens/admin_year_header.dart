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
//
//  ⚠️ ENREGISTRER ET IMPRIMER SONT DEUX ACTIONS DISTINCTES.
//  Le menu n'offrait qu'« Enregistrer » en apparence : l'entrée « Bilan de
//  l'année (PDF) », sous-titrée « Document officiel », appelait en réalité
//  `printReport()` — donc `Printing.layoutPdf`, qui sous Windows ouvre
//  `PrintDlg`, la boîte de CHOIX D'IMPRIMANTE. Trois conséquences, toutes
//  vécues comme « l'export ne marche pas » :
//    • aucun fichier n'est jamais écrit, quoi qu'on fasse dans la boîte ;
//    • `PrintDlg` est ouverte avec `hwndOwner = nullptr` (printing 5.14.3,
//      windows/print_job.cpp) : sans fenêtre propriétaire, elle peut s'afficher
//      DERRIÈRE l'application, qui paraît alors figée sur « Génération… » ;
//    • fermée ou annulée — ou faute d'imprimante installée — le plugin rend
//      « non imprimé » sans erreur : l'application ne dit donc rien du tout.
//  `AcademicYearPdfService.downloadReport()` existait déjà, écrite et jamais
//  appelée. C'est elle que veut l'agent qui cherche à déposer un bilan.
enum _ExportKind { pdfEnregistrer, pdfImprimer, csvBilan, csvComparatif }

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
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Analytics fraîches garanties : un export ne doit jamais figer un cache.
      final analytics =
          await ref.read(adminYearAnalyticsProvider(widget.year.id).future);

      // `null` = l'agent a fermé la boîte d'enregistrement. Ce n'est pas une
      // erreur, et ce n'est pas non plus un succès : on se tait.
      String? chemin;
      switch (kind) {
        case _ExportKind.pdfEnregistrer:
          chemin = await AcademicYearPdfService.downloadReport(
            year: widget.year,
            analytics: analytics,
            allYears: widget.years,
          );
        case _ExportKind.pdfImprimer:
          await AcademicYearPdfService.printReport(
            year: widget.year,
            analytics: analytics,
            allYears: widget.years,
          );
        case _ExportKind.csvBilan:
          chemin = await AcademicYearCsvService.downloadYearReport(
            year: widget.year,
            analytics: analytics,
          );
        case _ExportKind.csvComparatif:
          chemin =
              await AcademicYearCsvService.downloadYearsOverview(widget.years);
      }

      // Dire OÙ le fichier est parti. Un export muet est indiscernable d'un
      // export raté : l'agent rouvre le menu et recommence.
      if (mounted && chemin != null) {
        messenger.showSnackBar(SnackBar(
          backgroundColor: kGreen,
          duration: const Duration(seconds: 6),
          content: Text('Enregistré : $chemin'),
        ));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
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
          value: _ExportKind.pdfEnregistrer,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.picture_as_pdf_rounded, size: 19),
            title: Text('Bilan de l\'année (PDF)'),
            subtitle: Text('Document officiel — enregistrer le fichier'),
          ),
        ),
        PopupMenuItem(
          value: _ExportKind.pdfImprimer,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_rounded, size: 19),
            title: Text('Imprimer le bilan'),
            subtitle: Text('Ouvre le choix de l\'imprimante'),
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

