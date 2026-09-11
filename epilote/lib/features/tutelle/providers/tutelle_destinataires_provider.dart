import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  À QUI UNE TUTELLE PEUT ÉCRIRE DANS UN GROUPE SUPERVISÉ
//
//  ── POURQUOI UNE RPC ET PAS UNE REQUÊTE ───────────────────────────────────
//  `profiles_select` borne un `admin_groupe` aux profils de SON groupe. Un
//  ministère ne peut donc pas lire — même en lecture seule — l'identité de
//  l'administrateur d'un groupe qu'il supervise, ni celle des chefs de ses
//  établissements. `tutelle_destinataires` (migration 0174) franchit ce mur en
//  un seul endroit, avec deux gardes : être une tutelle, ET que le groupe soit
//  sous cette tutelle.
//
//  ── ⚠️ LE CHEF SE RECONNAÎT À SON RÔLE ───────────────────────────────────
//  Mesuré le 2026-09-03 : `schools.director_id` est NULL sur les onze écoles
//  supervisées du MEPSA, alors que chacune a bien un chef actif — rattaché par
//  `profiles.school_id` avec le rôle `directeur` ou `proviseur`. La RPC résout
//  donc par le RÔLE. (La colonne « chef d'établissement » de `tutelle_ecoles`,
//  elle, lit `director_id` : elle est vide en pratique. Défaut distinct, non
//  corrigé ici — le corriger changerait des écrans et des PDF déjà livrés.)
// ════════════════════════════════════════════════════════════════════════════

/// Une personne à qui la tutelle peut adresser un message.
class DestinataireTutelle {
  const DestinataireTutelle({
    required this.userId,
    required this.fonction,
    this.nom,
    this.schoolId,
    this.ecole,
  });

  factory DestinataireTutelle.fromRow(Map<String, dynamic> r) =>
      DestinataireTutelle(
        userId: r['user_id'] as String,
        nom: (r['nom'] as String?)?.trim(),
        fonction: r['fonction'] as String? ?? '—',
        schoolId: r['school_id'] as String?,
        ecole: (r['ecole'] as String?)?.trim(),
      );

  final String userId;
  final String? nom;
  final String fonction;

  /// `null` pour l'administrateur du groupe — c'est ce qui le distingue d'un
  /// chef d'établissement, et ce qui permet de les présenter séparément.
  final String? schoolId;
  final String? ecole;

  bool get estLeGroupe => schoolId == null;

  /// Ce qu'on lit à l'écran. ⚠️ Jamais l'identifiant : un UUID n'apprend rien
  /// au rédacteur, et il ne saurait pas s'il s'est trompé de personne.
  String get libelle => (nom == null || nom!.isEmpty) ? fonction : nom!;
}

/// Les destinataires possibles dans le groupe [groupId].
///
/// ⚠️ `family` sur l'identifiant : deux fiches ouvertes coup sur coup ne
/// doivent pas se partager une liste de destinataires.
final destinatairesTutelleProvider = FutureProvider.autoDispose
    .family<List<DestinataireTutelle>, String>((ref, groupId) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .rpc('tutelle_destinataires', params: {'p_group_id': groupId}) as List;
  return [
    for (final r in rows)
      DestinataireTutelle.fromRow(Map<String, dynamic>.from(r as Map)),
  ];
});
