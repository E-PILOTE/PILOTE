import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../../structure/providers/academic_year_provider.dart' show currentSchoolProvider;
import '../providers/exam_candidates_provider.dart';
import '../providers/exam_registration_provider.dart';
import '../services/exam_export_service.dart';
import '../widgets/examens_widgets.dart' show ExamErrorCard;
import '../widgets/exam_candidate_grouped.dart';
import '../widgets/exam_candidate_list.dart';
import '../widgets/exam_register_dialog.dart';
import '../widgets/transmissions_panel.dart';

const _kSlug = 'examens';

// ════════════════════════════════════════════════════════════════════════════
//  SESSION D'EXAMEN — la page qui PRODUIT, tenue À L'ÉCHELLE.
//
//  Un examen traverse la structure académique : le panneau Cycle ▸ Niveau ▸
//  Classe (ScopeDrilldownPanel) sélectionne le périmètre. Sous lui, les
//  candidats sont REGROUPÉS PAR CLASSE (badge filière, en-têtes pliables) et
//  rendus en SLIVERS : à 500 candidats, seules les lignes visibles sont
//  construites. Le corps est donc UN `CustomScrollView`, pas un `ListView` plat.
//
//  Et il produit du papier : la LISTE DES CANDIDATS déposée au centre d'examen
//  (PDF officiel, sur le périmètre courant) + le CSV pour le tableur du ministère.
// ════════════════════════════════════════════════════════════════════════════
class ExamSessionScreen extends ConsumerStatefulWidget {
  const ExamSessionScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<ExamSessionScreen> createState() => _State();
}

class _State extends ConsumerState<ExamSessionScreen> {
  ScopeSel _scope = const ScopeSel();
  final _search = TextEditingController();
  String _dossier = 'tous';
  String _result = 'tous';
  String _filiere = 'toutes';
  bool _isTable = true;
  final _selected = <String>{};
  Set<String?> _collapsed = <String?>{};
  String _groupKey = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String? get _schoolName =>
      ref.read(currentSchoolProvider).valueOrNull?['name'] as String?;

  /// Candidats du PÉRIMÈTRE courant (scope) — c'est CE sous-ensemble qui part à
  /// l'export et à la transmission : on dépose la liste officielle du périmètre,
  /// jamais un sous-ensemble filtré à l'écran.
  List<ExamCandidateRow> _scoped(ExamSessionCandidates s) {
    return s.candidates.where((c) {
      if (_scope.classId != null) return c.classId == _scope.classId;
      if (_scope.level != null) return c.levelCode == _scope.level;
      if (_scope.cycle != null) return c.cycleCode == _scope.cycle;
      return true;
    }).toList();
  }

  /// Filtres de CONSULTATION (dossier/résultat/filière/recherche) appliqués par
  /// dessus le périmètre — n'affectent que l'affichage, pas l'export.
  List<ExamCandidateRow> _panelFilter(List<ExamCandidateRow> rows) {
    final q = _search.text.trim().toLowerCase();
    return rows.where((c) {
      if (_dossier == 'complet' && !c.isComplete) return false;
      if (_dossier == 'incomplet' && c.isComplete) return false;
      if (_dossier == 'depose' && !c.isSubmitted) return false;
      if (_result == 'avec' && !c.hasResult) return false;
      if (_result == 'sans' && c.hasResult) return false;
      if (_filiere != 'toutes' && c.filiereLabel != _filiere) return false;
      if (q.isEmpty) return true;
      return c.fullName.toLowerCase().contains(q) ||
          (c.matricule ?? '').toLowerCase().contains(q) ||
          (c.candidateNumber ?? '').toLowerCase().contains(q) ||
          (c.className ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _exportPdf(ExamSessionCandidates s) {
    final rows = _scoped(s);
    showPdfPreviewDialog(
      context,
      title: 'Liste des candidats — ${s.examShortName}',
      subtitle: '${rows.length} candidat(s)'
          '${_scope.active ? ' · ${_scope.label}' : ''}',
      pdfFileName: 'Candidats_${s.examShortName}_${s.yearLabel ?? ''}.pdf',
      build: (_) => ExamExportService.buildCandidateListPdf(
        candidates: rows,
        examName: s.examName,
        examShortName: s.examShortName,
        yearLabel: s.yearLabel,
        schoolName: _schoolName,
        tutelle: s.tutelle,
        writtenFrom: s.writtenFrom,
      ),
      onDownload: () => ExamExportService.downloadCandidateListPdf(
        candidates: rows,
        examName: s.examName,
        examShortName: s.examShortName,
        yearLabel: s.yearLabel,
        schoolName: _schoolName,
        tutelle: s.tutelle,
        writtenFrom: s.writtenFrom,
      ),
    );
  }

  Future<void> _exportCsv(ExamSessionCandidates s) async {
    final path = await ExamExportService.downloadCsv(
      candidates: _scoped(s),
      examShortName: s.examShortName,
      yearLabel: s.yearLabel,
    );
    if (!mounted || path == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Exporté : $path'),
      backgroundColor: kGreen,
    ));
  }

  /// Action GROUPÉE : marquer déposés les dossiers COMPLETS sélectionnés. On ne
  /// dépose jamais un dossier incomplet (la DEC le refuserait) : les candidats
  /// non éligibles sont ignorés et signalés, pas bloquants.
  Future<void> _bulkDeposit(List<ExamCandidateRow> rows) async {
    final eligible = rows.where((r) => r.isComplete && !r.isSubmitted).toList();
    final skipped = rows.length - eligible.length;
    if (eligible.isEmpty) {
      _snack('Aucun dossier complet non déposé dans la sélection.', kRed);
      return;
    }
    final ok = await _confirm(
      'Marquer ${eligible.length} dossier(s) déposé(s)',
      'Ces dossiers complets seront marqués comme déposés au centre d\'examen.'
          '${skipped > 0 ? '\n\n$skipped candidat(s) ignoré(s) : dossier incomplet ou déjà déposé.' : ''}',
      'Marquer déposé(s)',
      kNavy,
    );
    if (ok != true) return;
    for (final r in eligible) {
      await submitDossier(r.id);
    }
    ref.invalidate(sessionCandidatesProvider(widget.sessionId));
    setState(_selected.clear);
    _snack('${eligible.length} dossier(s) marqué(s) déposé(s).', kGreen);
  }

  /// Action GROUPÉE : retirer les candidatures NON déposées sélectionnées.
  /// Un dossier déposé est opposable et ne se retire plus — on l'ignore.
  Future<void> _bulkRemove(List<ExamCandidateRow> rows) async {
    final eligible = rows.where((r) => !r.isSubmitted).toList();
    final skipped = rows.length - eligible.length;
    if (eligible.isEmpty) {
      _snack('Aucune candidature retirable (toutes déposées).', kRed);
      return;
    }
    final ok = await _confirm(
      'Retirer ${eligible.length} candidature(s)',
      'Les candidatures sont supprimées ; les élèves ne sont pas touchés et '
          'pourront être réinscrits.'
          '${skipped > 0 ? '\n\n$skipped ignorée(s) : dossier déposé, non retirable.' : ''}',
      'Retirer',
      kRed,
    );
    if (ok != true) return;
    for (final r in eligible) {
      await unregisterCandidate(r.id);
    }
    ref.invalidate(sessionCandidatesProvider(widget.sessionId));
    setState(_selected.clear);
    _snack('${eligible.length} candidature(s) retirée(s).', kGreen);
  }

  Future<bool?> _confirm(String title, String body, String action, Color tone) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
          content: Text(body,
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Annuler', style: TextStyle(color: kTextMuted)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: tone),
              child: Text(action),
            ),
          ],
        ),
      );

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  /// Défaut de pliage : petit périmètre (≤ 3 classes) = tout déplié ; grand
  /// périmètre = tout replié (l'utilisateur déplie ce qu'il traite). Recalculé
  /// quand l'ensemble des classes change (changement de scope/filtre), pas quand
  /// l'utilisateur plie/déplie à la main.
  void _syncCollapse(Set<String?> classIds) {
    final key = (classIds.map((e) => e ?? '·').toList()..sort()).join('|');
    if (key == _groupKey) return;
    _groupKey = key;
    _collapsed = classIds.length > 3 ? {...classIds} : <String?>{};
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionCandidatesProvider(widget.sessionId));
    final canExport = ref.watch(canProvider((slug: _kSlug, action: 'export')));
    final canRegister = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    // Le dépôt à la DEC engage l'établissement : acte du chef d'établissement.
    final canSubmit = ref.watch(canProvider((slug: _kSlug, action: 'validate')));

    return ModuleScaffold(
      slug: _kSlug,
      title: 'Session d\'examen',
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ExamErrorCard(message: '$e'),
        data: (s) {
          if (s == null) {
            return const Center(child: Text('Session introuvable'));
          }
          return _buildBody(s, canExport, canRegister, canEdit, canSubmit);
        },
      ),
    );
  }

  Widget _buildBody(
    ExamSessionCandidates s,
    bool canExport,
    bool canRegister,
    bool canEdit,
    bool canSubmit,
  ) {
    final scoped = _scoped(s);
    final filtered = _panelFilter(scoped);

    // Filières présentes dans le périmètre (pour le filtre + le badge).
    final filieres = {
      for (final r in scoped) if (r.filiereLabel != null) r.filiereLabel!
    };
    final showFiliere = filieres.isNotEmpty;

    // Pliage par défaut selon le nombre de classes du jeu filtré.
    final classIds = {for (final r in filtered) r.classId};
    _syncCollapse(classIds);

    // Sélection : ne garder que des ids encore présents dans le périmètre.
    final scopedIds = {for (final r in scoped) r.id};
    _selected.retainWhere(scopedIds.contains);
    final selectedRows = scoped.where((r) => _selected.contains(r.id)).toList();

    final onRegister = (_scope.classId != null && canRegister)
        ? () => showExamRegisterDialog(context,
            classId: _scope.classId!, className: _scope.label)
        : null;

    final slivers = <Widget>[
      _pad(_Head(
        session: s,
        canExport: canExport,
        onPdf: () => _exportPdf(s),
        onCsv: () => _exportCsv(s),
      )),
      _gap(20),
      _pad(ExamKpiRow(session: s, canWrite: canRegister || canSubmit)),
      _gap(24),
      _pad(ScopeDrilldownPanel(
        units: s.scopeUnits,
        title: 'Couverture des dossiers',
        metricLabel: 'Complets',
        unitNoun: 'candidats',
        selected: _scope,
        onSelect: (sel) => setState(() => _scope = sel),
      )),
      _gap(24),
      _pad(ListFilterBar(
        searchCtrl: _search,
        searchHint: 'Rechercher un candidat, un matricule, un n°…',
        isTableView: _isTable,
        addLabel: 'Inscrire des élèves',
        addIcon: Icons.how_to_reg_rounded,
        onAdd: onRegister,
        onSearchChange: (_) => setState(() {}),
        onToggleView: () => setState(() => _isTable = !_isTable),
        onReset: () => setState(() {
          _search.clear();
          _dossier = 'tous';
          _result = 'tous';
          _filiere = 'toutes';
        }),
        filters: [
          ListFilterDropdown(
            icon: Icons.fact_check_rounded,
            label: 'Dossier',
            value: _dossier,
            items: const {
              'tous': 'Tous',
              'complet': 'Complets',
              'incomplet': 'Incomplets',
              'depose': 'Déposés',
            },
            onChanged: (v) => setState(() => _dossier = v),
          ),
          ListFilterDropdown(
            icon: Icons.emoji_events_rounded,
            label: 'Résultat',
            value: _result,
            items: const {
              'tous': 'Tous',
              'avec': 'Avec résultat',
              'sans': 'Sans résultat',
            },
            onChanged: (v) => setState(() => _result = v),
          ),
          if (showFiliere)
            ListFilterDropdown(
              icon: Icons.account_tree_rounded,
              label: 'Filière',
              value: _filiere,
              items: {
                'toutes': 'Toutes filières',
                for (final f in filieres) f: f,
              },
              onChanged: (v) => setState(() => _filiere = v),
            ),
        ],
      )),
      if (canEdit && selectedRows.isNotEmpty) ...[
        _gap(10),
        _pad(ExamBulkBar(
          selected: selectedRows,
          onDeposit: () => _bulkDeposit(selectedRows),
          onRemove: () => _bulkRemove(selectedRows),
          onClear: () => setState(_selected.clear),
        )),
      ],
      _gap(16),
      _pad(ListResultHeader(
        total: scoped.length,
        filtered: filtered.length,
        noun: 'candidat',
      )),
      _gap(4),
    ];

    // Corps candidats : vide, sans correspondance, ou groupé/virtualisé.
    if (scoped.isEmpty) {
      slivers.add(_pad(const ExamEmptyCandidates()));
    } else if (filtered.isEmpty) {
      slivers.add(_pad(const ExamNoMatch()));
    } else {
      slivers.addAll(examCandidateSlivers(
        rows: filtered,
        collapsed: _collapsed,
        canEdit: canEdit,
        isTable: _isTable,
        showFiliere: showFiliere,
        sessionId: widget.sessionId,
        examCode: s.examCode,
        selected: _selected,
        onToggleGroup: (classId) => setState(() {
          if (_collapsed.contains(classId)) {
            _collapsed.remove(classId);
          } else {
            _collapsed.add(classId);
          }
        }),
        onToggleGroupSelect: (group) => setState(() {
          final all = group.items.every((r) => _selected.contains(r.id));
          if (all) {
            _selected.removeAll(group.items.map((r) => r.id));
          } else {
            _selected.addAll(group.items.map((r) => r.id));
          }
        }),
        onToggleItem: (id) => setState(() =>
            _selected.contains(id) ? _selected.remove(id) : _selected.add(id)),
      ));
    }

    // Le geste ENGAGEANT : figer la liste du périmètre en un dépôt opposable.
    slivers.add(_gap(28));
    slivers.add(_pad(TransmissionsPanel(
      sessionId: widget.sessionId,
      tutelle: s.tutelle,
      yearLabel: s.yearLabel,
      candidates: scoped,
      canValidate: canSubmit,
      scopeLabel: _scope.active ? _scope.label : null,
    )));
    slivers.add(_gap(32));

    return CustomScrollView(slivers: slivers);
  }

  // Enveloppes slivers : padding horizontal homogène + intervalles verticaux.
  Widget _pad(Widget child) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        ),
      );

  Widget _gap(double h) => SliverToBoxAdapter(child: SizedBox(height: h));
}

class _Head extends StatelessWidget {
  const _Head({
    required this.session,
    required this.canExport,
    required this.onPdf,
    required this.onCsv,
  });
  final ExamSessionCandidates session;
  final bool canExport;
  final VoidCallback onPdf, onCsv;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kNavyDeep, // aplat mono : tient dans les 3 thèmes
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.tutelle?.toUpperCase() ?? ''} · session ${session.yearLabel ?? ''}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                      letterSpacing: 0.6),
                ),
                const SizedBox(height: 4),
                Text(session.examName,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
          if (canExport) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
              ),
              onPressed: onCsv,
              icon: const Icon(Icons.table_view_rounded, size: 16),
              label: const Text('CSV'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: kNavyDeep),
              onPressed: onPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
              label: const Text('Liste des candidats'),
            ),
          ],
        ]),
      );
}
