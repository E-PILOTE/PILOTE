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
  /// « Directeur des Études » existe bel et bien, mais comme **profil d'accès**
  /// (`access_profiles.role_type`, proposé par l'espace admin groupe), pas
  /// comme `user_role`. La personne qui occupe ce poste reçoit donc un rôle de
  /// l'enum — et si on lui donne `enseignant`, elle n'atteindra pas le
  /// Calendrier scolaire malgré son profil. **Question produit, à trancher :**
  /// ajouter `directeur_etudes` à l'enum, ou assumer qu'un D.E. porte le rôle
  /// `directeur`.
  static const Set<String> directionRoles = {
    roleProviseur,
    roleDirecteur,
    roleSecretaire,
  };
}
