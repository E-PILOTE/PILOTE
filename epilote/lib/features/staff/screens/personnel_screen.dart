import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../communication/widgets/user_avatar.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../../students/widgets/scope_drilldown_panel.dart' show scopeCycleName;
import '../../user/widgets/staff_account_widgets.dart' show staffRoleLabel;
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../providers/staff_directory_provider.dart';
import '../providers/staff_dossier_provider.dart' show employmentStatusLabel;
import '../services/personnel_export_service.dart';
import '../widgets/staff_kit.dart';
import 'personnel_dossier_sheet.dart';

part 'personnel_views.dart';

const _kSlug = 'personnel';

// ════════════════════════════════════════════════════════════════════════════
//  PERSONNEL — annuaire RICHE, scope-aware. KPI hero → distinction 3 axes
//  (Catégorie / Statut / Cycle) + graphe de répartition → filtres + recherche →
//  bascule vue Cartes / Tableau → ouverture du dossier RH. Export PDF + CSV.
//  Gestion du profil (créer/modifier/transférer) = capacité `canManage`
//  (admin_groupe online) ; la direction école est en lecture + dossier offline.
// ════════════════════════════════════════════════════════════════════════════
class PersonnelScreen extends ConsumerWidget {
  const PersonnelScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Personnel',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  StaffAxis _axis = StaffAxis.categorie;
  String? _seg;
  bool _table = false;
  String _status = 'all'; // all | active | inactive
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String? get _schoolName =>
      ref.read(currentSchoolProvider).valueOrNull?['name'] as String?;

  void _exportPdf(List<StaffMember> agents) => showPdfPreviewDialog(
        context,
        title: 'Annuaire du personnel',
        subtitle: '${agents.length} agents',
        pdfFileName: 'Annuaire_personnel.pdf',
        build: (_) => PersonnelExportService.buildPdf(
            agents: agents, schoolName: _schoolName),
        onDownload: () => PersonnelExportService.downloadPdf(
            agents: agents, schoolName: _schoolName),
      );

  Future<void> _exportCsv(List<StaffMember> agents) async {
    final path = await PersonnelExportService.downloadCsv(agents: agents);
    if (!mounted || path == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annuaire exporté (CSV)')));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(staffDirectoryProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (all) {
        // Segments selon l'axe (métrique « ok » = actifs).
        final segs = staffSegments(all, _axis, okOf: (a) => a.isActive);

        // Filtrage : segment + statut + recherche.
        final q = _q.trim().toLowerCase();
        final agents = [
          for (final a in all)
            if ((_seg == null || staffSegKey(a, _axis) == _seg) &&
                (_status == 'all' ||
                    (_status == 'active' && a.isActive) ||
                    (_status == 'inactive' && !a.isActive)) &&
                (q.isEmpty || a.searchBlob.contains(q)))
              a
        ];

        final actifs = all.where((a) => a.isActive).length;
        final enseignants = all.where((a) => a.role == 'enseignant').length;
        final fonctionnaires =
            all.where((a) => a.employmentStatus == 'fonctionnaire').length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            VsHeader(
              title: 'Personnel',
              subtitle: 'Annuaire, dossiers et carrière des agents',
              trailing: _Toolbar(
                table: _table,
                onView: (v) => setState(() => _table = v),
                onPdf: all.isEmpty ? null : () => _exportPdf(agents),
                onCsv: all.isEmpty ? null : () => _exportCsv(agents),
              ),
            ),
            const SizedBox(height: 20),
            VsHeroKpis(cards: [
              (Icons.groups_2_rounded, 'Effectif', '${all.length}', kNavy,
                  'agents'),
              (Icons.verified_user_rounded, 'Actifs', '$actifs', kGreen,
                  '${all.length - actifs} inactifs'),
              (Icons.school_rounded, 'Enseignants', '$enseignants',
                  const Color(0xFF0EA5E9), 'corps enseignant'),
              (Icons.badge_rounded, 'Fonctionnaires', '$fonctionnaires',
                  const Color(0xFF7C3AED), 'titulaires'),
            ]),
            const SizedBox(height: 18),
            // Distinction par axe
            Row(children: [
              const Text('Répartir par',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted)),
              const SizedBox(width: 10),
              StaffAxisToggle(
                  axis: _axis,
                  onChanged: (a) => setState(() {
                        _axis = a;
                        _seg = null;
                      })),
            ]),
            const SizedBox(height: 12),
            StaffSegmentBar(
              segments: segs,
              selected: _seg,
              onSelect: (s) => setState(() => _seg = s),
              metricLabel: 'actifs',
            ),
            const SizedBox(height: 14),
            _DistributionBar(segments: segs),
            const SizedBox(height: 16),
            // Recherche + filtre statut
            Row(children: [
              Expanded(child: _SearchField(
                controller: _search,
                count: all.length,
                onChanged: (v) => setState(() => _q = v),
              )),
              const SizedBox(width: 12),
              _StatusFilter(
                  value: _status, onChanged: (s) => setState(() => _status = s)),
            ]),
            const SizedBox(height: 16),
            VsSectionLabel(
                icon: Icons.people_alt_rounded,
                text: '${agents.length} agent${agents.length > 1 ? 's' : ''} '
                    'affiché${agents.length > 1 ? 's' : ''}'),
            const SizedBox(height: 10),
            if (agents.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: AdminEmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'Aucun agent',
                  message: 'Aucun agent ne correspond à ce filtre.',
                ),
              )
            else if (_table)
              _PersonnelTable(
                  agents: agents, onOpen: (a) => showStaffDossier(context, a.id))
            else
              _PersonnelCards(
                  agents: agents, onOpen: (a) => showStaffDossier(context, a.id)),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}

// ─── Barre d'outils : bascule vue + export ───────────────────────────────────
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.table,
    required this.onView,
    required this.onPdf,
    required this.onCsv,
  });
  final bool table;
  final ValueChanged<bool> onView;
  final VoidCallback? onPdf, onCsv;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      // bascule Cartes / Tableau
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _viewBtn(Icons.grid_view_rounded, !table, () => onView(false)),
          _viewBtn(Icons.table_rows_rounded, table, () => onView(true)),
        ]),
      ),
      const SizedBox(width: 10),
      PopupMenuButton<String>(
        enabled: onPdf != null || onCsv != null,
        onSelected: (v) => v == 'pdf' ? onPdf?.call() : onCsv?.call(),
        itemBuilder: (_) => const [
          PopupMenuItem(
              value: 'pdf',
              child: Row(children: [
                Icon(Icons.picture_as_pdf_outlined, size: 17, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Text('Exporter PDF'),
              ])),
          PopupMenuItem(
              value: 'csv',
              child: Row(children: [
                Icon(Icons.table_chart_outlined, size: 17, color: kGreen),
                SizedBox(width: 8),
                Text('Exporter CSV'),
              ])),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [kNavyDark, kNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.download_rounded, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text('Exporter',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]);
  }

  Widget _viewBtn(IconData icon, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon,
              size: 18, color: active ? Colors.white : kTextMuted),
        ),
      );
}
