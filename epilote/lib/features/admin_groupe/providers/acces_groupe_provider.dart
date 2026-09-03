import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ACCÈS D'UN GROUPE, COUPÉ POUR IMPAYÉ
//
//  ── LA DÉCISION DU FONDATEUR ──────────────────────────────────────────────
//  J'avais objecté qu'une licence suspendue ne devait couper personne (C4 du
//  0160). Il a maintenu : sans aucun levier, un marché de quarante millions ne
//  se recouvre qu'au tribunal. Le levier existe donc — mais SÉPARÉ du statut
//  de la licence, et c'est la seule chose que je n'ai pas cédée :
//
//    • suspendre une LICENCE  → état contractuel, ne coupe rien ;
//    • couper un ACCÈS        → second geste, explicite, motivé, tracé.
//
//  Les lier ferait de chaque suspension comptable une coupure d'État, et plus
//  personne n'oserait suspendre. Deux gestes, deux décisions.
//
//  ── ⚠️ FAIL-SOFT, DANS CE SENS-LÀ ET PAS L'AUTRE ──────────────────────────
//  Requête en erreur, réseau coupé, réponse illisible ⇒ **accès OUVERT**.
//  Se tromper dans ce sens laisse travailler un groupe qui aurait dû être
//  bloqué le temps d'un incident réseau. Se tromper dans l'autre ferme le
//  ministère de l'Éducation nationale parce qu'une requête a expiré — et
//  personne, ce jour-là, ne saura pourquoi.
//
//  La coupure qui COMPTE est de toute façon côté serveur : depuis 0187,
//  `auth_peut_superviser()` rend faux, et les quatre RPC de tutelle refusent
//  en 42501. Cet écran-ci ne fait qu'expliquer ; il n'est pas la serrure.
// ════════════════════════════════════════════════════════════════════════════

class AccesGroupe {
  const AccesGroupe({required this.suspendu, this.motif, this.depuis});

  /// L'état par défaut, et celui de tous les cas douteux : ouvert.
  static const ouvert = AccesGroupe(suspendu: false);

  final bool suspendu;

  /// Le texte écrit par E-PILOTE Congo au moment de couper. C'est la SEULE
  /// chose que le groupe lira en ouvrant l'application.
  final String? motif;

  final DateTime? depuis;
}

final accesGroupeProvider =
    FutureProvider.autoDispose<AccesGroupe>((ref) async {
  final profil = ref.watch(authNotifierProvider).valueOrNull;
  final groupId = profil?.groupId;
  if (groupId == null || groupId.isEmpty) return AccesGroupe.ouvert;
  try {
    final g = await ref
        .watch(supabaseClientProvider)
        .from('school_groups')
        .select('acces_suspendu, acces_suspendu_motif, acces_suspendu_le')
        .eq('id', groupId)
        .maybeSingle();
    if (g == null) return AccesGroupe.ouvert;
    return AccesGroupe(
      suspendu: g['acces_suspendu'] as bool? ?? false,
      motif: g['acces_suspendu_motif'] as String?,
      depuis: DateTime.tryParse(g['acces_suspendu_le'] as String? ?? ''),
    );
  } catch (_) {
    return AccesGroupe.ouvert;
  }
});
