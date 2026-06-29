import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/orientation_provider.dart';
import '../widgets/vs_kit.dart';

part 'orientation_sheet.dart';

const _kSlug = 'orientation';

// ════════════════════════════════════════════════════════════════════════════
//  ORIENTATION — recommandations par élève × trimestre. En-tête (trimestre) →
//  KPI hero → panneau Cycle ▸ Niveau ▸ Classe (élèves orientés) → couverture par
//  classe ; ouvrir = liste élèves → fiche d'orientation (niveau/filière cible,
//  recommandation, parents consultés).
// ════════════════════════════════════════════════════════════════════════════
class OrientationScreen extends ConsumerWidget {
  const OrientationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Orientation',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  String? _trimesterId;
  ScopeSel _scope = const ScopeSel();
  String? _openClassId;

  String? get _activeClassId => _openClassId ?? _scope.classId;

  void _openSheet(OrientationRow r) {
    final readOnly = ref.read(yearReadOnlyProvider);
    final canEdit =
        ref.read(canProvider((slug: _kSlug, action: 'update'))) && !readOnly;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrientationSheet(
        row: r,
        trimesterId: _trimesterId,
        canEdit: canEdit,
        onSaved: () => ref.invalidate(orientationOverviewProvider(_trimesterId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yearId = ref.watch(activeYearIdProvider);
    final trims = (yearId != null
            ? ref.watch(trimestersProvider(yearId)).valueOrNull
            : null) ??
        const [];
    _trimesterId ??=
        trims.where((t) => t.isCurrent).map((t) => t.id).firstOrNull ??
            (trims.isNotEmpty ? trims.first.id : null);
    final overview = ref.watch(orientationOverviewProvider(_trimesterId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        VsHeader(
          title: 'Orientation des élèves',
          subtitle: 'Recommandations par cycle, niveau et classe',
          trailing: SizedBox(
            width: 230,
            child: DropdownButtonFormField<String>(
              initialValue: _trimesterId,
              isExpanded: true,
              decoration:
                  adminFilledInput('Trimestre', icon: Icons.date_range_rounded),
              items: [
                for (final t in trims)
                  DropdownMenuItem(value: t.id, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() {
                _trimesterId = v;
                _scope = const ScopeSel();
                _openClassId = null;
              }),
            ),
          ),
        ),
        const SizedBox(height: 20),
        overview.when(
          loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text('Erreur : $e'))),
          data: _content,
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _content(OrientationOverview ov) {
    if (ov.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: AdminEmptyState(
          icon: Icons.explore_outlined,
          title: 'Aucune classe',
          message: 'Aucune classe active dans votre périmètre cette année.',
        ),
      );
    }
    final rate = ov.students == 0 ? 0 : ov.oriented * 100 ~/ ov.students;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VsHeroKpis(cards: [
        (Icons.explore_rounded, 'Élèves orientés', '${ov.oriented}', kNavy,
            '$rate% de l\'effectif'),
        (Icons.groups_2_rounded, 'Effectif', '${ov.students}',
            const Color(0xFF0EA5E9), '${ov.classesTotal} classes'),
        (Icons.family_restroom_rounded, 'Parents consultés', '${ov.consulted}',
            kGreen, 'sur ${ov.oriented}'),
        (Icons.pending_actions_rounded, 'À orienter',
            '${ov.students - ov.oriented}',
            ov.students - ov.oriented == 0 ? kTextMuted : const Color(0xFFF59E0B),
            null),
      ]),
      const SizedBox(height: 16),
      ScopeDrilldownPanel(
        title: 'Couverture de l\'orientation',
        metricLabel: 'Orientés',
        unitNoun: 'élèves',
        selected: _scope,
        onSelect: (s) => setState(() {
          _scope = s;
          _openClassId = null;
        }),
        units: vsScopeUnits(ov.rows),
      ),
      if (_scope.active || _openClassId != null) ...[
        const SizedBox(height: 12),
        VsScopeChip(
          label: _activeClassId != null
              ? 'Classe : ${_nameOf(ov, _activeClassId!)}'
              : _scope.label,
          onClear: () => setState(() {
            _scope = const ScopeSel();
            _openClassId = null;
          }),
        ),
      ],
      const SizedBox(height: 18),
      if (_activeClassId != null)
        _ClassOrientation(
          args: (classId: _activeClassId!, trimesterId: _trimesterId),
          className: _nameOf(ov, _activeClassId!),
          onOpen: _openSheet,
        )
      else ...[
        const VsSectionLabel(
            icon: Icons.touch_app_rounded,
            text: 'Ouvrez une classe pour orienter ses élèves'),
        const SizedBox(height: 12),
        VsCoverageList(
          rows: vsFilterScope(ov.rows, _scope),
          metricLabel: 'orientés',
          openLabel: 'Orienter',
          onOpen: (r) => setState(() => _openClassId = r.classId),
        ),
      ],
    ]);
  }

  String _nameOf(OrientationOverview ov, String classId) => ov.rows
          .where((r) => r.classId == classId)
          .map((r) => r.className)
          .firstOrNull ??
      '';
}

// ─── Liste des élèves d'une classe (atelier d'orientation) ───────────────────
class _ClassOrientation extends ConsumerWidget {
  const _ClassOrientation({
    required this.args,
    required this.className,
    required this.onOpen,
  });
  final OrientationArgs args;
  final String className;
  final ValueChanged<OrientationRow> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(classOrientationProvider(args));
    return Container(
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.class_rounded, size: 18, color: kNavy),
          const SizedBox(width: 8),
          Text(className,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
        ]),
        const SizedBox(height: 14),
        async.when(
          loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (rows) {
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: AdminEmptyState(
                  icon: Icons.group_off_outlined,
                  title: 'Aucun élève',
                  message: 'Cette classe n\'a pas d\'élève actif inscrit.',
                ),
              );
            }
            return Column(
              children: [for (final r in rows) _row(r)],
            );
          },
        ),
      ]),
    );
  }

  Widget _row(OrientationRow r) {
    final target = [
      if ((r.targetLevel ?? '').isNotEmpty) r.targetLevel!,
      if ((r.targetFiliere ?? '').isNotEmpty) r.targetFiliere!,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: InkWell(
        onTap: () => onOpen(r),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: (r.oriented ? kNavy : kTextMuted).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(
                  r.oriented ? Icons.explore_rounded : Icons.help_outline_rounded,
                  size: 17,
                  color: r.oriented ? kNavy : kTextMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(
                        r.oriented
                            ? (target.isEmpty ? 'Recommandation saisie' : target)
                            : 'À orienter',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: r.oriented ? const Color(0xFF0EA5E9) : kTextMuted)),
                  ]),
            ),
            if (r.oriented && r.parentConsulted)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.family_restroom_rounded,
                    size: 16, color: kGreen),
              ),
            const Icon(Icons.chevron_right_rounded, color: kTextMuted),
          ]),
        ),
      ),
    );
  }
}
