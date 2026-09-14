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

part 'subject_detail_assignment.dart';
part 'subject_detail_actions.dart';

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
