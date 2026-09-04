import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  QUI TIENT LE RÉFÉRENTIEL NATIONAL DES EXAMENS
//
//  ── POURQUOI CET ÉCRAN A BESOIN DE LE SAVOIR ──────────────────────────────
//  La migration 0155 a fermé une brèche : n'importe quel admin_groupe pouvait
//  modifier le BAC national et réécrire les 35 sessions officielles d'un coup
//  — mesuré depuis un compte de groupe PRIVÉ. L'écriture est désormais
//  réservée au super_admin et au ministère de la tutelle concernée.
//
//  ⚠️ MAIS UN REFUS DE RLS EST MUET SUR UPDATE ET DELETE. La politique écarte
//  la ligne par son `USING` : zéro ligne touchée, réponse 204, aucune erreur.
//  Un bouton « Supprimer » laissé en place ne dirait donc RIEN — ni succès ni
//  échec. C'est exactement le défaut que 0154 a corrigé sur le barème de
//  passage, et il ne faut pas le réintroduire par la porte d'à côté.
//
//  D'où ce drapeau : l'écran RETIRE les actions au lieu d'afficher des boutons
//  qui ne font rien, et dit en une phrase pourquoi.
// ════════════════════════════════════════════════════════════════════════════

/// VRAI si l'utilisateur courant peut écrire dans le référentiel national.
///
/// Deux cas : le super_admin (qui n'a pas de groupe), et l'admin d'un groupe
/// marqué `administre_referentiel_national` — les deux ministères.
///
/// ⚠️ Retombe sur FAUX en cas d'erreur ou d'absence : un droit qu'on n'a pas
/// pu établir n'est pas un droit acquis. Se tromper dans ce sens retire un
/// bouton ; se tromper dans l'autre laisse détruire un diplôme d'État.
final groupeAdministreReferentielProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final profil = ref.watch(authNotifierProvider).valueOrNull;
  if (profil == null) return false;
  if (profil.isSuperAdmin) return true;
  return ref.watch(groupeEstMinistereProvider.future);
});

/// VRAI si le GROUPE de l'utilisateur est un ministère de tutelle.
///
/// ⚠️ À ne pas confondre avec `groupeAdministreReferentielProvider`, qui
/// répond OUI au super_admin : lui n'a pas de groupe. La question posée ici
/// est celle de la NATURE du groupe, et c'est elle qu'il faut poser pour
/// décider ce qu'un espace client contient — un fondateur n'est pas un
/// ministère, et lui donner les écrans de supervision par cette porte serait
/// un accident.
///
/// Même repli prudent : au doute, FAUX. Se tromper dans ce sens retire un
/// outil de supervision à qui y avait droit — visible, corrigible. Se tromper
/// dans l'autre met la carte nationale entre les mains d'un client privé.
final groupeEstMinistereProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final profil = ref.watch(authNotifierProvider).valueOrNull;
  final groupId = profil?.groupId;
  if (groupId == null || groupId.isEmpty) return false;
  try {
    final g = await ref
        .watch(supabaseClientProvider)
        .from('school_groups')
        .select('administre_referentiel_national')
        .eq('id', groupId)
        .maybeSingle();
    return g?['administre_referentiel_national'] as bool? ?? false;
  } catch (_) {
    return false;
  }
});

/// Bandeau de lecture seule, à placer en tête d'un écran du référentiel.
/// Ne s'affiche QUE lorsque le droit manque — un écran qui l'a n'a rien à lire.
class ReferentielLectureSeuleBandeau extends ConsumerWidget {
  const ReferentielLectureSeuleBandeau({super.key, required this.quoi});

  /// Ce dont on parle, au pluriel : « ces examens », « ces sessions ».
  final String quoi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peut =
        ref.watch(groupeAdministreReferentielProvider).valueOrNull ?? false;
    if (peut) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kNavy.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.visibility_outlined, size: 18, color: kNavy),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Consultation seule',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(height: 3),
            Text(
              '$quoi relèvent du référentiel NATIONAL : ils sont les mêmes pour '
              'toutes les écoles du pays, et seul le ministère de tutelle les '
              'modifie. Vous les consultez tels qu\'ils s\'appliquent à vos '
              'établissements.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.45),
            ),
          ]),
        ),
      ]),
    );
  }
}
