import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/documents_provider.dart';
import '../providers/student_documents_provider.dart';
import '../providers/students_registry_provider.dart';
import '../services/documents_pdf_service.dart';

part 'documents_parts.dart';
part 'documents_detail.dart';

const _kSlug = 'documents';

// Filtre de conformité.
enum _DossierFilter { all, complete, incomplete, expired }

// ─── Référentiel cycles (couleur / nom / ordre) ──────────────────────────────
const _cycleColors = <String, Color>{
  'prescolaire': Color(0xFFEC4899),
  'primaire': Color(0xFF0EA5E9),
  'college': kGreen,
  'lycee': kNavy,
  'formation_pro': Color(0xFFF59E0B),
  'fp': Color(0xFFF59E0B),
};
const _cycleNames = <String, String>{
  'prescolaire': 'Préscolaire',
  'primaire': 'Primaire',
  'college': 'Collège',
  'lycee': 'Lycée',
  'formation_pro': 'Formation Pro.',
  'fp': 'Formation Pro.',
};
const _cycleOrder = <String, int>{
  'prescolaire': 1, 'primaire': 2, 'college': 3, 'lycee': 4,
  'formation_pro': 5, 'fp': 5,
};
Color _cycColor(String? code) => _cycleColors[code ?? ''] ?? kTextMuted;
String _cycName(String? code) => _cycleNames[code ?? ''] ?? 'Non classé';
int _cycOrder(String? code) => _cycleOrder[code ?? ''] ?? 9;

// ════════════════════════════════════════════════════════════════════════════
//  PAGE DOCUMENTS — pilotage de la CONFORMITÉ des dossiers d'élèves. Deux vues :
//  « Par élève » (checklist des pièces exigées + état du dossier) et « Registre »
//  (toutes les pièces déposées). Offline-first. Réutilise `student_documents` et
//  le catalogue partagé `studentDocTypes`. Design plateforme (KPI → filtres →
//  contenu).
// ════════════════════════════════════════════════════════════════════════════
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Documents',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _search = TextEditingController();
  _DossierFilter _filter = _DossierFilter.all;
  bool _byStudent = true; // true = Par élève | false = Registre

  // Panneau « Conformité » — navigation en cascade Cycle › Niveau › Classe.
  // À chaque cran, la liste d'élèves se restreint au scope courant.
  String? _navCycle, _navLevel, _navClass;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // Descendre d'un cran (cycle → niveau → classe).
  void _drillCycle(String c) => setState(() {
        _navCycle = c;
        _navLevel = _navClass = null;
      });
  void _drillLevel(String l) => setState(() {
        _navLevel = l;
        _navClass = null;
      });
  void _drillClass(String id) =>
      setState(() => _navClass = _navClass == id ? null : id);

  // Remonter via le fil d'Ariane : 0 = Tous, 1 = cycle, 2 = niveau.
  void _crumbTo(int depth) => setState(() {
        if (depth < 1) _navCycle = null;
        if (depth < 2) _navLevel = null;
        _navClass = null;
      });

  bool get _hasPick => _navCycle != null;

  bool _matchesPick(StudentRow s) {
    if (_navCycle != null && s.cycleCode != _navCycle) return false;
    if (_navLevel != null && s.levelCode != _navLevel) return false;
    if (_navClass != null && s.classId != _navClass) return false;
    return true;
  }

  // Libellé du scope courant (cran le plus profond) pour le bandeau de filtre.
  String _pickLabel(List<StudentDossier> all) {
    if (_navClass != null) {
      final m = all
          .where((d) => d.student.classId == _navClass)
          .map((d) => d.student.className)
          .firstWhere((n) => n != null, orElse: () => null);
      return 'Classe : ${m ?? '—'}';
    }
    if (_navLevel != null) return 'Niveau : $_navLevel';
    return 'Cycle : ${_cycName(_navCycle)}';
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  void _reset() => setState(() {
        _search.clear();
        _filter = _DossierFilter.all;
        _navCycle = _navLevel = _navClass = null;
      });

  List<StudentDossier> _applyDossiers(List<StudentDossier> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((d) {
      if (_hasPick && !_matchesPick(d.student)) return false;
      switch (_filter) {
        case _DossierFilter.complete:
          if (!d.isComplete) return false;
        case _DossierFilter.incomplete:
          if (d.isComplete) return false;
        case _DossierFilter.expired:
          if (d.expiredCount == 0) return false;
        case _DossierFilter.all:
          break;
      }
      if (q.isEmpty) return true;
      return d.student.fullName.toLowerCase().contains(q) ||
          d.student.matricule.toLowerCase().contains(q) ||
          (d.student.className ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<DocRow> _applyDocs(List<DocRow> all, Set<String>? allowedIds) {
    final q = _search.text.trim().toLowerCase();
    return all.where((d) {
      if (allowedIds != null && !allowedIds.contains(d.studentId)) return false;
      if (_filter == _DossierFilter.expired && !d.isExpired) return false;
      if (q.isEmpty) return true;
      return d.fullName.toLowerCase().contains(q) ||
          d.matricule.toLowerCase().contains(q) ||
          d.typeLabel.toLowerCase().contains(q) ||
          (d.className ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _openDossier(StudentDossier d) => showDialog(
        context: context,
        builder: (_) => _DossierDetail(dossier: d),
      );

  void _previewPdf(List<StudentDossier> dossiers) {
    if (dossiers.isEmpty) {
      _snack('Aucun dossier à exporter', kTextMuted);
      return;
    }
    final year = ref.read(activeYearProvider)?.label;
    showPdfPreviewDialog(
      context,
      title: 'Dossiers documentaires',
      subtitle: '${dossiers.length} élève${dossiers.length > 1 ? 's' : ''}'
          '${year != null ? ' · $year' : ''}',
      pdfFileName: 'Dossiers.pdf',
      build: (_) =>
          DocumentsPdfService.buildPdf(dossiers: dossiers, yearLabel: year),
      onDownload: () =>
          DocumentsPdfService.downloadDoc(dossiers: dossiers, yearLabel: year),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dossiersAsync = ref.watch(studentDossiersProvider);
    return dossiersAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $e', style: const TextStyle(color: kRed)),
        ),
      ),
      data: (allDossiers) {
        final st = ref.watch(docStatsProvider);
        final docs = ref.watch(schoolDocumentsProvider).valueOrNull ?? const [];
        final allowedIds = _hasPick
            ? {
                for (final d in allDossiers)
                  if (_matchesPick(d.student)) d.student.id
              }
            : null;
        final filteredDossiers = _applyDossiers(allDossiers);
        final filteredDocs = _applyDocs(docs, allowedIds);
        final hasAny = allDossiers.isNotEmpty;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(st: st),
              if (hasAny) ...[
                const SizedBox(height: 16),
                _ConformitePanel(
                  dossiers: allDossiers,
                  navCycle: _navCycle,
                  navLevel: _navLevel,
                  navClass: _navClass,
                  onDrillCycle: _drillCycle,
                  onDrillLevel: _drillLevel,
                  onDrillClass: _drillClass,
                  onCrumb: _crumbTo,
                ),
              ],
              const SizedBox(height: 22),
              _FilterBar(
                searchCtrl: _search,
                filter: _filter,
                byStudent: _byStudent,
                onSearch: (_) => setState(() {}),
                onFilter: (v) => setState(() => _filter = v),
                onToggleView: () => setState(() => _byStudent = !_byStudent),
                onReset: _reset,
              ),
              const SizedBox(height: 16),
              _ResultHeader(
                byStudent: _byStudent,
                count: _byStudent ? filteredDossiers.length : filteredDocs.length,
                total: _byStudent ? allDossiers.length : docs.length,
                onExportPdf: filteredDossiers.isEmpty
                    ? null
                    : () => _previewPdf(filteredDossiers),
              ),
              if (_hasPick) ...[
                const SizedBox(height: 10),
                _ActiveFilterChip(
                  label: _pickLabel(allDossiers),
                  onClear: () => _crumbTo(0),
                ),
              ],
              const SizedBox(height: 12),
              if (!hasAny)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.folder_off_rounded,
                    title: 'Aucun élève inscrit',
                    message:
                        'Les dossiers documentaires apparaîtront ici dès que '
                        'des élèves seront inscrits. Les pièces se téléversent '
                        'depuis la fiche élève ou ce module.',
                  ),
                )
              else if (_byStudent && filteredDossiers.isEmpty ||
                  !_byStudent && filteredDocs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun résultat',
                    message: 'Ajustez la recherche ou les filtres.',
                  ),
                )
              else if (_byStudent)
                _DossierGrid(dossiers: filteredDossiers, onOpen: _openDossier)
              else
                _RegistryTable(rows: filteredDocs),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ─── KPIs ─────────────────────────────────────────────────────────────────────
class _Kpis extends StatelessWidget {
  const _Kpis({required this.st});
  final DocStats st;
  @override
  Widget build(BuildContext context) {
    final pct = st.totalFolders == 0
        ? 0
        : (st.completeFolders * 100 / st.totalFolders).round();
    final items = <(IconData, String, String, Color, String?)>[
      (Icons.description_rounded, 'Pièces déposées', '${st.totalDocs}', kNavy,
          'tous dossiers'),
      (Icons.verified_rounded, 'Vérifiées', '${st.verified}',
          const Color(0xFF0EA5E9), st.totalDocs > 0
              ? '${(st.verified * 100 / st.totalDocs).round()}% du total'
              : null),
      (Icons.folder_special_rounded, 'Dossiers complets', '${st.completeFolders}',
          kGreen, '$pct% des élèves'),
      (Icons.event_busy_rounded, 'Pièces expirées', '${st.expired}',
          st.expired > 0 ? kRed : kTextMuted, 'à renouveler'),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 920 ? 4 : (w >= 620 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 176,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final (icon, label, value, color, sub) = items[i];
          return AdminStatCard(
              label: label,
              value: value,
              icon: icon,
              color: color,
              subtitle: sub);
        },
      );
    });
  }
}
