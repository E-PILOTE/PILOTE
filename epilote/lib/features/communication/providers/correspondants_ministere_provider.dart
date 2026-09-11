import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RECONNAÎTRE UN MINISTÈRE DANS LA MESSAGERIE
//
//  ── LE DÉFAUT ─────────────────────────────────────────────────────────────
//  Un ministère de tutelle se distingue partout — pastille pleine, icône
//  d'institution, nom d'usage — SAUF dans la messagerie, c'est-à-dire là où
//  ça compte le plus. Un message du MEPSA arrivait dans la même tuile, avec
//  la même typographie, qu'un message d'un confrère de l'école d'à côté. Une
//  instruction de la tutelle se lisait et se rangeait comme une conversation
//  ordinaire.
//
//  ── ⚠️ POURQUOI ÇA NE SE FAIT PAS PAR UNE JOINTURE ────────────────────────
//  L'écran connaît l'identifiant de l'interlocuteur, jamais son GROUPE, et
//  `profiles → school_groups` ne rend RIEN : la RLS de `school_groups` borne
//  chaque groupe au sien. Pire, ça échoue en SILENCE — un refus de RLS en
//  SELECT écarte la ligne sans lever d'erreur. On aurait donc affiché « — »
//  en croyant afficher un nom.
//
//  D'où la RPC `correspondants_ministere()` (migration 0184), qui rend le
//  minimum : uniquement les correspondants appartenant à l'un des DEUX
//  ministères, et uniquement parmi les gens avec qui l'appelant a réellement
//  échangé. Elle n'apprend rien sur les groupes ordinaires, et ne sert pas
//  d'annuaire du personnel ministériel.
//
//  ── FAIL-SOFT ─────────────────────────────────────────────────────────────
//  En cas d'échec : map VIDE, donc aucune pastille. On perd un ornement, on
//  ne casse pas la messagerie. L'inverse — afficher « MINISTÈRE » sur un
//  correspondant ordinaire parce qu'une requête a mal tourné — serait bien
//  pire : il porterait l'autorité de l'État sans l'avoir.
// ════════════════════════════════════════════════════════════════════════════

/// Ce qu'on affiche d'un correspondant ministériel : son ministère, et rien
/// d'autre. Volontairement pauvre — c'est tout ce que la RPC accepte de dire.
typedef CorrespondantMinistere = ({String groupeNom, String? tutelle});

/// Les correspondants de l'utilisateur qui appartiennent à un ministère,
/// indexés par identifiant de profil.
///
/// La très grande majorité des utilisateurs n'en a AUCUN : la map est vide, et
/// c'est le cas normal. Deux groupes sur tout le pays sont des ministères.
final correspondantsMinistereProvider =
    FutureProvider.autoDispose<Map<String, CorrespondantMinistere>>((ref) async {
  final profil = ref.watch(authNotifierProvider).valueOrNull;
  if (profil == null) return const {};
  try {
    final rows =
        await ref.watch(supabaseClientProvider).rpc('correspondants_ministere')
            as List;
    return {
      for (final r in rows)
        (r as Map)['profile_id'] as String: (
          groupeNom: r['group_name'] as String? ?? '—',
          tutelle: r['tutelle'] as String?,
        ),
    };
  } catch (_) {
    // Fail-soft assumé : pas de pastille plutôt qu'une pastille fausse.
    return const {};
  }
});
