-- ================================================================
-- E-PILOTE CONGO v3.0 — Schéma Base de Données PostgreSQL
-- Stack : Supabase (PostgreSQL 15) + PowerSync + Flutter
-- Généré le : 25 mai 2026
-- ================================================================
-- Architecture : Multi-tenant SaaS
--   • Niveau 1 : SUPER_ADMIN      → accès global plateforme
--   • Niveau 2 : ADMIN_GROUPE     → tenant (group_id)
--   • Niveau 3 : UTILISATEURS     → école (school_id)
-- Isolation   : TenantGuard via RLS (group_id + school_id)
-- Offline     : PowerSync — toutes les tables ont updated_at
-- ================================================================

-- ================================================================
-- EXTENSIONS
-- ================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- recherche full-text

-- ================================================================
-- TYPES ÉNUMÉRÉS
-- ================================================================

CREATE TYPE user_role AS ENUM (
  'super_admin',
  'admin_groupe',
  'directeur',
  'proviseur',
  'enseignant',
  'cpe',
  'comptable',
  'secretaire',
  'surveillant',
  'parent',
  'eleve',
  'infirmier',
  'responsable_cantine'
);

CREATE TYPE plan_slug AS ENUM (
  'gratuit',
  'premium',
  'pro',
  'institutionnel'
);

CREATE TYPE subscription_status AS ENUM (
  'trial',
  'active',
  'suspended',
  'expired',
  'cancelled'
);

CREATE TYPE group_type AS ENUM (
  'public',
  'prive'
);

CREATE TYPE gender AS ENUM ('M', 'F');

CREATE TYPE notation_type AS ENUM (
  'competences',        -- Maternelle : Acquis / En cours / Non acquis
  'numeric_no_coef',    -- Primaire : /20 sans coefficient
  'numeric_with_coef'   -- Collège + Lycée : /20 avec coefficient
);

CREATE TYPE enrollment_status AS ENUM (
  'active',
  'transferred',
  'withdrawn',
  'graduated'
);

CREATE TYPE payment_method AS ENUM (
  'mtn_money',
  'airtel_money',
  'visa',
  'especes'
);

CREATE TYPE payment_status AS ENUM (
  'pending',
  'confirmed',
  'cancelled',
  'refunded'
);

CREATE TYPE invoice_status AS ENUM (
  'pending',
  'paid',
  'overdue',
  'cancelled'
);

CREATE TYPE attendance_status AS ENUM (
  'present',
  'absent',
  'late'
);

CREATE TYPE session_period AS ENUM ('AM', 'PM');

CREATE TYPE evaluation_type AS ENUM (
  'composition',
  'devoir_surveille',
  'sequence',
  'examen',
  'controle'
);

CREATE TYPE evaluation_status AS ENUM (
  'draft',      -- brouillon (visible enseignant seul)
  'submitted',  -- soumis au directeur
  'validated',  -- validé par directeur
  'published'   -- publié (parents/élèves voient)
);

CREATE TYPE bulletin_status AS ENUM (
  'draft',
  'submitted',
  'validated',
  'published'
);

CREATE TYPE transfer_status AS ENUM (
  'pending',
  'approved',
  'rejected',
  'completed'
);

CREATE TYPE leave_status AS ENUM (
  'pending',
  'approved',
  'rejected',
  'cancelled'
);

CREATE TYPE fee_type AS ENUM (
  'inscription',
  'mensualite',
  'frais_examens',
  'autre'
);

CREATE TYPE data_scope AS ENUM (
  'own_classes',  -- l'enseignant ne voit que ses classes
  'own_school'    -- accès à toute l'école
);

CREATE TYPE contract_type AS ENUM (
  'permanent',
  'contractuel',
  'vacataire',
  'stagiaire'
);

CREATE TYPE competence_level AS ENUM (
  'acquis',
  'en_cours',
  'non_acquis'
);

-- ================================================================
-- FONCTION GLOBALE : mise à jour automatique de updated_at
-- ================================================================
CREATE OR REPLACE FUNCTION fn_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Macro helper pour créer le trigger sur une table
CREATE OR REPLACE FUNCTION create_updated_at_trigger(tbl TEXT)
RETURNS VOID AS $$
BEGIN
  EXECUTE format(
    'CREATE OR REPLACE TRIGGER trg_%s_updated_at
     BEFORE UPDATE ON %I
     FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at()',
    tbl, tbl
  );
END;
$$ LANGUAGE plpgsql;


-- ================================================================
-- ▌BLOC 1 — PLATEFORME GLOBALE (Super Admin)
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : subscription_plans
-- Plans tarifaires gérés par le SUPER_ADMIN
-- ────────────────────────────────────────────────────────────────
CREATE TABLE subscription_plans (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name              VARCHAR(50) NOT NULL,             -- "Premium"
  slug              plan_slug   NOT NULL UNIQUE,      -- 'premium'
  price_xaf         INTEGER     NOT NULL DEFAULT 0,   -- 0 = gratuit
  max_schools       INTEGER     NOT NULL DEFAULT 1,   -- -1 = illimité
  max_students      INTEGER     NOT NULL DEFAULT 100, -- -1 = illimité
  max_staff         INTEGER     NOT NULL DEFAULT 10,  -- -1 = illimité
  module_count      SMALLINT    NOT NULL DEFAULT 8,
  description       TEXT,
  is_public_plan    BOOLEAN     NOT NULL DEFAULT FALSE, -- TRUE = institutionnel (État)
  is_active         BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('subscription_plans');

-- ────────────────────────────────────────────────────────────────
-- TABLE : module_categories
-- 8 catégories fonctionnelles
-- ────────────────────────────────────────────────────────────────
CREATE TABLE module_categories (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name          VARCHAR(100) NOT NULL,         -- "SCOLARISATION"
  slug          VARCHAR(50)  NOT NULL UNIQUE,  -- "scolarisation"
  icon          VARCHAR(10),                   -- "🎓"
  display_order SMALLINT     NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('module_categories');

-- ────────────────────────────────────────────────────────────────
-- TABLE : modules
-- 38 modules au total
-- ────────────────────────────────────────────────────────────────
CREATE TABLE modules (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id   UUID         NOT NULL REFERENCES module_categories(id),
  name          VARCHAR(100) NOT NULL,          -- "Notes & Évaluations"
  slug          VARCHAR(50)  NOT NULL UNIQUE,   -- "notes"
  description   TEXT,
  icon          VARCHAR(10),
  display_order SMALLINT     NOT NULL DEFAULT 0,
  is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('modules');

-- ────────────────────────────────────────────────────────────────
-- TABLE : plan_modules
-- Association Plan ↔ Modules (configurée par SUPER_ADMIN)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE plan_modules (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id     UUID        NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
  module_id   UUID        NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (plan_id, module_id)
);
SELECT create_updated_at_trigger('plan_modules');


-- ================================================================
-- ▌BLOC 2 — GROUPES SCOLAIRES (Tenants)
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : school_groups
-- Racine tenant — créé par SUPER_ADMIN
-- ────────────────────────────────────────────────────────────────
CREATE TABLE school_groups (
  id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  name                  VARCHAR(200) NOT NULL,          -- "Réseau Scolaire Saint-Pierre"
  slug                  VARCHAR(100) UNIQUE,
  group_type            group_type   NOT NULL DEFAULT 'prive',
  department            VARCHAR(100),                   -- "Brazzaville"
  plan_id               UUID         NOT NULL REFERENCES subscription_plans(id),
  subscription_status   subscription_status NOT NULL DEFAULT 'trial',
  subscription_start    DATE,
  subscription_end      DATE,
  admin_email           VARCHAR(255) NOT NULL,
  phone                 VARCHAR(30),
  address               TEXT,
  logo_url              TEXT,
  is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
  notes                 TEXT,                           -- notes internes super_admin
  created_by            UUID,                           -- auth.uid() du super_admin
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('school_groups');

-- ────────────────────────────────────────────────────────────────
-- TABLE : group_invoices
-- Factures créées par SUPER_ADMIN après paiement du groupe
-- C'est SEULEMENT après facture validée que les modules sont disponibles
-- ────────────────────────────────────────────────────────────────
CREATE TABLE group_invoices (
  id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id           UUID         NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  invoice_number     VARCHAR(50)  NOT NULL UNIQUE,  -- "INV-2026-001"
  amount_xaf         INTEGER      NOT NULL,
  period_start       DATE         NOT NULL,
  period_end         DATE         NOT NULL,
  plan_id            UUID         REFERENCES subscription_plans(id),
  status             invoice_status NOT NULL DEFAULT 'pending',
  paid_at            TIMESTAMPTZ,
  payment_method     payment_method,
  payment_reference  VARCHAR(100),
  notes              TEXT,
  created_by         UUID         NOT NULL,  -- super_admin user id
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('group_invoices');


-- ================================================================
-- ▌BLOC 3 — UTILISATEURS & PROFILS
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : profiles
-- Étend auth.users de Supabase — créé automatiquement à l'inscription
-- ────────────────────────────────────────────────────────────────
CREATE TABLE profiles (
  id                UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  group_id          UUID        REFERENCES school_groups(id),
  school_id         UUID,                                -- FK ajoutée après schools
  role              user_role   NOT NULL,
  access_profile_id UUID,                                -- FK ajoutée après access_profiles
  first_name        VARCHAR(100) NOT NULL,
  last_name         VARCHAR(100) NOT NULL,
  phone             VARCHAR(30),
  avatar_url        TEXT,
  employee_number   VARCHAR(30),                         -- N° matricule personnel
  is_active         BOOLEAN     NOT NULL DEFAULT TRUE,
  last_login        TIMESTAMPTZ,
  fcm_token         TEXT,                                -- token Firebase push notifications
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('profiles');

-- ────────────────────────────────────────────────────────────────
-- TABLE : schools
-- Écoles au sein d'un groupe scolaire — créées par ADMIN_GROUPE
-- ────────────────────────────────────────────────────────────────
-- Type école : public, privé ou mixte (établissements à gestion mixte)
CREATE TYPE school_type_enum AS ENUM ('public', 'prive', 'mixte');

CREATE TABLE schools (
  id              UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID             NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  name            VARCHAR(200)     NOT NULL,          -- "École Primaire Saint-Pierre de Bacongo"
  school_type     school_type_enum NOT NULL DEFAULT 'prive',
  school_code     VARCHAR(50)      UNIQUE,             -- Code officiel attribué par MEPSA/METP
  address         TEXT,
  city            VARCHAR(100),
  department      VARCHAR(100),                        -- département administratif
  province        VARCHAR(100),                        -- province (découpage géographique Congo)
  arrondissement  VARCHAR(100),
  email           VARCHAR(255),
  phone           VARCHAR(30),
  website         VARCHAR(255),
  founded_year    SMALLINT,                            -- année de fondation
  motto           VARCHAR(300),                        -- devise de l'école
  director_id     UUID             REFERENCES profiles(id),
  logo_url        TEXT,                                -- Supabase Storage URL
  is_active       BOOLEAN          NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('schools');

-- Ajout FK différées (après création des tables dépendantes)
ALTER TABLE profiles
  ADD CONSTRAINT fk_profiles_school
  FOREIGN KEY (school_id) REFERENCES schools(id);

-- ────────────────────────────────────────────────────────────────
-- TABLE : access_profiles
-- Profils d'accès créés par ADMIN_GROUPE
-- Définissent les permissions par module pour chaque rôle
-- ────────────────────────────────────────────────────────────────
CREATE TABLE access_profiles (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID         NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  name        VARCHAR(100) NOT NULL,     -- "Profil Directeur"
  description TEXT,
  is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
  created_by  UUID         REFERENCES profiles(id),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('access_profiles');

ALTER TABLE profiles
  ADD CONSTRAINT fk_profiles_access_profile
  FOREIGN KEY (access_profile_id) REFERENCES access_profiles(id);

-- ────────────────────────────────────────────────────────────────
-- TABLE : profile_permissions
-- Permissions granulaires par module pour chaque profil d'accès
-- ────────────────────────────────────────────────────────────────
CREATE TABLE profile_permissions (
  id          UUID       PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id  UUID       NOT NULL REFERENCES access_profiles(id) ON DELETE CASCADE,
  module_id   UUID       NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
  group_id    UUID       NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  can_read    BOOLEAN    NOT NULL DEFAULT FALSE,
  can_write   BOOLEAN    NOT NULL DEFAULT FALSE,
  can_delete  BOOLEAN    NOT NULL DEFAULT FALSE,
  can_export  BOOLEAN    NOT NULL DEFAULT FALSE,
  data_scope  data_scope NOT NULL DEFAULT 'own_school',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (profile_id, module_id)
);
SELECT create_updated_at_trigger('profile_permissions');

-- ────────────────────────────────────────────────────────────────
-- TABLE : staff_members
-- Infos RH complémentaires pour le personnel (au-delà du profil)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE staff_members (
  id              UUID          PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  group_id        UUID          NOT NULL REFERENCES school_groups(id),
  school_id       UUID          NOT NULL REFERENCES schools(id),
  job_title       VARCHAR(100),              -- "Professeur de Mathématiques"
  hire_date       DATE,
  contract_type   contract_type DEFAULT 'permanent',
  base_salary_xaf INTEGER       DEFAULT 0,
  iban            VARCHAR(50),
  speciality      VARCHAR(100),             -- matière principale
  is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('staff_members');


-- ================================================================
-- ▌BLOC 4 — NIVEAUX SCOLAIRES & CALENDRIER ACADÉMIQUE
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : school_levels
-- Niveaux scolaires personnalisables par groupe
-- Maternelle, Primaire, Collège, Lycée + niveaux custom
-- ────────────────────────────────────────────────────────────────
CREATE TABLE school_levels (
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id       UUID          NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  school_id      UUID          REFERENCES schools(id),  -- NULL = tout le groupe
  name           VARCHAR(100)  NOT NULL,     -- "Primaire", "Collège"
  slug           VARCHAR(50)   NOT NULL,     -- "primaire"
  notation_type  notation_type NOT NULL DEFAULT 'numeric_with_coef',
  display_order  SMALLINT      NOT NULL DEFAULT 0,
  is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE (group_id, slug)
);
SELECT create_updated_at_trigger('school_levels');

-- ────────────────────────────────────────────────────────────────
-- TABLE : academic_years
-- Années académiques — ex. "2026-2027"
-- CRITIQUE : toutes les données doivent être rattachées à une année
-- ────────────────────────────────────────────────────────────────
CREATE TABLE academic_years (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID        NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  school_id   UUID        REFERENCES schools(id),  -- NULL = toutes les écoles du groupe
  label       VARCHAR(20) NOT NULL,    -- "2026-2027"
  start_date  DATE        NOT NULL,    -- ex. 2026-09-01
  end_date    DATE        NOT NULL,    -- ex. 2027-07-31
  is_current  BOOLEAN     NOT NULL DEFAULT FALSE,
  is_locked   BOOLEAN     NOT NULL DEFAULT FALSE,  -- verrou fin d'année
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (group_id, school_id, label)
);
SELECT create_updated_at_trigger('academic_years');

-- ────────────────────────────────────────────────────────────────
-- TABLE : trimesters
-- 3 trimestres par année scolaire
-- ────────────────────────────────────────────────────────────────
CREATE TABLE trimesters (
  id                UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_year_id  UUID      NOT NULL REFERENCES academic_years(id) ON DELETE CASCADE,
  group_id          UUID      NOT NULL REFERENCES school_groups(id),
  school_id         UUID      REFERENCES schools(id),
  label             VARCHAR(50) NOT NULL,     -- "1er Trimestre"
  trimester_number  SMALLINT  NOT NULL CHECK (trimester_number IN (1,2,3)),
  start_date        DATE      NOT NULL,
  end_date          DATE      NOT NULL,
  is_current        BOOLEAN   NOT NULL DEFAULT FALSE,
  is_locked         BOOLEAN   NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (academic_year_id, trimester_number)
);
SELECT create_updated_at_trigger('trimesters');

-- ────────────────────────────────────────────────────────────────
-- TABLE : sequences
-- Mode séquentiel optionnel : 6 séquences/an (2 par trimestre)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE sequences (
  id                UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  trimester_id      UUID      NOT NULL REFERENCES trimesters(id) ON DELETE CASCADE,
  group_id          UUID      NOT NULL REFERENCES school_groups(id),
  school_id         UUID      REFERENCES schools(id),
  label             VARCHAR(50) NOT NULL,   -- "Séquence 1"
  sequence_number   SMALLINT  NOT NULL CHECK (sequence_number BETWEEN 1 AND 6),
  start_date        DATE      NOT NULL,
  end_date          DATE      NOT NULL,
  is_current        BOOLEAN   NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('sequences');


-- ================================================================
-- ▌BLOC 5 — ÉLÈVES & INSCRIPTIONS
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : students
-- Dossier élève — conservation 10 ans (règle métier)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE students (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     UUID         NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  school_id    UUID         NOT NULL REFERENCES schools(id),
  matricule    VARCHAR(30)  NOT NULL,           -- "2026-001"
  first_name   VARCHAR(100) NOT NULL,
  last_name    VARCHAR(100) NOT NULL,
  date_of_birth DATE        NOT NULL,
  gender       gender       NOT NULL,
  nationality  VARCHAR(100) DEFAULT 'Congolaise',
  blood_group  VARCHAR(10),
  allergies    TEXT,
  address      TEXT,
  city         VARCHAR(100),
  photo_url    TEXT,
  is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
  user_id      UUID         REFERENCES profiles(id),   -- si l'élève a accès à l'appli
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (group_id, matricule)
);
SELECT create_updated_at_trigger('students');

-- ────────────────────────────────────────────────────────────────
-- TABLE : student_tutors
-- Tuteurs légaux (père, mère, tuteur) de l'élève
-- ────────────────────────────────────────────────────────────────
CREATE TABLE student_tutors (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id        UUID         NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  group_id          UUID         NOT NULL REFERENCES school_groups(id),
  first_name        VARCHAR(100) NOT NULL,
  last_name         VARCHAR(100) NOT NULL,
  relationship      VARCHAR(50)  NOT NULL,   -- "pere", "mere", "tuteur", "autre"
  phone_primary     VARCHAR(30)  NOT NULL,
  phone_secondary   VARCHAR(30),
  email             VARCHAR(255),
  profession        VARCHAR(100),
  is_primary_contact BOOLEAN     NOT NULL DEFAULT FALSE,
  has_app_access    BOOLEAN      NOT NULL DEFAULT FALSE,
  user_id           UUID         REFERENCES profiles(id),  -- compte parent
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('student_tutors');

-- ────────────────────────────────────────────────────────────────
-- TABLE : classes
-- Classe scolaire par année (CE1-A, 6e-B, 2nde-A, ...)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE classes (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID        NOT NULL REFERENCES school_groups(id),
  school_id        UUID        NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  academic_year_id UUID        NOT NULL REFERENCES academic_years(id),
  level_id         UUID        REFERENCES school_levels(id),
  name             VARCHAR(50) NOT NULL,     -- "CE1-A", "6e-B", "2nde-STI"
  capacity         SMALLINT    NOT NULL DEFAULT 45,
  main_teacher_id  UUID        REFERENCES profiles(id),
  room             VARCHAR(50),
  is_active        BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (school_id, academic_year_id, name)
);
SELECT create_updated_at_trigger('classes');

-- ────────────────────────────────────────────────────────────────
-- TABLE : class_enrollments
-- Inscription d'un élève dans une classe pour une année scolaire
-- ────────────────────────────────────────────────────────────────
CREATE TABLE class_enrollments (
  id                UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id          UUID              NOT NULL REFERENCES school_groups(id),
  school_id         UUID              NOT NULL REFERENCES schools(id),
  student_id        UUID              NOT NULL REFERENCES students(id),
  class_id          UUID              NOT NULL REFERENCES classes(id),
  academic_year_id  UUID              NOT NULL REFERENCES academic_years(id),
  enrollment_date   DATE              NOT NULL DEFAULT CURRENT_DATE,
  status            enrollment_status NOT NULL DEFAULT 'active',
  is_repeating      BOOLEAN           NOT NULL DEFAULT FALSE,
  previous_class_id UUID              REFERENCES classes(id),
  withdrawal_date   DATE,
  withdrawal_reason TEXT,
  created_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  UNIQUE (student_id, academic_year_id)
);
SELECT create_updated_at_trigger('class_enrollments');

-- ────────────────────────────────────────────────────────────────
-- TABLE : student_documents
-- Pièces justificatives (acte de naissance, carnet vaccination, ...)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE student_documents (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id       UUID         NOT NULL REFERENCES school_groups(id),
  school_id      UUID         NOT NULL REFERENCES schools(id),
  student_id     UUID         NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  document_type  VARCHAR(100) NOT NULL,  -- "acte_naissance", "carnet_vaccination"
  document_name  VARCHAR(200) NOT NULL,
  file_url       TEXT,                   -- Supabase Storage URL
  is_verified    BOOLEAN      NOT NULL DEFAULT FALSE,
  verified_by    UUID         REFERENCES profiles(id),
  verified_at    TIMESTAMPTZ,
  expiry_date    DATE,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('student_documents');

-- ────────────────────────────────────────────────────────────────
-- TABLE : student_transfers
-- Transferts d'élèves entre écoles (interne ou externe)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE student_transfers (
  id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID            NOT NULL REFERENCES school_groups(id),
  student_id       UUID            NOT NULL REFERENCES students(id),
  from_school_id   UUID            NOT NULL REFERENCES schools(id),
  to_school_id     UUID            REFERENCES schools(id),       -- NULL = externe
  to_school_name   VARCHAR(200),                                 -- si école externe
  transfer_date    DATE            NOT NULL,
  reason           TEXT,
  status           transfer_status NOT NULL DEFAULT 'pending',
  approved_by      UUID            REFERENCES profiles(id),
  approved_at      TIMESTAMPTZ,
  academic_year_id UUID            REFERENCES academic_years(id),
  created_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('student_transfers');


-- ================================================================
-- ▌BLOC 6 — MATIÈRES & ENSEIGNEMENTS
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : subjects
-- Matières enseignées (Mathématiques, Français, SVT, ...)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE subjects (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id      UUID         NOT NULL REFERENCES school_groups(id),
  school_id     UUID         REFERENCES schools(id),     -- NULL = tout le groupe
  level_id      UUID         REFERENCES school_levels(id),
  name          VARCHAR(100) NOT NULL,    -- "Mathématiques"
  slug          VARCHAR(50)  NOT NULL,    -- "mathematiques"
  coefficient   SMALLINT     NOT NULL DEFAULT 1,
  is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
  display_order SMALLINT     NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (group_id, level_id, slug)
);
SELECT create_updated_at_trigger('subjects');

-- ────────────────────────────────────────────────────────────────
-- TABLE : teacher_subjects
-- Affectation enseignant → matière → classe → année
-- ────────────────────────────────────────────────────────────────
CREATE TABLE teacher_subjects (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID        NOT NULL REFERENCES school_groups(id),
  school_id        UUID        NOT NULL REFERENCES schools(id),
  staff_id         UUID        NOT NULL REFERENCES profiles(id),
  subject_id       UUID        NOT NULL REFERENCES subjects(id),
  class_id         UUID        NOT NULL REFERENCES classes(id),
  academic_year_id UUID        NOT NULL REFERENCES academic_years(id),
  weekly_hours     SMALLINT    DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (staff_id, subject_id, class_id, academic_year_id)
);
SELECT create_updated_at_trigger('teacher_subjects');

-- ────────────────────────────────────────────────────────────────
-- TABLE : timetable_slots
-- Emploi du temps — créneaux horaires par classe
-- ────────────────────────────────────────────────────────────────
CREATE TABLE timetable_slots (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID        NOT NULL REFERENCES school_groups(id),
  school_id        UUID        NOT NULL REFERENCES schools(id),
  class_id         UUID        NOT NULL REFERENCES classes(id),
  subject_id       UUID        NOT NULL REFERENCES subjects(id),
  staff_id         UUID        NOT NULL REFERENCES profiles(id),
  academic_year_id UUID        NOT NULL REFERENCES academic_years(id),
  day_of_week      SMALLINT    NOT NULL CHECK (day_of_week BETWEEN 1 AND 6),  -- 1=Lundi, 6=Samedi
  start_time       TIME        NOT NULL,
  end_time         TIME        NOT NULL,
  room             VARCHAR(50),
  is_active        BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('timetable_slots');

-- ────────────────────────────────────────────────────────────────
-- TABLE : lesson_entries
-- Cahier de textes numérique — journal de cours par enseignant
-- ────────────────────────────────────────────────────────────────
CREATE TABLE lesson_entries (
  id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID         NOT NULL REFERENCES school_groups(id),
  school_id        UUID         NOT NULL REFERENCES schools(id),
  class_id         UUID         NOT NULL REFERENCES classes(id),
  subject_id       UUID         NOT NULL REFERENCES subjects(id),
  staff_id         UUID         NOT NULL REFERENCES profiles(id),
  academic_year_id UUID         NOT NULL REFERENCES academic_years(id),
  trimester_id     UUID         REFERENCES trimesters(id),
  entry_date       DATE         NOT NULL,
  lesson_title     VARCHAR(200) NOT NULL,
  content          TEXT,
  objectives       TEXT,
  homework         TEXT,
  resources        TEXT,
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('lesson_entries');

-- ────────────────────────────────────────────────────────────────
-- TABLE : school_programs
-- Programmes / Curricula par niveau et matière
-- ────────────────────────────────────────────────────────────────
CREATE TABLE school_programs (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID         NOT NULL REFERENCES school_groups(id),
  school_id   UUID         REFERENCES schools(id),
  level_id    UUID         NOT NULL REFERENCES school_levels(id),
  subject_id  UUID         NOT NULL REFERENCES subjects(id),
  academic_year_id UUID    REFERENCES academic_years(id),
  title       VARCHAR(200) NOT NULL,
  content     TEXT,
  trimester_id UUID        REFERENCES trimesters(id),
  is_official BOOLEAN      NOT NULL DEFAULT FALSE,
  created_by  UUID         REFERENCES profiles(id),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('school_programs');


-- ================================================================
-- ▌BLOC 7 — ÉVALUATIONS, NOTES & BULLETINS
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : evaluations
-- Compositions, devoirs, séquences — créées par l'enseignant
-- ────────────────────────────────────────────────────────────────
CREATE TABLE evaluations (
  id               UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID              NOT NULL REFERENCES school_groups(id),
  school_id        UUID              NOT NULL REFERENCES schools(id),
  class_id         UUID              NOT NULL REFERENCES classes(id),
  subject_id       UUID              NOT NULL REFERENCES subjects(id),
  academic_year_id UUID              NOT NULL REFERENCES academic_years(id),
  trimester_id     UUID              REFERENCES trimesters(id),
  sequence_id      UUID              REFERENCES sequences(id),
  title            VARCHAR(200)      NOT NULL,    -- "Composition T1 Mathématiques"
  evaluation_type  evaluation_type   NOT NULL DEFAULT 'composition',
  evaluation_date  DATE              NOT NULL,
  max_score        NUMERIC(5,2)      NOT NULL DEFAULT 20,
  coefficient      SMALLINT          NOT NULL DEFAULT 1,
  created_by       UUID              NOT NULL REFERENCES profiles(id),
  status           evaluation_status NOT NULL DEFAULT 'draft',
  validated_by     UUID              REFERENCES profiles(id),
  validated_at     TIMESTAMPTZ,
  published_at     TIMESTAMPTZ,
  notes            TEXT,
  created_at       TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('evaluations');

-- ────────────────────────────────────────────────────────────────
-- TABLE : grades
-- Notes numériques /20 (Primaire / Collège / Lycée)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE grades (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID         NOT NULL REFERENCES school_groups(id),
  school_id       UUID         NOT NULL REFERENCES schools(id),
  evaluation_id   UUID         NOT NULL REFERENCES evaluations(id) ON DELETE CASCADE,
  student_id      UUID         NOT NULL REFERENCES students(id),
  enrollment_id   UUID         NOT NULL REFERENCES class_enrollments(id),
  score           NUMERIC(5,2),            -- NULL si absent
  is_absent       BOOLEAN      NOT NULL DEFAULT FALSE,
  appreciation    VARCHAR(50),             -- "Excellent", "Très Bien", "Bien"
  teacher_comment TEXT,
  created_by      UUID         NOT NULL REFERENCES profiles(id),
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (evaluation_id, student_id),
  CONSTRAINT chk_score_or_absent CHECK (
    (is_absent = TRUE  AND score IS NULL) OR
    (is_absent = FALSE AND score IS NOT NULL)
  )
);
SELECT create_updated_at_trigger('grades');

-- ────────────────────────────────────────────────────────────────
-- TABLE : competence_grades
-- Notes de compétences pour la Maternelle (Acquis/En cours/Non acquis)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE competence_grades (
  id              UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID              NOT NULL REFERENCES school_groups(id),
  school_id       UUID              NOT NULL REFERENCES schools(id),
  evaluation_id   UUID              NOT NULL REFERENCES evaluations(id) ON DELETE CASCADE,
  student_id      UUID              NOT NULL REFERENCES students(id),
  competence_name VARCHAR(200)      NOT NULL,    -- "Reconnaît les lettres de l'alphabet"
  level           competence_level  NOT NULL DEFAULT 'en_cours',
  teacher_comment TEXT,
  created_by      UUID              NOT NULL REFERENCES profiles(id),
  created_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  UNIQUE (evaluation_id, student_id, competence_name)
);
SELECT create_updated_at_trigger('competence_grades');

-- ────────────────────────────────────────────────────────────────
-- TABLE : bulletins
-- Bulletins trimestriels — conservés 10 ans (règle métier)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE bulletins (
  id               UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID           NOT NULL REFERENCES school_groups(id),
  school_id        UUID           NOT NULL REFERENCES schools(id),
  student_id       UUID           NOT NULL REFERENCES students(id),
  enrollment_id    UUID           NOT NULL REFERENCES class_enrollments(id),
  academic_year_id UUID           NOT NULL REFERENCES academic_years(id),
  trimester_id     UUID           NOT NULL REFERENCES trimesters(id),
  overall_average  NUMERIC(5,2),
  class_average    NUMERIC(5,2),
  rank             SMALLINT,
  total_students   SMALLINT,
  mention          VARCHAR(50),             -- "Très Bien", "Bien", "Excellent"
  total_absences   SMALLINT       NOT NULL DEFAULT 0,
  total_lates      SMALLINT       NOT NULL DEFAULT 0,
  decision         VARCHAR(50),             -- "admis", "redoublant", "oriente"
  teacher_comment  TEXT,
  director_comment TEXT,
  status           bulletin_status NOT NULL DEFAULT 'draft',
  submitted_by     UUID           REFERENCES profiles(id),
  submitted_at     TIMESTAMPTZ,
  validated_by     UUID           REFERENCES profiles(id),
  validated_at     TIMESTAMPTZ,
  published_at     TIMESTAMPTZ,
  pdf_url          TEXT,                    -- URL Supabase Storage
  created_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  UNIQUE (student_id, trimester_id)
);
SELECT create_updated_at_trigger('bulletins');

-- ────────────────────────────────────────────────────────────────
-- TABLE : bulletin_subject_lines
-- Ligne par matière dans le bulletin
-- ────────────────────────────────────────────────────────────────
CREATE TABLE bulletin_subject_lines (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  bulletin_id      UUID        NOT NULL REFERENCES bulletins(id) ON DELETE CASCADE,
  subject_id       UUID        NOT NULL REFERENCES subjects(id),
  group_id         UUID        NOT NULL REFERENCES school_groups(id),
  average          NUMERIC(5,2),
  class_average    NUMERIC(5,2),
  rank             SMALLINT,
  coefficient      SMALLINT    NOT NULL DEFAULT 1,
  weighted_average NUMERIC(6,2),
  appreciation     TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (bulletin_id, subject_id)
);
SELECT create_updated_at_trigger('bulletin_subject_lines');

-- ────────────────────────────────────────────────────────────────
-- TABLE : council_meetings
-- Conseils de classe (enseignants + directeur)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE council_meetings (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID        NOT NULL REFERENCES school_groups(id),
  school_id        UUID        NOT NULL REFERENCES schools(id),
  class_id         UUID        NOT NULL REFERENCES classes(id),
  trimester_id     UUID        NOT NULL REFERENCES trimesters(id),
  academic_year_id UUID        NOT NULL REFERENCES academic_years(id),
  meeting_date     DATE        NOT NULL,
  meeting_time     TIME,
  location         VARCHAR(200),
  presided_by      UUID        REFERENCES profiles(id),
  minutes_text     TEXT,
  minutes_url      TEXT,       -- PDF compte-rendu
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('council_meetings');


-- ================================================================
-- ▌BLOC 8 — PRÉSENCES
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : attendance_records
-- Enregistrement journalier de présence (par classe + période)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE attendance_records (
  id               UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID           NOT NULL REFERENCES school_groups(id),
  school_id        UUID           NOT NULL REFERENCES schools(id),
  class_id         UUID           NOT NULL REFERENCES classes(id),
  subject_id       UUID           REFERENCES subjects(id),  -- NULL = présence générale
  academic_year_id UUID           NOT NULL REFERENCES academic_years(id),
  record_date      DATE           NOT NULL,
  period           session_period NOT NULL,
  recorded_by      UUID           NOT NULL REFERENCES profiles(id),
  is_finalized     BOOLEAN        NOT NULL DEFAULT FALSE,
  created_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  UNIQUE (class_id, record_date, period, COALESCE(subject_id, '00000000-0000-0000-0000-000000000000'::UUID))
);
SELECT create_updated_at_trigger('attendance_records');

-- ────────────────────────────────────────────────────────────────
-- TABLE : attendance_entries
-- Présence individuelle par élève
-- ────────────────────────────────────────────────────────────────
CREATE TABLE attendance_entries (
  id                    UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_record_id  UUID              NOT NULL REFERENCES attendance_records(id) ON DELETE CASCADE,
  student_id            UUID              NOT NULL REFERENCES students(id),
  group_id              UUID              NOT NULL REFERENCES school_groups(id),
  school_id             UUID              NOT NULL REFERENCES schools(id),
  status                attendance_status NOT NULL DEFAULT 'present',
  arrival_time          TIME,             -- si retard
  justification         TEXT,
  justification_doc_url TEXT,
  parent_notified       BOOLEAN           NOT NULL DEFAULT FALSE,
  notified_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  UNIQUE (attendance_record_id, student_id)
);
SELECT create_updated_at_trigger('attendance_entries');

-- ────────────────────────────────────────────────────────────────
-- TABLE : staff_attendance
-- Présences du personnel enseignant et administratif
-- ────────────────────────────────────────────────────────────────
CREATE TABLE staff_attendance (
  id              UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID              NOT NULL REFERENCES school_groups(id),
  school_id       UUID              NOT NULL REFERENCES schools(id),
  staff_id        UUID              NOT NULL REFERENCES profiles(id),
  record_date     DATE              NOT NULL,
  status          attendance_status NOT NULL DEFAULT 'present',
  arrival_time    TIME,
  departure_time  TIME,
  notes           TEXT,
  recorded_by     UUID              REFERENCES profiles(id),
  created_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  UNIQUE (staff_id, record_date)
);
SELECT create_updated_at_trigger('staff_attendance');


-- ================================================================
-- ▌BLOC 9 — FINANCE
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : fee_structures
-- Barèmes des frais de scolarité par école et par année
-- ────────────────────────────────────────────────────────────────
CREATE TABLE fee_structures (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id              UUID        NOT NULL REFERENCES school_groups(id),
  school_id             UUID        NOT NULL REFERENCES schools(id),
  academic_year_id      UUID        NOT NULL REFERENCES academic_years(id),
  name                  VARCHAR(100) NOT NULL,    -- "Mensualité CE1"
  fee_type              fee_type    NOT NULL DEFAULT 'mensualite',
  amount_xaf            INTEGER     NOT NULL,
  due_day_of_month      SMALLINT,               -- ex. 5 = chaque 5 du mois
  applies_to_level_id   UUID        REFERENCES school_levels(id),  -- NULL = tous niveaux
  is_active             BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('fee_structures');

-- ────────────────────────────────────────────────────────────────
-- TABLE : student_payments
-- Paiements des frais de scolarité — données conservées 5 ans
-- ────────────────────────────────────────────────────────────────
CREATE TABLE student_payments (
  id                   UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id             UUID           NOT NULL REFERENCES school_groups(id),
  school_id            UUID           NOT NULL REFERENCES schools(id),
  student_id           UUID           NOT NULL REFERENCES students(id),
  enrollment_id        UUID           NOT NULL REFERENCES class_enrollments(id),
  fee_structure_id     UUID           REFERENCES fee_structures(id),
  amount_xaf           INTEGER        NOT NULL,
  payment_date         DATE           NOT NULL DEFAULT CURRENT_DATE,
  period_month         SMALLINT       CHECK (period_month BETWEEN 1 AND 12),
  period_year          SMALLINT,
  payment_method       payment_method NOT NULL DEFAULT 'especes',
  transaction_reference VARCHAR(100),
  receipt_number       VARCHAR(50)    UNIQUE,     -- "REC-2026-001-0847"
  recorded_by          UUID           NOT NULL REFERENCES profiles(id),
  status               payment_status NOT NULL DEFAULT 'confirmed',
  notes                TEXT,
  created_at           TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('student_payments');

-- ────────────────────────────────────────────────────────────────
-- TABLE : expenses
-- Dépenses de l'école (maintenance, fournitures, salaires, ...)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE expenses (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID        NOT NULL REFERENCES school_groups(id),
  school_id        UUID        NOT NULL REFERENCES schools(id),
  academic_year_id UUID        REFERENCES academic_years(id),
  title            VARCHAR(200) NOT NULL,
  description      TEXT,
  amount_xaf       INTEGER     NOT NULL,
  expense_date     DATE        NOT NULL,
  category         VARCHAR(100),     -- "Maintenance", "Fournitures", "Personnel"
  approved_by      UUID        REFERENCES profiles(id),
  receipt_url      TEXT,
  created_by       UUID        NOT NULL REFERENCES profiles(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('expenses');

-- ────────────────────────────────────────────────────────────────
-- TABLE : budget_lines
-- Lignes budgétaires par catégorie et par année
-- ────────────────────────────────────────────────────────────────
CREATE TABLE budget_lines (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id             UUID        NOT NULL REFERENCES school_groups(id),
  school_id            UUID        NOT NULL REFERENCES schools(id),
  academic_year_id     UUID        NOT NULL REFERENCES academic_years(id),
  category             VARCHAR(100) NOT NULL,
  budgeted_amount_xaf  INTEGER     NOT NULL DEFAULT 0,
  actual_amount_xaf    INTEGER     NOT NULL DEFAULT 0,
  notes                TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('budget_lines');


-- ────────────────────────────────────────────────────────────────
-- TABLE : payment_configs
-- Configuration des passerelles de paiement par groupe scolaire
-- Gérée par le SUPER_ADMIN dans "Mode de paiement"
-- Permet de stocker les clés API MTN, Airtel, VISA par tenant
-- ────────────────────────────────────────────────────────────────
CREATE TABLE payment_configs (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID         NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  provider        payment_method NOT NULL,             -- 'mtn_money', 'airtel_money', 'visa', 'especes'
  display_name    VARCHAR(100) NOT NULL,               -- "MTN Money Congo"
  api_key         TEXT,                                -- clé API chiffrée (Edge Function)
  api_secret      TEXT,                                -- secret API chiffré (Edge Function)
  merchant_id     VARCHAR(100),                        -- identifiant marchand
  webhook_url     TEXT,                                -- URL de callback paiement
  is_active       BOOLEAN      NOT NULL DEFAULT FALSE, -- activé seulement après configuration complète
  is_test_mode    BOOLEAN      NOT NULL DEFAULT TRUE,  -- TRUE = sandbox, FALSE = production
  configured_by   UUID         REFERENCES profiles(id),
  configured_at   TIMESTAMPTZ,
  notes           TEXT,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (group_id, provider)
);
SELECT create_updated_at_trigger('payment_configs');

ALTER TABLE payment_configs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "payment_configs_select" ON payment_configs FOR SELECT USING (
  is_super_admin() OR group_id = auth_group_id()
);
CREATE POLICY "payment_configs_write" ON payment_configs FOR ALL USING (
  is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
);

CREATE INDEX idx_payment_configs_group ON payment_configs(group_id);

-- ================================================================
-- ▌BLOC 10 — RESSOURCES HUMAINES
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : leave_requests
-- Demandes de congé du personnel
-- ────────────────────────────────────────────────────────────────
CREATE TABLE leave_requests (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id          UUID         NOT NULL REFERENCES school_groups(id),
  school_id         UUID         NOT NULL REFERENCES schools(id),
  staff_id          UUID         NOT NULL REFERENCES profiles(id),
  leave_type        VARCHAR(50)  NOT NULL,   -- "annuel", "maladie", "maternite"
  start_date        DATE         NOT NULL,
  end_date          DATE         NOT NULL,
  days_count        SMALLINT     NOT NULL,
  reason            TEXT,
  status            leave_status NOT NULL DEFAULT 'pending',
  reviewed_by       UUID         REFERENCES profiles(id),
  reviewed_at       TIMESTAMPTZ,
  rejection_reason  TEXT,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('leave_requests');

-- ────────────────────────────────────────────────────────────────
-- TABLE : payroll
-- Fiches de paie du personnel
-- ────────────────────────────────────────────────────────────────
CREATE TABLE payroll (
  id                 UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id           UUID           NOT NULL REFERENCES school_groups(id),
  school_id          UUID           NOT NULL REFERENCES schools(id),
  staff_id           UUID           NOT NULL REFERENCES profiles(id),
  period_month       SMALLINT       NOT NULL CHECK (period_month BETWEEN 1 AND 12),
  period_year        SMALLINT       NOT NULL,
  base_salary_xaf    INTEGER        NOT NULL DEFAULT 0,
  bonuses_xaf        INTEGER        NOT NULL DEFAULT 0,
  deductions_xaf     INTEGER        NOT NULL DEFAULT 0,
  net_salary_xaf     INTEGER        NOT NULL DEFAULT 0,
  payment_date       DATE,
  payment_method     payment_method DEFAULT 'especes',
  payment_reference  VARCHAR(100),
  status             payment_status NOT NULL DEFAULT 'pending',
  notes              TEXT,
  created_by         UUID           NOT NULL REFERENCES profiles(id),
  created_at         TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  UNIQUE (staff_id, period_month, period_year)
);
SELECT create_updated_at_trigger('payroll');


-- ================================================================
-- ▌BLOC 11 — VIE SCOLAIRE
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : discipline_incidents
-- Incidents de discipline (violence, incivilité, retards répétés)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE discipline_incidents (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id          UUID        NOT NULL REFERENCES school_groups(id),
  school_id         UUID        NOT NULL REFERENCES schools(id),
  student_id        UUID        NOT NULL REFERENCES students(id),
  academic_year_id  UUID        REFERENCES academic_years(id),
  incident_date     DATE        NOT NULL,
  description       TEXT        NOT NULL,
  incident_type     VARCHAR(50) NOT NULL,   -- "violence", "incivilite", "retard_repete"
  sanction          VARCHAR(200),           -- "Avertissement", "Exclusion 3 jours"
  sanction_date     DATE,
  reported_by       UUID        NOT NULL REFERENCES profiles(id),
  parent_notified   BOOLEAN     NOT NULL DEFAULT FALSE,
  notified_at       TIMESTAMPTZ,
  follow_up_notes   TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('discipline_incidents');

-- ────────────────────────────────────────────────────────────────
-- TABLE : infirmary_visits
-- Passages à l'infirmerie (module infirmerie)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE infirmary_visits (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id            UUID        NOT NULL REFERENCES school_groups(id),
  school_id           UUID        NOT NULL REFERENCES schools(id),
  student_id          UUID        NOT NULL REFERENCES students(id),
  visit_date          DATE        NOT NULL,
  visit_time          TIME,
  symptoms            TEXT,
  diagnosis           TEXT,
  treatment           TEXT,
  medication          TEXT,
  rest_period_hours   SMALLINT    NOT NULL DEFAULT 0,
  parent_notified     BOOLEAN     NOT NULL DEFAULT FALSE,
  notified_at         TIMESTAMPTZ,
  staff_id            UUID        NOT NULL REFERENCES profiles(id),   -- infirmier
  follow_up_required  BOOLEAN     NOT NULL DEFAULT FALSE,
  follow_up_notes     TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('infirmary_visits');

-- ────────────────────────────────────────────────────────────────
-- TABLE : canteen_subscriptions
-- Abonnements cantine par élève et par année
-- ────────────────────────────────────────────────────────────────
CREATE TABLE canteen_subscriptions (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id          UUID        NOT NULL REFERENCES school_groups(id),
  school_id         UUID        NOT NULL REFERENCES schools(id),
  student_id        UUID        NOT NULL REFERENCES students(id),
  academic_year_id  UUID        NOT NULL REFERENCES academic_years(id),
  is_subscribed     BOOLEAN     NOT NULL DEFAULT FALSE,
  monthly_amount_xaf INTEGER    NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (student_id, academic_year_id)
);
SELECT create_updated_at_trigger('canteen_subscriptions');

-- ────────────────────────────────────────────────────────────────
-- TABLE : canteen_records
-- Présence quotidienne à la cantine
-- ────────────────────────────────────────────────────────────────
CREATE TABLE canteen_records (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID        NOT NULL REFERENCES school_groups(id),
  school_id   UUID        NOT NULL REFERENCES schools(id),
  student_id  UUID        NOT NULL REFERENCES students(id),
  record_date DATE        NOT NULL,
  meal_type   VARCHAR(20) NOT NULL DEFAULT 'dejeuner',
  is_present  BOOLEAN     NOT NULL DEFAULT TRUE,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (student_id, record_date, meal_type)
);
SELECT create_updated_at_trigger('canteen_records');

-- ────────────────────────────────────────────────────────────────
-- TABLE : student_orientations
-- Orientation scolaire (bilan, recommandations)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE student_orientations (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         UUID        NOT NULL REFERENCES school_groups(id),
  school_id        UUID        NOT NULL REFERENCES schools(id),
  student_id       UUID        NOT NULL REFERENCES students(id),
  academic_year_id UUID        NOT NULL REFERENCES academic_years(id),
  trimester_id     UUID        REFERENCES trimesters(id),
  recommendation   TEXT,
  target_level     VARCHAR(100),        -- niveau recommandé
  target_filiere   VARCHAR(100),        -- filière recommandée
  counselor_id     UUID        REFERENCES profiles(id),
  parent_consulted BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('student_orientations');


-- ================================================================
-- ▌BLOC 12 — COMMUNICATION
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : announcements
-- Annonces (direction → parents/élèves/personnel)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE announcements (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID         NOT NULL REFERENCES school_groups(id),
  school_id       UUID         REFERENCES schools(id),    -- NULL = tout le groupe
  title           VARCHAR(200) NOT NULL,
  content         TEXT         NOT NULL,
  target_audience VARCHAR(50)  NOT NULL DEFAULT 'all',    -- all/students/staff/parents
  is_pinned       BOOLEAN      NOT NULL DEFAULT FALSE,
  is_published    BOOLEAN      NOT NULL DEFAULT FALSE,
  published_at    TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ,
  created_by      UUID         NOT NULL REFERENCES profiles(id),
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('announcements');

-- ────────────────────────────────────────────────────────────────
-- TABLE : messages
-- Messagerie interne (fil de discussion)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE messages (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id          UUID        NOT NULL REFERENCES school_groups(id),
  sender_id         UUID        NOT NULL REFERENCES profiles(id),
  recipient_id      UUID        NOT NULL REFERENCES profiles(id),
  subject           VARCHAR(200),
  body              TEXT        NOT NULL,
  is_read           BOOLEAN     NOT NULL DEFAULT FALSE,
  read_at           TIMESTAMPTZ,
  parent_message_id UUID        REFERENCES messages(id),   -- threading
  is_archived       BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('messages');

-- ────────────────────────────────────────────────────────────────
-- TABLE : events
-- Événements scolaires (réunion parents, excursion, compétition...)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE events (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID         NOT NULL REFERENCES school_groups(id),
  school_id       UUID         REFERENCES schools(id),
  title           VARCHAR(200) NOT NULL,
  description     TEXT,
  event_date      DATE         NOT NULL,
  end_date        DATE,
  start_time      TIME,
  end_time        TIME,
  location        VARCHAR(200),
  target_audience VARCHAR(50)  DEFAULT 'all',
  is_published    BOOLEAN      NOT NULL DEFAULT FALSE,
  created_by      UUID         NOT NULL REFERENCES profiles(id),
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('events');

-- ────────────────────────────────────────────────────────────────
-- TABLE : notifications
-- Notifications push FCM (bulletins, absences, paiements, ...)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE notifications (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID        NOT NULL REFERENCES school_groups(id),
  recipient_id    UUID        NOT NULL REFERENCES profiles(id),
  type            VARCHAR(50) NOT NULL,     -- "bulletin", "absence", "paiement"
  title           VARCHAR(200) NOT NULL,
  body            TEXT        NOT NULL,
  data            JSONB,                    -- payload flexible (ex: {bulletin_id: "..."})
  is_read         BOOLEAN     NOT NULL DEFAULT FALSE,
  read_at         TIMESTAMPTZ,
  sent_at         TIMESTAMPTZ,
  fcm_message_id  VARCHAR(200),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('notifications');


-- ================================================================
-- ▌BLOC 13 — RESSOURCES (BIBLIOTHÈQUE)
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : library_items
-- Catalogue de la bibliothèque
-- ────────────────────────────────────────────────────────────────
CREATE TABLE library_items (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id            UUID        NOT NULL REFERENCES school_groups(id),
  school_id           UUID        NOT NULL REFERENCES schools(id),
  title               VARCHAR(200) NOT NULL,
  author              VARCHAR(200),
  isbn                VARCHAR(20),
  category            VARCHAR(100),     -- "Littérature", "Sciences", "Manga"
  quantity            SMALLINT    NOT NULL DEFAULT 1,
  available_quantity  SMALLINT    NOT NULL DEFAULT 1,
  location            VARCHAR(100),     -- emplacement rayon
  is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('library_items');

-- ────────────────────────────────────────────────────────────────
-- TABLE : library_loans
-- Emprunts et retours de la bibliothèque
-- ────────────────────────────────────────────────────────────────
CREATE TABLE library_loans (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     UUID        NOT NULL REFERENCES school_groups(id),
  school_id    UUID        NOT NULL REFERENCES schools(id),
  item_id      UUID        NOT NULL REFERENCES library_items(id),
  borrower_id  UUID        NOT NULL REFERENCES profiles(id),
  borrow_date  DATE        NOT NULL DEFAULT CURRENT_DATE,
  due_date     DATE        NOT NULL,
  return_date  DATE,
  status       VARCHAR(20) NOT NULL DEFAULT 'active',   -- active, returned, overdue
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('library_loans');


-- ================================================================
-- ▌BLOC 14 — ANNUAIRE & ORIENTATION SCOLAIRE
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : school_directory
-- Annuaire public de l'école (contacts par département/service)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE school_directory (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID        NOT NULL REFERENCES school_groups(id),
  school_id   UUID        NOT NULL REFERENCES schools(id),
  staff_id    UUID        REFERENCES profiles(id),
  name        VARCHAR(200) NOT NULL,
  role_label  VARCHAR(100),
  department  VARCHAR(100),
  phone       VARCHAR(30),
  email       VARCHAR(255),
  is_public   BOOLEAN     NOT NULL DEFAULT TRUE,
  display_order SMALLINT  NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_updated_at_trigger('school_directory');


-- ================================================================
-- ▌BLOC 15 — AUDIT & TRAÇABILITÉ
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- TABLE : audit_logs
-- Journal de toutes les actions sensibles (CREATE/UPDATE/DELETE)
-- IMMUABLE — pas d'updated_at, jamais modifié
-- ────────────────────────────────────────────────────────────────
CREATE TABLE audit_logs (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID        REFERENCES school_groups(id),
  school_id   UUID        REFERENCES schools(id),
  user_id     UUID        NOT NULL,
  user_role   user_role,
  action      VARCHAR(20) NOT NULL,       -- CREATE, UPDATE, DELETE, LOGIN, EXPORT
  table_name  VARCHAR(100) NOT NULL,
  record_id   UUID,
  old_values  JSONB,
  new_values  JSONB,
  ip_address  INET,
  user_agent  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
  -- Pas de updated_at : les logs sont immuables
);


-- ================================================================
-- ▌BLOC 16 — INDEXES DE PERFORMANCE
-- ================================================================

-- profiles
CREATE INDEX idx_profiles_group_id     ON profiles(group_id);
CREATE INDEX idx_profiles_school_id    ON profiles(school_id);
CREATE INDEX idx_profiles_role         ON profiles(role);
CREATE INDEX idx_profiles_access       ON profiles(access_profile_id);

-- school_groups
CREATE INDEX idx_groups_plan           ON school_groups(plan_id);
CREATE INDEX idx_groups_status         ON school_groups(subscription_status);
CREATE INDEX idx_groups_department     ON school_groups(department);

-- schools
CREATE INDEX idx_schools_group         ON schools(group_id);

-- students
CREATE INDEX idx_students_group        ON students(group_id);
CREATE INDEX idx_students_school       ON students(school_id);
CREATE INDEX idx_students_name         ON students USING gin((first_name || ' ' || last_name) gin_trgm_ops);

-- classes
CREATE INDEX idx_classes_school        ON classes(school_id);
CREATE INDEX idx_classes_year          ON classes(academic_year_id);

-- class_enrollments
CREATE INDEX idx_enrollments_student   ON class_enrollments(student_id);
CREATE INDEX idx_enrollments_class     ON class_enrollments(class_id);
CREATE INDEX idx_enrollments_year      ON class_enrollments(academic_year_id);
CREATE INDEX idx_enrollments_status    ON class_enrollments(status);

-- evaluations
CREATE INDEX idx_evaluations_class     ON evaluations(class_id);
CREATE INDEX idx_evaluations_trimester ON evaluations(trimester_id);
CREATE INDEX idx_evaluations_status    ON evaluations(status);

-- grades
CREATE INDEX idx_grades_evaluation     ON grades(evaluation_id);
CREATE INDEX idx_grades_student        ON grades(student_id);
CREATE INDEX idx_grades_group          ON grades(group_id);

-- attendance
CREATE INDEX idx_att_records_class     ON attendance_records(class_id, record_date);
CREATE INDEX idx_att_entries_student   ON attendance_entries(student_id);
CREATE INDEX idx_att_entries_record    ON attendance_entries(attendance_record_id);

-- bulletins
CREATE INDEX idx_bulletins_student     ON bulletins(student_id);
CREATE INDEX idx_bulletins_trimester   ON bulletins(trimester_id);
CREATE INDEX idx_bulletins_status      ON bulletins(status);

-- payments
CREATE INDEX idx_payments_student      ON student_payments(student_id);
CREATE INDEX idx_payments_school       ON student_payments(school_id);
CREATE INDEX idx_payments_date         ON student_payments(payment_date);
CREATE INDEX idx_payments_status       ON student_payments(status);

-- notifications
CREATE INDEX idx_notif_recipient       ON notifications(recipient_id);
CREATE INDEX idx_notif_unread          ON notifications(recipient_id) WHERE is_read = FALSE;

-- audit_logs
CREATE INDEX idx_audit_group           ON audit_logs(group_id);
CREATE INDEX idx_audit_user            ON audit_logs(user_id);
CREATE INDEX idx_audit_table           ON audit_logs(table_name);
CREATE INDEX idx_audit_created         ON audit_logs(created_at DESC);

-- academic_years
CREATE INDEX idx_years_group_current   ON academic_years(group_id) WHERE is_current = TRUE;

-- timetable
CREATE INDEX idx_timetable_class       ON timetable_slots(class_id);
CREATE INDEX idx_timetable_staff       ON timetable_slots(staff_id);

-- messages
CREATE INDEX idx_messages_recipient    ON messages(recipient_id) WHERE is_read = FALSE;

-- payment_configs
CREATE INDEX idx_payment_configs_active ON payment_configs(group_id) WHERE is_active = TRUE;


-- ================================================================
-- ▌BLOC 17 — ROW LEVEL SECURITY (RLS)
-- ================================================================

-- Activer RLS sur toutes les tables sensibles
ALTER TABLE profiles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_groups       ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_invoices      ENABLE ROW LEVEL SECURITY;
ALTER TABLE schools             ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_members       ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_levels       ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_years      ENABLE ROW LEVEL SECURITY;
ALTER TABLE trimesters          ENABLE ROW LEVEL SECURITY;
ALTER TABLE sequences           ENABLE ROW LEVEL SECURITY;
ALTER TABLE students            ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_tutors      ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes             ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_enrollments   ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects            ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_subjects    ENABLE ROW LEVEL SECURITY;
ALTER TABLE evaluations         ENABLE ROW LEVEL SECURITY;
ALTER TABLE grades              ENABLE ROW LEVEL SECURITY;
ALTER TABLE bulletins           ENABLE ROW LEVEL SECURITY;
ALTER TABLE bulletin_subject_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records  ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_entries  ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_payments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications       ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages            ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements       ENABLE ROW LEVEL SECURITY;

-- ────────────────────────────────────────────────────────────────
-- FONCTIONS HELPERS RLS (SECURITY DEFINER pour performance)
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth_user_role()
RETURNS user_role LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT role FROM profiles WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION auth_group_id()
RETURNS UUID LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT group_id FROM profiles WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION auth_school_id()
RETURNS UUID LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT school_id FROM profiles WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin')
$$;

CREATE OR REPLACE FUNCTION is_admin_groupe()
RETURNS BOOLEAN LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin_groupe')
$$;

-- ────────────────────────────────────────────────────────────────
-- POLITIQUES RLS
-- ────────────────────────────────────────────────────────────────

-- ── profiles ──
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (
  is_super_admin()
  OR (is_admin_groupe() AND group_id = auth_group_id())
  OR id = auth.uid()
);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (
  is_super_admin()
  OR (is_admin_groupe() AND group_id = auth_group_id())
);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (
  is_super_admin()
  OR (is_admin_groupe() AND group_id = auth_group_id())
  OR id = auth.uid()  -- un user peut modifier son propre profil (avatar, phone)
);

-- ── school_groups ──
CREATE POLICY "groups_select" ON school_groups FOR SELECT USING (
  is_super_admin() OR id = auth_group_id()
);
CREATE POLICY "groups_insert" ON school_groups FOR INSERT WITH CHECK (is_super_admin());
CREATE POLICY "groups_update" ON school_groups FOR UPDATE USING (is_super_admin());
CREATE POLICY "groups_delete" ON school_groups FOR DELETE USING (is_super_admin());

-- ── group_invoices ──
CREATE POLICY "invoices_select" ON group_invoices FOR SELECT USING (
  is_super_admin() OR group_id = auth_group_id()
);
CREATE POLICY "invoices_write" ON group_invoices FOR INSERT WITH CHECK (is_super_admin());
CREATE POLICY "invoices_update" ON group_invoices FOR UPDATE USING (is_super_admin());

-- ── schools ──
CREATE POLICY "schools_select" ON schools FOR SELECT USING (
  is_super_admin() OR group_id = auth_group_id()
);
CREATE POLICY "schools_insert" ON schools FOR INSERT WITH CHECK (
  is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
);
CREATE POLICY "schools_update" ON schools FOR UPDATE USING (
  is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
);

-- ── access_profiles ──
CREATE POLICY "ap_select" ON access_profiles FOR SELECT USING (
  is_super_admin() OR group_id = auth_group_id()
);
CREATE POLICY "ap_write" ON access_profiles FOR ALL USING (
  is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
);

-- ── profile_permissions ──
CREATE POLICY "pp_select" ON profile_permissions FOR SELECT USING (
  group_id = auth_group_id()
);
CREATE POLICY "pp_write" ON profile_permissions FOR ALL USING (
  is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
);

-- ── students (TenantGuard) ──
CREATE POLICY "students_tenant" ON students FOR ALL USING (
  is_super_admin()
  OR (
    group_id = auth_group_id()
    AND (is_admin_groupe() OR school_id = auth_school_id())
  )
);

-- ── classes ──
CREATE POLICY "classes_tenant" ON classes FOR ALL USING (
  is_super_admin()
  OR (
    group_id = auth_group_id()
    AND (is_admin_groupe() OR school_id = auth_school_id())
  )
);

-- ── evaluations ──
CREATE POLICY "evals_tenant" ON evaluations FOR ALL USING (
  group_id = auth_group_id()
  AND (is_admin_groupe() OR school_id = auth_school_id())
);

-- ── grades ──
CREATE POLICY "grades_tenant" ON grades FOR ALL USING (
  group_id = auth_group_id()
  AND (is_admin_groupe() OR school_id = auth_school_id())
);

-- ── bulletins ──
CREATE POLICY "bulletins_tenant" ON bulletins FOR ALL USING (
  group_id = auth_group_id()
  AND (is_admin_groupe() OR school_id = auth_school_id())
);

-- ── attendance ──
CREATE POLICY "att_records_tenant" ON attendance_records FOR ALL USING (
  group_id = auth_group_id()
  AND (is_admin_groupe() OR school_id = auth_school_id())
);
CREATE POLICY "att_entries_tenant" ON attendance_entries FOR ALL USING (
  group_id = auth_group_id()
  AND (is_admin_groupe() OR school_id = auth_school_id())
);

-- ── student_payments ──
CREATE POLICY "payments_tenant" ON student_payments FOR ALL USING (
  group_id = auth_group_id()
  AND (is_admin_groupe() OR school_id = auth_school_id())
);

-- ── notifications (personnel uniquement) ──
CREATE POLICY "notif_own" ON notifications FOR ALL USING (
  group_id = auth_group_id()
  AND recipient_id = auth.uid()
);

-- ── messages ──
CREATE POLICY "msg_select" ON messages FOR SELECT USING (
  group_id = auth_group_id()
  AND (sender_id = auth.uid() OR recipient_id = auth.uid())
);
CREATE POLICY "msg_insert" ON messages FOR INSERT WITH CHECK (
  group_id = auth_group_id() AND sender_id = auth.uid()
);

-- ── announcements ──
CREATE POLICY "announce_select" ON announcements FOR SELECT USING (
  group_id = auth_group_id()
  AND (is_admin_groupe() OR school_id IS NULL OR school_id = auth_school_id())
);
CREATE POLICY "announce_write" ON announcements FOR INSERT WITH CHECK (
  group_id = auth_group_id()
  AND (is_admin_groupe() OR school_id = auth_school_id())
);


-- ================================================================
-- ▌BLOC 18 — FONCTIONS MÉTIER
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- FONCTION : calcul de la mention selon la moyenne
-- Règle : ≥16 Excellent | 14-15.99 TB | 12-13.99 Bien
--         10-11.99 AB | 8-9.99 Passable | <8 Insuffisant
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_mention(avg NUMERIC)
RETURNS VARCHAR AS $$
BEGIN
  RETURN CASE
    WHEN avg >= 16    THEN 'Excellent'
    WHEN avg >= 14    THEN 'Très Bien'
    WHEN avg >= 12    THEN 'Bien'
    WHEN avg >= 10    THEN 'Assez Bien'
    WHEN avg >= 8     THEN 'Passable'
    ELSE                   'Insuffisant'
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ────────────────────────────────────────────────────────────────
-- FONCTION : génération automatique du numéro de reçu
-- Format : REC-{school_id_prefix}-{année}-{séq}
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION generate_receipt_number()
RETURNS VARCHAR AS $$
DECLARE
  seq_val BIGINT;
  year_str VARCHAR(4);
BEGIN
  SELECT EXTRACT(YEAR FROM NOW())::VARCHAR INTO year_str;
  SELECT NEXTVAL('seq_receipt_number') INTO seq_val;
  RETURN 'REC-' || year_str || '-' || LPAD(seq_val::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS seq_receipt_number START 1;

-- ────────────────────────────────────────────────────────────────
-- FONCTION : génération numéro de facture
-- Format : INV-{année}-{séq}
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS VARCHAR AS $$
DECLARE
  seq_val BIGINT;
  year_str VARCHAR(4);
BEGIN
  SELECT EXTRACT(YEAR FROM NOW())::VARCHAR INTO year_str;
  SELECT NEXTVAL('seq_invoice_number') INTO seq_val;
  RETURN 'INV-' || year_str || '-' || LPAD(seq_val::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS seq_invoice_number START 1;

-- ────────────────────────────────────────────────────────────────
-- FONCTION : vérification QuotaGuard (limites du plan)
-- Retourne TRUE si la limite n'est pas atteinte
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION check_quota(
  p_group_id    UUID,
  p_quota_type  VARCHAR  -- 'schools', 'students', 'staff'
)
RETURNS BOOLEAN AS $$
DECLARE
  v_max     INTEGER;
  v_current INTEGER;
BEGIN
  -- Récupérer la limite du plan
  SELECT
    CASE p_quota_type
      WHEN 'schools'   THEN sp.max_schools
      WHEN 'students'  THEN sp.max_students
      WHEN 'staff'     THEN sp.max_staff
    END
  INTO v_max
  FROM school_groups sg
  JOIN subscription_plans sp ON sp.id = sg.plan_id
  WHERE sg.id = p_group_id;

  -- -1 = illimité
  IF v_max = -1 THEN RETURN TRUE; END IF;

  -- Compter l'existant
  CASE p_quota_type
    WHEN 'schools' THEN
      SELECT COUNT(*) INTO v_current FROM schools
      WHERE group_id = p_group_id AND is_active = TRUE;
    WHEN 'students' THEN
      SELECT COUNT(*) INTO v_current FROM students
      WHERE group_id = p_group_id AND is_active = TRUE;
    WHEN 'staff' THEN
      SELECT COUNT(*) INTO v_current FROM profiles
      WHERE group_id = p_group_id AND is_active = TRUE
        AND role NOT IN ('super_admin', 'admin_groupe', 'parent', 'eleve');
  END CASE;

  RETURN v_current < v_max;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ────────────────────────────────────────────────────────────────
-- TRIGGER : auto-remplir receipt_number à l'insertion d'un paiement
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION trg_fn_payment_receipt()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.receipt_number IS NULL THEN
    NEW.receipt_number := generate_receipt_number();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payment_receipt
  BEFORE INSERT ON student_payments
  FOR EACH ROW EXECUTE FUNCTION trg_fn_payment_receipt();

-- ────────────────────────────────────────────────────────────────
-- TRIGGER : sync FCM token lors de la mise à jour du profil
-- (placeholder — la logique réelle est dans une Edge Function)
-- ────────────────────────────────────────────────────────────────

-- ────────────────────────────────────────────────────────────────
-- TRIGGER : hook Supabase Auth → création automatique du profil
-- Déclenché par auth.users après INSERT
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, first_name, last_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'enseignant')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION fn_handle_new_user();


-- ================================================================
-- ▌BLOC 19 — DONNÉES INITIALES (SEED)
-- ================================================================

-- Plans d'abonnement
INSERT INTO subscription_plans (name, slug, price_xaf, max_schools, max_students, max_staff, module_count, is_public_plan) VALUES
  ('Gratuit',        'gratuit',        0,       1,    100,   10,    8,  FALSE),
  ('Premium',        'premium',        150000,  5,    2000,  200,   26, FALSE),
  ('Pro',            'pro',            350000,  20,   10000, 1000,  36, FALSE),
  ('Institutionnel', 'institutionnel', 900000, -1,   50000, 5000,  38, TRUE);

-- ────────────────────────────────────────────────────────────────
-- Niveaux scolaires par défaut (communs à tous les groupes)
-- Chaque groupe peut les personnaliser (school_levels.group_id)
-- Source : ancienne version + ajout TECH, PROF, UNIV pour le METP
-- ────────────────────────────────────────────────────────────────
-- NOTE : Ces niveaux sont des RÉFÉRENCES — ils seront copiés/adaptés
--        pour chaque groupe à la création via une Edge Function.
--        group_id = NULL signifie "niveau de référence global"

-- Niveaux standards (insérés avec group_id = NULL = référence globale)
-- Les groupes peuvent les copier ou créer leurs propres niveaux.
-- Implémentation : la colonne group_id est NOT NULL dans school_levels,
-- donc on utilise un group_id sentinel (UUID zéro) pour les références.
-- En pratique, l'Edge Function "on_group_created" copie ces niveaux.

-- Catégories de modules
INSERT INTO module_categories (name, slug, icon, display_order) VALUES
  ('SCOLARISATION',           'scolarisation',   '🎓', 1),
  ('PÉDAGOGIE',               'pedagogie',       '📚', 2),
  ('VIE SCOLAIRE',            'vie-scolaire',    '🏫', 3),
  ('FINANCE',                 'finance',         '💰', 4),
  ('RESSOURCES HUMAINES',     'rh',              '👥', 5),
  ('COMMUNICATION',           'communication',   '📢', 6),
  ('RESSOURCES',              'ressources',      '📖', 7),
  ('INTELLIGENCE ARTIFICIELLE','ia',             '🤖', 8);

-- Modules (38 au total) — insérés par catégorie slug
DO $$
DECLARE
  cat_scol  UUID; cat_peda UUID; cat_vie UUID; cat_fin UUID;
  cat_rh    UUID; cat_comm UUID; cat_res UUID; cat_ia  UUID;
BEGIN
  SELECT id INTO cat_scol FROM module_categories WHERE slug='scolarisation';
  SELECT id INTO cat_peda FROM module_categories WHERE slug='pedagogie';
  SELECT id INTO cat_vie  FROM module_categories WHERE slug='vie-scolaire';
  SELECT id INTO cat_fin  FROM module_categories WHERE slug='finance';
  SELECT id INTO cat_rh   FROM module_categories WHERE slug='rh';
  SELECT id INTO cat_comm FROM module_categories WHERE slug='communication';
  SELECT id INTO cat_res  FROM module_categories WHERE slug='ressources';
  SELECT id INTO cat_ia   FROM module_categories WHERE slug='ia';

  -- 🎓 SCOLARISATION (8)
  INSERT INTO modules (category_id, name, slug, icon, display_order) VALUES
    (cat_scol, 'Élèves',          'eleves',       '👨‍🎓', 1),
    (cat_scol, 'Inscriptions',    'inscriptions', '📋', 2),
    (cat_scol, 'Classes',         'classes',      '🏛️', 3),
    (cat_scol, 'Matières',        'matieres',     '📖', 4),
    (cat_scol, 'Transferts',      'transferts',   '🔄', 5),
    (cat_scol, 'Documents',       'documents',    '📄', 6),
    (cat_scol, 'Annuaire',        'annuaire',     '📒', 7),
    (cat_scol, 'Niveaux',         'niveaux',      '🎚️', 8);

  -- 📚 PÉDAGOGIE (10)
  INSERT INTO modules (category_id, name, slug, icon, display_order) VALUES
    (cat_peda, 'Notes & Évaluations',    'notes',            '📝', 1),
    (cat_peda, 'Présences Élèves',       'presences-eleves', '📅', 2),
    (cat_peda, 'Bulletins',              'bulletins',        '📊', 3),
    (cat_peda, 'Emploi du Temps',        'emploi-du-temps',  '🗓️', 4),
    (cat_peda, 'Cahier de Textes',       'cahier-textes',    '📓', 5),
    (cat_peda, 'Évaluations',            'evaluations',      '📏', 6),
    (cat_peda, 'Conseils de Classe',     'conseils',         '🤝', 7),
    (cat_peda, 'Programmes',             'programmes',       '📑', 8),
    (cat_peda, 'Devoirs en Ligne',       'devoirs-en-ligne', '💻', 9),
    (cat_peda, 'Résultats & Classements','resultats',        '🏆', 10);

  -- 🏫 VIE SCOLAIRE (4)
  INSERT INTO modules (category_id, name, slug, icon, display_order) VALUES
    (cat_vie, 'Discipline',    'discipline',  '⚠️', 1),
    (cat_vie, 'Orientation',   'orientation', '🧭', 2),
    (cat_vie, 'Infirmerie',    'infirmerie',  '🏥', 3),
    (cat_vie, 'Cantine',       'cantine',     '🍽️', 4);

  -- 💰 FINANCE (7)
  INSERT INTO modules (category_id, name, slug, icon, display_order) VALUES
    (cat_fin, 'Frais de Scolarité',  'frais-scolarite',   '💳', 1),
    (cat_fin, 'Paiements Élèves',    'paiements-eleves',  '💵', 2),
    (cat_fin, 'Facturation École',   'facturation-ecole', '🧾', 3),
    (cat_fin, 'Dépenses',            'depenses',          '📉', 4),
    (cat_fin, 'Budget',              'budget',            '💹', 5),
    (cat_fin, 'Comptabilité',        'comptabilite',      '📊', 6),
    (cat_fin, 'Mobile Money',        'mobile-money',      '📱', 7);

  -- 👥 RESSOURCES HUMAINES (4)
  INSERT INTO modules (category_id, name, slug, icon, display_order) VALUES
    (cat_rh, 'Personnel',            'personnel',           '👤', 1),
    (cat_rh, 'Présences Personnel',  'presences-personnel', '📅', 2),
    (cat_rh, 'Congés',               'conges',              '🏖️', 3),
    (cat_rh, 'Paie',                 'paie',                '💰', 4);

  -- 📢 COMMUNICATION (5)
  INSERT INTO modules (category_id, name, slug, icon, display_order) VALUES
    (cat_comm, 'Annonces',       'annonces',      '📢', 1),
    (cat_comm, 'Notifications',  'notifications', '🔔', 2),
    (cat_comm, 'Messagerie',     'messagerie',    '✉️', 3),
    (cat_comm, 'Événements',     'evenements',    '📅', 4),
    (cat_comm, 'Espace Parent',  'espace-parent', '👨‍👩‍👧', 5);

  -- 📖 RESSOURCES (1)
  INSERT INTO modules (category_id, name, slug, icon, display_order) VALUES
    (cat_res, 'Bibliothèque', 'bibliotheque', '📚', 1);

  -- 🤖 IA (2)
  INSERT INTO modules (category_id, name, slug, icon, display_order) VALUES
    (cat_ia, 'Rapports IA',    'rapport-ia',    '🤖', 1),
    (cat_ia, 'Suggestions IA', 'suggestions-ia','💡', 2);
END $$;

-- Association Plan ↔ Modules
-- Gratuit (8) : eleves, inscriptions, classes, matieres, niveaux, notes, presences-eleves, annonces, notifications
-- Premium (26) : + bulletins, emploi-du-temps, cahier-textes, evaluations, messagerie, evenements, espace-parent,
--                  discipline, frais-scolarite, paiements-eleves, facturation-ecole, mobile-money, presences-personnel, transferts, documents
-- Pro (36) : + annuaire, conseils, programmes, orientation, depenses, budget, comptabilite, personnel, conges, paie, bibliotheque
-- Institutionnel (38) : + infirmerie, cantine, rapport-ia, suggestions-ia, devoirs-en-ligne, resultats
DO $$
DECLARE
  plan_gratuit       UUID; plan_premium UUID;
  plan_pro           UUID; plan_instit  UUID;
  modules_gratuit    TEXT[] := ARRAY['eleves','inscriptions','classes','matieres','niveaux','notes','presences-eleves','annonces','notifications'];
  modules_premium    TEXT[] := ARRAY['bulletins','emploi-du-temps','cahier-textes','evaluations','messagerie',
                                     'evenements','espace-parent','discipline','frais-scolarite','paiements-eleves',
                                     'facturation-ecole','mobile-money','presences-personnel','transferts','documents',
                                     'resultats'];
  modules_pro        TEXT[] := ARRAY['annuaire','conseils','programmes','orientation','depenses','budget',
                                     'comptabilite','personnel','conges','paie','bibliotheque','devoirs-en-ligne'];
  modules_instit     TEXT[] := ARRAY['infirmerie','cantine','rapport-ia','suggestions-ia'];
  mod_slug           TEXT;
  mod_id             UUID;
BEGIN
  SELECT id INTO plan_gratuit FROM subscription_plans WHERE slug='gratuit';
  SELECT id INTO plan_premium FROM subscription_plans WHERE slug='premium';
  SELECT id INTO plan_pro     FROM subscription_plans WHERE slug='pro';
  SELECT id INTO plan_instit  FROM subscription_plans WHERE slug='institutionnel';

  -- Plan Gratuit
  FOREACH mod_slug IN ARRAY modules_gratuit LOOP
    SELECT id INTO mod_id FROM modules WHERE slug = mod_slug;
    IF mod_id IS NOT NULL THEN
      INSERT INTO plan_modules (plan_id, module_id) VALUES
        (plan_gratuit, mod_id), (plan_premium, mod_id),
        (plan_pro, mod_id),     (plan_instit, mod_id)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  -- Plan Premium (en plus du Gratuit)
  FOREACH mod_slug IN ARRAY modules_premium LOOP
    SELECT id INTO mod_id FROM modules WHERE slug = mod_slug;
    IF mod_id IS NOT NULL THEN
      INSERT INTO plan_modules (plan_id, module_id) VALUES
        (plan_premium, mod_id), (plan_pro, mod_id), (plan_instit, mod_id)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  -- Plan Pro (en plus du Premium)
  FOREACH mod_slug IN ARRAY modules_pro LOOP
    SELECT id INTO mod_id FROM modules WHERE slug = mod_slug;
    IF mod_id IS NOT NULL THEN
      INSERT INTO plan_modules (plan_id, module_id) VALUES
        (plan_pro, mod_id), (plan_instit, mod_id)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  -- Plan Institutionnel uniquement
  FOREACH mod_slug IN ARRAY modules_instit LOOP
    SELECT id INTO mod_id FROM modules WHERE slug = mod_slug;
    IF mod_id IS NOT NULL THEN
      INSERT INTO plan_modules (plan_id, module_id) VALUES (plan_instit, mod_id)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
END $$;


-- ================================================================
-- ▌BLOC 20 — NOTES POWERSYNC
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- CONFIGURATION POWERSYNC (powersync.yaml)
-- ────────────────────────────────────────────────────────────────
--
-- PowerSync définit des "sync buckets" — des règles qui déterminent
-- quelles lignes sont synchronisées vers quel utilisateur.
-- Toutes les tables ont un champ updated_at pour le suivi des modifications.
--
-- BUCKET 1 : global_readonly
--   Tables : subscription_plans, module_categories, modules, plan_modules
--   Règle  : disponible pour tous les utilisateurs authentifiés
--   Raison : données de référence (plans, modules)
--
-- BUCKET 2 : group_data (paramètre : group_id)
--   Tables : school_groups, group_invoices, schools, access_profiles,
--            profile_permissions, school_levels, academic_years,
--            trimesters, sequences, profiles (membres du groupe)
--   Règle  : auth.uid() appartient au group_id du token JWT
--   Raison : configuration du tenant
--
-- BUCKET 3 : school_data (paramètre : school_id)
--   Tables : students, student_tutors, classes, class_enrollments,
--            student_documents, subjects, teacher_subjects,
--            timetable_slots, lesson_entries, school_programs,
--            fee_structures, announcements, events,
--            council_meetings, school_directory
--   Règle  : auth.uid() a school_id correspondant
--   Raison : données de l'école isolées par tenant
--
-- BUCKET 4 : offline_critical (sous-ensemble de school_data)
--   Tables : grades, evaluations (pour enseignants → saisie hors ligne)
--            attendance_records, attendance_entries
--            class_enrollments (liste élèves par classe)
--            timetable_slots (emploi du temps)
--   Règle  : priorité haute, sync immédiate au login
--   Raison : enseignants utilisent l'app hors ligne au tableau
--
-- BUCKET 5 : personal_data (paramètre : user_id)
--   Tables : notifications (WHERE recipient_id = user_id)
--            messages (WHERE sender_id = user_id OR recipient_id = user_id)
--            staff_attendance (WHERE staff_id = user_id)
--   Règle  : données personnelles de l'utilisateur uniquement
--
-- BUCKET 6 : finance_data (rôles : comptable, directeur, admin_groupe)
--   Tables : student_payments, expenses, budget_lines, payroll
--   Règle  : school_id + rôle financier requis
--
-- TOKEN JWT Claims (Supabase Auth → PowerSync)
-- L'Edge Function PowerSync Token doit inclure :
--   { "group_id": "uuid", "school_id": "uuid",
--     "role": "directeur", "access_profile_id": "uuid" }
--
-- Résolution des conflits : LAST-WRITE-WINS basé sur updated_at
-- Token offline : valide 30 jours, renouvelé automatiquement
-- ────────────────────────────────────────────────────────────────


-- ================================================================
-- FIN DU SCHÉMA E-PILOTE CONGO v3.0
-- ================================================================
-- Tables         : 47 tables
-- Enums          : 16 types
-- Index          : 30+ indexes
-- Politiques RLS : 25+ politiques
-- Fonctions      : 10 fonctions métier
-- Triggers       : auto updated_at + receipt + auth hook
-- ================================================================

-------------------------------------------------------------------------------------------------------------------------------------------------------
REMARQUE : JE NE VOIS PAS LA GESTION DES ANNÉES ACADEMIQUE, CAR L'ÉCOLE C'EST CHAQUE ANNÉE IL YA LA RENTRÉE ETC... ET CELA EST D'UNE IMPORTANCE CAPITAL
-------------------------------------------------------------------------------------------------------------------------------------------------------
