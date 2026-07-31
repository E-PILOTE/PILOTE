part of 'passage_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Passage : bandeau de campagne, carte de classe, ligne
//  d'élève, feuille de verdict. L'état et les écritures vivent dans l'écran.
// ════════════════════════════════════════════════════════════════════════════

/// Bandeau de campagne : d'où vers où, et ce qui bloque encore.
class _CampaignHeader extends StatelessWidget {
  const _CampaignHeader({
    required this.yearLabel,
    required this.nextLabel,
    required this.nextHasTrimesters,
    required this.structureReady,
    required this.canEdit,
    required this.busy,
    required this.onRollover,
  });

  final String yearLabel;
  final String? nextLabel;
  final bool nextHasTrimesters;
  final bool structureReady, canEdit, busy;
  final VoidCallback onRollover;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.moving_rounded, size: 20, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Passage en classe supérieure',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(height: 2),
              Text(
                nextLabel == null
                    ? '$yearLabel · aucune année suivante déclarée'
                    : '$yearLabel  →  $nextLabel',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              const SizedBox(height: 6),
              // Dire d'emblée ce qui se décide ici et ce qui s'est décidé
              // ailleurs : les deux conseils portent le même nom et ne
              // tranchent pas la même chose.
              Text(
                'Les conseils de classe trimestriels décernent les distinctions '
                'sur les bulletins. Ce conseil-ci rend le verdict de l\'année, '
                'sur la moyenne des trois trimestres.',
                style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
              ),
            ]),
          ),
          if (nextLabel != null && !structureReady && canEdit)
            FilledButton.icon(
              onPressed: busy ? null : onRollover,
              style: FilledButton.styleFrom(backgroundColor: kNavy),
              icon: const Icon(Icons.content_copy_rounded, size: 16),
              label: Text(busy ? 'Reconduction…' : 'Reconduire les classes'),
            ),
        ]),
        if (nextLabel == null) ...[
          const SizedBox(height: 12),
          _Notice(
            color: kAccent,
            icon: Icons.event_busy_rounded,
            text: 'L\'année scolaire suivante n\'existe pas encore. Le conseil '
                'peut délibérer : les décisions sont enregistrées. La '
                'réinscription attendra que l\'année soit ouverte.',
          ),
        ] else if (!structureReady) ...[
          const SizedBox(height: 12),
          _Notice(
            color: kAccent,
            icon: Icons.class_outlined,
            text: 'Les classes de $nextLabel n\'existent pas encore. '
                'Reconduisez la structure pour pouvoir réinscrire — le nom, le '
                'niveau, la filière et le programme sont recopiés ; le '
                'professeur principal reste à désigner.',
          ),
        ],
        // Le calendrier appartient au GROUPE : l'école ne peut pas créer les
        // trimestres de l'année d'accueil (RLS `trimesters_write_ministry`).
        // Elle doit donc le signaler à temps — sans trimestre, la classe
        // reconduite ne pourra recevoir aucune note à la rentrée.
        if (nextLabel != null && !nextHasTrimesters) ...[
          const SizedBox(height: 12),
          _Notice(
            color: kRed,
            icon: Icons.event_repeat_rounded,
            text: '$nextLabel n\'a encore aucun trimestre. Les classes peuvent '
                'être reconduites et les élèves réinscrits, mais aucune note ne '
                'pourra y être saisie tant que le calendrier n\'est pas ouvert. '
                'Le découpage de l\'année se déclare au niveau du groupe '
                '(« Années scolaires ») : signalez-le à votre direction '
                'générale.',
          ),
        ],
      ]),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: kTextPrimary, height: 1.45)),
          ),
        ]),
      );
}

/// Carte d'une classe de passage dans la liste de campagne.
class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.row, required this.onOpen});
  final PassageClass row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final pct = row.students == 0 ? 0.0 : row.decided / row.students;
    final done = row.students > 0 && row.decided == row.students;
    return Material(
      color: kCardBg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: kBorder),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(row.className,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ),
              if (done)
                Icon(Icons.check_circle_rounded, size: 17, color: kGreen)
              else
                Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
            ]),
            if (row.filiereLabel != null) ...[
              const SizedBox(height: 3),
              Text(row.filiereLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: kTextMuted)),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: kBorder,
                valueColor:
                    AlwaysStoppedAnimation(done ? kGreen : kNavy),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${row.decided}/${row.students} délibérés'
              '${row.reenrolled > 0 ? ' · ${row.reenrolled} réinscrits' : ''}',
              style: TextStyle(
                  fontSize: 11.5,
                  color: done ? kGreen : kTextMuted,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Largeur d'une colonne de moyenne trimestrielle.
const _kTrimCol = 46.0;

/// Une ligne d'élève dans la table de délibération.
class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.entry,
    required this.trimesterCount,
    required this.canEdit,
    required this.onTap,
  });
  final PassageEntry entry;

  /// Nombre de colonnes trimestrielles à afficher. Il vient de la SESSION, pas
  /// de l'élève : un élève sans note au 2ᵉ trimestre doit garder sa colonne, un
  /// tiret dedans, sinon les colonnes se décalent d'une ligne à l'autre.
  final int trimesterCount;
  final bool canEdit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = verdictFor(entry.decision);
    final avg = entry.annualAverage;
    return InkWell(
      onTap: canEdit ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 34,
            child: Text('${entry.rank}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kTextMuted)),
          ),
          Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
              if (entry.matricule != null)
                Text(entry.matricule!,
                    style: TextStyle(fontSize: 10.5, color: kTextMuted)),
              // Le redoublement n'est autorisé qu'une fois par niveau. Le
              // conseil doit voir la contrainte AVANT de voter, pas la
              // découvrir à la rentrée. On signale, on ne bloque pas : une
              // dérogation relève de l'établissement, pas du logiciel.
              if (entry.repeatingTwice)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.report_problem_rounded, size: 12, color: kAccent),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text('redouble déjà ce niveau',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: kAccent)),
                  ),
                ])
              else if (entry.alreadyRepeating)
                Text('redoublant cette année',
                    style: TextStyle(fontSize: 10.5, color: kTextMuted)),
            ]),
          ),
          // Les trois moyennes trimestrielles qui composent l'annuelle. Le
          // conseil lit la trajectoire, pas seulement le résultat : un 8 qui
          // finit à 11 ne se juge pas comme un 12 qui finit à 9.
          for (var i = 0; i < trimesterCount; i++)
            SizedBox(
              width: _kTrimCol,
              child: Text(
                i < entry.trimesterAverages.length &&
                        entry.trimesterAverages[i] != null
                    ? entry.trimesterAverages[i]!.toStringAsFixed(2)
                    : '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: kTextMuted),
              ),
            ),
          SizedBox(
            width: 92,
            child: Text(
              avg == null ? '—' : '${avg.toStringAsFixed(2)}/20',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: avg == null
                    ? kTextMuted
                    : (avg >= 10 ? kGreen : kRed),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: v == null
                ? Text('à délibérer',
                    style: TextStyle(
                        fontSize: 12,
                        color: kTextMuted,
                        fontStyle: FontStyle.italic))
                : Row(children: [
                    Icon(v.icon, size: 15, color: v.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(v.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: v.color)),
                    ),
                  ]),
          ),
          SizedBox(
            width: 96,
            child: entry.reenrolled
                ? Row(children: [
                    Icon(Icons.how_to_reg_rounded, size: 14, color: kGreen),
                    const SizedBox(width: 4),
                    Text('réinscrit',
                        style: TextStyle(
                            fontSize: 11,
                            color: kGreen,
                            fontWeight: FontWeight.w600)),
                  ])
                : const SizedBox.shrink(),
          ),
          if (canEdit)
            Icon(Icons.edit_rounded, size: 14, color: kTextMuted)
          else
            const SizedBox(width: 14),
        ]),
      ),
    );
  }
}

/// Feuille de verdict : le conseil tranche pour un élève.
class _VerdictSheet extends StatefulWidget {
  const _VerdictSheet({
    required this.entry,
    required this.trimesters,
    required this.upper,
    required this.repeat,
  });
  final PassageEntry entry;
  final List<PassageTrimester> trimesters;
  final TargetClass? upper, repeat;

  @override
  State<_VerdictSheet> createState() => _VerdictSheetState();
}

class _VerdictSheetState extends State<_VerdictSheet> {
  late String? _code = widget.entry.decision;

  String? _targetFor(String? code) => switch (code) {
        'passe' => widget.upper?.id,
        'redouble' => widget.repeat?.id,
        _ => null,
      };

  String? _targetNameFor(String? code) => switch (code) {
        'passe' => widget.upper?.name,
        'redouble' => widget.repeat?.name,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final target = _targetNameFor(_code);
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
              color: kBorder, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.studentName,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(height: 3),
            Text(
              e.annualAverage == null
                  ? 'Aucune note cette année'
                  : 'Moyenne annuelle ${e.annualAverage!.toStringAsFixed(2)}/20 '
                      '· ${e.rank}ᵉ sur ${e.totalStudents}',
              style: TextStyle(fontSize: 12.5, color: kTextMuted),
            ),
          ]),
        ),
        // Le détail du calcul, sous les yeux du conseil : la moyenne annuelle
        // est la moyenne de ces trois-là, celles des bulletins.
        if (widget.trimesters.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            for (var i = 0; i < widget.trimesters.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _TrimesterChip(
                  label: widget.trimesters[i].shortLabel,
                  average: i < e.trimesterAverages.length
                      ? e.trimesterAverages[i]
                      : null,
                ),
              ),
            ],
          ]),
        ],
        const SizedBox(height: 18),
        for (final v in passageVerdicts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _VerdictTile(
              verdict: v,
              selected: _code == v.code,
              targetName: _targetNameFor(v.code),
              onTap: () => setState(() => _code = _code == v.code ? null : v.code),
            ),
          ),
        if (_code == 'reoriente') ...[
          const SizedBox(height: 4),
          _Notice(
            color: kAccent,
            icon: Icons.info_outline_rounded,
            text: 'Un élève réorienté n\'est pas réinscrit automatiquement : '
                'sa classe d\'accueil se choisit dossier par dossier.',
          ),
        ],
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: kTextMuted)),
            ),
          ),
          const SizedBox(width: 12),
          // Rien de coché : il n'y a à effacer que s'il y avait une décision.
          // Sinon le bouton principal proposait « Effacer la décision » à un
          // élève qui n'avait jamais été délibéré — un geste sans objet.
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kNavy),
              onPressed: _code == null && !e.decided
                  ? null
                  : () => Navigator.pop(context, (
                        code: _code,
                        targetClassId: _targetFor(_code),
                      )),
              child: Text(_code == null
                  ? (e.decided ? 'Effacer la décision' : 'Choisissez un verdict')
                  : (target == null ? 'Enregistrer' : 'Enregistrer → $target')),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Une moyenne trimestrielle dans la feuille de verdict.
class _TrimesterChip extends StatelessWidget {
  const _TrimesterChip({required this.label, required this.average});
  final String label;
  final double? average;

  @override
  Widget build(BuildContext context) {
    final a = average;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: kTextMuted)),
        const SizedBox(height: 3),
        Text(a == null ? '—' : a.toStringAsFixed(2),
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: a == null ? kTextMuted : (a >= 10 ? kGreen : kRed))),
      ]),
    );
  }
}

class _VerdictTile extends StatelessWidget {
  const _VerdictTile({
    required this.verdict,
    required this.selected,
    required this.targetName,
    required this.onTap,
  });
  final PassageVerdict verdict;
  final bool selected;
  final String? targetName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected
            ? verdict.color.withValues(alpha: 0.10)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: selected ? verdict.color : kBorder,
              width: selected ? 1.4 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(verdict.icon, size: 18, color: verdict.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(verdict.label,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      if (targetName != null)
                        Text('vers $targetName',
                            style:
                                TextStyle(fontSize: 11, color: kTextMuted)),
                    ]),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 18, color: verdict.color),
            ]),
          ),
        ),
      );
}
