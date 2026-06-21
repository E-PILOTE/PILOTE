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
    Column.integer('is_active'),
    Column.text('last_login'),
    Column.text('fcm_token'),
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

  Table('classes', [
    Column.text('name'),
    Column.integer('capacity'),
    Column.text('main_teacher_id'),
    Column.text('room'),
    Column.text('level_id'),
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
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // ════════════════════════════════════════════════════════════════════════
  // PHASE 2 — ACTEURS
  // ════════════════════════════════════════════════════════════════════════

  Table('students', [
    Column.text('matricule'),
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

  Table('staff_members', [
    Column.text('group_id'),
    Column.text('school_id'),
    // ⚠️ profile_id N'EXISTE PAS encore en base LIVE (audit 2026-06-21). Conservé
    // ici car myStaffIdProvider le LIT (renvoie null tant que non peuplé) — le
    // retirer ferait crasher cette requête. NE RIEN ÉCRIRE dessus (échec upload
    // silencieux). À matérialiser en Phase 5 (Paie) : ALTER TABLE en prod + FK.
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

  // ════════════════════════════════════════════════════════════════════════
  // PHASE 3 — QUOTIDIEN
  // ════════════════════════════════════════════════════════════════════════

  Table('timetable_slots', [
    Column.text('group_id'),
    Column.text('school_id'),
    Column.text('class_id'),
    Column.text('subject_id'),
    Column.text('staff_id'),
    Column.text('academic_year_id'),
    Column.integer('day_of_week'),  // 1=lun … 7=dim
    Column.text('start_time'),
    Column.text('end_time'),
    Column.text('room'),
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
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
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
    Column.real('amount_xaf'),
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

  // Notifications push (jsonb data stocké en TEXT)
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
    Column.text('fcm_message_id'),
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
    Column.integer('is_verified'),
    Column.text('verified_by'),
    Column.text('verified_at'),
    Column.text('expiry_date'),
    Column.text('created_at'),
    Column.text('updated_at'),
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
]);
