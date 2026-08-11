import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../models/exam_dossier_piece.dart';
import '../providers/exam_registration_provider.dart';
import '../providers/examens_provider.dart';
import 'examens_widgets.dart' show formatDate;
import '../../../core/utils/message_erreur.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Inscrire une classe à une session d'examen.
//  Convention projet : modal-form -> shrinkWrap, jamais pleine hauteur.
// ════════════════════════════════════════════════════════════════════════════

Future<void> showExamRegisterDialog(
  BuildContext context, {
  required String classId,
  required String className,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ExamRegisterDialog(classId: classId, className: className),
    );

class _ExamRegisterDialog extends ConsumerStatefulWidget {
  const _ExamRegisterDialog({required this.classId, required this.className});
  final String classId;
  final String className;

  @override
  ConsumerState<_ExamRegisterDialog> createState() => _State();
}

class _State extends ConsumerState<_ExamRegisterDialog> {
  final _selected = <String>{};
  bool _saving = false;
  bool _init = false;

  Future<void> _submit(ClassRegistration reg) async {
    if (_selected.isEmpty || reg.sessionId == null) return;
    setState(() => _saving = true);
    final n = await registerCandidates(
      ref,
      sessionId: reg.sessionId!,
      classId: widget.classId,
      studentIds: _selected.toList(),
    );
    ref.invalidate(classRegistrationProvider(widget.classId));
    ref.invalidate(examOverviewProvider);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$n élève(s) inscrit(s) à ${reg.examShortName}'),
      backgroundColor: kGreen,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(classRegistrationProvider(widget.classId));

    return Dialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(messageErreur(e), style: TextStyle(color: kRed)),
          ),
          data: (reg) {
            // Pré-cocher les non-inscrits une seule fois (sinon on écraserait
            // les décocher de l'utilisateur à chaque rebuild).
            if (!_init) {
              _init = true;
              _selected.addAll(reg.pending.map((s) => s.studentId));
            }
            return _content(reg);
          },
        ),
      ),
    );
  }

  Widget _content(ClassRegistration reg) {
    final overAgeIds = {for (final s in reg.overAge) s.studentId};

    return Column(
      mainAxisSize: MainAxisSize.min, // shrinkWrap : le modal suit son contenu
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
          child: Row(children: [
            Icon(Icons.how_to_reg_rounded, color: kNavy, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inscrire ${widget.className}',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  if (reg.hasSession)
                    Text(
                      '${reg.examShortName} · session ${reg.yearLabel}'
                      '${reg.registrationClosesAt != null ? ' · clôture le ${formatDate(reg.registrationClosesAt)}' : ''}',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: kTextMuted),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        Divider(height: 1, color: kBorder),

        if (!reg.hasSession)
          _noSession()
        else ...[
          if (reg.overAge.isNotEmpty) _ageWarning(reg),
          if (reg.requiredDocuments.isNotEmpty) _piecesPreview(reg),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  for (final s in reg.students)
                    _studentTile(s, reg, overAgeIds.contains(s.studentId)),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: kBorder),
          _footer(reg),
        ],
      ],
    );
  }

  Widget _noSession() => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          Icon(Icons.event_busy_rounded, size: 36, color: kTextMuted),
          const SizedBox(height: 12),
          Text('Aucune session ouverte',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 6),
          Text(
            'Aucune session d\'examen n\'est encore configurée pour cette classe. '
            'Le ministère doit ouvrir la session avant toute inscription.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.5),
          ),
        ]),
      );

  /// Avertissement d'âge : consultatif. On n'empêche PAS l'inscription —
  /// des dérogations existent et la date d'appréciation n'est pas établie.
  Widget _ageWarning(ClassRegistration reg) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kAccent.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.cake_rounded, size: 17, color: kAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${reg.overAge.length} élève(s) dépassent l\'âge de ${reg.maxAge} ans '
              'exigé pour ${reg.examShortName}. Vous pouvez tout de même les '
              'inscrire (dérogation) — le ministère tranchera.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
            ),
          ),
        ]),
      );

  /// Les pièces que l'école devra réunir, annoncées AVANT d'inscrire.
  ///
  /// Inscrire prend dix secondes ; réunir les pièces prend des semaines. Les
  /// découvrir seulement en ouvrant le dossier, c'est les découvrir trop tard.
  /// On les annonce ici — le téléversement, lui, se fait dans le dossier.
  Widget _piecesPreview(ClassRegistration reg) {
    final pieces = ExamDossierPiece.parseList(reg.requiredDocuments);
    final due = pieces.where((p) => !p.isConditional).toList();
    if (due.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNavy.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.fact_check_outlined, size: 16, color: kNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${due.length} pièce(s) à réunir par candidat pour '
                '${reg.examShortName}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            due.map((p) => p.label).join(' · '),
            style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            'Les scans se déposent ensuite dans le dossier de chaque candidat.',
            style: TextStyle(
                fontSize: 10.5,
                color: kTextMuted,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _studentTile(ExamStudentRow s, ClassRegistration reg, bool overAge) {
    final age = s.ageAt(reg.ageReference);

    if (s.isRegistered) {
      return ListTile(
        dense: true,
        leading: Icon(Icons.check_circle_rounded, color: kGreen, size: 20),
        title: Text(s.fullName,
            style: TextStyle(fontSize: 13, color: kTextPrimary)),
        subtitle: Text(
          s.candidateNumber != null
              ? 'N° ${s.candidateNumber} · dossier ${s.dossierStatus}'
              : 'Déjà inscrit · dossier ${s.dossierStatus}',
          style: TextStyle(fontSize: 11, color: kTextMuted),
        ),
      );
    }

    return CheckboxListTile(
      dense: true,
      value: _selected.contains(s.studentId),
      onChanged: _saving
          ? null
          : (v) => setState(() {
                v == true
                    ? _selected.add(s.studentId)
                    : _selected.remove(s.studentId);
              }),
      title: Text(s.fullName,
          style: TextStyle(fontSize: 13, color: kTextPrimary)),
      subtitle: Row(children: [
        Text(
          s.matricule ?? 'sans matricule',
          style: TextStyle(fontSize: 11, color: kTextMuted),
        ),
        if (age != null) ...[
          const SizedBox(width: 8),
          Text(
            '$age ans',
            style: TextStyle(
              fontSize: 11,
              fontWeight: overAge ? FontWeight.w700 : FontWeight.w400,
              color: overAge ? kAccent : kTextMuted,
            ),
          ),
        ],
        if (s.dateOfBirth == null) ...[
          const SizedBox(width: 8),
          Text('date de naissance manquante',
              style: TextStyle(fontSize: 10.5, color: kRed)),
        ],
      ]),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _footer(ClassRegistration reg) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Row(children: [
          Text(
            '${reg.registered.length} inscrit(s) · ${reg.pending.length} à inscrire',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          ),
          const Spacer(),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            onPressed: _saving || _selected.isEmpty ? null : () => _submit(reg),
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.how_to_reg_rounded, size: 17),
            label: Text('Inscrire ${_selected.length} élève(s)'),
          ),
        ]),
      );
}
