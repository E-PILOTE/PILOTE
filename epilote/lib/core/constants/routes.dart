/// Chemins de navigation (go_router)
class Routes {
  Routes._();

  // ── Auth ────────────────────────────────────────────────────────────────
  static const String splash         = '/';
  static const String login          = '/login';
  static const String profilePending = '/profile-pending';
  static const String forgotPassword = '/forgot-password';

  /// Le poste a perdu sa session serveur mais se reconnaît et tient encore les
  /// données de son école. Prend la place de l'écran de connexion, qui serait
  /// un mur : sur place, personne ne connaît le mot de passe du compte.
  static const String reprisePoste   = '/reprise-poste';

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
  static const String superVersions     = '/super/versions';

  // ── Admin Groupe ─────────────────────────────────────────────────────────
  static const String adminDashboard    = '/admin/dashboard';
  static const String adminEcoles       = '/admin/ecoles';
  /// Le réseau SOUS TUTELLE — à ne pas confondre avec `adminEcoles`, qui
  /// montre les écoles que le groupe POSSÈDE. Pour un ministère les deux
  /// nombres diffèrent (le MEPSA possède 14 des 25 écoles de sa tutelle).
  static const String adminTutelle      = '/admin/tutelle';
  static const String adminEcoleDetail  = '/admin/ecoles/:id';
  static const String adminUtilisateurs = '/admin/utilisateurs';
  static const String adminEleves       = '/admin/eleves';
  static const String adminProfils      = '/admin/profils';
  // Le SEUL endroit de la plateforme où un montant se crée. L'école reçoit et
  // applique — elle n'a plus aucun écran d'écriture (migration 0096, D2).
  static const String adminFrais        = '/admin/frais';
  // Où pointe la 6e de chaque école. Un tarif réseau par niveau (mig. 0101)
  // vise une entrée du référentiel ; toute la chaîne tient à ce rattachement,
  // et rien ne le montrait — d'où cet écran de constat, en lecture seule.
  static const String adminRattachement = '/admin/rattachement';
  static const String adminExamens      = '/admin/examens';
  // Le référentiel national et son calendrier appartiennent au MINISTÈRE, pas
  // à l'opérateur de la plateforme : c'est lui qui connaît les examens et
  // reçoit les arrêtés. Le super_admin exploite le SaaS, il ne le peuple pas.
  static const String adminReferentiel  = '/admin/referentiel-examens';
  static const String adminSessions     = '/admin/sessions-examen';
  static const String adminResultats    = '/admin/resultats';
  static const String adminPalmares     = '/admin/palmares';
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
  // Sous-chemin de `documents` : `moduleSlugForLocation` reconnaît les
  // sous-chemins, l'écran hérite donc du même verrou sans module supplémentaire.
  static const String registreDocuments = '/user/documents/registre';
  // ⚠️ Sous `documents`, et NON sous `eleves` : `/user/eleves/:id` capterait
  // « /user/eleves/registre-matricule » comme un identifiant d'élève. Le
  // rattachement est de toute façon juste — c'est un document que l'école
  // produit, tenu par les mêmes mains que les pièces du dossier.
  static const String registreMatricule = '/user/documents/registre-matricule';
  static const String etatRentree     = '/user/documents/etat-rentree';
  static const String cartes          = '/user/cartes'; // cartes scolaires
  static const String annuaire        = '/user/annuaire';
  static const String structure       = '/user/structure'; // structure académique (module 'niveaux')
  static const String classes         = '/user/classes';
  static const String classeDetail    = '/user/classes/:id';
  static const String calendrier      = '/user/calendrier'; // config direction (natif)
  static const String matieres        = '/user/matieres';
  static const String programmes      = '/user/programmes';
  static const String examens        = '/user/examens';
  static const String stages         = '/user/stages';
  static const String examenSession  = '/user/examens/session/:id';
  static const String notes           = '/user/notes';
  static const String bulletins       = '/user/bulletins';
  static const String conseils        = '/user/conseils';
  static const String passage         = '/user/passage';
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
