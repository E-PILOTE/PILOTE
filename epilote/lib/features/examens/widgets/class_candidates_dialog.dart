import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../models/exam_fee.dart';
import '../providers/exam_fees_provider.dart';
import '../providers/exam_registration_provider.dart';
import 'candidate_file_dialog.dart';
import 'exam_dossier_dialog.dart';
import 'exam_payment_dialog.dart';
import 'exam_register_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES INSCRITS D'UNE CLASSE — consultation, pas sélection.
//
//  Auparavant « Voir » et « Inscrire » ouvraient LE MÊME écran : une liste de
//  cases à cocher. D'où deux défauts à l'usage : on ne consultait jamais
//  vraiment (tout invitait à cocher), et à 100 inscrits la liste — non
//  virtualisée, sans recherche — devenait illisible puis lente.
//
//  Deux intentions, deux écrans. Ici on RELIT : recherche, liste virtualisée
//  (seules les lignes visibles sont construites), état du dossier et des frais
//  d'un coup d'œil, accès direct à la fiche. « Inscrire » reste à un clic pour
//  ceux qui manquent — mais ce n'est plus le sujet par défaut.
// ════════════════════════════════════════════════════════════════════════════

Future<void> showClassCandidatesDialog(
  BuildContext context, {
  required String classId,
  required String className,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) =>
          _ClassCandidatesDialog(classId: classId, className: className),
    );

class _ClassCandidatesDialog extends ConsumerStatefulWidget {
  const _ClassCandidatesDialog({
    required this.classId,
    required this.className,
  });

  final String classId, className;

  @override
  ConsumerState<_ClassCandidatesDialog> createState() => _State();
}

class _State extends ConsumerState<_ClassCandidatesDialog> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(classRegistrationProvider(widget.classId));
    final canEdit = ref.watch(canProvider((slug: 'examens', action: 'update')));

    return Dialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur : $e', style: TextStyle(color: kRed)),
          ),
          data: (reg) => _content(reg, canEdit),
        ),
      ),
    );
  }

  Widget _content(ClassRegistration reg, bool canEdit) {
    final all = reg.registered;
    final q = _query.trim().toLowerCase();
    final rows = q.isEmpty
        ? all
        : all
            .where((s) =>
                s.fullName.toLowerCase().contains(q) ||
                (s.matricule ?? '').toLowerCase().contains(q))
            .toList();

    final fees = reg.sessionId == null
        ? null
        : ref.watch(examFeesProvider(reg.sessionId!)).valueOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _head(reg),
        Divider(height: 1, color: kBorder),
        if (all.isEmpty)
          _empty(reg, canEdit)
        else ...[
          _searchBar(all.length, rows.length),
          Divider(height: 1, color: kBorder),
          Flexible(
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('Aucun candidat ne correspond à « $_query ».',
                          style: TextStyle(fontSize: 12.5, color: kTextMuted)),
                    ),
                  )
                // Virtualisée : à 500 inscrits, seules les lignes visibles sont
                // construites. C'est ce qui manquait.
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => _CandidateLine(
                      row: rows[i],
                      sessionId: reg.sessionId,
                      canEdit: canEdit,
                      feeState: fees?.stateFor(rows[i].studentId),
                    ),
                  ),
          ),
          Divider(height: 1, color: kBorder),
          _footer(reg, canEdit),
        ],
      ],
    );
  }

  Widget _head(ClassRegistration reg) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
        child: Row(children: [
          Icon(Icons.groups_rounded, color: kNavy, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inscrits — ${widget.className}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                if (reg.hasSession)
                  Text('${reg.examShortName} · session ${reg.yearLabel}',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: kTextMuted),
            onPressed: () => Navigator.pop(context),
          ),
        ]),
      );

  Widget _searchBar(int total, int shown) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 13, color: kTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Rechercher un nom ou un matricule…',
                  hintStyle: TextStyle(fontSize: 12.5, color: kTextMuted),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: kTextMuted),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.clear_rounded, size: 16, color: kTextMuted),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: kBorder),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            shown == total ? '$total inscrit(s)' : '$shown / $total',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: kTextMuted),
          ),
        ]),
      );

  Widget _empty(ClassRegistration reg, bool canEdit) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.person_off_outlined, size: 36, color: kTextMuted),
          const SizedBox(height: 12),
          Text('Aucun élève inscrit',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 6),
          Text(
            'Cette classe n\'a encore aucun candidat inscrit à '
            '${reg.examShortName}.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.5),
          ),
          if (canEdit && reg.hasSession) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openRegister,
              icon: const Icon(Icons.how_to_reg_rounded, size: 17),
              label: const Text('Inscrire les élèves'),
              style: FilledButton.styleFrom(backgroundColor: kNavy),
            ),
          ],
        ]),
      );

  Widget _footer(ClassRegistration reg, bool canEdit) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(children: [
          if (reg.pending.isNotEmpty)
            Expanded(
              child: Text(
                '${reg.pending.length} élève(s) de la classe ne sont pas '
                'inscrits.',
                style: TextStyle(fontSize: 11.5, color: kAccent),
              ),
            )
          else
            const Spacer(),
          if (canEdit && reg.pending.isNotEmpty) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _openRegister,
              icon: const Icon(Icons.how_to_reg_rounded, size: 16),
              label: const Text('Inscrire'),
              style: OutlinedButton.styleFrom(foregroundColor: kNavy),
            ),
          ],
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: kTextMuted)),
          ),
        ]),
      );

  void _openRegister() {
    Navigator.pop(context);
    showExamRegisterDialog(context,
        classId: widget.classId, className: widget.className);
  }
}

/// Une ligne d'inscrit : l'essentiel lisible, les actions à portée.
class _CandidateLine extends StatelessWidget {
  const _CandidateLine({
    required this.row,
    required this.sessionId,
    required this.canEdit,
    required this.feeState,
  });

  final ExamStudentRow row;
  final String? sessionId;
  final bool canEdit;
  final FeePaymentState? feeState;

  @override
  Widget build(BuildContext context) {
    final (tone, label) = switch (row.dossierStatus) {
      'valide' => (kGreen, 'Validé'),
      'depose' => (kGreen, 'Déposé'),
      'complet' => (kNavy, 'Complet'),
      'rejete' => (kRed, 'Rejeté'),
      _ => (kRed, 'Incomplet'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
              const SizedBox(height: 2),
              Text(
                [
                  row.matricule ?? 'sans matricule',
                  if (row.candidateNumber != null) 'n° ${row.candidateNumber}',
                ].join(' · '),
                style: TextStyle(fontSize: 10.5, color: kTextMuted),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: tone)),
            ),
          ),
        ),
        SizedBox(
          width: 74,
          child: feeState == null
              ? const SizedBox.shrink()
              : Text(
                  feeStateLabel(feeState!),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: switch (feeState!) {
                      FeePaymentState.solde => kGreen,
                      FeePaymentState.partiel => kAccent,
                      FeePaymentState.impaye => kRed,
                    },
                  ),
                ),
        ),
        if (row.candidateId != null) ...[
          IconButton(
            onPressed: () => showCandidateFileDialog(context,
                candidateId: row.candidateId!),
            icon: const Icon(Icons.badge_outlined, size: 17),
            color: kNavy,
            tooltip: 'Fiche d\'inscription',
            visualDensity: VisualDensity.compact,
          ),
          if (canEdit)
            IconButton(
              onPressed: () => showExamDossierDialog(context,
                  candidateId: row.candidateId!),
              icon: const Icon(Icons.fact_check_outlined, size: 17),
              color: kTextMuted,
              tooltip: 'Dossier',
              visualDensity: VisualDensity.compact,
            ),
          if (canEdit && sessionId != null)
            IconButton(
              onPressed: () => showExamPaymentDialog(
                context,
                sessionId: sessionId!,
                studentId: row.studentId,
                studentName: row.fullName,
              ),
              icon: const Icon(Icons.payments_outlined, size: 17),
              color: kTextMuted,
              tooltip: 'Frais d\'examen',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ]),
    );
  }
}
