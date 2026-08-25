part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  EN-TÊTE DE PAGE — identité, rafraîchissement, exports, actions d'année.
// ════════════════════════════════════════════════════════════════════════════

// ─── En-tête + actions ─────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.years, this.selected});
  final List<AdminYear> years;
  final AdminYear? selected;

  /// En dessous de cette largeur, les quatre commandes ne tiennent plus à côté
  /// du titre sans l'écraser.
  static const double _seuilLigneUnique = 1000;

  @override
  Widget build(BuildContext context) {
    final identite = Row(
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
      ],
    );

    List<Widget> commandes() => [
          _RefreshButton(selected: selected),
          if (selected != null) _ExportMenu(year: selected!, years: years),
          if (years.isNotEmpty)
            AdminActionButton(
              label: "Passage d'année",
              icon: Icons.move_up_rounded,
              color: kGreen,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _RolloverDialog(years: years),
              ),
            ),
          AdminActionButton(
            label: 'Nouvelle année',
            icon: Icons.add_rounded,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _YearDialog(),
            ),
          ),
        ];

    // ⚠️ QUATRE COMMANDES ET UN TITRE NE TIENNENT PAS TOUJOURS SUR UNE LIGNE.
    //
    //  Les boutons prennent leur largeur naturelle, le titre se contente du
    //  reste : sur un portable, « Années scolaires du groupe » passait sur deux
    //  lignes et sa description sur quatre, dans une colonne étroite — pendant
    //  qu'une large bande restait vide à droite des boutons. Sous le seuil, les
    //  commandes descendent d'une ligne et le titre reprend toute la largeur.
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= _seuilLigneUnique) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: identite),
            const SizedBox(width: 16),
            for (final (i, w) in commandes().indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              w,
            ],
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          identite,
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: commandes(),
          ),
        ],
      );
    });
  }
}

// ─── Rafraîchir ────────────────────────────────────────────────────────────────
//  Les providers ne sont plus `keepAlive` — mais rien ne prévient d'un
//  changement fait depuis un autre poste. Un bouton explicite reste le seul
//  moyen honnête de dire « ce que je vois date de quand ? ».
class _RefreshButton extends ConsumerWidget {
  const _RefreshButton({this.selected});

  /// L'année RÉELLEMENT affichée — pas seulement celle qu'on aurait cliquée.
  ///
  /// Le bouton ne rafraîchissait que `selectedAdminYearIdProvider`, lequel reste
  /// `null` tant qu'aucune pastille n'a été touchée : à l'ouverture de la page,
  /// c'est l'année COURANTE qui s'affiche sans que ce provider soit renseigné.
  /// « Actualiser » rechargeait donc la liste des années, mais laissait intacts
  /// les KPI, la frise et la table de préparation — exactement ce qu'on venait
  /// de demander à revoir.
  final AdminYear? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargement = ref.watch(adminAcademicYearsProvider).isLoading;
    return IconButton(
      tooltip: 'Actualiser',
      onPressed: chargement
          ? null
          : () {
              ref.invalidate(adminAcademicYearsProvider);
              final id = ref.read(selectedAdminYearIdProvider) ?? selected?.id;
              if (id != null) {
                ref.invalidate(adminYearAnalyticsProvider(id));
                ref.invalidate(adminYearCalendarProvider(id));
                ref.invalidate(adminYearHolidaysProvider(id));
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
//  ⚠️ LE PDF PASSE PAR L'APERÇU PARTAGÉ, COMME PARTOUT AILLEURS.
//  Vingt écrans de l'application ouvrent `showPdfPreviewDialog` : on voit le
//  document, PUIS on l'enregistre ou on l'imprime. Cette page était la seule à
//  ne pas le faire — et ce qu'elle faisait à la place était pire qu'une
//  omission. L'entrée « Bilan de l'année (PDF) », sous-titrée « Document
//  officiel », appelait `printReport()`, donc `Printing.layoutPdf`, qui sous
//  Windows ouvre `PrintDlg` : la boîte de CHOIX D'IMPRIMANTE. Trois
//  conséquences, toutes vécues comme « l'export ne marche pas » :
//    • aucun fichier n'était jamais écrit, quoi qu'on fasse dans la boîte ;
//    • `PrintDlg` est ouverte avec `hwndOwner = nullptr` (printing 5.14.3,
//      windows/print_job.cpp) : sans fenêtre propriétaire, elle peut s'afficher
//      DERRIÈRE l'application, qui paraît alors figée sur « Génération… » ;
//    • fermée ou annulée — ou faute d'imprimante installée — le plugin rend
//      « non imprimé » sans erreur : l'application ne disait donc rien du tout.
//
//  Le document est construit UNE FOIS, avant d'ouvrir l'aperçu, puis les mêmes
//  octets servent à l'affichage et à l'enregistrement. Laisser `PdfPreview` le
//  reconstruire ferait porter au fichier déposé une référence et une heure
//  d'édition différentes de celles que l'agent vient de lire à l'écran — sur un
//  document dont le numéro de référence est justement ce qui l'identifie.
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Analytics fraîches garanties : un export ne doit jamais figer un cache.
      final analytics =
          await ref.read(adminYearAnalyticsProvider(widget.year.id).future);

      // `null` = l'agent a fermé la boîte d'enregistrement. Ce n'est pas une
      // erreur, et ce n'est pas non plus un succès : on se tait.
      String? chemin;
      switch (kind) {
        case _ExportKind.pdfBilan:
          final octets = await AcademicYearPdfService.buildPdf(
            year: widget.year,
            analytics: analytics,
            allYears: widget.years,
          );
          if (!mounted) return;
          await showPdfPreviewDialog(
            context,
            title: "Bilan de l'année ${widget.year.label}",
            subtitle: '${analytics.ecolesPreparees}/${analytics.ecolesTotal} '
                'établissements préparés · ${widget.year.eleves} élèves',
            pdfFileName: 'Bilan_${widget.year.label}.pdf',
            build: (_) async => octets,
            onDownload: () => AcademicYearPdfService.downloadReport(
              year: widget.year,
              analytics: analytics,
              allYears: widget.years,
              bytes: octets,
            ),
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
          value: _ExportKind.pdfBilan,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.picture_as_pdf_rounded, size: 19),
            title: Text('Bilan de l\'année (PDF)'),
            subtitle: Text('Aperçu, puis enregistrer ou imprimer'),
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

