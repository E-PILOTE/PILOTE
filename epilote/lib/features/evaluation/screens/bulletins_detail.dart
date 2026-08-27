part of 'bulletins_screen.dart';

// ─── Détail d'un bulletin (lignes-matières + PDF) ────────────────────────────
class _BulletinDetailSheet extends ConsumerWidget {
  const _BulletinDetailSheet({
    required this.student,
    required this.classAverage,
    required this.className,
    required this.trimesterId,
  });
  final StudentBulletin student;
  final double? classAverage;
  final String? className, trimesterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(currentSchoolProvider).valueOrNull;
    final year = ref.watch(activeYearProvider);
    final schoolName = school?['name'] as String?;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.studentName,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      Text(
                          '${className ?? ''} · ${student.rank == 0 ? '—' : '${rangOrdinal(student.rank)}/${student.totalStudents}'} · ${student.mention}',
                          style: TextStyle(fontSize: 12, color: kTextMuted)),
                    ]),
              ),
              IconButton(
                tooltip: 'Imprimer le bulletin',
                onPressed: () => showPdfPreviewDialog(
                  context,
                  title: 'Bulletin — ${student.studentName}',
                  subtitle: '${className ?? ''} · ${year?.label ?? ''}',
                  pdfFileName:
                      'bulletin_${student.studentName.replaceAll(' ', '_')}.pdf',
                  build: (_) => BulletinPdfService.buildPdf(
                    student: student,
                    classAverage: classAverage,
                    schoolName: schoolName,
                    className: className,
                    yearLabel: year?.label,
                  ),
                ),
                icon: Icon(Icons.picture_as_pdf_outlined, color: kGreen),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _SummaryStrip(student: student, classAverage: classAverage),
                const SizedBox(height: 14),
                _LinesTable(student: student),
                if (student.decision != null ||
                    (student.councilAppreciation ?? '').trim().isNotEmpty ||
                    (student.directorComment ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _CouncilCard(student: student),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.student, required this.classAverage});
  final StudentBulletin student;
  final double? classAverage;
  @override
  Widget build(BuildContext context) {
    Widget box(String l, String v, Color c) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.withValues(alpha: 0.25)),
            ),
            child: Column(children: [
              Text(v,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: c)),
              const SizedBox(height: 2),
              Text(l,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: kTextMuted)),
            ]),
          ),
        );
    return Row(children: [
      box(
          'Moyenne',
          student.overallAverage == null
              ? '—'
              : student.overallAverage!.toStringAsFixed(2),
          kNavy),
      box('Rang',
          student.rank == 0 ? '—' : '${student.rank}/${student.totalStudents}',
          kGreen),
      box('Mention', student.mention, const Color(0xFFF59E0B)),
      box('Moy. classe',
          classAverage == null ? '—' : classAverage!.toStringAsFixed(2),
          const Color(0xFF0EA5E9)),
    ]);
  }
}

// ─── Décision du conseil de classe (portée par le bulletin) ──────────────────
class _CouncilCard extends StatelessWidget {
  const _CouncilCard({required this.student});
  final StudentBulletin student;
  @override
  Widget build(BuildContext context) {
    final award = awardFor(student.decision);
    final appr = (student.councilAppreciation ?? '').trim();
    final director = (student.directorComment ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNavy.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.how_to_vote_rounded, size: 15, color: kNavy),
          const SizedBox(width: 7),
          Text('Conseil de classe',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kNavy,
                  letterSpacing: 0.2)),
        ]),
        if (award != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: award.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(award.icon, size: 15, color: award.color),
              const SizedBox(width: 7),
              Text(award.label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: award.color)),
            ]),
          ),
        ],
        if (appr.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(appr,
              style: TextStyle(
                  fontSize: 13, height: 1.45, color: kTextPrimary)),
        ],
        if (director.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Synthèse : $director',
              style: TextStyle(
                  fontSize: 12, height: 1.4, color: kTextMuted)),
        ],
      ]),
    );
  }
}

class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.student});
  final StudentBulletin student;
  @override
  Widget build(BuildContext context) {
    Widget cell(String t, {int flex = 1, bool head = false, bool bold = false,
            TextAlign align = TextAlign.left}) =>
        Expanded(
          flex: flex,
          child: Text(t,
              textAlign: align,
              style: TextStyle(
                  fontSize: head ? 11 : 12,
                  fontWeight:
                      head || bold ? FontWeight.w800 : FontWeight.w500,
                  color: head ? kTextMuted : kTextPrimary)),
        );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            cell('Matière', flex: 3, head: true),
            cell('Coef', head: true, align: TextAlign.center),
            cell('Moy/20', flex: 2, head: true, align: TextAlign.center),
            cell('Classe', flex: 2, head: true, align: TextAlign.center),
            cell('Rang', head: true, align: TextAlign.center),
          ]),
        ),
        for (var i = 0; i < student.lines.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : Border(top: BorderSide(color: kBorder, width: 0.5)),
            ),
            child: Row(children: [
              cell(student.lines[i].subjectName, flex: 3, bold: true),
              cell('${student.lines[i].coefficient}',
                  align: TextAlign.center),
              cell(
                  student.lines[i].average == null
                      ? '—'
                      : student.lines[i].average!.toStringAsFixed(2),
                  flex: 2,
                  bold: true,
                  align: TextAlign.center),
              cell(
                  student.lines[i].classAverage == null
                      ? '—'
                      : student.lines[i].classAverage!.toStringAsFixed(2),
                  flex: 2,
                  align: TextAlign.center),
              cell(student.lines[i].rank?.toString() ?? '—',
                  align: TextAlign.center),
            ]),
          ),
      ]),
    );
  }
}
