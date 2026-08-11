part of '../admin_regional_view.dart';

// ─── Bascule Carte / Tableau ─────────────────────────────────────────────────
class _ModeSwitch extends ConsumerWidget {
  const _ModeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(_regionalModeProv);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _ModeBtn(
            label: 'Carte',
            icon: Icons.map_rounded,
            selected: mode == RegionalViewMode.map,
            onTap: () =>
                ref.read(_regionalModeProv.notifier).state = RegionalViewMode.map,
          ),
          const SizedBox(width: 3),
          _ModeBtn(
            label: 'Tableau',
            icon: Icons.table_rows_rounded,
            selected: mode == RegionalViewMode.table,
            onTap: () => ref.read(_regionalModeProv.notifier).state =
                RegionalViewMode.table,
          ),
        ]),
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  const _ModeBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: selected ? Colors.white : kTextMuted),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : kTextMuted)),
        ]),
      ),
    );
  }
}

// ─── Filtres type d'établissement ───────────────────────────────────────────
class _FilterBar extends ConsumerWidget {
  const _FilterBar({this.floating = false});
  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f        = ref.watch(_regionalFilterProv);
    final notifier = ref.read(_regionalFilterProv.notifier);
    void setType(String? t) =>
        notifier.state = _RegionalFilter(type: t, activeOnly: f.activeOnly);
    void toggleActive() =>
        notifier.state = _RegionalFilter(type: f.type, activeOnly: !f.activeOnly);

    final chips = Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        _FilterChip(
            label: 'Tous', active: f.type == null,
            color: kNavy, onTap: () => setType(null)),
        _FilterChip(
            label: 'Public', active: f.type == 'public',
            color: _kBlue, onTap: () => setType('public')),
        _FilterChip(
            label: 'Privé', active: f.type == 'prive',
            color: kGreen, onTap: () => setType('prive')),
        _FilterChip(
            label: 'Actives',
            icon: Icons.check_circle_rounded,
            active: f.activeOnly,
            color: kAccent,
            onTap: toggleActive),
      ],
    );

    if (floating) {
      return Container(
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: chips,
      );
    }

    return Container(
      width: double.infinity,
      color: kCardBg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 13, color: kTextMuted),
              const SizedBox(width: 6),
              Text('FILTRER',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted,
                      letterSpacing: 1.0)),
              const Spacer(),
              if (!f.isDefault)
                _FilterChip(
                    label: 'Réinit.',
                    icon: Icons.close_rounded,
                    active: false,
                    color: kRed,
                    onTap: () =>
                        notifier.state = const _RegionalFilter()),
            ],
          ),
          const SizedBox(height: 8),
          chips,
        ],
      ),
    );
  }
}

// ─── Statistiques globales ──────────────────────────────────────────────────
class _GlobalStats extends StatelessWidget {
  const _GlobalStats({required this.data});
  final AdminRegionalData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kNavyDark, kNavy],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COUVERTURE DU GROUPE',
              style: TextStyle(color: Colors.white70, fontSize: 9,
                  fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          const Text('Vue Régionale',
              style: TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            _StatPill(
                value: '${data.coveredDepts}',
                label: 'Départ.',
                icon: Icons.map_rounded),
            const SizedBox(width: 8),
            _StatPill(
                value: '${data.totalSchools}',
                label: 'Écoles',
                icon: Icons.business_rounded),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _StatPill(
                value: '${data.activeSchools}',
                label: 'Actives',
                icon: Icons.check_circle_rounded),
            const SizedBox(width: 8),
            _StatPill(
                value: '${data.totalStudents}',
                label: 'Élèves',
                icon: Icons.people_rounded),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _StatPill(
                value: '${data.gpsCount}',
                label: 'GPS',
                icon: Icons.gps_fixed_rounded),
            const SizedBox(width: 8),
            _StatPill(
                value: '${data.noGpsCount}',
                label: 'Sans GPS',
                icon: Icons.gps_off_rounded),
          ]),
          // Backfill : géolocaliser les écoles sans position (via congo_places).
          if (data.noGpsCount > 0) ...[
            const SizedBox(height: 10),
            _GeocodeButton(noGps: data.noGpsCount),
          ],
        ],
      ),
    );
  }
}

/// Bouton de géocodage de masse des écoles sans GPS.
class _GeocodeButton extends ConsumerStatefulWidget {
  const _GeocodeButton({required this.noGps});
  final int noGps;

  @override
  ConsumerState<_GeocodeButton> createState() => _GeocodeButtonState();
}

class _GeocodeButtonState extends ConsumerState<_GeocodeButton> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final fixed = await ref.read(geocodeMissingProvider)();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: fixed > 0 ? kGreen : kTextMuted,
        content: Text(fixed > 0
            ? '$fixed école${fixed > 1 ? 's' : ''} géolocalisée${fixed > 1 ? 's' : ''}.'
            : 'Aucune ville reconnue à géocoder.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: kRed, content: Text(messageErreur(e))));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _running ? null : _run,
        icon: _running
            ? SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kNavy))
            : const Icon(Icons.my_location_rounded, size: 16),
        label: Text(_running
            ? 'Géolocalisation…'
            : 'Géolocaliser ${widget.noGps} école${widget.noGps > 1 ? 's' : ''}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: kNavy,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill(
      {required this.value, required this.label, required this.icon});
  final String value, label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(icon, size: 14, color: kAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 9)),
                  ]),
            ),
          ]),
        ),
      );
}

// ─── Export PDF officiel ─────────────────────────────────────────────────────
class _RegionalExportBar extends ConsumerStatefulWidget {
  const _RegionalExportBar({required this.data});
  final AdminRegionalData data;

  @override
  ConsumerState<_RegionalExportBar> createState() => _RegionalExportBarState();
}

class _RegionalExportBarState extends ConsumerState<_RegionalExportBar> {
  bool _busy = false;

  // ⚠️ APERÇU, PUIS ENREGISTRER OU IMPRIMER — comme les vingt autres exports.
  //
  //  Ce bouton appelait `printReport()`, donc `Printing.layoutPdf`, qui sous
  //  Windows ouvre `PrintDlg` : la boîte de CHOIX D'IMPRIMANTE. Trois
  //  conséquences, toutes vécues comme « l'export ne marche pas » :
  //    • aucun fichier n'était jamais écrit, quoi qu'on fasse dans la boîte —
  //      or c'était le SEUL chemin d'export de la vue régionale ;
  //    • `PrintDlg` est ouverte avec `hwndOwner = nullptr` (printing 5.14.3,
  //      windows/print_job.cpp) : sans fenêtre propriétaire, elle peut
  //      s'afficher DERRIÈRE l'application, qui paraît figée sur « Génération… » ;
  //    • annulée — ou faute d'imprimante installée — le plugin rend « non
  //      imprimé » sans erreur : l'application ne disait donc rien du tout.
  //
  //  Le document est construit UNE FOIS, avant d'ouvrir l'aperçu, et les mêmes
  //  octets servent à l'affichage et à l'enregistrement : le fichier déposé
  //  porte la référence et l'heure d'édition lues à l'écran.
  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // .future : on s'assure d'avoir les projets (et pas un instantané vide)
      // même si l'utilisateur exporte avant la fin du 1er chargement.
      final projects = await ref.read(adminProjectsProvider.future);
      final groupName =
          ref.read(adminDashboardProvider).valueOrNull?.groupName ??
              'Groupe scolaire';
      final octets = await RegionalPdfService.buildPdf(
        groupName: groupName,
        data: widget.data,
        projects: projects,
      );
      if (!mounted) return;
      await showPdfPreviewDialog(
        context,
        title: 'Rapport territorial',
        subtitle: '$groupName · ${widget.data.totalSchools} établissements · '
            '${widget.data.coveredDepts}/15 départements',
        pdfFileName: 'Rapport_territorial.pdf',
        build: (_) async => octets,
        onDownload: () => RegionalPdfService.downloadReport(
          groupName: groupName,
          data: widget.data,
          projects: projects,
          bytes: octets,
        ),
      );
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _busy ? null : _export,
          icon: _busy
              ? const SizedBox(
                  width: 15, height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf_rounded, size: 16),
          label: const Text('Rapport territorial (PDF)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}

