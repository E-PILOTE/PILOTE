import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_scolaire.dart';
import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../staff/providers/staff_directory_provider.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/academic_year_context.dart';
import '../providers/lesson_log_provider.dart';
import '../providers/subjects_provider.dart';
import '../providers/timetable_provider.dart';
import '../../../core/utils/message_erreur.dart';

part 'cahier_textes_parts.dart';
part 'cahier_textes_form.dart';
part 'cahier_textes_form_fields.dart';

const _kSlug = kSlugCahierTextes;

// ════════════════════════════════════════════════════════════════════════════
//  PAGE CAHIER DE TEXTES — journal des séances (ce qui a été fait en classe).
//  Offline-first. Design plateforme : KPI → filtres (classe / matière / texte)
//  → liste chronologique → détail (contenu, objectifs, devoirs, ressources).
// ════════════════════════════════════════════════════════════════════════════
class CahierTextesScreen extends ConsumerWidget {
  const CahierTextesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Cahier de textes',
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
  String? _subjectId;
  ScopeSel _scope = const ScopeSel();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _search.clear();
        _subjectId = null;
        _scope = const ScopeSel();
      });

  List<LessonEntry> _apply(List<LessonEntry> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((e) {
      if (_scope.cycle != null && (e.cycleCode ?? '') != _scope.cycle) {
        return false;
      }
      if (_scope.level != null && (e.levelCode ?? '') != _scope.level) {
        return false;
      }
      if (_scope.classId != null && e.classId != _scope.classId) return false;
      if (_subjectId != null && e.subjectId != _subjectId) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          (e.content ?? '').toLowerCase().contains(q) ||
          (e.subjectName ?? '').toLowerCase().contains(q) ||
          (e.className ?? '').toLowerCase().contains(q) ||
          (e.teacherName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _openForm({LessonEntry? entry}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LessonForm(entry: entry),
      );

  void _openDetail(LessonEntry e) {
    // Une année archivée se consulte, elle ne se réécrit pas. Le bouton
    // « Nouvelle séance » lisait déjà `yearReadOnlyProvider` ; « Modifier » et
    // « Supprimer » ne le lisaient pas — on interdisait donc d'ajouter une
    // séance à une année close, tout en laissant en effacer une.
    final readOnly = ref.read(yearReadOnlyProvider);
    final canUpdate =
        ref.read(canProvider((slug: _kSlug, action: 'update'))) && !readOnly;
    final canDelete =
        ref.read(canProvider((slug: _kSlug, action: 'delete'))) && !readOnly;
    showDialog(
      context: context,
      builder: (_) => _LessonDetail(
        entry: e,
        onEdit: canUpdate
            ? () {
                Navigator.pop(context);
                _openForm(entry: e);
              }
            : null,
        onDelete: canDelete ? () => _delete(e) : null,
      ),
    );
  }

  Future<void> _delete(LessonEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer cette séance ?'),
        content: Text('« ${e.title} » (${e.dateLabel}) sera retirée du cahier.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (Navigator.canPop(context)) Navigator.pop(context); // ferme le détail
    await runModuleWrite(context, () => deleteLessonEntry(e.id),
        success: 'Séance supprimée');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lessonEntriesProvider);
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final readOnly = ref.watch(yearReadOnlyProvider);

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(messageErreur(e))),
      data: (all) {
        final filtered = _apply(all);
        final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(entries: all),
              if (all.isNotEmpty) ...[
                const SizedBox(height: 16),
                ScopeDrilldownPanel(
                  title: 'Séances par cycle',
                  metricLabel: 'Avec devoirs',
                  unitNoun: 'séances',
                  selected: _scope,
                  onSelect: (s) => setState(() => _scope = s),
                  units: [
                    for (final e in all)
                      ScopeUnit(
                        cycleCode: e.cycleCode,
                        levelCode: e.levelCode,
                        levelOrder: e.levelOrder,
                        classId: e.classId,
                        className: e.className,
                        ok: e.hasHomework,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              _FilterBar(
                searchCtrl: _search,
                subjectId: _subjectId,
                subjects: {for (final s in subjects) s.id: s.name},
                readOnly: readOnly || !canCreate,
                onSearch: (_) => setState(() {}),
                onSubject: (v) => setState(() => _subjectId = v),
                onReset: _reset,
                onAdd: () => _openForm(),
              ),
              const SizedBox(height: 16),
              _ResultHeader(total: all.length, filtered: filtered.length),
              if (_scope.active) ...[
                const SizedBox(height: 10),
                _ScopeChip(
                  label: _scope.label,
                  onClear: () => setState(() => _scope = const ScopeSel()),
                ),
              ],
              const SizedBox(height: 12),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.history_edu_rounded,
                    title: 'Cahier de textes vide',
                    message:
                        'Consignez les séances : titre, contenu, objectifs et '
                        'devoirs donnés. Trace pédagogique offline.',
                    actionLabel:
                        (canCreate && !readOnly) ? 'Nouvelle séance' : null,
                    onAction:
                        (canCreate && !readOnly) ? () => _openForm() : null,
                  ),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: AdminEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun résultat',
                    message: 'Ajustez la recherche ou les filtres.',
                  ),
                )
              else
                _LessonList(entries: filtered, onOpen: _openDetail),
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
  const _Kpis({required this.entries});
  final List<LessonEntry> entries;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final thisWeek = entries
        .where((e) => e.entryDate != null && e.entryDate!.isAfter(weekAgo))
        .length;
    final classes = entries.map((e) => e.classId).toSet().length;
    final withHw = entries.where((e) => e.hasHomework).length;
    final items = <(IconData, String, String, Color, String?)>[
      (Icons.history_edu_rounded, 'Séances', '${entries.length}', kNavy,
          'consignées'),
      (Icons.date_range_rounded, 'Cette semaine', '$thisWeek',
          const Color(0xFF0EA5E9), '7 derniers jours'),
      (Icons.class_rounded, 'Classes couvertes', '$classes', kGreen, null),
      (Icons.assignment_turned_in_outlined, 'Avec devoirs', '$withHw',
          const Color(0xFFF59E0B), null),
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
              label: label, value: value, icon: icon, color: color, subtitle: sub);
        },
      );
    });
  }
}
