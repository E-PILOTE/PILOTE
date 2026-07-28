import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_schools_provider.dart';
import '../providers/exam_archives_provider.dart';
import 'exam_figure_fields.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RELEVER TOUS LES CHIFFRES D'UNE MÊME PUBLICATION.
//
//  Une publication de la DEC ne porte pas un chiffre : elle porte le national,
//  puis chacun des douze départements, puis parfois les établissements un à
//  un. Le panneau de relevé imposait un aller-retour complet à chaque ligne —
//  rouvrir, rechoisir la session, retrouver la pièce dans une liste. Trente
//  fois. Le résultat prévisible : on relevait le national, et on renonçait au
//  reste.
//
//  Ici, la pièce ne bouge plus. Elle est épinglée en tête, avec sa session et
//  sa date, et « Enregistrer et suivant » ne vide que le périmètre et les
//  nombres. Ce partage n'est pas cosmétique : garder les effectifs d'un
//  département sur le suivant produirait des chiffres faux qui ne se voient
//  pas — ils se découvrent dans une statistique nationale, des mois après.
// ════════════════════════════════════════════════════════════════════════════
Future<void> showExamFigureBatchPanel(
  BuildContext context, {
  required ExamPublication publication,
}) =>
    showAdminSidePanel<void>(
      context,
      builder: (_) => _BatchPanel(publication: publication),
    );

class _BatchPanel extends ConsumerStatefulWidget {
  const _BatchPanel({required this.publication});
  final ExamPublication publication;

  @override
  ConsumerState<_BatchPanel> createState() => _State();
}

class _State extends ConsumerState<_BatchPanel> {
  late FigureDraft _draft = FigureDraft.forPublication(widget.publication);

  /// Ce qui a déjà été enregistré pendant CETTE séance. Voir sa liste grandir
  /// est la seule façon de savoir où l'on en est dans un document de quinze
  /// pages — sinon on relève deux fois la Bouenza et jamais la Likouala.
  final List<String> _saved = [];

  late final _filiere = TextEditingController(text: _draft.filiereLabel);

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _filiere.dispose();
    super.dispose();
  }

  Future<void> _saveAndNext() async {
    final problem = _draft.problem;
    if (problem != null) return setState(() => _error = problem);

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(archiveActionsProvider).recordFigure(
            sessionId: _draft.sessionId!,
            scope: _draft.scope,
            department: _draft.department,
            schoolId: _draft.schoolId,
            filiereLabel: _draft.filiereLabel,
            registered: _draft.registered,
            present: _draft.present,
            admitted: _draft.admitted,
            passRate: _draft.rate,
            publicationId: _draft.publicationId,
            sourceLabel: widget.publication.title,
            publishedAt: _draft.publishedAt,
          );
      if (!mounted) return;
      setState(() {
        _saved.add(_draft.chipLabel);
        _draft = resetForNext(_draft);
        _filiere.clear();
        _saving = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schools =
        ref.watch(adminSchoolsProvider).valueOrNull?.schools ?? const [];
    final departments = <String>{
      for (final s in schools)
        if ((s.department ?? '').trim().isNotEmpty) s.department!.trim(),
    }.toList()
      ..sort();

    return AdminSidePanel(
      icon: Icons.playlist_add_check_rounded,
      title: 'Relever les chiffres de cette pièce',
      subtitle: 'Le document reste épinglé — seuls le périmètre et les nombres '
          'repartent à zéro',
      footer: AdminModalActions(
        saving: _saving,
        submitLabel: 'Enregistrer et suivant',
        submitIcon: Icons.arrow_forward_rounded,
        cancelLabel: _saved.isEmpty ? 'Annuler' : 'Terminer',
        onSubmit: _saveAndNext,
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PinnedPiece(publication: widget.publication),
        const SizedBox(height: 18),
        const AdminFormSectionLabel('PÉRIMÈTRE DE CE CHIFFRE'),
        const SizedBox(height: 9),
        FigureScopeFields(
          draft: _draft,
          departments: departments,
          schools: [for (final s in schools) (s.id, s.name)],
          onChanged: (d) => setState(() => _draft = d),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _filiere,
          onChanged: (v) => _draft = _draft.copyWith(filiereLabel: v),
          style: TextStyle(fontSize: 13, color: kTextPrimary),
          decoration: InputDecoration(
            labelText: 'Filière ou série (facultatif)',
            hintText: 'ex. F5, Électrotechnique',
            isDense: true,
            labelStyle: TextStyle(fontSize: 12.5, color: kTextMuted),
            hintStyle: TextStyle(fontSize: 12, color: kTextMuted),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        const AdminFormSectionLabel('CHIFFRES PORTÉS PAR LA PUBLICATION'),
        const SizedBox(height: 9),
        FigureCountsFields(
          draft: _draft,
          onChanged: (d) => setState(() => _draft = d),
        ),
        if (_saved.isNotEmpty) ...[
          const SizedBox(height: 18),
          const AdminFormSectionLabel('DÉJÀ RELEVÉ SUR CETTE PIÈCE'),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in _saved)
                AdminBadge(label, color: kGreen),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          AdminErrorBanner(message: _error!),
        ],
      ]),
    );
  }
}

/// La pièce, immobile. Elle est la seule chose qui ne doit jamais se vider :
/// tout l'intérêt du panneau tient à ce qu'on la voie rester en place pendant
/// que le reste défile.
class _PinnedPiece extends StatelessWidget {
  const _PinnedPiece({required this.publication});
  final ExamPublication publication;

  @override
  Widget build(BuildContext context) {
    final p = publication;
    final parts = [
      if (p.examShortName != null) p.examShortName!,
      if (p.yearLabel != null) p.yearLabel!,
      p.scopeLabel,
    ];
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: kNavy.withValues(alpha: 0.18)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.push_pin_rounded, size: 18, color: kNavy),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(height: 3),
            Text(parts.join('  ·  '),
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ]),
        ),
      ]),
    );
  }
}
