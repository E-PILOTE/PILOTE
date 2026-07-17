import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../../structure/providers/academic_year_provider.dart' show currentSchoolProvider;
import '../providers/exam_candidates_provider.dart';
import '../services/exam_export_service.dart';
import '../widgets/examens_widgets.dart' show ExamErrorCard, ExamSectionLabel;
import '../widgets/exam_candidate_list.dart';

const _kSlug = 'examens';

// ════════════════════════════════════════════════════════════════════════════
//  SESSION D'EXAMEN — la page qui PRODUIT.
//
//  Un examen traverse la structure académique : d'où le panneau partagé
//  Cycle ▸ Niveau ▸ Classe (ScopeDrilldownPanel), comme les autres modules du
//  projet, plutôt qu'une liste plate. On voit ainsi d'un coup quelle branche
//  n'est pas prête.
//
//  Et il produit du papier : la LISTE DES CANDIDATS déposée au centre d'examen
//  (PDF officiel) + le CSV pour le tableur du ministère.
// ════════════════════════════════════════════════════════════════════════════
class ExamSessionScreen extends ConsumerStatefulWidget {
  const ExamSessionScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<ExamSessionScreen> createState() => _State();
}

class _State extends ConsumerState<ExamSessionScreen> {
  ScopeSel _scope = const ScopeSel();

  String? get _schoolName =>
      ref.read(currentSchoolProvider).valueOrNull?['name'] as String?;

  /// Candidats filtrés par le scope courant — c'est CE sous-ensemble qui part
  /// à l'export : on imprime ce qu'on voit, jamais autre chose.
  List<ExamCandidateRow> _filtered(ExamSessionCandidates s) {
    return s.candidates.where((c) {
      if (_scope.classId != null) return c.classId == _scope.classId;
      if (_scope.level != null) return c.levelCode == _scope.level;
      if (_scope.cycle != null) return c.cycleCode == _scope.cycle;
      return true;
    }).toList();
  }

  void _exportPdf(ExamSessionCandidates s) {
    final rows = _filtered(s);
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
      candidates: _filtered(s),
      examShortName: s.examShortName,
      yearLabel: s.yearLabel,
    );
    if (!mounted || path == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Exporté : $path'),
      backgroundColor: kGreen,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionCandidatesProvider(widget.sessionId));
    final canExport =
        ref.watch(canProvider((slug: _kSlug, action: 'export')));

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
          final rows = _filtered(s);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _Head(session: s, canExport: canExport,
                  onPdf: () => _exportPdf(s), onCsv: () => _exportCsv(s)),
              const SizedBox(height: 20),
              ExamKpiRow(session: s),
              const SizedBox(height: 24),

              // Le panneau partagé du projet : un examen traverse la structure.
              ScopeDrilldownPanel(
                units: s.scopeUnits,
                title: 'Couverture des dossiers',
                metricLabel: 'Complets',
                unitNoun: 'candidats',
                selected: _scope,
                onSelect: (sel) => setState(() => _scope = sel),
              ),
              const SizedBox(height: 24),

              ExamSectionLabel(
                _scope.active ? 'Candidats · ${_scope.label}' : 'Candidats',
                trailing: '${rows.length} candidat(s)',
              ),
              const SizedBox(height: 12),
              ExamCandidateList(rows: rows, sessionId: widget.sessionId),
            ],
          );
        },
      ),
    );
  }
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
