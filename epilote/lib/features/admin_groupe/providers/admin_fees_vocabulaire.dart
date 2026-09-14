// ════════════════════════════════════════════════════════════════════════════
//  QUELS FRAIS CE GROUPE A LE DROIT DE PROPOSER
//
//  Ce n'est pas de la présentation, c'est du DROIT : la loi 25-95 (art. 1) pose
//  la gratuité de l'enseignement public. La mensualité disparaît donc du choix
//  quand le groupe est public — le serveur la refuse de toute façon (migration
//  0100), mais un choix qui n'existe pas vaut mieux qu'un refus après coup.
//
//  Extrait de `admin_fees_provider.dart` le 2026-09-06 : une règle lue par
//  l'écran, la ligne de liste et la boîte de saisie n'a rien à faire au milieu
//  des requêtes réseau.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_settings_provider.dart' show adminGroupProfileProvider;

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

/// Le groupe relève-t-il de l'enseignement PUBLIC ? Lu en base (`group_type`),
/// jamais déduit d'un nom. `null` tant que le secteur n'est pas connu.
final adminGroupePublicProvider = Provider.autoDispose<bool?>((ref) {
  final g = ref.watch(adminGroupProfileProvider).valueOrNull;
  return g == null ? null : g.groupType == 'public';
});

/// Les types de frais qu'on peut proposer à ce groupe.
///
/// ⚠️ **La mensualité disparaît du choix quand le groupe est PUBLIC** : la loi
/// 25-95 (art. 1) pose que l'enseignement public est gratuit. Le serveur la
/// refuse de toute façon (migration 0100) — mais un choix qui n'existe pas vaut
/// mieux qu'un refus après coup. C'est la même doctrine que le retrait des
/// mutations de barème côté école : « l'absence de bouton est la vraie
/// protection, la règle serveur n'est que le filet ».
///
/// Deux précautions :
///  • secteur INCONNU (chargement, erreur) → on ne présume rien, on laisse la
///    liste entière et c'est le serveur qui tranche, avec son message ;
///  • [typeActuel] est toujours réintroduit — on modifie un barème hérité sans
///    que la liste perde sa propre valeur (un `DropdownButtonFormField` dont la
///    `value` est absente des `items` lève une assertion), et le RETRAIT d'une
///    mensualité devenue illégale reste possible.
Map<String, String> typesDeFraisProposables({
  required bool? groupePublic,
  String? typeActuel,
}) {
  if (groupePublic != true) return kAdminFeeTypes;
  return {
    for (final e in kAdminFeeTypes.entries)
      if (e.key != 'mensualite' || e.key == typeActuel) e.key: e.value,
  };
}
