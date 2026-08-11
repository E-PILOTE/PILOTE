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

part 'infirmerie_form.dart';

const _kSlug = 'infirmerie';

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
      if (q.isEmpty) return true;
      return v.studentName.toLowerCase().contains(q) ||
          (v.symptoms ?? '').toLowerCase().contains(q) ||
          (v.diagnosis ?? '').toLowerCase().contains(q);
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
              subtitle: 'Passages par cycle, niveau et classe',
            ),
            const SizedBox(height: 20),
            VsHeroKpis(cards: [
              (Icons.local_hospital_rounded, 'Passages', '${all.length}',
                  kNavy, 'au total'),
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
              onSearch: (_) => setState(() {}),
              onReset: () => setState(() {
                _search.clear();
                _scope = const ScopeSel();
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
                ),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}

// ─── Barre de filtres ────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.search,
    required this.canCreate,
    required this.onSearch,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController search;
  final bool canCreate;
  final ValueChanged<String> onSearch;
  final VoidCallback onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: search,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Rechercher (élève, symptôme, diagnostic)…',
              hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
              prefixIcon:
                  Icon(Icons.search_rounded, color: kTextMuted, size: 20),
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Réinitialiser',
          onPressed: onReset,
          icon: Icon(Icons.filter_alt_off_outlined, color: kTextMuted),
        ),
        const SizedBox(width: 4),
        if (canCreate)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [kNavyDark, kNavy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Passage',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ─── Carte passage ───────────────────────────────────────────────────────────
class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });
  final InfirmaryVisit visit;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final v = visit;
    final line = [
      if ((v.diagnosis ?? '').isNotEmpty) v.diagnosis!,
      if ((v.treatment ?? '').isNotEmpty) 'Traitement : ${v.treatment}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.local_hospital_rounded, size: 20, color: kRed),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 3),
                  Text(
                      '${v.date}${v.time != null ? ' · ${v.time!.substring(0, 5)}' : ''}'
                      '${v.className != null ? ' · ${v.className}' : ''}'
                      '${v.restHours != null ? ' · repos ${v.restHours}h' : ''}',
                      style: TextStyle(fontSize: 12, color: kTextMuted)),
                  if ((v.symptoms ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Symptômes : ${v.symptoms!.trim()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, height: 1.35)),
                  ],
                  if (line.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: kTextMuted, height: 1.3)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    _Tag(
                      v.parentNotified
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                      v.parentNotified ? 'Parents notifiés' : 'Parents non notifiés',
                      v.parentNotified ? kGreen : kTextMuted,
                    ),
                    if (v.followUpRequired) ...[
                      const SizedBox(width: 8),
                      const _Tag(Icons.medical_services_rounded, 'Suivi requis',
                          Color(0xFFF59E0B)),
                    ],
                  ]),
                ]),
          ),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              icon:
                  Icon(Icons.more_vert_rounded, size: 20, color: kTextMuted),
              onSelected: (x) => x == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (ctx) => [
                if (canEdit)
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ])),
                if (canDelete)
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
                        const SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: kRed)),
                      ])),
              ],
            ),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]);
}
