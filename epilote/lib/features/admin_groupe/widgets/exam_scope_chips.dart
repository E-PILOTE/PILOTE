import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/ministry_exam_rows.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE PÉRIMÈTRE DU COCKPIT — quel examen on regarde.
//
//  La DEC proclame examen par examen : BET, BEP, BTF, BAC technique, BAC
//  professionnel. Un cockpit qui les additionne produit un chiffre que
//  personne ne peut recouper avec une publication officielle.
//
//  Les puces portent leur effectif. Ce n'est pas décoratif : « BET » seul ne
//  dit pas si l'on s'apprête à lire huit cents candidats ou douze — et un taux
//  sur douze candidats ne se commente pas de la même façon.
// ════════════════════════════════════════════════════════════════════════════
class ExamScopeChips extends StatelessWidget {
  const ExamScopeChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// Toujours l'ensemble des examens du réseau, jamais les seuls filtrés :
  /// sélectionner le BET ne doit pas faire disparaître le BAC T de la barre.
  final List<ExamOption> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.length < 2) return const SizedBox.shrink();
    final total = options.fold<int>(0, (s, o) => s + o.candidates);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Chip(
          label: 'Tous les examens',
          count: total,
          active: selected == null,
          onTap: () => onChanged(null),
        ),
        for (final o in options)
          _Chip(
            label: o.shortName,
            count: o.candidates,
            active: selected == o.code,
            onTap: () => onChanged(o.code),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: active ? kNavy : kCardBg,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: active ? kNavy : kBorder, width: active ? 1.4 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? Colors.white : kTextPrimary,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.20)
                      : kTextMuted.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : kTextMuted,
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}
