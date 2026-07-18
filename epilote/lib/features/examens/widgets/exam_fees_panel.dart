import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../providers/exam_fees_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RECOUVREMENT DES FRAIS D'EXAMEN — le revenu que l'école doit lever.
//
//  Les frais d'examen sont un revenu de l'école, donc du groupe scolaire. Ils
//  ne vivent pas dans un coin du module Examens : chaque encaissement est une
//  ligne `student_payments` ordinaire, donc il apparaît dans le module
//  Paiements et remonte au revenu SANS aucun recâblage. La relation avec
//  Finance n'est pas un pont ajouté après coup — c'est la même chaîne.
// ════════════════════════════════════════════════════════════════════════════

final _fmt = NumberFormat.decimalPattern('fr');
String formatXaf(int v) => '${_fmt.format(v)} FCFA';

class ExamFeesPanel extends ConsumerWidget {
  const ExamFeesPanel({
    super.key,
    required this.sessionId,
    required this.examShortName,
    required this.yearLabel,
  });

  final String sessionId;
  final String examShortName;
  final String? yearLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(examFeesProvider(sessionId));
    final canManage =
        ref.watch(canProvider((slug: 'examens', action: 'update')));

    return async.when(
      loading: () => const SizedBox(height: 96),
      error: (e, _) => const SizedBox.shrink(),
      data: (d) => _card(context, ref, d, canManage),
    );
  }

  Widget _card(
      BuildContext context, WidgetRef ref, ExamFeeData d, bool canManage) {
    final s = d.summary;
    final tone = s.expected == 0
        ? kTextMuted
        : (s.remaining == 0 ? kGreen : (s.rate >= 0.5 ? kNavy : kRed));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.payments_rounded, size: 18, color: kNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Frais d\'examen — recouvrement',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            if (canManage)
              TextButton.icon(
                onPressed: () => _defineAmount(context, ref, d),
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: Text(
                    d.amountPerCandidate == 0
                        ? 'Définir le montant'
                        : '${formatXaf(d.amountPerCandidate)} / candidat',
                    style: const TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(foregroundColor: kNavy),
              ),
          ]),
          if (d.amountPerCandidate == 0) ...[
            const SizedBox(height: 8),
            _hint(
              'Aucun montant fixé pour cette session. Tant qu\'il vaut zéro, '
              'aucun recouvrement n\'est attendu et aucun encaissement n\'est '
              'possible.',
              kTextMuted,
            ),
          ] else if (!d.isSchoolScale) ...[
            const SizedBox(height: 8),
            // Le montant national est une valeur par défaut visible, pas un
            // barème : tant que l'école ne l'a pas repris à son compte, aucun
            // encaissement ne peut être rattaché.
            _hint(
              'Montant repris du barème national de la session. Confirmez-le '
              'pour ouvrir les encaissements de votre établissement.',
              kAccent,
            ),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 22, runSpacing: 12, children: [
            _Stat(label: 'Attendu', value: formatXaf(s.expected), tone: kNavy),
            _Stat(
                label: 'Encaissé', value: formatXaf(s.collected), tone: kGreen),
            _Stat(
                label: 'Reste à recouvrer',
                value: formatXaf(s.remaining),
                tone: s.remaining > 0 ? kRed : kGreen),
            _Stat(
                label: 'Taux',
                value: '${(s.rate * 100).round()} %',
                tone: tone),
          ]),
          if (s.expected > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: s.rate,
                minHeight: 7,
                backgroundColor: kBorder,
                valueColor: AlwaysStoppedAnimation(tone),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${s.candidates} candidat(s) inscrit(s) · les encaissements '
              'apparaissent dans le module Paiements et dans le revenu de '
              'l\'école.',
              style: TextStyle(fontSize: 10.5, color: kTextMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hint(String text, Color tone) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: tone),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 11, color: tone, height: 1.35)),
          ),
        ],
      );

  Future<void> _defineAmount(
      BuildContext context, WidgetRef ref, ExamFeeData d) async {
    final controller =
        TextEditingController(text: d.amountPerCandidate.toString());

    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Frais de $examShortName',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kTextPrimary)),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Montant dû par candidat pour la session '
              '${yearLabel ?? ''}. Il sert de base au recouvrement et alimente '
              'le revenu de l\'établissement.',
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: kTextPrimary),
              decoration: InputDecoration(
                labelText: 'Montant en FCFA',
                border: const OutlineInputBorder(),
                isDense: true,
                labelStyle: TextStyle(color: kTextMuted),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim().replaceAll(' ', ''));
              if (v != null && v >= 0) Navigator.of(ctx).pop(v);
            },
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (value == null) return;

    final profile = ref.read(authNotifierProvider).valueOrNull;
    final year = ref.read(currentAcademicYearProvider).valueOrNull;
    final groupId = profile?.groupId ?? '';
    final schoolId = profile?.schoolId ?? '';

    // Sans année courante, `fee_structures.academic_year_id` (NOT NULL) serait
    // vide : le serveur rejetterait la ligne et le lot PowerSync entier serait
    // abandonné. On refuse franchement plutôt que de perdre du travail.
    if (year == null || groupId.isEmpty || schoolId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Aucune année scolaire courante : impossible de créer le barème.'),
          backgroundColor: kRed,
        ));
      }
      return;
    }

    final id = d.feeStructureId ??
        await ensureExamFeeStructure(
          sessionId: sessionId,
          groupId: groupId,
          schoolId: schoolId,
          academicYearId: year.id,
          amountXaf: value,
          label: 'Frais $examShortName ${yearLabel ?? ''}'.trim(),
        );
    if (d.feeStructureId != null) await setExamFeeAmount(id, value);

    ref.invalidate(examFeesProvider(sessionId));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.tone});
  final String label, value;
  final Color tone;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: kTextMuted)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: tone)),
        ],
      );
}
