-- ════════════════════════════════════════════════════════════════════════════
--  0125 — NUL NE SE DONNE SES PROPRES DROITS
--
--  ⛔ ESCALADE DE PRIVILÈGES — LA PLUS GRAVE DE L'AUDIT.
--
--  La politique `profiles_update` autorise un membre à mettre à jour SA propre
--  ligne (`id = auth.uid()`), et son `WITH CHECK` était NUL — Postgres retombe
--  alors sur le `USING`, qui reste vrai puisque c'est toujours sa ligne. Aucune
--  colonne n'était protégée. Or c'est cette table qui PORTE les droits :
--
--      is_super_admin()  =  profiles.role = 'super_admin'
--      is_admin_groupe() =  profiles.role = 'admin_groupe'
--      auth_school_id()  =  profiles.school_id
--      auth_group_id()   =  profiles.group_id
--      les 4 verrous     =  profiles.access_profile_id
--
--  Un compte enseignant pouvait donc, avec son propre jeton, en trois requêtes
--  contre l'API publique :
--    1. se donner le profil d'accès « Direction » ;
--    2. écrire `role = 'super_admin'` — c'est-à-dire prendre la plateforme
--       ENTIÈRE : tous les groupes, toutes les écoles, toutes les tables ;
--    3. se transférer dans une autre école.
--
--  Et le déclencheur `profiles_sensitive_flags`, qui DÉRIVE `sync_finance` /
--  `sync_medical` / `sync_discipline` du profil d'accès, achevait le travail :
--  il ouvrait de lui-même la paie, le médical et la discipline.
--
--  Mesuré en production le 2026-08-27 (transaction annulée) :
--      AVANT  role=enseignant  finance=f
--      se donner le profil DIRECTION      : OUI
--      se déclarer SUPER_ADMIN            : OUI
--      se transférer dans une AUTRE école : OUI
--      APRÈS  role=super_admin  finance=t
--
--  ── LA PARADE ──────────────────────────────────────────────────────────────
--  Un membre garde le droit de corriger SON état civil (nom, téléphone, photo,
--  jeton de notification…). Les colonnes de POUVOIR sont RAMENÉES à leur
--  valeur d'origine.
--
--  ⚠️ Ramenées, et non refusées. Un refus lèverait 42501 — code FATAL pour le
--  connecteur PowerSync, qui jette le LOT ENTIER en attente. Or l'appareil
--  remonte ses lignes en `upsert` complet : un poste dont la copie locale de
--  `profiles` a vieilli renverrait un `role` périmé sans aucune intention de
--  nuire, et perdrait au passage les notes et les paiements du même lot. On
--  neutralise donc l'écriture au lieu de l'interdire.
--
--  ⚠️ Ce déclencheur doit passer AVANT `profiles_sensitive_flags`, qui dérive
--  les drapeaux du profil d'accès. Postgres exécute les déclencheurs de même
--  moment par ORDRE ALPHABÉTIQUE : d'où le préfixe `aa_`.
--
--  ⚠️ Sans JWT (`auth.uid()` nul), on ne touche à rien : migrations, tâches
--  serveur et Edge Functions en `service_role` doivent pouvoir administrer. La
--  clé `service_role` ne quitte jamais le serveur (règle du projet).
--
--  ── VÉRIFIÉ APRÈS COUP (production, transaction annulée) ───────────────────
--      AVANT   role=enseignant   profil=21f4f71d  école=5819fe4d  finance=f
--      la requête d'escalade passe : 1 ligne (donc AUCUN 42501, aucun lot jeté)
--      APRÈS   role=enseignant   profil=21f4f71d  école=5819fe4d  finance=f
--      … et le prénom, lui, a bien changé : le libre-service marche toujours.
--      ADMIN GROUPE change le profil d'un membre : OUI (aucune régression).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.profiles_garde_colonnes_de_pouvoir()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  -- Pas de JWT : migration, tâche serveur, Edge Function. On n'entrave pas.
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- Les administrateurs administrent.
  IF public.is_super_admin() THEN
    RETURN NEW;
  END IF;
  IF public.is_admin_groupe()
     AND OLD.group_id IS NOT DISTINCT FROM public.auth_group_id() THEN
    RETURN NEW;
  END IF;

  -- Tout le reste — y compris soi-même sur sa propre ligne : les colonnes qui
  -- DONNENT du pouvoir gardent leur valeur, quoi qu'on ait écrit.
  NEW.role              := OLD.role;
  NEW.access_profile_id := OLD.access_profile_id;
  NEW.school_id         := OLD.school_id;
  NEW.group_id          := OLD.group_id;
  NEW.is_active         := OLD.is_active;
  NEW.sync_finance      := OLD.sync_finance;
  NEW.sync_medical      := OLD.sync_medical;
  NEW.sync_discipline   := OLD.sync_discipline;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS aa_profiles_garde_pouvoir ON profiles;

CREATE TRIGGER aa_profiles_garde_pouvoir
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.profiles_garde_colonnes_de_pouvoir();

COMMENT ON FUNCTION public.profiles_garde_colonnes_de_pouvoir() IS
  'Empêche un membre de modifier les colonnes qui lui donnent du pouvoir sur '
  'sa propre ligne `profiles` (role, access_profile_id, school_id, group_id, '
  'is_active, drapeaux sync_*). Les valeurs sont RAMENÉES, jamais refusées : '
  'un 42501 ferait jeter le lot PowerSync entier. Migration 0125.';
