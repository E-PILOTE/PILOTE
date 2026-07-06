/// Chemins de navigation (go_router)
class Routes {
  Routes._();

  // ── Auth ────────────────────────────────────────────────────────────────
  static const String splash         = '/';
  static const String login          = '/login';
  static const String profilePending = '/profile-pending';
  static const String forgotPassword = '/forgot-password';

  // ── Super Admin ─────────────────────────────────────────────────────────
  static const String superDashboard       = '/super/dashboard';
  static const String superGroupes         = '/super/groupes';
  static const String superGroupeDetail    = '/super/groupes/:id';
  static const String superAdministrateurs = '/super/administrateurs';
  static const String superModules         = '/super/modules';
  static const String superPlans        = '/super/plans';
  static const String superAbonnements  = '/super/abonnements';
  static const String superFactures     = '/super/factures';
  static const String superRecus        = '/super/recus';
  static const String superPaiements    = '/super/modes-paiement';
  static const String superMessages     = '/super/messagerie';
  static const String superMessagesInbox= '/super/messagerie/messages';
  static const String superTickets      = '/super/messagerie/tickets';
  static const String superAnnonces     = '/super/messagerie/annonces';
  static const String superMessagesAccueil = '/super/messagerie/accueil';
  static const String superPartenaires  = '/super/messagerie/partenaires';
  static const String superNotifications= '/super/notifications';
  static const String superIa           = '/super/ia';
  static const String superAudit        = '/super/audit';
  static const String superRapports     = '/super/rapports';
  static const String superParametres   = '/super/parametres';
  static const String superProfil       = '/super/profil';
  static const String superCarte        = '/super/carte';

  // ── Admin Groupe ─────────────────────────────────────────────────────────
  static const String adminDashboard    = '/admin/dashboard';
  static const String adminEcoles       = '/admin/ecoles';
  static const String adminEcoleDetail  = '/admin/ecoles/:id';
  static const String adminUtilisateurs = '/admin/utilisateurs';
  static const String adminProfils      = '/admin/profils';
  static const String adminRapports     = '/admin/rapports';
  static const String adminAbonnement   = '/admin/abonnement';
  static const String adminAudit        = '/admin/audit';
  static const String adminParametres   = '/admin/parametres';
  static const String adminProfil       = '/admin/profil';
  static const String adminModules      = '/admin/modules';
  static const String adminModuleDetail = '/admin/modules/:slug';
  static const String adminAnnees       = '/admin/annees';
  // Communication native (admin groupe)
  static const String adminAnnonces      = '/admin/annonces';
  static const String adminMessagerie    = '/admin/messagerie';
  static const String adminNotifications = '/admin/notifications';
  static const String adminEvenements    = '/admin/evenements';
  static const String adminSupport        = '/admin/support';

  // ── Modules (utilisateur école) ─────────────────────────────────────────
  static const String userDashboard   = '/user/dashboard';
  static const String userRapports    = '/user/rapports';
  static const String userAudit       = '/user/journal-audit'; // natif direction (online)
  static const String userParametres  = '/user/parametres';
  static const String userProfil      = '/user/profil';
  static const String userRenew       = '/user/renouvellement'; // mur hard-lock impayé
  static const String eleves          = '/user/eleves';
  static const String eleveDetail     = '/user/eleves/:id';
  static const String inscriptions    = '/user/inscriptions';
  static const String transferts      = '/user/transferts';
  static const String documents       = '/user/documents';
  static const String annuaire        = '/user/annuaire';
  static const String structure       = '/user/structure'; // structure académique (module 'niveaux')
  static const String classes         = '/user/classes';
  static const String classeDetail    = '/user/classes/:id';
  static const String calendrier      = '/user/calendrier'; // config direction (natif)
  static const String matieres        = '/user/matieres';
  static const String programmes      = '/user/programmes';
  static const String notes           = '/user/notes';
  static const String bulletins       = '/user/bulletins';
  static const String conseils        = '/user/conseils';
  static const String presences       = '/user/presences';
  static const String emploiDuTemps   = '/user/emploi-du-temps';
  static const String cahierTextes    = '/user/cahier-textes';
  static const String discipline      = '/user/discipline';
  static const String orientation     = '/user/orientation';
  static const String infirmerie      = '/user/infirmerie';
  static const String cantine         = '/user/cantine';
  static const String bibliotheque    = '/user/bibliotheque';
  static const String fraisScolarite  = '/user/frais';
  static const String paiements       = '/user/paiements';
  static const String depenses        = '/user/depenses';
  static const String budget          = '/user/budget';
  static const String personnel       = '/user/personnel';
  static const String presencesPersonnel = '/user/presences-personnel';
  static const String conges          = '/user/conges';
  static const String paie            = '/user/paie';
  // Communication native (personnel école / parent)
  static const String annonces        = '/user/annonces';
  static const String notifications   = '/user/notifications';
  static const String messagerie      = '/user/messagerie';
  static const String evenements      = '/user/evenements';
  static const String espaceParent    = '/user/espace-parent';
  static const String userSupport     = '/user/support';

  /// Hôte générique des modules pas encore dotés d'un écran dédié.
  /// `/user/m/:slug` → placeholder (la sidebar dynamique y route les modules
  /// accordés mais non encore construits).
  static const String moduleHost      = '/user/m/:slug';
}
