import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../data/models/subject_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/academic_structure_provider.dart';
import '../providers/class_subjects_provider.dart';
import '../../../core/utils/message_erreur.dart';

const _kSlug = 'matieres';

// Accents par cycle (cohérents avec la page Matières).
Map<String, Color> get _cycleColors => <String, Color>{
  'prescolaire': const Color(0xFFEC4899),
  'primaire': const Color(0xFF0EA5E9),
  'college': kGreen,
  'lycee': kNavy,
  'formation_pro': const Color(0xFFF59E0B),
  'fp': const Color(0xFFF59E0B),
};
Color _cyc(String? c) => _cycleColors[c ?? ''] ?? kNavy;

/// Ouvre le détail d'une matière (programme par classe : coef effectif,
/// professeur, effectif). [accent] = couleur de la matière dans la liste.
Future<void> showSubjectDetail(
        BuildContext context, SubjectModel subject, Color accent) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _SubjectDetailDialog(subject: subject, accent: accent),
    );

// ════════════════════════════════════════════════════════════════════════════
//  POPUP DÉTAIL MATIÈRE — une matière vit dans plusieurs classes, chacune avec
//  son coefficient effectif, son professeur et son effectif. Offline-first.
// ════════════════════════════════════════════════════════════════════════════
class _SubjectDetailDialog extends ConsumerWidget {
  const _SubjectDetailDialog({required this.subject, required this.accent});
  final SubjectModel subject;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subjectAssignmentsProvider(subject.id));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 720),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Header(subject: subject, accent: accent),
          Flexible(
            child: async.when(
              skipLoadingOnReload: true,
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(messageErreur(e), style: TextStyle(color: kRed)),
              ),
              data: (rows) =>
                  _Body(subject: subject, rows: rows, canEdit: canEdit),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.subject, required this.accent});
  final SubjectModel subject;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.menu_book_rounded, color: accent, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subject.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: [
              AdminBadge('Coef. par défaut ${subject.coefficient}',
                  color: kGreen),
              if (subject.isAssigned)
                AdminBadge(
                    '${subject.classCount} '
                    'classe${subject.classCount > 1 ? 's' : ''}',
                    color: kNavy),
            ]),
          ]),
        ),
        IconButton(
          tooltip: 'Fermer',
          icon: Icon(Icons.close_rounded, color: kTextMuted),
          onPressed: () => Navigator.pop(context),
        ),
      ]),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(
      {required this.subject, required this.rows, required this.canEdit});
  final SubjectModel subject;
  final List<SubjectAssignment> rows;
  final bool canEdit;

  Future<void> _assign(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => _AssignClassDialog(subject: subject),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalStudents = rows.fold<int>(0, (s, r) => s + r.studentCount);
    final coefs = rows.map((r) => r.effectiveCoef).toList()..sort();
    final coefRange = coefs.isEmpty
        ? '—'
        : (coefs.first == coefs.last
            ? '${coefs.first}'
            : '${coefs.first}–${coefs.last}');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Bandeau synthèse.
        Row(children: [
          _Stat('Classes', '${rows.length}', Icons.meeting_room_outlined, kNavy),
          const SizedBox(width: 10),
          _Stat('Élèves concernés', '$totalStudents',
              Icons.groups_2_outlined, kGreen),
          const SizedBox(width: 10),
          _Stat('Coef. effectif', coefRange, Icons.functions_rounded,
              const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Icon(Icons.school_outlined, size: 16, color: kNavy),
          const SizedBox(width: 8),
          Text('Dispensée dans ces classes',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const Spacer(),
          if (canEdit)
            AdminPrimaryButton(
              label: 'Affecter à une classe',
              icon: Icons.add_rounded,
              color: kNavy,
              onTap: () => _assign(context),
            ),
        ]),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: AdminEmptyState(
              icon: Icons.school_outlined,
              title: 'Pas encore au programme',
              message: 'Affectez « ${subject.name} » aux classes concernées '
                  '(tout cycle / niveau). Chaque classe peut avoir son propre '
                  'coefficient et son professeur (ex. coef. 4 en Tle C, 2 en Tle A).',
              actionLabel: canEdit ? 'Affecter à une classe' : null,
              onAction: canEdit ? () => _assign(context) : null,
            ),
          )
        else
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < rows.length; i++)
                _AssignmentRow(
                  subject: subject,
                  a: rows[i],
                  last: i == rows.length - 1,
                  canEdit: canEdit,
                ),
            ]),
          ),
        if (rows.any((r) => r.hasOverride)) ...[
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Coefficient ajusté pour cette classe (différent du coef du niveau).',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: kTextMuted)),
          ]),
        ),
      );
}

// ─── Ligne « classe » ────────────────────────────────────────────────────────
class _AssignmentRow extends ConsumerWidget {
  const _AssignmentRow({
    required this.subject,
    required this.a,
    required this.last,
    required this.canEdit,
  });
  final SubjectModel subject;
  final SubjectAssignment a;
  final bool last, canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: _cyc(a.cycleCode).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(Icons.meeting_room_outlined,
              size: 18, color: _cyc(a.cycleCode)),
        ),
        const SizedBox(width: 11),
        // Classe + prof + effectif.
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.className,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.person_outline_rounded,
                  size: 13, color: a.hasTeacher ? kNavy : kTextMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(a.teacherLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: a.hasTeacher ? kNavy : kTextMuted)),
              ),
              const SizedBox(width: 10),
              Icon(Icons.groups_2_outlined, size: 13, color: kTextMuted),
              const SizedBox(width: 4),
              Text('${a.studentCount}',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              if (a.weeklyHours != null) ...[
                const SizedBox(width: 10),
                Icon(Icons.schedule_outlined, size: 13, color: kTextMuted),
                const SizedBox(width: 4),
                Text('${a.weeklyHours}h',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        // Coefficient effectif.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: (a.hasOverride ? const Color(0xFFF59E0B) : kGreen)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text('Coef. ${a.effectiveCoef}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: a.hasOverride ? const Color(0xFFB45309) : kGreen)),
        ),
        if (canEdit)
          PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: Icon(Icons.more_vert_rounded,
                size: 18, color: kTextMuted),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            onSelected: (v) async {
              switch (v) {
                case 'coef':
                  await showDialog<void>(
                    context: context,
                    builder: (_) =>
                        _AssignmentEditDialog(subject: subject, a: a),
                  );
                case 'teacher':
                  await showDialog<void>(
                    context: context,
                    builder: (_) => _TeacherPickerDialog(subject: subject, a: a),
                  );
                case 'remove':
                  if (!context.mounted) return;
                  await runModuleWrite(context, () => removeAssignment(a.id),
                      success: 'Retirée du programme de ${a.className}');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'coef',
                  child: Row(children: [
                    Icon(Icons.tune_rounded, size: 17, color: kNavy),
                    const SizedBox(width: 10),
                    const Text('Coefficient / horaire'),
                  ])),
              PopupMenuItem(
                  value: 'teacher',
                  child: Row(children: [
                    Icon(Icons.person_add_alt_1_outlined,
                        size: 17, color: kNavy),
                    const SizedBox(width: 10),
                    const Text('Professeur'),
                  ])),
              PopupMenuItem(
                  value: 'remove',
                  child: Row(children: [
                    Icon(Icons.link_off_rounded, size: 17, color: kRed),
                    const SizedBox(width: 10),
                    const Text('Retirer de la classe'),
                  ])),
            ],
          ),
      ]),
    );
  }
}

// ─── Affecter à une (ou plusieurs) classe(s) ─────────────────────────────────
class _AssignClassDialog extends ConsumerStatefulWidget {
  const _AssignClassDialog({required this.subject});
  final SubjectModel subject;
  @override
  ConsumerState<_AssignClassDialog> createState() => _AssignClassDialogState();
}

class _AssignClassDialogState extends ConsumerState<_AssignClassDialog> {
  final Set<String> _picked = {};
  bool _saving = false;

  Future<void> _save() async {
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    final schoolId = profile?.schoolId;
    if (groupId == null || schoolId == null || _picked.isEmpty) return;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () async {
        for (final classId in _picked) {
          await assignSubjectToClass(
            groupId: groupId,
            schoolId: schoolId,
            subjectId: widget.subject.id,
            classId: classId,
          );
        }
      },
      success: '${widget.subject.name} ajoutée à ${_picked.length} classe(s)',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(assignableClassesProvider(widget.subject.id));
    final candidates = async.valueOrNull ?? const <CandidateClass>[];

    return AdminFormDialog(
      icon: Icons.add_rounded,
      title: 'Affecter « ${widget.subject.name} »',
      subtitle: 'Toutes classes · coef. hérité du défaut, ajustable ensuite',
      width: 460,
      saving: _saving,
      submitLabel: 'Affecter (${_picked.length})',
      submitIcon: Icons.check_rounded,
      onSubmit: (_saving || _picked.isEmpty) ? null : _save,
      body: candidates.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                  'Toutes les classes éligibles ont déjà cette matière, ou '
                  'aucune classe n\'existe pour ce niveau.',
                  style: TextStyle(fontSize: 12.5, color: kTextMuted)),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Material(
                type: MaterialType.transparency,
                child: SingleChildScrollView(
                child: Column(children: [
                  for (final c in candidates)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: kNavy,
                      value: _picked.contains(c.id),
                      onChanged: (v) => setState(() =>
                          v == true ? _picked.add(c.id) : _picked.remove(c.id)),
                      title: Text(c.label,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary)),
                    ),
                ]),
              ),
              ),
            ),
    );
  }
}

// ─── Éditer coefficient effectif / volume horaire ────────────────────────────
class _AssignmentEditDialog extends ConsumerStatefulWidget {
  const _AssignmentEditDialog({required this.subject, required this.a});
  final SubjectModel subject;
  final SubjectAssignment a;
  @override
  ConsumerState<_AssignmentEditDialog> createState() =>
      _AssignmentEditDialogState();
}

class _AssignmentEditDialogState extends ConsumerState<_AssignmentEditDialog> {
  late bool _inherit = widget.a.coefOverride == null;
  late int _coef = widget.a.effectiveCoef;
  late final _hours = TextEditingController(
      text: widget.a.weeklyHours?.toString() ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final h = int.tryParse(_hours.text.trim());
    final ok = await runModuleWrite(
      context,
      () => updateAssignment(
        id: widget.a.id,
        coefficient: _inherit ? null : _coef,
        weeklyHours: h,
        clearCoefficient: _inherit,
      ),
      success: 'Programme de ${widget.a.className} mis à jour',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.tune_rounded,
      title: widget.a.className,
      subtitle: '${widget.subject.name} · coefficient dans cette classe',
      width: 420,
      saving: _saving,
      submitLabel: 'Enregistrer',
      submitIcon: Icons.check_rounded,
      onSubmit: _saving ? null : _save,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: kNavy,
          value: _inherit,
          onChanged: (v) => setState(() {
            _inherit = v;
            if (v) _coef = widget.subject.coefficient;
          }),
          title: Text('Hériter du coef. par défaut',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
          subtitle: Text('Coef. par défaut = ${widget.subject.coefficient}',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ),
        ),
        if (!_inherit) ...[
          const SizedBox(height: 8),
          Text('Coefficient de cette classe',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            _Step(
                icon: Icons.remove_rounded,
                onTap: () => setState(() => _coef = (_coef - 1).clamp(1, 20))),
            Expanded(
              child: Center(
                child: Text('$_coef',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: kNavy)),
              ),
            ),
            _Step(
                icon: Icons.add_rounded,
                onTap: () => setState(() => _coef = (_coef + 1).clamp(1, 20))),
          ]),
        ],
        const SizedBox(height: 16),
        Text('Volume horaire hebdomadaire (optionnel)',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _hours,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13.5),
          decoration:
              adminFilledInput('Ex. 4', icon: Icons.schedule_outlined),
        ),
      ]),
    );
  }
}

// ─── Affecter le professeur ──────────────────────────────────────────────────
class _TeacherPickerDialog extends ConsumerStatefulWidget {
  const _TeacherPickerDialog({required this.subject, required this.a});
  final SubjectModel subject;
  final SubjectAssignment a;
  @override
  ConsumerState<_TeacherPickerDialog> createState() =>
      _TeacherPickerDialogState();
}

class _TeacherPickerDialogState extends ConsumerState<_TeacherPickerDialog> {
  late String? _teacherId = widget.a.teacherId;
  bool _saving = false;

  Future<void> _save() async {
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    final schoolId = profile?.schoolId;
    if (groupId == null || schoolId == null) return;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => setAssignmentTeacher(
        groupId: groupId,
        schoolId: schoolId,
        subjectId: widget.subject.id,
        classId: widget.a.classId,
        teacherId: _teacherId,
      ),
      success: 'Professeur mis à jour',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final teachers =
        ref.watch(schoolTeachersProvider).valueOrNull ?? const <SchoolTeacher>[];
    final hasSel = _teacherId == null || teachers.any((t) => t.id == _teacherId);
    return AdminFormDialog(
      icon: Icons.person_add_alt_1_outlined,
      title: 'Professeur',
      subtitle: '${widget.subject.name} · ${widget.a.className}',
      width: 420,
      saving: _saving,
      submitLabel: 'Enregistrer',
      submitIcon: Icons.check_rounded,
      onSubmit: _saving ? null : _save,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Enseignant titulaire',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: hasSel ? _teacherId : null,
          isExpanded: true,
          style: TextStyle(fontSize: 13.5, color: kTextPrimary),
          icon: Icon(Icons.expand_more_rounded,
              size: 18, color: kTextMuted),
          decoration: adminFilledInput('Non affecté'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Non affecté')),
            for (final t in teachers)
              DropdownMenuItem(value: t.id, child: Text(t.fullName)),
          ],
          onChanged: (v) => setState(() => _teacherId = v),
        ),
        if (teachers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                'Aucun enseignant enregistré. Ajoutez le personnel depuis '
                '« Personnel ».',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder)),
            child: Icon(icon, size: 20, color: kNavy),
          ),
        ),
      );
}
