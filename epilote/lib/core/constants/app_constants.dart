/// Constantes globales de l'application
class AppConstants {
  AppConstants._();

  static const String appName = 'E-PILOTE CONGO';
  static const String appVersion = '3.0.0';

  // Rôles utilisateur — enum user_role dans Supabase (3 valeurs dans profiles.role)
  static const String roleSuperAdmin       = 'super_admin';
  static const String roleAdminGroupe      = 'admin_groupe';
  static const String roleUtilisateur      = 'utilisateur';  // tout le personnel scolaire
  static const String roleDirecteur        = 'directeur';
  static const String roleProviseur        = 'proviseur';
  static const String roleEnseignant       = 'enseignant';
  static const String roleCpe              = 'cpe';
  static const String roleComptable        = 'comptable';
  static const String roleSecretaire       = 'secretaire';
  static const String roleSurveillant      = 'surveillant';
  static const String roleParent           = 'parent';
  static const String roleEleve            = 'eleve';
  static const String roleInfirmier        = 'infirmier';
  static const String roleResponsableCantine = 'responsable_cantine';

  // Durée token PowerSync
  static const int powersyncTokenDaysValidity = 30;

  // Pagination
  static const int defaultPageSize = 20;

  // Formats de date
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Mentions (doit correspondre à get_mention() dans Supabase)
  static const double seuilExcellent = 18.0;
  static const double seuilTresBien = 16.0;
  static const double seuilBien = 14.0;
  static const double seuilAssezBien = 12.0;
  static const double seuilPassable = 10.0;

  // Devise
  static const String currency = 'XAF';
  static const String currencySymbol = 'FCFA';
}
