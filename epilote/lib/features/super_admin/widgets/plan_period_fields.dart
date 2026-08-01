import 'package:flutter/material.dart';

import '../../../core/utils/billing_period.dart';
import '../providers/plans_provider.dart' show moneyXaf;

// ════════════════════════════════════════════════════════════════════════════
//  LA PÉRIODICITÉ DANS LE FORMULAIRE DE PLAN
//
//  Deux champs qui ne se quittent pas : le montant, et la durée qu'il couvre.
//  Les séparer est ce qui a produit le bug d'origine — l'écran affichait
//  « Prix mensuel » pendant que la base facturait douze mois.
//
//  `_PriceEquivalence` existe pour une raison précise : quand on saisit
//  2 500 000 FCFA par an, personne ne calcule de tête ce que ça pèse par mois.
//  L'équivalence est affichée sous le champ, à la frappe, parce que c'est ce
//  nombre-là qui alimentera le revenu récurrent de la plateforme.
// ════════════════════════════════════════════════════════════════════════════

const _kBorder = Color(0xFFE2E8F0);
const _kSurface = Color(0xFFF8FAFC);
const _kText = Color(0xFF0F172A);
const _kMuted = Color(0xFF64748B);

/// Sélecteur de périodicité — mensuel, trimestriel, semestriel, annuel.
class PlanPeriodPicker extends StatelessWidget {
  const PlanPeriodPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Périodicité *',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _kMuted),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _kSurface,
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: kBillingPeriods.containsKey(value)
                  ? value
                  : kDefaultBillingPeriod,
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded,
                  size: 18, color: _kMuted),
              style: const TextStyle(color: _kText, fontSize: 13),
              items: [
                for (final e in kBillingPeriods.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Row(children: [
                      const Icon(Icons.event_repeat_rounded,
                          size: 14, color: _kMuted),
                      const SizedBox(width: 8),
                      Text(e.value),
                    ]),
                  ),
              ],
              onChanged: (v) => onChanged(v ?? kDefaultBillingPeriod),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rappelle, sous le champ de tarif, ce que la saisie représente par mois et
/// par an. Reste muet pour un plan gratuit ou une périodicité mensuelle, où
/// l'équivalence n'apprend rien.
class PlanPriceEquivalence extends StatelessWidget {
  const PlanPriceEquivalence({
    super.key,
    required this.priceXaf,
    required this.period,
  });

  final int priceXaf;
  final String period;

  @override
  Widget build(BuildContext context) {
    if (priceXaf <= 0) return const SizedBox.shrink();
    final months = billingPeriodMonths(period);
    if (months <= 1) return const SizedBox.shrink();

    final parMois = monthlyEquivalent(priceXaf, period);
    final parAn = parMois * 12;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        'soit ${moneyXaf(parMois)} FCFA / mois · ${moneyXaf(parAn)} FCFA / an',
        style: const TextStyle(fontSize: 11.5, color: _kMuted),
      ),
    );
  }
}
