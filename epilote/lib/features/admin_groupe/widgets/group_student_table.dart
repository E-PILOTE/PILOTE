import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_students_provider.dart';
import 'student_avatar.dart';
import 'student_dossier_dialog.dart';

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
  const GroupStudentTable({
    super.key,
    required this.students,
    required this.sort,
    required this.onSort,
  });

  final List<GroupStudent> students;
  final StudentSortState sort;
  final ValueChanged<StudentSort> onSort;

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          _Header(sort: sort, onSort: onSort),
          for (var i = 0; i < students.length; i++)
            _Row(student: students[i], striped: i.isOdd),
        ]),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.sort, required this.onSort});

  final StudentSortState sort;
  final ValueChanged<StudentSort> onSort;

  /// Le matricule n'est pas triable : c'est un identifiant, son ordre
  /// alphabétique ne veut rien dire pour un lecteur.
  static const _cols = <(String, StudentSort?)>[
    ('ÉLÈVE', StudentSort.name),
    ('MATRICULE', null),
    ('ÉTABLISSEMENT', StudentSort.school),
    ('FILIÈRE', StudentSort.filiere),
    ('CLASSE', StudentSort.className),
    ('ÂGE', StudentSort.age),
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border(bottom: BorderSide(color: kBorder)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Row(children: [
          for (var i = 0; i < _cols.length; i++)
            Expanded(
              flex: _kFlex[i],
              child: Padding(
                padding: EdgeInsets.only(right: i == _cols.length - 1 ? 0 : 10),
                child: _HeaderCell(
                  label: _cols[i].$1,
                  column: _cols[i].$2,
                  right: i == 5,
                  active: _cols[i].$2 == sort.key,
                  ascending: sort.ascending,
                  onSort: onSort,
                ),
              ),
            ),
        ]),
      );
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.column,
    required this.right,
    required this.active,
    required this.ascending,
    required this.onSort,
  });

  final String label;
  final StudentSort? column;
  final bool right;
  final bool active;
  final bool ascending;
  final ValueChanged<StudentSort> onSort;

  @override
  Widget build(BuildContext context) {
    final text = Flexible(
      child: Text(
        label,
        textAlign: right ? TextAlign.right : TextAlign.left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: active ? kNavy : kTextMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6),
      ),
    );

    final row = Row(
      mainAxisAlignment:
          right ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        text,
        // La flèche n'apparaît que sur la colonne qui trie : six flèches grises
        // en permanence noieraient l'information au lieu de la donner.
        if (active) ...[
          const SizedBox(width: 3),
          Icon(
            ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: kNavy,
          ),
        ],
      ],
    );

    final col = column;
    if (col == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: row,
      );
    }
    return InkWell(
      onTap: () => onSort(col),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: row,
      ),
    );
  }
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
      onTap: () => showStudentDossierDialog(context, s.id),
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
              // Photo si l'école en a chargé une, initiales sinon : on
              // reconnaît une ligne d'un coup d'œil, ce qu'une pastille de
              // couleur seule ne permettait pas.
              StudentAvatar(
                name: s.fullName,
                photoUrl: s.photoUrl,
                gender: s.gender,
                radius: 14,
              ),
              const SizedBox(width: 10),
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
