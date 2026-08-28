import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/infirmerie_provider.dart';
import '../providers/vs_students_provider.dart';
import '../widgets/vs_kit.dart';
import '../widgets/vs_form_chrome.dart';
import '../widgets/vs_student_field.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/utils/date_scolaire.dart';

part 'infirmerie_cards.dart';
part 'infirmerie_form.dart';

const _kSlug = kSlugInfirmerie;

// ════════════════════════════════════════════════════════════════════════════
//  INFIRMERIE — journal des passages (sensible). KPI hero → panneau Cycle ▸
//  Niveau ▸ Classe (compteurs, filtre) → barre (recherche + Nouveau passage) →
//  liste des visites. Formulaire médical complet. 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class InfirmerieScreen extends ConsumerWidget {
  const InfirmerieScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Infirmerie',
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
  ScopeSel _scope = const ScopeSel();

  /// N'afficher que les passages dont le suivi reste ouvert. Sans ce filtre,
  /// le KPI « Suivis requis » annonçait un nombre que rien ne permettait
  /// d'atteindre : un rappel qu'on ne peut pas ouvrir n'est pas un rappel.
  bool _suiviSeul = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InfirmaryVisit> _apply(List<InfirmaryVisit> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((v) {
      if (_scope.cycle != null && v.cycleCode != _scope.cycle) return false;
      if (_scope.level != null && v.levelCode != _scope.level) return false;
      if (_scope.classId != null && v.classId != _scope.classId) return false;
      if (_suiviSeul && !v.followUpRequired) return false;
      if (q.isEmpty) return true;
      // Le traitement et la médication font partie de ce qu'on cherche :
      // « qui a reçu de l'amoxicilline cette semaine ? » est la question d'un
      // infirmier, et elle ne trouvait rien.
      return v.studentName.toLowerCase().contains(q) ||
          (v.symptoms ?? '').toLowerCase().contains(q) ||
          (v.diagnosis ?? '').toLowerCase().contains(q) ||
          (v.treatment ?? '').toLowerCase().contains(q) ||
          (v.medication ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _openForm({InfirmaryVisit? visit}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _VisitForm(visit: visit),
      );

  Future<void> _delete(InfirmaryVisit v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer ce passage ?'),
        content: Text('Le passage du ${v.date} de ${v.studentName} sera supprimé.'),
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
    await runModuleWrite(context, () => deleteVisit(v.id),
        success: 'Passage supprimé');
  }

  /// Clôt un suivi, en laissant dire ce qui a été fait.
  Future<void> _cloreSuivi(InfirmaryVisit v) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Suivi effectué'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              'Le suivi de ${v.studentName} (passage du ${v.date}) sera marqué '
              'comme effectué. Ce que vous écrivez ici s\'ajoute aux notes — '
              'rien n\'est effacé.',
              style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            maxLines: 2,
            decoration: adminFilledInput('Ce qui a été fait (facultatif)',
                icon: Icons.task_alt_rounded),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Marquer effectué'),
          ),
        ],
      ),
    );
    final note = ctrl.text;
    ctrl.dispose();
    if (ok != true || !mounted) return;
    await runModuleWrite(context, () => cloreSuivi(v.id, note: note),
        success: 'Suivi clos');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(visitsProvider);
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final readOnly = ref.watch(yearReadOnlyProvider);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(messageErreur(e))),
      data: (all) {
        final filtered = _apply(all);
        final todayCount = all.where((v) => v.date == today).length;
        final followUp = all.where((v) => v.followUpRequired).length;
        final notified = all.where((v) => v.parentNotified).length;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const VsHeader(
              title: 'Journal de l\'infirmerie',
              subtitle:
                  'Passages par cycle, niveau et classe — année en cours',
            ),
            const SizedBox(height: 20),
            VsHeroKpis(cards: [
              (Icons.local_hospital_rounded, 'Passages', '${all.length}',
                  kNavy, 'cette année'),
              (Icons.today_rounded, 'Aujourd\'hui', '$todayCount',
                  todayCount == 0 ? kTextMuted : const Color(0xFF0EA5E9), null),
              (Icons.medical_services_rounded, 'Suivis requis', '$followUp',
                  followUp == 0 ? kTextMuted : const Color(0xFFF59E0B), 'à surveiller'),
              (Icons.notifications_active_rounded, 'Parents notifiés',
                  '$notified', kGreen, 'sur ${all.length}'),
            ]),
            if (all.isNotEmpty) ...[
              const SizedBox(height: 16),
              ScopeDrilldownPanel(
                title: 'Passages par cycle / niveau / classe',
                metricLabel: '',
                unitNoun: 'passages',
                selected: _scope,
                onSelect: (s) => setState(() => _scope = s),
                units: [
                  for (final v in all)
                    ScopeUnit(
                      cycleCode: v.cycleCode,
                      levelCode: v.levelCode,
                      levelOrder: v.levelOrder,
                      classId: v.classId,
                      className: v.className,
                      ok: false,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            _FilterBar(
              search: _search,
              canCreate: canCreate && !readOnly,
              suiviSeul: _suiviSeul,
              suivisOuverts: followUp,
              onToggleSuivi: () => setState(() => _suiviSeul = !_suiviSeul),
              onSearch: (_) => setState(() {}),
              onReset: () => setState(() {
                _search.clear();
                _scope = const ScopeSel();
                _suiviSeul = false;
              }),
              onAdd: () => _openForm(),
            ),
            if (_scope.active) ...[
              const SizedBox(height: 12),
              VsScopeChip(
                  label: _scope.label,
                  onClear: () => setState(() => _scope = const ScopeSel())),
            ],
            const SizedBox(height: 16),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: AdminEmptyState(
                  icon: Icons.local_hospital_outlined,
                  title: 'Aucun passage',
                  message:
                      'Enregistrez un passage à l\'infirmerie pour en garder '
                      'la trace médicale et le suivi.',
                  actionLabel:
                      (canCreate && !readOnly) ? 'Nouveau passage' : null,
                  onAction: (canCreate && !readOnly) ? () => _openForm() : null,
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
              for (final v in filtered)
                _VisitCard(
                  visit: v,
                  canEdit: canEdit && !readOnly,
                  canDelete: canDelete && !readOnly,
                  onEdit: () => _openForm(visit: v),
                  onDelete: () => _delete(v),
                  onCloreSuivi: () => _cloreSuivi(v),
                ),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}
