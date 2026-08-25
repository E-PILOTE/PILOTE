import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/school_exam_candidates_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA LISTE NOMINATIVE DANS LA FICHE D'ÉTABLISSEMENT.
//
//  Repliée par défaut, et c'est délibéré : la modal doit s'ouvrir
//  instantanément. Le provider n'est observé qu'une fois la section dépliée —
//  une requête nominative ne doit pas retarder l'affichage des indicateurs.
//
//  Ce qu'on vient y chercher n'est pas « combien », c'est « lesquels ». D'où
//  les pièces manquantes NOMMÉES sur chaque ligne : « Acte de naissance » se
//  traite, « dossier incomplet » se classe.
// ════════════════════════════════════════════════════════════════════════════
class SchoolCandidatesSection extends ConsumerStatefulWidget {
  const SchoolCandidatesSection({super.key, required this.schoolId});
  final String schoolId;

  @override
  ConsumerState<SchoolCandidatesSection> createState() => _State();
}

class _State extends ConsumerState<SchoolCandidatesSection> {
  bool _open = false;
  String? _cycle;
  String? _filiere;
  bool _incompleteOnly = false;

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _open = true),
          icon: const Icon(Icons.groups_rounded, size: 16),
          label: const Text('Afficher les candidats'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kNavy,
            side: BorderSide(color: kBorder),
          ),
        ),
      );
    }

    final async = ref.watch(schoolExamCandidatesProvider(widget.schoolId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => AdminErrorBanner(message: '$e'),
      data: (rows) => _Body(
        rows: rows,
        cycle: _cycle,
        filiere: _filiere,
        incompleteOnly: _incompleteOnly,
        onCycle: (v) => setState(() => _cycle = v),
        onFiliere: (v) => setState(() => _filiere = v),
        onIncomplete: (v) => setState(() => _incompleteOnly = v),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.rows,
    required this.cycle,
    required this.filiere,
    required this.incompleteOnly,
    required this.onCycle,
    required this.onFiliere,
    required this.onIncomplete,
  });

  final List<SchoolCandidate> rows;
  final String? cycle;
  final String? filiere;
  final bool incompleteOnly;
  final ValueChanged<String?> onCycle;
  final ValueChanged<String?> onFiliere;
  final ValueChanged<bool> onIncomplete;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _Muted(
          'Aucun candidat déclaré par cet établissement sur les sessions '
          'connues.');
    }

    final groups = groupSchoolCandidates(
      rows,
      cycle: cycle,
      filiere: filiere,
      incompleteOnly: incompleteOnly,
    );
    final cycles = cycleOptions(rows);
    final filieres = filiereOptions(rows);
    final shown = groups.fold<int>(0, (s, g) => s + g.candidates.length);
    final blocked = rows.where((c) => !c.isComplete).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        if (cycles.length > 1)
          SizedBox(
            width: 190,
            height: 40,
            child: ListFilterDropdown(
              icon: Icons.school_rounded,
              label: 'Cycle',
              value: cycle ?? '',
              items: {
                '': 'Tous les cycles',
                for (final c in cycles) c: cycleLabelOf(c),
              },
              onChanged: (v) => onCycle(v.isEmpty ? null : v),
            ),
          ),
        if (filieres.isNotEmpty)
          SizedBox(
            width: 210,
            height: 40,
            child: ListFilterDropdown(
              icon: Icons.category_rounded,
              label: 'Filière',
              value: filiere ?? '',
              items: {
                '': 'Toutes les filières',
                for (final f in filieres) f: f,
              },
              onChanged: (v) => onFiliere(v.isEmpty ? null : v),
            ),
          ),
        // L'interrupteur qui sert vraiment : le ministère ne vient pas lire
        // une liste, il vient trouver ce qui bloque.
        FilterChip(
          selected: incompleteOnly,
          onSelected: onIncomplete,
          showCheckmark: false,
          avatar: Icon(Icons.report_problem_rounded,
              size: 15, color: incompleteOnly ? Colors.white : kListOrange),
          label: Text('Incomplets seulement ($blocked)'),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: incompleteOnly ? Colors.white : kTextPrimary,
          ),
          selectedColor: kListOrange,
          backgroundColor: kCardBg,
          side: BorderSide(color: incompleteOnly ? kListOrange : kBorder),
        ),
      ]),
      const SizedBox(height: 14),
      if (groups.isEmpty)
        const _Muted('Aucun candidat ne correspond à ces filtres.')
      else ...[
        Text('$shown candidat(s) affiché(s) sur ${rows.length}',
            style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        const SizedBox(height: 10),
        for (final g in groups) _Group(group: g),
      ],
    ]);
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.group});
  final CandidateGroup group;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(11),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            color: kNavy.withValues(alpha: 0.05),
            child: Row(children: [
              Expanded(
                child: Text(group.heading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: kTextPrimary)),
              ),
              if (group.incomplete > 0)
                AdminBadge('${group.incomplete} à compléter',
                    color: kListOrange),
            ]),
          ),
          for (var i = 0; i < group.candidates.length; i++)
            _Row(candidate: group.candidates[i], striped: i.isOdd),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.candidate, required this.striped});
  final SchoolCandidate candidate;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    // Un dossier peut être marqué incomplet SANS liste de pièces : le badge
    // alerte quand même, sinon l'écran affirmerait que tout va bien.
    final detail = c.missingDocuments.isEmpty
        ? 'pièces à préciser'
        : c.missingDocuments.join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: striped ? kNavy.withValues(alpha: 0.02) : null,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 34,
          child: Row(children: [
            Flexible(
              child: Text(c.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
            if (c.isRepeater) ...[
              const SizedBox(width: 6),
              Text('redoublant',
                  style: TextStyle(fontSize: 10, color: kTextMuted)),
            ],
          ]),
        ),
        Expanded(
          flex: 16,
          child: Text(c.className,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ),
        Expanded(
          flex: 16,
          child: Text(c.candidateNumber ?? 'n° à venir',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  color: c.candidateNumber == null ? kTextMuted : kTextPrimary,
                  fontStyle: c.candidateNumber == null
                      ? FontStyle.italic
                      : FontStyle.normal)),
        ),
        Expanded(
          flex: 34,
          child: c.isComplete
              ? Row(children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: kGreen),
                  const SizedBox(width: 5),
                  Text(c.isSubmitted ? 'complet · déposé' : 'complet',
                      style: TextStyle(fontSize: 11.5, color: kGreen)),
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.report_problem_rounded,
                      size: 14, color: kListOrange),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(detail,
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: kListOrange,
                            height: 1.35)),
                  ),
                ]),
        ),
      ]),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.45)),
      );
}
