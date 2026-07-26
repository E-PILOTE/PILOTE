import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_students_provider.dart';
import 'group_student_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉSULTATS DE RECHERCHE ÉLÈVES — vue ministère.
//
//  Colonnes choisies pour la question que se pose un ministère technique :
//  QUI, DANS QUELLE ÉCOLE, DANS QUELLE FILIÈRE. Un élève sans classe pour
//  l'année courante est signalé en rouge — c'est le cas qui appelle une
//  relance, pas un détail cosmétique.
// ════════════════════════════════════════════════════════════════════════════
const _kFlex = <int>[26, 13, 24, 20, 11, 8];

class GroupStudentTable extends StatelessWidget {
  const GroupStudentTable({super.key, required this.students});
  final List<GroupStudent> students;

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          const _Header(),
          for (var i = 0; i < students.length; i++)
            _Row(student: students[i], striped: i.isOdd),
        ]),
      );
}

class _Header extends StatelessWidget {
  const _Header();

  static const _labels = [
    'ÉLÈVE',
    'MATRICULE',
    'ÉTABLISSEMENT',
    'FILIÈRE',
    'CLASSE',
    'ÂGE',
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border(bottom: BorderSide(color: kBorder)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Row(children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              flex: _kFlex[i],
              child: Padding(
                padding:
                    EdgeInsets.only(right: i == _labels.length - 1 ? 0 : 10),
                child: Text(
                  _labels[i],
                  textAlign: i == 5 ? TextAlign.right : TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: kTextMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6),
                ),
              ),
            ),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.student, required this.striped});
  final GroupStudent student;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    final s = student;

    Widget cell(int i, String text, {Color? color, FontWeight? weight}) =>
        Expanded(
          flex: _kFlex[i],
          child: Padding(
            // Même gouttière que le palmarès : deux colonnes de texte ne
            // doivent jamais se toucher (elles se liraient comme un seul mot).
            padding: EdgeInsets.only(right: i == _kFlex.length - 1 ? 0 : 10),
            child: Text(
              text,
              textAlign: i == 5 ? TextAlign.right : TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color ?? kTextMuted,
                  fontSize: 12.5,
                  fontWeight: weight ?? FontWeight.w500),
            ),
          ),
        );

    return InkWell(
      onTap: () => showGroupStudentDialog(context, s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: striped ? kCardBg.withValues(alpha: 0.4) : Colors.transparent,
          border:
              Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          Expanded(
            flex: _kFlex[0],
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 9),
                decoration: BoxDecoration(
                  color: s.isFemale ? const Color(0xFF7C3AED) : kNavy,
                  shape: BoxShape.circle,
                ),
              ),
              Flexible(
                child: Text(s.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: kTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              if (s.hasScholarship) ...[
                const SizedBox(width: 6),
                Icon(Icons.school_rounded, size: 13, color: kGreen),
              ],
              ]),
            ),
          ),
          cell(1, s.matricule ?? '—'),
          cell(2, s.schoolName, color: kTextPrimary, weight: FontWeight.w600),
          cell(3, s.filiere ?? '—'),
          cell(
            4,
            s.className ?? 'sans classe',
            color: s.isUnplaced ? kRed : kTextMuted,
            weight: s.isUnplaced ? FontWeight.w700 : null,
          ),
          cell(5, s.age == null ? '—' : '${s.age}'),
        ]),
      ),
    );
  }
}
