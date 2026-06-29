import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/discipline_provider.dart';
import '../providers/vs_students_provider.dart';
import '../widgets/vs_kit.dart';
import '../widgets/vs_form_chrome.dart';
import '../widgets/vs_student_field.dart';

part 'discipline_form.dart';

const _kSlug = 'discipline';

// ════════════════════════════════════════════════════════════════════════════
//  DISCIPLINE — registre des incidents (sensible). KPI hero → panneau Cycle ▸
//  Niveau ▸ Classe (compteurs d'incidents, sert de filtre) → barre (recherche +
//  type + Nouvel incident) → liste d'incidents. Formulaire élève/type/sanction/
//  suivi. 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class DisciplineScreen extends ConsumerWidget {
  const DisciplineScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Discipline',
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
  String? _type;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DisciplineIncident> _apply(List<DisciplineIncident> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((i) {
      if (_scope.cycle != null && i.cycleCode != _scope.cycle) return false;
      if (_scope.level != null && i.levelCode != _scope.level) return false;
      if (_scope.classId != null && i.classId != _scope.classId) return false;
      if (_type != null && i.type != _type) return false;
      if (q.isEmpty) return true;
      return i.studentName.toLowerCase().contains(q) ||
          (i.description ?? '').toLowerCase().contains(q) ||
          incidentTypeLabel(i.type).toLowerCase().contains(q);
    }).toList();
  }

  void _openForm({DisciplineIncident? incident}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _IncidentForm(incident: incident),
      );

  Future<void> _delete(DisciplineIncident i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer cet incident ?'),
        content: Text(
            'L\'incident du ${i.date} concernant ${i.studentName} sera supprimé.'),
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
    await runModuleWrite(context, () => deleteIncident(i.id),
        success: 'Incident supprimé');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(incidentsProvider);
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final readOnly = ref.watch(yearReadOnlyProvider);

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (all) {
        final filtered = _apply(all);
        final withSanction = all.where((i) => i.hasSanction).length;
        final notified = all.where((i) => i.parentNotified).length;
        final noFollow = all
            .where((i) => i.hasSanction && (i.followUp ?? '').trim().isEmpty)
            .length;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const VsHeader(
              title: 'Registre de discipline',
              subtitle: 'Incidents par cycle, niveau et classe — année en cours',
            ),
            const SizedBox(height: 20),
            VsHeroKpis(cards: [
              (Icons.gavel_rounded, 'Incidents', '${all.length}', kNavy,
                  'cette année'),
              (Icons.report_rounded, 'Avec sanction', '$withSanction',
                  withSanction == 0 ? kTextMuted : const Color(0xFFF59E0B), null),
              (Icons.notifications_active_rounded, 'Parents notifiés',
                  '$notified', kGreen, 'sur ${all.length}'),
              (Icons.pending_actions_rounded, 'Sans suivi', '$noFollow',
                  noFollow == 0 ? kTextMuted : kRed, 'à traiter'),
            ]),
            if (all.isNotEmpty) ...[
              const SizedBox(height: 16),
              ScopeDrilldownPanel(
                title: 'Incidents par cycle / niveau / classe',
                metricLabel: '',
                unitNoun: 'incidents',
                selected: _scope,
                onSelect: (s) => setState(() => _scope = s),
                units: [
                  for (final i in all)
                    ScopeUnit(
                      cycleCode: i.cycleCode,
                      levelCode: i.levelCode,
                      levelOrder: i.levelOrder,
                      classId: i.classId,
                      className: i.className,
                      ok: false,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            _FilterBar(
              search: _search,
              type: _type,
              canCreate: canCreate && !readOnly,
              onSearch: (_) => setState(() {}),
              onType: (v) => setState(() => _type = v),
              onReset: () => setState(() {
                _search.clear();
                _type = null;
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
                  icon: Icons.gavel_outlined,
                  title: 'Aucun incident',
                  message:
                      'Enregistrez un incident disciplinaire pour en assurer '
                      'le suivi et la notification aux familles.',
                  actionLabel:
                      (canCreate && !readOnly) ? 'Nouvel incident' : null,
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
              for (final i in filtered)
                _IncidentCard(
                  incident: i,
                  canEdit: canEdit && !readOnly,
                  canDelete: canDelete && !readOnly,
                  onEdit: () => _openForm(incident: i),
                  onDelete: () => _delete(i),
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
    required this.type,
    required this.canCreate,
    required this.onSearch,
    required this.onType,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController search;
  final String? type;
  final bool canCreate;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onType;
  final VoidCallback onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: search,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Rechercher (élève, motif)…',
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: kTextMuted, size: 20),
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
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String?>(
            initialValue: type,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: kSurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            hint: const Text('Type', style: TextStyle(fontSize: 13)),
            items: [
              const DropdownMenuItem(value: null, child: Text('Type : tous')),
              for (final (v, l) in kIncidentTypes)
                DropdownMenuItem(value: v, child: Text(l)),
            ],
            onChanged: onType,
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Réinitialiser',
          onPressed: onReset,
          icon: const Icon(Icons.filter_alt_off_outlined, color: kTextMuted),
        ),
        const SizedBox(width: 4),
        if (canCreate)
          _AddBtn(onTap: onAdd),
      ]),
    );
  }
}

class _AddBtn extends StatelessWidget {
  const _AddBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [kNavyDark, kNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('Incident',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// ─── Carte incident ──────────────────────────────────────────────────────────
class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.incident,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });
  final DisciplineIncident incident;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final i = incident;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
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
                color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.gavel_rounded,
                size: 20, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(i.studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                    ),
                    const SizedBox(width: 8),
                    _Badge(incidentTypeLabel(i.type), kNavy),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                      '${i.date}${i.className != null ? ' · ${i.className}' : ''}'
                      '${i.hasSanction ? ' · ${sanctionLabel(i.sanction)}' : ''}',
                      style: const TextStyle(fontSize: 12, color: kTextMuted)),
                  if ((i.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(i.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, height: 1.35)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    _Tag(
                      i.parentNotified
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                      i.parentNotified ? 'Parents notifiés' : 'Parents non notifiés',
                      i.parentNotified ? kGreen : kTextMuted,
                    ),
                    if (i.hasSanction && (i.followUp ?? '').trim().isEmpty) ...[
                      const SizedBox(width: 8),
                      const _Tag(Icons.pending_actions_rounded, 'Suivi requis', kRed),
                    ],
                  ]),
                ]),
          ),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              icon:
                  const Icon(Icons.more_vert_rounded, size: 20, color: kTextMuted),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
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
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: kRed)),
                      ])),
              ],
            ),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]);
}
