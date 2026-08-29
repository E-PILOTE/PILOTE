import 'package:powersync/powersync.dart';

/// Schéma PowerSync — toutes les tables offline (phases 1-8 + navigation).
/// Tables admin-only (super_admin / admin_groupe) restent en Supabase direct.
const schema = Schema([

  // ════════════════════════════════════════════════════════════════════════
  // NAVIGATION DYNAMIQUE (données globales plateforme)
  // ════════════════════════════════════════════════════════════════════════

  Table('module_categories', [
    Column.text('name'),
    Column.text('slug'),
    Column.text('icon'),
    Column.integer('display_order'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Messages de service (vitrine des postes) — diffusion globale (migration 0034)
  Table('platform_service_messages', [
    Column.text('body'),
    Column.integer('is_active'),
    Column.text('starts_at'),
    Column.text('ends_at'),
  ]),

  // Partenaires (vitrine des postes) — diffusion globale (migration 0035)
  Table('platform_partners', [
    Column.text('name'),
    Column.text('logo_url'),
    Column.text('website_url'),
    Column.text('category'),
    Column.integer('is_active'),
    Column.integer('sort_order'),
    Column.text('starts_at'),
    Column.text('ends_at'),
  ]),

  Table('modules', [
    Column.text('category_id'),
    Column.text('name'),
    Column.text('slug'),
    Column.text('description'),
    Column.text('icon'),
    Column.integer('display_order'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Modules inclus dans le plan du groupe
  Table('plan_modules', [
    Column.text('plan_id'),
    Column.text('module_id'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // CONTRÔLE D'ACCÈS (profil du membre courant — verrous 3 & 4 offline)
  // ════════════════════════════════════════════════════════════════════════

  // Profil d'accès assigné au membre (sync-rules : uniquement le sien).
  Table('access_profiles', [
    Column.text('group_id'),
    Column.text('name'),
    Column.text('description'),
    Column.text('role_type'),
    Column.integer('is_active'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Permissions module-par-module du profil (10 booléens + périmètre).
  Table('profile_permissions', [
    Column.text('profile_id'),
    Column.text('module_id'),
    Column.text('group_id'),
    Column.integer('can_read'),
    Column.integer('can_create'),
    Column.integer('can_update'),
    Column.integer('can_delete'),
    Column.integer('can_export'),
    Column.integer('can_import'),
    Column.integer('can_validate'),
    Column.integer('can_approve'),
    Column.integer('can_manage'),
    Column.integer('can_write'),
    Column.text('data_scope'),       // own_classes | own_school
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // IDENTITÉ (profil + groupe)
  // ════════════════════════════════════════════════════════════════════════

  Table('profiles', [
    Column.text('first_name'),
    Column.text('last_name'),
    Column.text('avatar_url'),
    Column.text('role'),
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('access_profile_id'),
    Column.text('phone'),
    Column.text('employee_number'),
    Column.text('date_of_birth'),
    // Identité étendue (dossier RH)
    Column.text('gender'),
    Column.text('birth_place'),
    Column.text('address'),
    // Volet carrière fonction publique (migration 0023)
    Column.text('employment_status'),
    Column.text('grade'),
    Column.text('echelon'),
    Column.text('category'),
    Column.text('hire_date'),
    Column.text('speciality'),
    Column.integer('is_active'),
    Column.text('last_login'),
    // ⚠️ `profiles.fcm_token` N'EST PLUS DÉCLARÉE ICI (2026-08-29).
    // La plateforme n'a qu'un fournisseur — Supabase — donc aucun jeton
    // Firebase ne sera jamais produit. La colonne subsiste en base (0 valeur
    // sur 344 profils) et sera retirée par la migration 0146, une fois tous
    // les postes passés sur cette version : un client qui enverrait encore
    // `fcm_token` à une colonne disparue provoquerait un 42703, que le
    // connecteur ne traite PAS comme fatal — il rejouerait le lot sans fin.
    // La retirer du schéma local est donc l'étape qui rend le DROP sûr.
    // Verrouillé par `test/notification_sans_firebase_test.dart`.
    // Reset PIN de poste par admin_groupe (migration 0033)
    Column.text('pin_reset_requested_at'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Groupe scolaire — contient plan_id → clé de navigation offline
  Table('school_groups', [
    Column.text('name'),
    Column.text('slug'),
    Column.text('group_type'),
    Column.text('department'),
    Column.text('plan_id'),
    Column.text('subscription_status'),
    Column.text('subscription_start'),
    Column.text('subscription_end'),
    Column.text('admin_email'),
    Column.text('phone'),
    Column.text('address'),
    Column.text('logo_url'),
    Column.integer('is_active'),
    // Opt-in affichage partenaires sur les postes du groupe (migration 0035)
    Column.integer('partner_display_enabled'),
    // Fenêtre d'alerte d'échéance recopiée depuis platform_settings (mig 0106).
    // Seul chemin par lequel un réglage de la PLATEFORME atteint un poste
    // école hors ligne : platform_settings n'est pas synchronisée (RLS
    // super_admin), school_groups descend en entier via `by_group`.
    Column.integer('subscription_alert_days'),
    // Barème de passage du GROUPE (migration 0107) — la barre au-dessus de
    // laquelle l'élève passe, et le plancher sous lequel il redouble sans
    // discussion. Entre les deux s'ouvre la zone de délibération : le logiciel
    // ne propose rien et le conseil tranche.
    //
    // Le seuil descend par `school_groups` pour la même raison que la fenêtre
    // d'alerte juste au-dessus : la table est synchronisée en entier par
    // `by_group` (SELECT *), donc un réglage du ministère atteint les postes
    // sans toucher aux sync-rules.
    Column.real('promotion_pass_mark'),
    Column.real('promotion_deliberation_floor'),
    Column.text('notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // PHASE 1 — STRUCTURE SCOLAIRE
  // ════════════════════════════════════════════════════════════════════════

  Table('schools', [
    Column.text('group_id'),
    Column.text('name'),
    Column.text('school_type'),
    Column.text('school_code'),
    Column.text('address'),
    Column.text('city'),
    Column.text('department'),
    Column.text('province'),
    Column.text('arrondissement'),
    Column.text('email'),
    Column.text('phone'),
    Column.text('website'),
    Column.integer('founded_year'),
    Column.text('motto'),
    Column.text('director_id'),
    Column.text('logo_url'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('academic_years', [
    Column.text('label'),
    Column.text('start_date'),
    Column.text('end_date'),
    Column.integer('is_current'),
    Column.integer('is_locked'),
    Column.text('school_id'),
    Column.text('group_id'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('trimesters', [
    Column.text('academic_year_id'),
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('label'),
    Column.integer('trimester_number'),
    Column.text('start_date'),
    Column.text('end_date'),
    Column.integer('is_current'),
    Column.integer('is_locked'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('sequences', [
    Column.text('trimester_id'),
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('label'),
    Column.integer('sequence_number'),
    Column.text('start_date'),
    Column.text('end_date'),
    Column.integer('is_current'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ── Structure académique de l'école (cycles/niveaux réels, offline) ────────
  // Permet à la page Inscriptions d'afficher TOUS les cycles/niveaux configurés
  // pour l'école (même à 0 inscrit). education_cycles = référentiel global
  // (libellés/ordre) ; school_cycles = cycles RÉELS de l'école ; school_levels =
  // catalogue de niveaux du groupe (rattachés à un cycle).
  Table('education_cycles', [
    Column.text('code'),
    Column.text('name'),
    Column.integer('order_index'),
    Column.integer('has_programs'),
    Column.text('group_id'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('school_cycles', [
    Column.text('school_id'),
    Column.text('cycle_id'),
    Column.text('group_id'),
    Column.text('created_at'),
  ]),

  Table('school_levels', [
    Column.text('code'),
    Column.text('name'),
    Column.text('slug'),
    Column.text('cycle_id'),
    Column.text('program_id'),
    Column.integer('order_index'),
    Column.integer('display_order'),
    Column.text('notation_type'),
    // Correspondance vers le NIVEAU NATIONAL du référentiel partagé.
    //
    // ⚠️ Sans cette colonne, `baremesApplicablesProvider` lève « no such
    // column: sl.education_level_id » : sa jointure traduit le niveau national
    // visé par un tarif du ministère (migration 0101) en niveau de l'école.
    // La requête entière échoue, donc le dû de CHAQUE élève devient
    // indéterminé et les écrans Frais et Paiements tombent en erreur — sur
    // tous les postes à la fois. Une colonne absente du schéma local n'est pas
    // « une donnée en moins » : c'est une requête qui ne s'exécute pas.
    Column.text('education_level_id'),
    // Barème de passage PROPRE à ce niveau — NULL = on hérite de celui du
    // groupe (`school_groups.promotion_pass_mark`). Migration 0107.
    Column.real('pass_mark'),
    Column.real('deliberation_floor'),
    Column.text('group_id'),
    Column.text('school_id'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Référentiel des niveaux par cycle (Congo : 6e/5e… , CP1→CM2, 2nde/Tle, FP).
  // group_id NULL = global ; sinon perso au groupe. Lecture seule côté école
  // (RLS write = admin_groupe). program_id = filière (lycée/FP), sinon NULL.
  Table('education_levels', [
    Column.text('cycle_id'),
    Column.text('program_id'),
    Column.text('code'),
    Column.text('name'),
    Column.integer('order_index'),
    Column.text('group_id'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Référentiel des filières/séries (lycée A/C/D/E/F…/G ; FP métiers).
  Table('education_programs', [
    Column.text('cycle_id'),
    Column.text('code'),
    Column.text('name'),
    Column.text('description'),
    Column.integer('order_index'),
    Column.text('group_id'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('classes', [
    Column.text('name'),
    Column.integer('capacity'),
    Column.text('main_teacher_id'),
    Column.text('room'),
    Column.text('level_id'),
    Column.text('cycle_code'),       // cycle dénormalisé (migration 0010) → KPI réels
    Column.text('level_code'),       // niveau dénormalisé (0011) → KPI par niveau
    Column.integer('level_order'),   // ordre pédagogique du niveau (0011)
    Column.text('filiere_code'),     // filière dénormalisée (0012) → KPI par filière
    Column.text('filiere_label'),    // libellé filière (lycée/FP), NULL si aucune
    // Classe d'examen (0044/0045) — DÉRIVÉ côté serveur par trigger : le client
    // LIT, il n'écrit jamais exam_id/exam_status (aucune règle dupliquée en Dart).
    Column.text('exam_id'),          // examen d'État résolu (NULL = aucun)
    Column.text('exam_status'),      // examen | passage | a_qualifier
    Column.text('exam_override_id'), // surcharge explicite (saisissable)
    Column.integer('exam_excluded'), // exclusion explicite (saisissable)
    Column.text('school_id'),
    Column.text('group_id'),
    Column.text('academic_year_id'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('class_enrollments', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('student_id'),
    Column.text('class_id'),
    Column.text('academic_year_id'),
    Column.text('enrollment_date'),
    Column.text('status'),          // pending_validation|active|rejected|withdrawn|transferred|graduated
    Column.integer('is_repeating'),
    Column.text('previous_class_id'),
    Column.text('withdrawal_date'),
    Column.text('withdrawal_reason'),
    // Catégorie normalisée de la sortie (migration 0082) — c'est elle
    // qui se compte ; `withdrawal_reason` reste le commentaire libre.
    Column.text('withdrawal_motif'),
    // Workflow inscription
    Column.text('inscription_type'),       // new|reinscription|transfer
    Column.text('transfer_reason'),        // motif si type=transfer (migration 0007)
    Column.text('filiere_id'),             // filière FP → education_programs (0007)
    Column.text('notes'),                  // notes internes d'inscription (0007)
    Column.text('created_by'),             // agent ayant saisi l'inscription (0007)
    Column.text('validated_at'),
    Column.text('validated_by'),
    Column.text('rejection_reason'),
    Column.text('previous_school_name'),
    Column.text('previous_class_name'),
    // Exonération de scolarité de CETTE année (migration 0109). Le taux vit
    // sur l'inscription et non sur l'élève : une bourse se reconduit, elle ne
    // se traîne pas. ⚠️ Sans ces deux colonnes ici, le dû d'un boursier serait
    // calculé plein sur les postes — l'exonération existerait en base et
    // n'existerait nulle part sur le terrain.
    Column.integer('exemption_rate'),
    Column.text('exemption_motif'),
    // Décision de fin d'année du conseil de classe (migration 0074).
    // `promotion_average` est un `numeric` en base : `real` est le bon miroir.
    Column.text('promotion_decision'),        // passe|redouble|reoriente
    Column.real('promotion_average'),
    Column.text('promotion_target_class_id'),
    Column.text('promotion_decided_at'),
    Column.text('promotion_decided_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // PHASE 2 — ACTEURS
  // ════════════════════════════════════════════════════════════════════════

  Table('students', [
    Column.text('matricule'),
    // Identifiant NATIONAL — 11 chiffres, attribué par le serveur et immuable
    // (migration 0080). Distinct du matricule, qui reste le numéro propre à
    // l'école. Reste NULL tant qu'une inscription saisie hors ligne n'a pas
    // été synchronisée : c'est le prix de l'unicité nationale garantie.
    Column.text('ine'),
    Column.text('first_name'),
    Column.text('last_name'),
    Column.text('date_of_birth'),
    Column.text('gender'),
    Column.text('nationality'),
    Column.text('address'),
    Column.text('city'),
    Column.text('region'),            // région/département de résidence (0007)
    Column.text('photo_url'),
    Column.text('blood_group'),
    Column.text('allergies'),
    Column.text('user_id'),           // compte parent si activé
    // Champs Congo-spécifiques
    Column.text('place_of_birth'),
    Column.text('situation_familiale'),
    Column.integer('nombre_freres_soeurs'),
    Column.integer('is_boarder'),
    Column.integer('has_scholarship'),
    Column.text('scholarship_type'),
    Column.integer('has_social_aid'),
    Column.text('social_aid_type'),
    Column.integer('is_affecte'),
    Column.text('school_id'),
    Column.text('group_id'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('student_tutors', [
    Column.text('student_id'),
    Column.text('group_id'),
    // École de l'élève rattaché (migration 0110). C'est elle qui permet aux
    // sync-rules de descendre les tuteurs PAR ÉCOLE : sans cette colonne, la
    // seule clause possible était `group_id`, et chaque poste recevait les
    // coordonnées des familles de toutes les écoles du groupe.
    //
    // ⚠️ Le serveur la recalcule par trigger, mais le client l'écrit AUSSI :
    // une fiche saisie hors ligne vit dans cette base-ci avant d'atteindre le
    // serveur, et une colonne locale vide ferait disparaître le tuteur de
    // toute requête filtrant sur l'école jusqu'au retour du réseau.
    Column.text('school_id'),
    Column.text('first_name'),
    Column.text('last_name'),
    Column.text('relationship'),    // pere|mere|tuteur|autre
    Column.text('phone_primary'),
    Column.text('phone_secondary'),
    Column.text('email'),
    Column.text('profession'),
    Column.text('address'),          // adresse du tuteur (migration 0007)
    Column.integer('is_primary_contact'),
    Column.integer('has_app_access'),
    Column.text('user_id'),
    Column.integer('is_emergency_contact'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Demandes de changement de photo d'agent (migration 0113).
  //
  // ⚠️ L'école n'écrit PAS `profiles.avatar_url` : la RLS `profiles_update`
  // refuse à un directeur d'écrire dans la fiche d'un autre agent, et un refus
  // fait abandonner à PowerSync le LOT ENTIER. Elle dépose donc une DEMANDE
  // dans cette table-ci, que le serveur applique par trigger avec l'autorité
  // de `corriger_fiche_agent`.
  //
  // `applied_at` et `refus` reviennent renseignés par le serveur : c'est par
  // eux que l'écran sait si la demande a abouti, et pourquoi sinon.
  Table('staff_photo_requests', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('profile_id'),
    Column.text('avatar_url'),
    Column.integer('effacer'),
    Column.text('requested_by'),
    Column.text('applied_at'),
    Column.text('refus'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('staff_members', [
    Column.text('group_id'),
    Column.text('school_id'),
    // ⚠️ COLONNE FANTÔME — n'existe pas en base LIVE, donc toujours vide.
    // Plus personne ne la LIT : le périmètre `own_classes` passait par elle et
    // ne trouvait jamais rien (cf. scopedClassIdsProvider). Il n'y a d'ailleurs
    // rien à y mettre — `staff_members.id` EST déjà l'id du profil
    // (`staff_members_id_fkey → profiles(id)`), le lien existe par la clé
    // primaire. Conservée le temps d'un cycle pour ne pas provoquer de
    // migration du schéma local avant la démonstration ; à supprimer ensuite.
    // NE RIEN ÉCRIRE dessus (échec d'upload silencieux).
    Column.text('profile_id'),
    Column.text('job_title'),
    Column.text('hire_date'),
    Column.text('contract_type'),
    Column.integer('base_salary_xaf'),
    Column.text('speciality'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('teacher_subjects', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('staff_id'),
    Column.text('subject_id'),
    Column.text('class_id'),
    Column.text('academic_year_id'),
    Column.integer('weekly_hours'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('subjects', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('level_id'),
    Column.text('name'),
    Column.text('slug'),
    Column.integer('coefficient'),
    Column.integer('is_active'),
    Column.integer('display_order'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Programme par classe : coefficient EFFECTIF (override) + volume horaire
  // d'une matière dans une classe donnée. coefficient NULL = hérite du niveau.
  Table('class_subjects', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('class_id'),
    Column.text('subject_id'),
    Column.integer('coefficient'),
    Column.integer('weekly_hours'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Programme pédagogique / syllabus d'une matière à un niveau (optionnellement
  // par trimestre) : titre + contenu, officiel ou personnalisé.
  Table('school_programs', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('level_id'),
    Column.text('subject_id'),
    Column.text('academic_year_id'),
    Column.text('trimester_id'),
    Column.text('title'),
    Column.text('content'),
    Column.integer('is_official'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // PHASE 3 — QUOTIDIEN
  // ════════════════════════════════════════════════════════════════════════

  // Registre des salles typées (remplace le `room` texte libre).
  Table('rooms', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('code'),
    Column.text('name'),
    Column.text('room_type'),
    Column.integer('capacity'),
    Column.text('building'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Trame horaire configurable par école/cycle (remplace kStdPeriods codé en dur).
  Table('school_periods', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('cycle_code'),    // NULL = tous cycles
    Column.text('label'),
    Column.integer('period_index'),
    Column.text('kind'),          // cours|recreation|pause_meridienne
    Column.text('start_time'),
    Column.text('end_time'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Disponibilités / indispos / préférences enseignant.
  Table('teacher_availability', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('staff_id'),
    Column.text('academic_year_id'),
    Column.integer('day_of_week'),
    Column.text('start_time'),
    Column.text('end_time'),
    Column.text('status'),        // unavailable|preference_against|preference_for
    Column.text('note'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Version d'EDT = cycle de vie (brouillon→…→publié→archivé) + publication.
  Table('timetable_versions', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('academic_year_id'),
    Column.text('trimester_id'),
    Column.text('label'),
    Column.text('status'),
    Column.integer('is_active'),
    Column.text('published_at'),
    Column.text('validated_by'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Calendrier scolaire : jours non ouvrés (vacances + fériés) → projection de
  // la trame hebdomadaire sur le calendrier réel (vues mois/trimestre/annuel).
  Table('school_holidays', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('academic_year_id'),
    Column.text('label'),
    Column.text('kind'),          // ferie | vacances
    Column.text('start_date'),
    Column.text('end_date'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Journal d'audit (synchro offline LIMITÉE aux tables EDT par les sync-rules)
  // → historique « qui a modifié quoi, quand » de l'emploi du temps.
  Table('audit_logs', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('user_id'),
    Column.text('user_role'),
    Column.text('action'),       // INSERT | UPDATE | DELETE
    Column.text('table_name'),
    Column.text('record_id'),
    Column.text('old_values'),   // jsonb (texte côté SQLite)
    Column.text('new_values'),
    Column.text('created_at'),
  ]),

  // Exceptions ponctuelles à la trame (à une date précise) : séance annulée /
  // déplacée / exceptionnelle. Rend exactes les vues calendaires projetées.
  Table('timetable_exceptions', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('academic_year_id'),
    Column.text('slot_id'),        // NULL si 'extra'
    Column.text('exception_date'),
    Column.text('kind'),           // cancelled | moved | extra
    Column.text('new_start_time'),
    Column.text('new_end_time'),
    Column.text('new_room_id'),
    Column.text('new_staff_id'),
    Column.text('new_subject_id'),
    Column.text('new_class_id'),
    Column.text('reason'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('timetable_slots', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('version_id'),       // → timetable_versions
    Column.text('class_id'),
    Column.text('subject_id'),
    Column.text('staff_id'),
    Column.text('academic_year_id'),
    Column.integer('day_of_week'),  // 1=lun … 7=dim
    Column.text('start_time'),
    Column.text('end_time'),
    Column.text('room'),            // legacy texte libre (transition)
    Column.text('room_id'),         // → rooms (référencé)
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('lesson_entries', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('class_id'),
    Column.text('subject_id'),
    Column.text('staff_id'),
    Column.text('academic_year_id'),
    Column.text('trimester_id'),
    Column.text('entry_date'),
    Column.text('lesson_title'),
    Column.text('content'),
    Column.text('objectives'),
    Column.text('homework'),
    Column.text('resources'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('attendance_records', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('class_id'),
    Column.text('subject_id'),
    Column.text('academic_year_id'),
    Column.text('record_date'),
    Column.text('period'),
    Column.text('recorded_by'),
    Column.integer('is_finalized'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('attendance_entries', [
    Column.text('attendance_record_id'),
    Column.text('student_id'),
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('status'),
    Column.text('arrival_time'),
    Column.text('justification'),
    Column.text('justification_doc_url'),
    Column.integer('parent_notified'),
    Column.text('notified_at'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // PHASE 4 — ÉVALUATION
  // ════════════════════════════════════════════════════════════════════════

  Table('evaluations', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('class_id'),
    Column.text('subject_id'),
    Column.text('academic_year_id'),
    Column.text('trimester_id'),
    Column.text('sequence_id'),
    Column.text('title'),
    Column.text('evaluation_type'),
    Column.text('evaluation_date'),
    Column.real('max_score'),
    Column.integer('coefficient'),
    Column.text('created_by'),
    Column.text('status'),
    Column.text('validated_by'),
    Column.text('validated_at'),
    Column.text('published_at'),
    Column.text('notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ⚠️ Schéma aligné sur la base LIVE (2026-06-09) : grade NORMALISÉ → relié à
  // l'évaluation par evaluation_id (l'année/trimestre/matière/classe vivent dans
  // `evaluations`). L'ancienne définition dénormalisée (evaluation_name/date/
  // trimester/class_id/subject_id/teacher_id/max_score/coefficient/status/
  // academic_year_id) NE CORRESPONDAIT PLUS à la table réelle → corrigée.
  Table('grades', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('evaluation_id'),
    Column.text('student_id'),
    Column.text('enrollment_id'),
    Column.real('score'),
    Column.integer('is_absent'),
    Column.text('appreciation'),
    Column.text('teacher_comment'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('competence_grades', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('evaluation_id'),
    Column.text('student_id'),
    Column.text('competence_name'),
    Column.text('level'),
    Column.text('teacher_comment'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('bulletins', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('student_id'),
    Column.text('enrollment_id'),
    Column.text('academic_year_id'),
    Column.text('trimester_id'),
    Column.real('overall_average'),
    Column.real('class_average'),
    Column.integer('rank'),
    Column.integer('total_students'),
    Column.text('mention'),
    Column.integer('total_absences'),
    Column.integer('total_lates'),
    Column.text('decision'),
    Column.text('teacher_comment'),
    Column.text('director_comment'),
    Column.text('status'),
    Column.text('submitted_by'),
    Column.text('submitted_at'),
    Column.text('validated_by'),
    Column.text('validated_at'),
    Column.text('published_at'),
    Column.text('pdf_url'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('bulletin_subject_lines', [
    Column.text('bulletin_id'),
    Column.text('subject_id'),
    Column.text('group_id'),
    Column.text('school_id'),
    Column.real('average'),
    Column.real('class_average'),
    Column.integer('rank'),
    Column.integer('coefficient'),
    Column.real('weighted_average'),
    Column.text('appreciation'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // PHASE 5 — FINANCE
  // ════════════════════════════════════════════════════════════════════════

  Table('fee_structures', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('academic_year_id'),
    Column.text('name'),
    Column.text('fee_type'),
    Column.integer('amount_xaf'),
    Column.integer('due_day_of_month'),
    Column.text('applies_to_level_id'),
    // Niveau du RÉFÉRENTIEL PARTAGÉ (migration 0101) : c'est ainsi que le
    // ministère tarifie « la 6e » pour tout son réseau. `applies_to_level_id`
    // ne désigne que le niveau d'UNE école et ne vaut que pour elle ; sans
    // cette colonne sur le poste, un tarif national par niveau arriverait
    // amputé de sa cible et serait réclamé à tous les élèves.
    Column.text('applies_to_education_level_id'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
      // Barème des frais d'UNE session d'examen précise. Cf. migration 0058.
    Column.text('exam_session_id'),
    // L'EXAMEN visé (migration 0103) — le ciblage courant. `exam_session_id`
    // désigne une instance annuelle : il n'a jamais été renseigné une seule
    // fois en production, parce qu'un ministère fixe ses frais AVANT d'ouvrir
    // la session. Le poste résout ici la session de son année scolaire ; sans
    // cette colonne, il ne trouverait aucun barème et la caisse de l'examen
    // resterait fermée.
    Column.text('applies_to_exam_id'),
    // Le texte qui fonde le tarif (arrêté, note de service, délibération
    // d'assemblée APE). Un montant sans texte fondateur n'est pas un tarif,
    // c'est un chiffre. Cf. migration 0096.
    Column.text('source_reference'),
  ]),

  // api_key et api_secret exclus intentionnellement (données sensibles)
  Table('payment_configs', [
    Column.text('group_id'),
    Column.text('provider'),
    Column.text('display_name'),
    Column.text('merchant_id'),
    Column.text('webhook_url'),
    Column.integer('is_active'),
    Column.integer('is_test_mode'),
    Column.text('configured_by'),
    Column.text('configured_at'),
    Column.text('notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('student_payments', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('student_id'),
    Column.text('enrollment_id'),
    Column.text('fee_structure_id'),
    // ⚠️ INTEGER, jamais `real` — et c'est un piège qui a coûté de l'argent.
    // `student_payments.amount_xaf` est un `integer` côté Postgres (le franc
    // CFA n'a pas de subdivision). Déclarée `real` ici, la colonne locale
    // stockait 10000.0 ; le connecteur l'envoyait tel quel et Postgres
    // refusait — « invalid input syntax for type integer: "10000.0" », code
    // 22P02. PowerSync ABANDONNE alors la transaction ENTIÈRE : le paiement
    // était perdu, et avec lui toutes les écritures du même lot.
    // Le type local doit suivre le type serveur pour toute colonne numérique.
    Column.integer('amount_xaf'),
    Column.text('payment_date'),
    Column.integer('period_month'),
    Column.integer('period_year'),
    Column.text('payment_method'),
    Column.text('transaction_reference'),
    Column.text('receipt_number'),
    Column.text('recorded_by'),
    Column.text('status'),
    Column.text('notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
    // ⚠️ NOT NULL en base (migration 0095). Une écriture locale sans année
    // ferait rejeter le lot ENTIER (23502) et perdrait le paiement.
    Column.text('academic_year_id'),
    // ── Annulation et remboursement (migration 0094) ─────────────────────────
    // Un paiement ne se supprime plus : il s'annule, et l'annulation porte son
    // auteur et son motif. Ces colonnes descendent par le `SELECT *` du bucket
    // by_school — aucune modification de sync-rules n'est requise.
    Column.text('cancelled_at'),
    Column.text('cancelled_by'),
    Column.text('cancellation_reason'),
    // ⚠️ `integer` local pour un `integer` serveur : un `real` ferait rejeter
    // le lot ENTIER (22P02) et perdrait le paiement, comme pour `amount_xaf`.
    Column.integer('refunded_amount_xaf'),
    Column.text('refunded_at'),
    Column.text('refunded_by'),
    Column.text('refund_reason'),
  ]),

  Table('budget_lines', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('academic_year_id'),
    Column.text('category'),
    Column.integer('budgeted_amount_xaf'),
    Column.integer('actual_amount_xaf'),
    Column.text('notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('expenses', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('academic_year_id'),
    Column.text('title'),
    Column.text('description'),
    Column.integer('amount_xaf'),
    Column.text('expense_date'),
    Column.text('category'),
    Column.text('approved_by'),
    Column.text('receipt_url'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('payroll', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('staff_id'),
    Column.integer('period_month'),
    Column.integer('period_year'),
    Column.integer('base_salary_xaf'),
    Column.integer('bonuses_xaf'),
    Column.integer('deductions_xaf'),
    Column.integer('net_salary_xaf'),
    Column.text('payment_date'),
    Column.text('payment_method'),
    Column.text('payment_reference'),
    Column.text('status'),
    Column.text('notes'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // PHASE 6 — VIE SCOLAIRE
  // ════════════════════════════════════════════════════════════════════════

  Table('discipline_incidents', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('student_id'),
    Column.text('academic_year_id'),
    Column.text('incident_date'),
    Column.text('description'),
    Column.text('incident_type'),
    Column.text('sanction'),
    Column.text('sanction_date'),
    Column.text('reported_by'),
    Column.integer('parent_notified'),
    Column.text('notified_at'),
    Column.text('follow_up_notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('infirmary_visits', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('student_id'),
    // Ajoutee par la migration 0132. Sans elle, le journal cumulait toutes
    // les promotions et la classe du passage ne pouvait pas etre celle du
    // jour des faits.
    Column.text('academic_year_id'),
    Column.text('visit_date'),
    Column.text('visit_time'),
    Column.text('symptoms'),
    Column.text('diagnosis'),
    Column.text('treatment'),
    Column.text('medication'),
    Column.integer('rest_period_hours'),
    Column.integer('parent_notified'),
    Column.text('notified_at'),
    Column.text('staff_id'),
    Column.integer('follow_up_required'),
    Column.text('follow_up_notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('canteen_records', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('student_id'),
    Column.text('record_date'),
    Column.text('meal_type'),
    Column.integer('is_present'),
    Column.text('notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('library_items', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('title'),
    Column.text('author'),
    Column.text('isbn'),
    Column.text('category'),
    Column.integer('quantity'),
    Column.integer('available_quantity'),
    Column.text('location'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('library_loans', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('item_id'),
    Column.text('borrower_id'),
    Column.text('borrow_date'),
    Column.text('due_date'),
    Column.text('return_date'),
    Column.text('status'),
    Column.text('notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // PHASE 7 — COMMUNICATION
  // ════════════════════════════════════════════════════════════════════════

  Table('announcements', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('title'),
    Column.text('content'),
    Column.text('target_audience'),
    Column.integer('is_pinned'),
    Column.integer('is_published'),
    Column.integer('is_archived'), // REQUIS : setAnnouncementArchivedLocal fait
                                   // un UPDATE local dessus → sans cette colonne,
                                   // « no such column » au 1er archivage offline.
    Column.text('published_at'),
    Column.text('expires_at'),
    Column.text('attachments'), // jsonb [{name,url,mime,size,kind}] en TEXT
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('events', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('title'),
    Column.text('description'),
    Column.text('event_date'),
    Column.text('end_date'),
    Column.text('start_time'),
    Column.text('end_time'),
    Column.text('location'),
    Column.text('target_audience'),
    Column.integer('is_published'),
    Column.text('attachments'), // jsonb [{name,url,mime,size,kind}] en TEXT
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Réactions aux annonces (like/love/clap — 1 par utilisateur par annonce)
  Table('announcement_reactions', [
    Column.text('announcement_id'),
    Column.text('user_id'),
    Column.text('group_id'),
    Column.text('reaction'),
    Column.text('created_at'),
  ]),

  // Commentaires sur annonces (avec support de réponses imbriquées via parent_id)
  Table('announcement_comments', [
    Column.text('announcement_id'),
    Column.text('author_id'),
    Column.text('group_id'),
    Column.text('content'),
    Column.text('parent_id'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Annonces enregistrées ("bookmarks") — 1 par utilisateur par annonce
  Table('saved_announcements', [
    Column.text('announcement_id'),
    Column.text('user_id'),
    Column.text('group_id'),
    Column.text('created_at'),
  ]),

  // Stories éphémères 24h (type WhatsApp) — image/vidéo/texte, scope-aware
  Table('stories', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('author_id'),
    Column.text('media_url'),
    Column.text('media_type'),     // image | video | text
    Column.text('caption'),
    Column.text('text_content'),
    Column.text('bg_color'),
    Column.text('created_at'),
    Column.text('expires_at'),
  ]),

  // Vues de stories (« vu par ») — 1 par viewer par story
  Table('story_views', [
    Column.text('story_id'),
    Column.text('group_id'),
    Column.text('viewer_id'),
    Column.text('viewed_at'),
  ]),

  // Messages privés (sender ↔ recipient) OU de groupe (conversation_id)
  Table('messages', [
    Column.text('group_id'),
    Column.text('sender_id'),
    Column.text('recipient_id'),
    Column.text('conversation_id'),   // groupe : lien vers conversations
    Column.text('subject'),
    Column.text('body'),
    Column.integer('is_read'),
    Column.text('read_at'),
    Column.text('parent_message_id'),
    Column.integer('is_archived'),
    Column.text('attachments'), // jsonb [{name,url,mime,size,kind}] en TEXT
    Column.text('reactions'),   // jsonb { "👍": ["uid",...] } en TEXT
    Column.text('edited_at'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Conversations de groupe (chat multi-membres)
  Table('conversations', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('title'),
    Column.integer('is_group'),
    Column.text('avatar_url'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Membres d'une conversation de groupe
  Table('conversation_members', [
    Column.text('conversation_id'),
    Column.text('user_id'),
    Column.text('group_id'),
    Column.text('role'),          // member | admin
    Column.text('joined_at'),
    Column.text('last_read_at'),
  ]),

  // Notifications de l'application (jsonb data stocké en TEXT).
  // C'est LE canal : alimentée par les déclencheurs `notify_on_announcement` /
  // `notify_on_message`, synchronisée par PowerSync, lue par la cloche de
  // l'en-tête. Elle fonctionne hors ligne et sur les quatre cibles — aucun
  // fournisseur de push n'intervient (décision du 2026-08-29 : Supabase seul).
  // `fcm_message_id` n'est volontairement PAS déclarée ici : voir migration 0146.
  Table('notifications', [
    Column.text('group_id'),
    Column.text('recipient_id'),
    Column.text('type'),
    Column.text('title'),
    Column.text('body'),
    Column.text('data'),          // jsonb → stocké comme TEXT
    Column.integer('is_read'),
    Column.text('read_at'),
    Column.text('sent_at'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Demandes au support plateforme (sync-rules : uniquement les siennes)
  Table('support_tickets', [
    Column.text('group_id'),
    Column.text('submitted_by'),
    Column.text('subject'),
    Column.text('body'),
    Column.text('category'),
    Column.text('status'),
    Column.text('priority'),
    Column.text('assigned_to'),
    Column.text('resolved_at'),
    Column.text('response'),
    Column.text('attachment_url'),
    Column.text('attachments'), // jsonb [{name,url,mime,size,kind}] en TEXT
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Fil de conversation par ticket (chat support temps réel).
  // ticket_owner_id dénormalisé pour le bucket by_user (pas de JOIN en sync-rules).
  Table('support_ticket_messages', [
    Column.text('ticket_id'),
    Column.text('group_id'),
    Column.text('ticket_owner_id'),
    Column.text('author_id'),
    Column.text('body'),
    Column.integer('is_from_support'),
    Column.text('attachments'), // jsonb [{name,url,mime,size,kind}] en TEXT
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // PHASE 8 — DOCUMENTS & MOBILITÉ
  // ════════════════════════════════════════════════════════════════════════

  Table('student_documents', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('student_id'),
    Column.text('document_type'),
    Column.text('document_name'),
    Column.text('file_url'),
    // NULL = pièce de l'élève (réutilisable à chaque candidature) ; renseigné =
    // pièce propre à CETTE candidature d'examen. Cf. migration 0056.
    Column.text('exam_candidate_id'),
    // Idem pour un stage : convention signée, fiche d'évaluation du tuteur.
    // Cf. migration 0057.
    Column.text('internship_id'),
    Column.integer('is_verified'),
    Column.text('verified_by'),
    Column.text('verified_at'),
    Column.text('expiry_date'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ── Registre des documents DÉLIVRÉS (migration 0149) ─────────────────────
  //  Ne pas confondre avec `student_documents`, qui suit les pièces que
  //  l'école REÇOIT. Celle-ci note les papiers qu'elle ÉMET : certificat de
  //  scolarité, radiation, carte scolaire, attestation de travail.
  //
  //  ⚠️ Aucune colonne pour le PDF, et il n'en faut pas : le registre note
  //  l'ACTE. Entreposer chaque certificat, ce serait des milliers de pièces
  //  portant identité, date de naissance et adresse d'enfants, sur le disque
  //  de chaque poste de l'école.
  //
  //  ⚠️ La table est IMMUABLE côté serveur (trigger `RETURN OLD`) : un rejeu
  //  de lot après coupure passe sans erreur et ne change rien. Ne jamais
  //  écrire d'UPDATE dessus depuis le client — ce serait sans effet, donc un
  //  mensonge à l'écran.
  Table('issued_documents', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('academic_year_id'),
    Column.text('document_type'),
    Column.text('student_id'),
    Column.text('staff_profile_id'),
    // Figés à l'émission : un registre doit dire ce qui a été écrit ce
    // jour-là, pas ce que la base contient aujourd'hui.
    Column.text('recipient_name'),
    Column.text('recipient_ref'),
    Column.text('issued_by'),
    Column.text('issued_by_name'),
    Column.text('issued_at'),
    Column.text('purpose'),
    Column.text('created_at'),
  ]),

  Table('student_orientations', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('student_id'),
    Column.text('academic_year_id'),
    Column.text('trimester_id'),
    Column.text('recommendation'),
    Column.text('target_level'),
    Column.text('target_filiere'),
    Column.text('counselor_id'),
    Column.integer('parent_consulted'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('student_transfers', [
    Column.text('group_id'),
    Column.text('student_id'),
    Column.text('from_school_id'),
    Column.text('to_school_id'),
    Column.text('to_school_name'),
    Column.text('transfer_date'),
    Column.text('reason'),
    Column.text('status'),
    Column.text('approved_by'),
    Column.text('approved_at'),
    Column.text('academic_year_id'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('leave_requests', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('staff_id'),
    Column.text('leave_type'),
    Column.text('start_date'),
    Column.text('end_date'),
    Column.integer('days_count'),
    Column.text('reason'),
    Column.text('status'),
    Column.text('reviewed_by'),
    Column.text('reviewed_at'),
    Column.text('rejection_reason'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ── RH : pointage quotidien des agents (staff_id -> profiles.id) ───────────
  Table('staff_attendance', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('staff_id'),
    Column.text('record_date'),
    Column.text('status'),
    Column.text('arrival_time'),
    Column.text('departure_time'),
    Column.text('notes'),
    Column.text('recorded_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ── RH : parcours professionnel de l'agent (migration 0023) ───────────────
  Table('staff_career', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('profile_id'),
    Column.text('position'),
    Column.text('organization'),
    Column.text('start_date'),
    Column.text('end_date'),
    Column.integer('is_current'),
    Column.text('notes'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ── RH : diplômes & qualifications de l'agent (migration 0023) ────────────
  Table('staff_diplomas', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('profile_id'),
    Column.text('title'),
    Column.text('level'),
    Column.text('field'),
    Column.text('institution'),
    Column.integer('year_obtained'),
    Column.text('file_url'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // JOURNAL LOCAL D'ÉCHECS DE SYNCHRO (local-only, ne remonte JAMAIS au serveur)
  // ════════════════════════════════════════════════════════════════════════
  // Trace des transactions rejetées DÉFINITIVEMENT par le serveur (contrainte,
  // RLS, données invalides) puis abandonnées → écritures locales perdues.
  // `localOnly` = jamais uploadée, aucun impact sync-rules/prod ; sert à rendre
  // la perte VISIBLE et ACQUITTABLE par l'utilisateur (défense en profondeur).
  Table.localOnly('sync_failures', [
    Column.text('at'),           // ISO-8601 UTC du rejet
    Column.text('code'),         // code PostgreSQL (ex. 23502, 42501)
    Column.text('message'),      // message serveur brut
    Column.text('ops'),          // JSON des opérations perdues
    Column.text('summary'),      // libellé lisible (ex. « Inscription d'élève »)
    Column.integer('acknowledged'), // 0 = à voir, 1 = acquitté par l'utilisateur
  ]),

  // ── File d'attente d'envoi de fichiers (local-only) ────────────────────────
  // PowerSync met en file les écritures SQL, mais PAS les fichiers : Supabase
  // Storage exige le réseau. Sans cela, joindre une photo hors-ligne faisait
  // échouer l'envoi ENTIER du message (le texte partait pourtant très bien).
  // Ici : les octets sont écrits sur le disque, le chemin Storage est calculé
  // en local (UUID, aucun réseau) et le message référence ce chemin tout de
  // suite. Le fichier est téléversé au retour du réseau, à ce chemin exact.
  // ════════════════════════════════════════════════════════════════════════
  // EXAMENS D'ÉTAT (migrations 0044→0046)
  // ════════════════════════════════════════════════════════════════════════
  // Référentiel NATIONAL (national_exams / rules / sessions / centers) : diffusé
  // à TOUS les appareils — il ne contient aucune donnée d'élève, il est petit et
  // il doit rester lisible hors ligne (une école doit savoir quel examen prépare
  // sa classe même sans réseau).
  // exam_candidates, lui, est filtré par école : c'est de la donnée nominative.

  Table('national_exams', [
    Column.text('code'),          // CEPE | BEPC | BET | BAC_G | ...
    Column.text('name'),
    Column.text('short_name'),
    Column.text('tutelle'),       // mepsa | metp
    Column.text('cycle_code'),
    Column.text('kind'),          // diplome | concours
    Column.real('min_average'),
    Column.integer('order_index'),
    Column.integer('is_active'),
  ]),

  // Règles « quelle classe prépare quel examen ». Synchronisées pour AFFICHAGE
  // et traçabilité (« pourquoi cet examen ? ») — la résolution reste serveur.
  Table('exam_eligibility_rules', [
    Column.text('exam_id'),
    Column.text('cycle_code'),
    Column.text('level_code'),
    Column.text('program_code'),
    Column.text('tutelle'),
    Column.text('valid_from'),
    Column.text('valid_to'),
    Column.text('group_id'),
    Column.text('note'),
    Column.integer('is_active'),
  ]),

  Table('exam_sessions', [
    Column.text('exam_id'),
    Column.text('year_label'),
    Column.text('registration_opens_at'),
    Column.text('registration_closes_at'),
    Column.text('written_from'),
    Column.text('written_to'),
    Column.text('practical_from'),
    Column.text('practical_to'),
    Column.text('results_published_at'),
    Column.integer('max_age'),
    Column.text('age_reference_date'),
    Column.real('fee_amount'),
    Column.text('required_documents'), // jsonb -> texte JSON côté SQLite
    Column.text('status'),
    Column.text('notes'),
  ]),

  Table('exam_centers', [
    Column.text('code'),
    Column.text('name'),
    Column.text('department_id'),
    Column.text('school_id'),
    Column.text('tutelle'),
    Column.integer('capacity'),
    Column.real('latitude'),
    Column.real('longitude'),
    Column.integer('is_active'),
  ]),

  // Candidatures — écrites hors ligne par l'école, remontées à la reconnexion.
  Table('exam_candidates', [
    Column.text('session_id'),
    Column.text('student_id'),
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('class_id'),
    // ── Champs ENTRANTS : la DEC les décide, nous ne faisons que les recevoir.
    Column.text('candidate_number'),   // attribué par la DEC — ne jamais générer
    Column.text('center_id'),          // affecté par la DEC — ne jamais décider
    Column.text('dossier_status'),     // incomplet | complet | depose | valide | rejete
    Column.text('missing_documents'),  // jsonb -> texte JSON
    Column.integer('is_repeater'),
    Column.text('registered_at'),
    Column.text('submitted_at'),
    Column.text('result'),             // admis | ajourne | absent | fraude | en_attente
    Column.real('average'),
    Column.text('mention'),
    // Deux horloges à ne pas confondre (migration 0053) :
    Column.text('decided_at'),          // PROCLAMATION par la DEC (leur horloge)
    Column.text('result_received_at'),  // RÉCEPTION chez nous (notre horloge)
    Column.text('result_source'),       // saisie_manuelle | import_csv | api_dec
    Column.text('result_recorded_by'),
    Column.text('notes'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ── TRANSMISSIONS (migration 0054) — dépôt OPPOSABLE à la DEC ──────────────
  // Ce que l'école a DÉCLARÉ, et quand. Écrit hors ligne, figé à la soumission.
  // `snapshot`/`payload` = jsonb -> texte JSON. `reference` est un libellé
  // humain (PAS une clé d'unicité serveur : cf. migration 0054).
  Table('transmissions', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('kind'),
    Column.text('recipient'),
    Column.text('session_id'),
    Column.text('reference'),
    Column.text('status'),
    Column.text('channel'),
    Column.text('snapshot'),        // jsonb -> texte : la liste TELLE QUE DÉPOSÉE
    Column.integer('item_count'),
    Column.text('transmitted_at'),
    Column.text('transmitted_by'),
    Column.text('acknowledged_at'),
    Column.text('acknowledgment_ref'),
    Column.text('corrects_id'),
    Column.text('notes'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('transmission_items', [
    Column.text('transmission_id'),
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('candidate_id'),
    Column.text('student_id'),
    Column.text('local_ref'),
    Column.integer('lot_number'),   // le lot (~50) est À L'INTÉRIEUR d'une classe
    Column.integer('position'),
    Column.text('payload'),         // jsonb -> texte : nom, matricule, classe…
    Column.text('created_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // STAGES (migration 0048) — dépendance DURE du bac professionnel :
  // l'attestation de stage est une pièce obligatoire du dossier d'examen.
  // ════════════════════════════════════════════════════════════════════════

  Table('internship_companies', [
    Column.text('group_id'),
    Column.text('school_id'),      // NULL = entreprise partagée au groupe
    Column.text('name'),
    Column.text('sector'),
    Column.text('address'),
    Column.text('city'),
    Column.text('department_id'),
    Column.text('contact_name'),
    Column.text('contact_phone'),
    Column.text('contact_email'),
    Column.text('notes'),
    Column.integer('is_active'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('internships', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('student_id'),
    Column.text('class_id'),
    Column.text('academic_year_id'),
    Column.text('company_id'),
    Column.text('title'),
    Column.text('start_date'),
    Column.text('end_date'),
    Column.text('school_tutor_id'),
    Column.text('company_tutor_name'),
    Column.text('company_tutor_phone'),
    Column.text('convention_signed_at'),
    Column.text('convention_url'),
    Column.text('status'),          // prevu | en_cours | termine | interrompu | valide
    Column.text('attestation_issued_at'),
    Column.text('attestation_url'),
    Column.real('evaluation_grade'),
    Column.text('evaluation_comment'),
    Column.text('notes'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Référentiel territorial (0043) — 15 départements, national.
  Table('departments', [
    Column.text('code'),
    Column.text('name'),
    Column.text('chef_lieu'),
    Column.integer('order_index'),
    Column.integer('is_active'),
  ]),

  Table.localOnly('upload_outbox', [
    Column.text('bucket'),      // bucket Storage cible
    Column.text('storage_path'),// chemin définitif ({groupId}/{uuid}_{nom})
    Column.text('local_path'),  // fichier sur le disque, en attente
    Column.text('mime'),
    Column.text('file_name'),
    Column.integer('size'),
    Column.text('created_at'),  // ISO-8601 UTC
    Column.integer('attempts'), // tentatives d'envoi
    Column.text('last_error'),  // dernier échec (diagnostic)
  ]),
]);
