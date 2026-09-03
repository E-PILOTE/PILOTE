import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE REPLI SUIT L'AGENT AU CLAVIER, PAS L'APPAREIL.
//
//  Même raisonnement que le thème (`theme_prefs.dart`) : sur un poste partagé
//  d'établissement, plusieurs agents se succèdent derrière le même écran et la
//  même session Supabase. Celui qui replie FINANCE parce qu'il ne l'ouvre
//  jamais ne doit pas la replier pour le comptable qui prend sa place — et
//  inversement, il doit la retrouver repliée le lendemain.
//
//  Local, hors-ligne, jamais synchronisé : quelles sections un agent garde
//  ouvertes n'est pas une donnée d'établissement.
// ════════════════════════════════════════════════════════════════════════════

String _key(String agentId) => 'epilote_nav_replie_$agentId';

/// Titres des sections repliées par [agentId].
///
/// Fail-soft : agent inconnu, préférence absente ou illisible → ensemble vide,
/// c'est-à-dire tout déplié — le comportement d'avant la persistance. Une
/// barre qui s'ouvre trop est un désagrément ; une barre qui masque une
/// section sans qu'on sache pourquoi est un défaut.
Future<Set<String>> loadSectionsRepliees(String? agentId) async {
  if (agentId == null || agentId.isEmpty) return const <String>{};
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(_key(agentId)) ?? const <String>[]).toSet();
}

/// Enregistre les sections repliées de [agentId].
///
/// Sans agent, on n'écrit rien : mieux vaut perdre la préférence que la coller
/// au mauvais agent sur un poste partagé.
Future<void> saveSectionsRepliees(String? agentId, Set<String> titres) async {
  if (agentId == null || agentId.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_key(agentId), titres.toList());
}
