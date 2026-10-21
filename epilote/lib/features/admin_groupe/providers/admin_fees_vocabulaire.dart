// ════════════════════════════════════════════════════════════════════════════
//  LE VOCABULAIRE DES FRAIS
//
//  Extrait de `admin_fees_provider.dart` le 2026-09-06 : un catalogue lu par
//  l'écran, la ligne de liste et la boîte de saisie n'a rien à faire au milieu
//  des requêtes réseau.
//
//  ⚠️ La règle « pas de mensualité dans le public » (loi 25-95) a été retirée
//  le 2026-10-21 : la plateforme ne sert plus que des groupes privés, pour qui
//  la mensualité est le premier revenu. Tous les types sont proposables.
// ════════════════════════════════════════════════════════════════════════════

/// Le catalogue des types de frais, aligné sur l'enum `fee_type` en base
/// (`inscription, mensualite, frais_examens, autre, cotisation_ape`).
///
/// Il vit ici, avec la donnée, et non dans le formulaire : l'écran, la ligne de
/// liste et la boîte de saisie le lisent tous les trois. Deux libellés qui
/// dérivent l'un de l'autre sur une page d'argent, c'est un ticket de support.
const kAdminFeeTypes = <String, String>{
  'inscription': 'Inscription',
  'mensualite': 'Mensualité',
  'frais_examens': 'Frais d\'examens',
  'cotisation_ape': 'Cotisation APE',
  'autre': 'Autre',
};

String adminFeeTypeLabel(String? t) => kAdminFeeTypes[t] ?? 'Autre';
