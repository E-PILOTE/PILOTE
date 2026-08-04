import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉTIQUETTE DU POSTE
//
//  Six caractères hexadécimaux, tirés une fois et conservés. C'est ce qui rend
//  deux reçus de deux postes distincts d'une même école impossibles à
//  confondre, SANS aucune coordination réseau — la seule propriété qui tienne
//  dans une école congolaise sans connexion.
//
//  Elle vit à côté de `epilote.identite_poste` (SessionKeeper), pas dedans :
//  l'identité du poste peut être oubliée par une déconnexion volontaire, alors
//  que la numérotation comptable, elle, ne doit jamais repartir de zéro.
//
//  16⁶ ≈ 16,7 millions de valeurs : sur un parc de 1 000 écoles de 5 postes, la
//  probabilité qu'UNE école ait deux postes de même étiquette est de l'ordre de
//  6 pour 10 000 — et il faudrait encore que les deux soient hors ligne au même
//  instant sur la même séquence pour que cela coûte quelque chose.
// ════════════════════════════════════════════════════════════════════════════

const String _kCle = 'epilote.poste_tag';

String? _cache;

/// Étiquette de CE poste, stable pour la durée de vie de l'installation.
Future<String> posteTag() async {
  final hit = _cache;
  if (hit != null) return hit;

  final prefs = await SharedPreferences.getInstance();
  final existant = prefs.getString(_kCle);
  if (existant != null && existant.length == 6) return _cache = existant;

  final neuf =
      const Uuid().v4().replaceAll('-', '').substring(0, 6).toLowerCase();
  await prefs.setString(_kCle, neuf);
  return _cache = neuf;
}

/// Vide le cache mémoire — utilisé par les tests pour simuler un redémarrage.
void resetPosteTagCache() => _cache = null;
