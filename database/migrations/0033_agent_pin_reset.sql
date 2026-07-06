-- 0033_agent_pin_reset.sql
-- Réinitialisation du code PIN de poste par admin_groupe (Phase 2).
--
-- Le PIN de poste est haché EN LOCAL (SharedPreferences), jamais synchronisé.
-- Quand un agent l'oublie, admin_groupe (online) pose ici un horodatage de
-- demande de reset ; il redescend par PowerSync (bucket `directory`) sur les
-- postes de l'école, qui invalident le PIN local si ce champ est postérieur à
-- la date locale de création du PIN (`agent_pin_set_at`). L'agent recrée alors
-- son code (self-réparateur : la nouvelle date locale repasse devant le drapeau).
--
-- RLS : AUCUNE nouvelle policy. La policy UPDATE existante d'admin_groupe sur
-- `profiles` (group_id = auth_group_id() AND is_admin_groupe()) couvre déjà la
-- colonne (RLS = row-level). À vérifier live avant application.

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS pin_reset_requested_at timestamptz;

COMMENT ON COLUMN profiles.pin_reset_requested_at IS
  'Demande de reset du PIN de poste (admin_groupe). Le poste invalide le PIN '
  'local si ce champ est postérieur à sa date de création locale (agent_pin_set_at).';
