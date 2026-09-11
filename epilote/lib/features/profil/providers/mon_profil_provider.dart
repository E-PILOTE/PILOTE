import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/profile_model.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../admin_groupe/providers/admin_settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../../user/providers/user_profile_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MON PROFIL — une seule page pour les trois espaces
//
//  ── CE QU'IL Y AVAIT AVANT (2026-09-04) ───────────────────────────────────
//  TROIS écrans « Mon profil », un par espace, qui avaient divergé :
//    • super_admin  : 742 lignes, une carte « Sécurité » dont les trois lignes
//      étaient des CONSTANTES — « alertes de connexion par e-mail : activé »
//      alors que rien n'envoie d'alerte — et un champ « mot de passe actuel »
//      jamais lu par le code qui change le mot de passe ;
//    • admin_groupe : 267 lignes, prénom/nom/téléphone et rien d'autre ;
//    • personnel    : le plus complet des trois, et le seul offline-first.
//  Aucun des trois ne permettait de déposer sa PHOTO, alors que `avatar_url`
//  s'affiche dans l'annuaire, la messagerie, le fil d'annonces et le sélecteur
//  d'agent : la colonne était lue partout, écrite nulle part.
//
//  ── LA RÈGLE DU PROJET ────────────────────────────────────────────────────
//  Une fonctionnalité transverse = UN module partagé dont le périmètre se
//  déduit du rôle. « Mon profil » l'est par nature : tout le monde en a un.
//
//  ── LES DEUX CHEMINS DE DONNÉES ───────────────────────────────────────────
//  C'est le concept structurant de l'application, et il s'applique ici :
//    • personnel scolaire → PowerSync (SQLite local, lecture réactive, écriture
//      locale remontée par le connecteur) : la page marche sans réseau ;
//    • super_admin / admin_groupe → Supabase direct.
//  La bascule se lit sur `ProfileModel.isSchoolStaff`, jamais recopiée.
//
//  ── ⚠️ CE QUE CETTE PAGE N'ÉCRIT JAMAIS ───────────────────────────────────
//  `role`, `access_profile_id`, `school_id`, `group_id`, `is_active` et les
//  trois `sync_*` sont GELÉS par le déclencheur `profiles_garde_colonnes_de_
//  pouvoir` (0188) dès que la ligne modifiée est la sienne — silencieusement,
//  sans erreur. Les envoyer ferait afficher « enregistré » sur une valeur que
//  la base a remise comme avant. `nul_ne_se_donne_le_pouvoir_test.dart` garde
//  ce fichier ligne à ligne.
// ════════════════════════════════════════════════════════════════════════════

/// Ce que « Mon profil » a besoin de savoir, quel que soit l'espace.
class MonProfil {
  const MonProfil({
    required this.profil,
    required this.emailDuCompte,
    required this.estLeCompteAppareil,
  });

  /// La ligne `profiles` de la personne au clavier.
  final ProfileModel profil;

  /// L'adresse qui OUVRE la session — elle vit dans `auth.users`, pas ici.
  /// Nulle quand la session appartient à quelqu'un d'autre (poste partagé).
  final String? emailDuCompte;

  /// Vrai quand la personne affichée EST celle qui a authentifié l'appareil.
  ///
  /// ⚠️ Faux sur un poste partagé où un collègue a pris la main par code PIN :
  /// la session Supabase reste celle du compte appareil. Tout ce qui touche au
  /// COMPTE (mot de passe, sessions) concernerait alors quelqu'un d'autre.
  final bool estLeCompteAppareil;

  String get nomComplet => profil.fullName;

  /// Vrai quand cette page a le droit d'ÉCRIRE la fiche affichée.
  ///
  /// ⚠️ Ce n'est pas une précaution d'écran, c'est une garde de synchro.
  /// `profiles_update` n'accepte que `id = auth.uid()` (ou un administrateur).
  /// Sur un poste partagé, la fiche montrée est celle de l'AGENT au clavier
  /// tandis que la session appartient au compte APPAREIL : l'écriture partirait
  /// dans la file, reviendrait en `42501` — code fatal pour le connecteur — et
  /// emporterait le LOT ENTIER, c'est-à-dire les notes et les paiements écrits
  /// dans la même fenêtre. La correction de la fiche d'un collègue passe par
  /// l'écran Personnel, qui dépose une DEMANDE (cf. `staff_photo_requests`).
  bool get peutModifierSaFiche => estLeCompteAppareil;
}

/// La ligne `profiles` lue en direct, pour les deux espaces en ligne.
final _profilEnLigneProvider =
    FutureProvider.autoDispose<ProfileModel?>((ref) async {
  final compte = ref.watch(authNotifierProvider).valueOrNull;
  if (compte == null) return null;
  return _lireProfilEnLigne(ref, compte.id);
});

/// Le profil de la personne au clavier, par le chemin de données de son rôle.
///
/// Un `Provider` qui RELAIE l'état de la source choisie : le personnel a besoin
/// du réactif (la ligne locale change dès l'enregistrement, sans réseau) et
/// l'espace en ligne d'une lecture unique. Les deux arrivent ici sous la même
/// forme, et l'écran n'a qu'un `when` à écrire.
final monProfilProvider = Provider.autoDispose<AsyncValue<MonProfil?>>((ref) {
  final compte = ref.watch(authNotifierProvider).valueOrNull;
  final session = ref.watch(currentUserProvider);
  if (compte == null) return const AsyncValue<MonProfil?>.data(null);

  // Offline-first côté personnel : la source suit l'AGENT ACTIF, pas seulement
  // le compte qui a authentifié l'appareil.
  final source = compte.isSchoolStaff
      ? ref.watch(myProfileRowProvider)
      : ref.watch(_profilEnLigneProvider);

  return source.whenData((p) {
    final profil = p ?? compte;
    final estMoi = session != null && session.id == profil.id;
    return MonProfil(
      profil: profil,
      emailDuCompte: estMoi ? session.email : null,
      estLeCompteAppareil: estMoi,
    );
  });
});

Future<ProfileModel?> _lireProfilEnLigne(Ref ref, String id) async {
  final client = ref.read(supabaseClientProvider);
  final row = await client
      .from('profiles')
      .select(
        'id, group_id, school_id, role, access_profile_id, first_name, '
        'last_name, phone, avatar_url, employee_number, is_active, '
        'last_login, created_at, updated_at',
      )
      .eq('id', id)
      .maybeSingle();
  return row == null ? null : ProfileModel.fromMap(row);
}

/// À quoi la personne est rattachée : sa plateforme, son groupe ou son école.
///
/// Trois provenances, un seul libellé — c'est ce que la page affiche sous le
/// nom, et il ne veut pas dire la même chose selon l'espace.
final monRattachementProvider = Provider.autoDispose<String?>((ref) {
  final compte = ref.watch(authNotifierProvider).valueOrNull;
  if (compte == null) return null;
  if (compte.isSuperAdmin) return 'Plateforme E-PILOTE';
  if (compte.isAdminGroupe) {
    return ref.watch(adminGroupProfileProvider).valueOrNull?.name;
  }
  return ref.watch(currentSchoolProvider).valueOrNull?['name'] as String?;
});

/// Enregistre l'identité — et RIEN d'autre.
///
/// Trois colonnes, choisies : ce sont les seules de cette page que la base
/// laisse une personne changer sur sa propre ligne (cf. l'en-tête). La PHOTO
/// n'en fait pas partie — elle a son propre chemin, et sa propre raison :
/// `services/mon_avatar_service.dart`.
Future<void> enregistrerMonProfil(
  WidgetRef ref, {
  required MonProfil moi,
  required String prenom,
  required String nom,
  String? telephone,
}) async {
  final tel = telephone?.trim();
  final telephoneNet = (tel == null || tel.isEmpty) ? null : tel;

  if (moi.profil.isSchoolStaff) {
    await updateMyProfile(
      id: moi.profil.id,
      firstName: prenom,
      lastName: nom,
      phone: telephoneNet,
    );
    // L'en-tête de l'application relit le nom affiché.
    await ref.read(authNotifierProvider.notifier).reload();
    return;
  }

  final client = ref.read(supabaseClientProvider);
  await client.from('profiles').update({
    'first_name': prenom.trim(),
    'last_name': nom.trim(),
    'phone': telephoneNet,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', moi.profil.id);
  await ref.read(authNotifierProvider.notifier).reload();
  ref.invalidate(_profilEnLigneProvider);
}

/// Vrai quand la synchro offline est active sur cet appareil.
/// Sert à dire pourquoi une action de COMPTE (mot de passe) exige le réseau.
final monProfilEnLigneProvider = Provider.autoDispose<bool>((ref) {
  final compte = ref.watch(authNotifierProvider).valueOrNull;
  if (compte == null || !compte.isSchoolStaff) return true;
  return ref.watch(isSyncingProvider);
});
