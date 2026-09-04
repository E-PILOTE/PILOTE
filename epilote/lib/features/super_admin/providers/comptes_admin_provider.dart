import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE COMPTE QUI SE CONNECTE — et pourquoi ce n'est PAS `admin_email`
//
//  ── CE QUI S'EST PASSÉ (2026-09-04) ───────────────────────────────────────
//  Le fondateur a voulu ouvrir l'espace d'un client. Il a lu l'adresse
//  affichée sous le nom du groupe, sur sa propre page Abonnements —
//  `admin@edec.cg` — et la connexion a échoué. Il a conclu à un mot de passe
//  perdu et a demandé une réinitialisation. Le mot de passe était bon : le
//  compte s'appelle `admin.edec@epilote.cg`.
//
//  `school_groups.admin_email` est une colonne de CONTACT, saisie dans le
//  formulaire du groupe. Elle n'a jamais été un identifiant. Vérifié sur les
//  huit comptes d'administrateur de la base : **huit adresses affichées, zéro
//  correspondance** avec le compte réel.
//
//  Ce n'est pas un détail cosmétique. Cet écran est celui qu'on ouvre quand un
//  client appelle parce qu'il n'arrive pas à se connecter — et il donnait
//  l'adresse qui ne marche pas.
//
//  ── POURQUOI UNE RPC ──────────────────────────────────────────────────────
//  L'adresse de connexion vit dans `auth.users`, que PostgREST n'expose pas.
//  `get_platform_admins()` (SECURITY DEFINER, réservée au super_admin) la
//  rend, avec le `group_id`. UN appel pour tout le parc : pas de requête par
//  ligne, la page reste tenable à mille groupes.
// ════════════════════════════════════════════════════════════════════════════

/// Un compte d'administration réel, celui qui ouvre une session.
class CompteAdmin {
  const CompteAdmin({
    required this.id,
    required this.email,
    required this.nom,
    required this.actif,
  });

  final String id;

  /// L'adresse de CONNEXION, lue dans `auth.users`.
  final String email;
  final String nom;
  final bool actif;
}

/// Les comptes d'administration par groupe : `group_id` → comptes.
///
/// Un groupe peut en avoir plusieurs (le MEPSA en a deux). L'ordre place les
/// comptes ACTIFS d'abord : quand on lit une adresse à quelqu'un au téléphone,
/// c'est celle qui fonctionne qu'il faut lire.
///
/// ⚠️ Repli silencieux : en cas d'échec, la carte est VIDE — les écrans
/// retombent alors sur l'e-mail de contact, mais étiqueté comme tel. Un
/// contact présenté comme un identifiant est exactement ce qu'on corrige ici.
final comptesAdminParGroupeProvider =
    FutureProvider.autoDispose<Map<String, List<CompteAdmin>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final parGroupe = <String, List<CompteAdmin>>{};
  try {
    final rows = await client.rpc('get_platform_admins') as List;
    for (final r in rows) {
      final m = Map<String, dynamic>.from(r as Map);
      if (m['role'] != 'admin_groupe') continue;
      final gid = m['group_id'] as String?;
      final mail = (m['email'] as String?)?.trim();
      if (gid == null || gid.isEmpty || mail == null || mail.isEmpty) continue;
      (parGroupe[gid] ??= []).add(CompteAdmin(
        id: m['id'] as String,
        email: mail,
        nom: '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim(),
        actif: m['is_active'] as bool? ?? true,
      ));
    }
    for (final l in parGroupe.values) {
      l.sort((a, b) {
        if (a.actif != b.actif) return a.actif ? -1 : 1;
        return a.email.compareTo(b.email);
      });
    }
  } catch (_) {
    return const {};
  }
  return parGroupe;
});

/// L'adresse à afficher sous le nom d'un groupe.
///
/// Le compte réel s'il est connu ; sinon l'e-mail de contact — jamais une
/// invention, et jamais un contact présenté comme un identifiant (les écrans
/// qui retombent dessus doivent l'étiqueter « contact »).
String? compteDeConnexion(
  Map<String, List<CompteAdmin>> parGroupe,
  String groupId,
) {
  final l = parGroupe[groupId];
  if (l == null || l.isEmpty) return null;
  return l.first.email;
}
