import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../students/widgets/inscription_form_kit.dart';
import '../providers/academic_structure_provider.dart';
import '../providers/academic_year_context.dart';

// ─── Accents par cycle (cohérents avec la page Inscriptions) ─────────────────
const _cycleColors = <String, Color>{
  'prescolaire': Color(0xFFEC4899),
  'primaire': Color(0xFF0EA5E9),
  'college': kGreen,
  'lycee': kNavy,
  'formation_pro': Color(0xFFF59E0B),
};
Color _cycleColor(String code) => _cycleColors[code] ?? kNavy;

class AcademicStructureScreen extends ConsumerWidget {
  const AcademicStructureScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: 'niveaux',
        title: 'Structure académique',
        child: _Body(),
      );
}

class _Body extends ConsumerWidget {
  const _Body();

  void _openClassForm(BuildContext context, StructCycle cycle, StructLevel level,
          {StructClass? existing}) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _ClassFormModal(cycle: cycle, level: level, existing: existing),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(academicStructureProvider);
    final readOnly = ref.watch(yearReadOnlyProvider);

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $e', style: const TextStyle(color: kRed)),
        ),
      ),
      data: (st) {
        if (st.cycles.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: AdminEmptyState(
                icon: Icons.account_tree_outlined,
                title: 'Aucun cycle configuré',
                message:
                    'Les cycles d\'enseignement de l\'école sont définis par '
                    'l\'administration du groupe. Une fois attribués, ils '
                    'apparaîtront ici avec leurs niveaux.',
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(st: st),
              const SizedBox(height: 26),
              const AdminSectionTitle('Organisation pédagogique',
                  icon: Icons.account_tree_rounded,
                  subtitle:
                      'Cycle ▸ Niveau ▸ Classe. Créez les classes sous leur niveau réel.'),
              const SizedBox(height: 14),
              for (final c in st.cycles) ...[
                _CycleSection(
                  cycle: c,
                  readOnly: readOnly,
                  onAddClass: (lvl) => _openClassForm(context, c, lvl),
                  onEditClass: (lvl, cls) =>
                      _openClassForm(context, c, lvl, existing: cls),
                ),
                const SizedBox(height: 16),
              ],
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
  final AcademicStructure st;
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.account_tree_outlined, 'Cycles', '${st.cycles.length}', kNavy),
      (Icons.stairs_outlined, 'Niveaux', '${st.levelCount}', const Color(0xFF0EA5E9)),
      (Icons.class_outlined, 'Classes', '${st.classCount}', kGreen),
      (Icons.groups_outlined, 'Élèves inscrits', '${st.enrolled}', const Color(0xFFF59E0B)),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 880 ? 4 : (w >= 460 ? 2 : 1);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: cols == 1 ? 4.2 : 2.5,
        children: [
          for (final (icon, label, value, color) in items)
            AdminStatCard(label: label, value: value, icon: icon, color: color),
        ],
      );
    });
  }
}

// ─── Section d'un cycle ──────────────────────────────────────────────────────
class _CycleSection extends StatelessWidget {
  const _CycleSection({
    required this.cycle,
    required this.readOnly,
    required this.onAddClass,
    required this.onEditClass,
  });
  final StructCycle cycle;
  final bool readOnly;
  final void Function(StructLevel) onAddClass;
  final void Function(StructLevel, StructClass) onEditClass;

  @override
  Widget build(BuildContext context) {
    final color = _cycleColor(cycle.code);
    return AdminCard(
      padding: EdgeInsets.zero,
      accent: color,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête cycle
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.account_tree_rounded, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cycle.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 2),
                  Text(
                      '${cycle.levels.length} niveaux · ${cycle.classCount} classes · ${cycle.enrolled} élèves',
                      style: const TextStyle(fontSize: 12, color: kTextMuted)),
                ],
              ),
            ),
            if (cycle.hasPrograms)
              const AdminBadge('Filières', color: kNavy,
                  icon: Icons.workspaces_outline),
          ]),
        ),
        // Niveaux
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            children: [
              for (final lvl in cycle.levels)
                _LevelRow(
                  level: lvl,
                  color: color,
                  readOnly: readOnly,
                  onAdd: () => onAddClass(lvl),
                  onEdit: (cls) => onEditClass(lvl, cls),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Ligne d'un niveau (nom + classes + créer) ───────────────────────────────
class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.color,
    required this.readOnly,
    required this.onAdd,
    required this.onEdit,
  });
  final StructLevel level;
  final Color color;
  final bool readOnly;
  final VoidCallback onAdd;
  final void Function(StructClass) onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Pastille niveau
        Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Text(level.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ),
        const SizedBox(width: 12),
        // Classes + bouton créer
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final c in level.classes)
                _ClassChip(
                  cls: c,
                  color: color,
                  onTap: readOnly ? null : () => onEdit(c),
                ),
              if (level.classes.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Aucune classe',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: kTextMuted,
                          fontStyle: FontStyle.italic)),
                ),
              if (!readOnly) _AddChip(color: color, onTap: onAdd),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({required this.cls, required this.color, required this.onTap});
  final StructClass cls;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final ratio = cls.fillRatio;
    final fillColor = cls.isOver
        ? kRed
        : (ratio != null && ratio >= 0.9 ? const Color(0xFFF59E0B) : color);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: fillColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(cls.name,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            if (cls.filiereLabel != null) ...[
              const SizedBox(width: 6),
              Text(cls.filiereLabel!,
                  style: const TextStyle(fontSize: 11, color: kTextMuted)),
            ],
            const SizedBox(width: 8),
            Text(
                cls.capacity != null
                    ? '${cls.enrolled}/${cls.capacity}'
                    : '${cls.enrolled}',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: fillColor)),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.edit_outlined, size: 13, color: kTextMuted),
            ],
          ]),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: color.withValues(alpha: 0.4),
                  style: BorderStyle.solid),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 15, color: color),
              const SizedBox(width: 5),
              Text('Classe',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ]),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  MODAL — créer / modifier une classe sous un niveau (design plateforme).
// ════════════════════════════════════════════════════════════════════════════
class _ClassFormModal extends ConsumerStatefulWidget {
  const _ClassFormModal({
    required this.cycle,
    required this.level,
    this.existing,
  });
  final StructCycle cycle;
  final StructLevel level;
  final StructClass? existing;
  @override
  ConsumerState<_ClassFormModal> createState() => _ClassFormModalState();
}

class _ClassFormModalState extends ConsumerState<_ClassFormModal> {
  late final _name = TextEditingController(
      text: widget.existing?.name ?? '${widget.level.code} A');
  late final _capacity = TextEditingController(
      text: widget.existing?.capacity != null
          ? '${widget.existing!.capacity}'
          : '');
  final _room = TextEditingController();
  String? _filiereCode;
  String? _filiereLabel;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    // Pré-sélection filière en édition (via le libellé existant).
    _filiereLabel = widget.existing?.filiereLabel;
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Le nom de la classe est obligatoire.', kRed);
      return;
    }
    setState(() => _saving = true);
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    try {
      if (_isEdit) {
        await updateClassInfo(
          classId: widget.existing!.id,
          name: name,
          capacity: int.tryParse(_capacity.text.trim()),
          room: _room.text.trim(),
          filiereCode: _filiereCode,
          filiereLabel: _filiereLabel,
        );
      } else {
        await createStructuredClass(
          schoolId: profile?.schoolId ?? '',
          groupId: profile?.groupId ?? '',
          academicYearId: yearId ?? '',
          name: name,
          levelId: widget.level.id,
          cycleCode: widget.cycle.code,
          levelCode: widget.level.code,
          levelOrder: widget.level.order,
          capacity: int.tryParse(_capacity.text.trim()),
          room: _room.text.trim().isEmpty ? null : _room.text.trim(),
          filiereCode: _filiereCode,
          filiereLabel: _filiereLabel,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        _snack(_isEdit ? 'Classe modifiée.' : 'Classe créée.', kGreen);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Erreur : $e', kRed);
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Archiver la classe ?'),
        content: Text(
            'La classe « ${widget.existing!.name} » sera archivée (masquée). '
            'Les inscriptions existantes sont conservées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await archiveClass(widget.existing!.id);
      if (mounted) {
        Navigator.of(context).pop();
        _snack('Classe archivée.', kTextMuted);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Erreur : $e', kRed);
      }
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final filieresAsync = widget.cycle.hasPrograms
        ? ref.watch(cycleFilieresProvider(widget.cycle.code))
        : null;
    return InscriptionModalFrame(
      width: 540,
      maxHeight: 640,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InscriptionHeader(
          icon: _isEdit ? Icons.edit_outlined : Icons.add_rounded,
          title: _isEdit ? 'Modifier la classe' : 'Nouvelle classe',
          subtitle: '${widget.cycle.name} · Niveau ${widget.level.name}',
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (filieresAsync != null)
                  filieresAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (fils) => fils.isEmpty
                        ? const SizedBox.shrink()
                        : FormDropdown<String>(
                            label: 'Filière / série',
                            value: _filiereCode ??
                                _codeForLabel(fils, _filiereLabel),
                            items: {
                              for (final f in fils) f.code: f.name,
                            },
                            onChanged: (v) => setState(() {
                              _filiereCode = v;
                              _filiereLabel =
                                  fils.firstWhere((f) => f.code == v).name;
                            }),
                          ),
                  ),
                FormTextField(
                    controller: _name,
                    label: 'Nom de la classe *',
                    icon: Icons.class_outlined),
                Row(children: [
                  Expanded(
                    child: FormTextField(
                        controller: _capacity,
                        label: 'Capacité',
                        keyboardType: TextInputType.number,
                        icon: Icons.event_seat_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FormTextField(
                        controller: _room,
                        label: 'Salle',
                        icon: Icons.meeting_room_outlined),
                  ),
                ]),
                if (_isEdit) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(Icons.archive_outlined, size: 17),
                      label: const Text('Archiver la classe'),
                      style: TextButton.styleFrom(foregroundColor: kRed),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        AdminDialogFooter(
          saving: _saving,
          submitLabel: _isEdit ? 'Enregistrer' : 'Créer la classe',
          submitIcon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
          submitColor: _isEdit ? kNavy : kGreen,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: _save,
        ),
      ]),
    );
  }

  String? _codeForLabel(List<StructFiliere> fils, String? label) {
    if (label == null) return null;
    for (final f in fils) {
      if (f.name == label) return f.code;
    }
    return null;
  }
}
