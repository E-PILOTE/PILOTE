import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/active_agent_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../finance/providers/paiements_provider.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../providers/exam_fees_provider.dart';
import 'exam_fees_panel.dart' show formatXaf;

// ════════════════════════════════════════════════════════════════════════════
//  ENCAISSER LES FRAIS D'UN CANDIDAT.
//
//  L'écriture passe par `savePayment` du module Paiements — pas par une requête
//  maison. C'est ce qui garantit que ce revenu se comporte EXACTEMENT comme les
//  autres : même reçu, même statut, même remontée vers le revenu de l'école
//  puis du groupe. Un chemin parallèle aurait fini par diverger.
//
//  Les paiements PARTIELS sont acceptés : un parent paie en deux fois, et
//  refuser le premier versement reviendrait à ne rien encaisser du tout.
// ════════════════════════════════════════════════════════════════════════════

Future<bool> showExamPaymentDialog(
  BuildContext context, {
  required String sessionId,
  required String studentId,
  required String studentName,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _ExamPaymentDialog(
        sessionId: sessionId,
        studentId: studentId,
        studentName: studentName,
      ),
    ) ??
    false;

class _ExamPaymentDialog extends ConsumerStatefulWidget {
  const _ExamPaymentDialog({
    required this.sessionId,
    required this.studentId,
    required this.studentName,
  });

  final String sessionId, studentId, studentName;

  @override
  ConsumerState<_ExamPaymentDialog> createState() => _State();
}

class _State extends ConsumerState<_ExamPaymentDialog> {
  final _amount = TextEditingController();
  String _method = 'especes';
  bool _saving = false;
  bool _prefilled = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(examFeesProvider(widget.sessionId));

    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.studentName,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const SizedBox(height: 2),
          Text('Encaisser les frais d\'examen',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e', style: TextStyle(color: kRed)),
          data: (d) => _form(d),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text('Annuler', style: TextStyle(color: kTextMuted)),
        ),
        FilledButton(
          onPressed: _saving || async.valueOrNull == null
              ? null
              : () => _save(async.value!),
          style: FilledButton.styleFrom(backgroundColor: kGreen),
          child: Text(_saving ? 'Enregistrement…' : 'Encaisser'),
        ),
      ],
    );
  }

  Widget _form(ExamFeeData d) {
    final paid = d.paidFor(widget.studentId);
    final due = d.amountPerCandidate;
    final rest = (due - paid) < 0 ? 0 : due - paid;

    // Pré-remplir le RESTE, pas le montant total : c'est ce qu'on encaisse
    // neuf fois sur dix, et un montant déjà juste évite une faute de frappe.
    if (!_prefilled) {
      _prefilled = true;
      _amount.text = rest.toString();
    }

    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(child: _kv('Dû', formatXaf(due))),
            Expanded(child: _kv('Déjà versé', formatXaf(paid))),
            Expanded(
                child: _kv('Reste', formatXaf(rest),
                    tone: rest > 0 ? kRed : kGreen)),
          ]),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(fontSize: 14, color: kTextPrimary),
          decoration: InputDecoration(
            labelText: 'Montant encaissé (FCFA)',
            helperText: 'Un versement partiel est accepté.',
            helperStyle: TextStyle(fontSize: 11, color: kTextMuted),
            border: const OutlineInputBorder(),
            isDense: true,
            labelStyle: TextStyle(color: kTextMuted),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: InputDecoration(
            labelText: 'Moyen de paiement',
            border: const OutlineInputBorder(),
            isDense: true,
            labelStyle: TextStyle(color: kTextMuted),
          ),
          items: const [
            DropdownMenuItem(value: 'especes', child: Text('Espèces')),
            DropdownMenuItem(value: 'mtn_money', child: Text('MTN Money')),
            DropdownMenuItem(value: 'airtel_money', child: Text('Airtel Money')),
            DropdownMenuItem(value: 'visa', child: Text('Carte bancaire')),
          ],
          onChanged: (v) => setState(() => _method = v ?? 'especes'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(
                  fontSize: 12, color: kRed, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }

  Widget _kv(String k, String v, {Color? tone}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k.toUpperCase(),
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: kTextMuted)),
          const SizedBox(height: 2),
          Text(v,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: tone ?? kTextPrimary)),
        ],
      );

  Future<void> _save(ExamFeeData d) async {
    final amount = int.tryParse(_amount.text.trim().replaceAll(' ', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Montant invalide.');
      return;
    }
    if (d.feeStructureId == null) {
      setState(() => _error =
          'Aucun barème de frais pour cette session : définissez d\'abord le '
          'montant dû par candidat.');
      return;
    }

    final profile = ref.read(authNotifierProvider).valueOrNull;
    final year = ref.read(currentAcademicYearProvider).valueOrNull;
    final agentId = ref.read(activeAgentIdProvider) ?? profile?.id;
    final groupId = profile?.groupId ?? '';
    final schoolId = profile?.schoolId ?? '';

    if (year == null || agentId == null || groupId.isEmpty || schoolId.isEmpty) {
      setState(() => _error =
          'Contexte incomplet (année scolaire ou agent) : encaissement '
          'impossible.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // `student_payments.enrollment_id` est NOT NULL. L'écrire vide ferait
      // rejeter la ligne par le serveur, ce qui abandonne le lot PowerSync
      // ENTIER — et l'encaissement disparaîtrait sans bruit. On refuse net.
      final enrollmentId = await resolveEnrollmentId(
        studentId: widget.studentId,
        academicYearId: year.id,
      );
      if (enrollmentId == null) {
        throw MissingEnrollmentException(widget.studentName);
      }

      await savePayment(
        groupId: groupId,
        schoolId: schoolId,
        studentId: widget.studentId,
        enrollmentId: enrollmentId,
        feeStructureId: d.feeStructureId,
        amount: amount,
        date: DateTime.now().toIso8601String().substring(0, 10),
        method: _method,
        status: 'confirmed',
        notes: 'Frais d\'examen',
        recordedBy: agentId,
      );

      ref.invalidate(examFeesProvider(widget.sessionId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
