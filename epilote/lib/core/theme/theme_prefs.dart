import 'package:shared_preferences/shared_preferences.dart';

import 'palette.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Le thème suit l'AGENT ACTIF, pas l'appareil.
//
//  Sur un poste partagé, plusieurs agents se succèdent derrière le même écran
//  et la même session Supabase : c'est l'agent au clavier qui regarde l'écran,
//  donc c'est lui qui choisit. Même chemin que le PIN et le mode d'appareil —
//  local, hors-ligne, jamais synchronisé (rien à faire remonter au serveur : un
//  goût de couleur n'est pas une donnée d'établissement).
// ════════════════════════════════════════════════════════════════════════════

String _key(String agentId) => 'epilote_theme_$agentId';

/// Thème de [agentId]. Fail-soft : agent inconnu, préférence absente ou
/// corrompue → Clair (le comportement d'avant les thèmes).
Future<EpiloteThemeId> loadThemeFor(String? agentId) async {
  if (agentId == null || agentId.isEmpty) return EpiloteThemeId.clair;
  final prefs = await SharedPreferences.getInstance();
  return EpiloteThemeId.parse(prefs.getString(_key(agentId)));
}

/// Enregistre le thème de [agentId]. Sans agent, on n'écrit rien : mieux vaut
/// perdre la préférence que la coller au mauvais agent sur un poste partagé.
Future<void> saveThemeFor(String? agentId, EpiloteThemeId id) async {
  if (agentId == null || agentId.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key(agentId), id.name);
}
