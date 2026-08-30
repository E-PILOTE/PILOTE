/// Constantes globales de l'application.
///
/// ── CE QUI A ÉTÉ RETIRÉ LE 2026-08-25, ET POURQUOI ──────────────────────────
/// Ce fichier portait treize constantes que plus rien n'utilisait. Deux
/// d'entre elles n'étaient pas seulement mortes, elles étaient DANGEREUSES :
///
/// • `roleUtilisateur = 'utilisateur'` — l'enum `user_role` n'a JAMAIS eu cette
///   valeur ; le rôle EST le métier (`enseignant`, `secretaire`, `comptable`…).
///   Un test `role == 'utilisateur'` avait tué la synchro de tout le personnel,
///   corrigé le 2026-06-06. La constante restait là, prête à le refaire pour
///   qui l'aurait crue authentique. Elle n'existe plus.
///
/// • `seuilExcellent`, `seuilTresBien`, `seuilBien`, `seuilAssezBien`,
///   `seuilPassable` — un QUATRIÈME exemplaire du barème des mentions, alors
///   que `core/utils/mention.dart` se déclare source unique après que trois
///   copies eurent divergé de deux points (« Passable » pour 8/20, une note
///   d'échec présentée comme une réussite). Un barème qu'on n'appelle pas ne
///   se teste pas, et diverge en silence. Le barème vit dans `mention.dart`.
///
/// Les autres — `appName`, `appVersion` (figé à « 3.0.0 » alors que le produit
/// est en 3.3.0), `dateFormat`, `currency`… — étaient inoffensives mais
/// fausses ou redondantes. Ne rien laisser qu'un lecteur puisse croire vrai.
///
/// ⚠️ N'ajouter ici que ce qui sert à PLUSIEURS endroits. Une constante sans
/// appelant est une affirmation que personne ne vérifie.
class AppConstants {
  AppConstants._();

  // Rôles — enum `user_role` en base. Le rôle EST le métier.
  static const String roleSuperAdmin = 'super_admin';
  static const String roleAdminGroupe = 'admin_groupe';
  static const String roleDirecteur = 'directeur';
  static const String roleProviseur = 'proviseur';
  static const String roleEnseignant = 'enseignant';
  static const String roleCpe = 'cpe';
  static const String roleComptable = 'comptable';
  static const String roleSecretaire = 'secretaire';
  static const String roleSurveillant = 'surveillant';
  static const String roleParent = 'parent';
  static const String roleEleve = 'eleve';
  static const String roleInfirmier = 'infirmier';
  static const String roleResponsableCantine = 'responsable_cantine';

  /// Les treize valeurs de l'enum `user_role`, et rien d'autre.
  ///
  /// Sert de référence aux gardes : un aiguillage sur le rôle qui contient une
  /// valeur absente d'ici ne s'exécutera JAMAIS, et un rôle absent de
  /// l'aiguillage tombe dans son cas par défaut. Les deux se voient mal à la
  /// lecture — d'où `test/roles_connus_test.dart`.
  static const Set<String> tousLesRoles = {
    roleSuperAdmin,
    roleAdminGroupe,
    roleDirecteur,
    roleProviseur,
    roleEnseignant,
    roleCpe,
    roleComptable,
    roleSecretaire,
    roleSurveillant,
    roleParent,
    roleEleve,
    roleInfirmier,
    roleResponsableCantine,
  };

  /// Rôles « direction » d'un établissement : seuls habilités à la config
  /// native de l'école (ex. Calendrier scolaire). Source UNIQUE — utilisée
  /// par le garde du routeur, la sidebar ET l'écran Calendrier.
  ///
  /// ⚠️ `'directeur_etudes'` figurait ici. **L'enum `user_role` ne le contient
  /// pas** — aucun compte ne peut porter cette valeur, le test ne pouvait donc
  /// jamais réussir. C'est exactement le piège de `roleUtilisateur`, retiré le
  /// 2026-08-25 : une valeur morte dans un test de rôle, qui rassure sans rien
  /// faire. Retiré le 2026-08-27.
  ///
  /// ── DIRECTEUR DES ÉTUDES : TRANCHÉ LE 2026-08-30 ────────────────────────
  /// **`directeur_etudes` n'entre PAS dans l'enum.** Le poste existe, mais
  /// comme **profil d'accès** (`access_profiles.role_type`), et ce profil
  /// fonctionne déjà : `role_type` ne contraint aucune affectation, un D.E.
  /// reçoit donc le préréglage « Directeur des Études » quel que soit son rôle,
  /// et en tire exactement les pouvoirs pédagogiques décrits — programmes,
  /// évaluations, bulletins, conseils.
  ///
  /// Le Calendrier scolaire n'est délibérément PAS de ceux-là : déclarer les
  /// trimestres et les vacances d'un établissement est l'acte de son chef, pas
  /// du pilote pédagogique. Le préréglage D.E. ne demande pas cette catégorie.
  /// Il n'y a donc rien à réparer — seulement une question qui restait ouverte.
  ///
  /// Ce qui a emporté la décision : personne, en production, ne porte ce rôle
  /// et aucun profil d'accès ne l'utilise. Ajouter une valeur à un enum
  /// national à la veille d'un déploiement obligerait à la traiter dans CHAQUE
  /// aiguillage — tableau de bord du routeur, sidebar, RLS, étiquettes — et en
  /// oublier un poserait un D.E. devant un écran vide, pour zéro utilisateur
  /// gagné.
  static const Set<String> directionRoles = {
    roleProviseur,
    roleDirecteur,
    roleSecretaire,
  };
}
