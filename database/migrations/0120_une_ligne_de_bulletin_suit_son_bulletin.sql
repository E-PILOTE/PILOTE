-- ════════════════════════════════════════════════════════════════════════════
--  0120 — LES LIGNES D'UN BULLETIN S'ÉCRIVENT LÀ OÙ LE BULLETIN S'ÉCRIT
--
--  0118 a posé `bulletins_insert` sur DEUX modules — `bulletins` ET `conseils`
--  — parce que DEUX écrans génèrent des bulletins : la page Bulletins et la
--  délibération du conseil de classe. Mais `bsl_write`, sur les lignes-matières
--  du même bulletin, n'en exigeait qu'UN : `bulletins`.
--
--  Aujourd'hui aucun profil ne tombe dans l'écart (tous ceux qui ont `conseils`
--  ont aussi `bulletins` — relevé le 2026-08-27). C'est précisément la forme du
--  piège corrigé en 0116 : un droit d'écriture se déduit des ÉCRANS QUI
--  ÉCRIVENT, pas du nom du module. Le jour où un groupe crée un profil
--  « Conseil de classe » sans `bulletins`, la génération insérerait le bulletin
--  puis se ferait refuser ses lignes — 42501, code FATAL pour le connecteur
--  PowerSync, qui jette le lot ENTIER en attente.
--
--  On aligne donc la ligne sur son bulletin.
-- ════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS bsl_write ON bulletin_subject_lines;

CREATE POLICY bsl_write ON bulletin_subject_lines
  FOR ALL
  USING (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (
        school_id = (SELECT auth_school_id())
        AND (SELECT auth_module_permet(ARRAY['bulletins', 'conseils'], 'create'))
      )
    )
  )
  WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (
        school_id = (SELECT auth_school_id())
        AND (SELECT auth_module_permet(ARRAY['bulletins', 'conseils'], 'create'))
      )
    )
  );
