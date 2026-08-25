-- 0049 — Octroi des nouveaux modules aux profils d'accès EXISTANTS
--
-- ── LE BUG (confirmé, pas supposé) ─────────────────────────────────────────
-- Profil d'Aline (Directeur, Collège Public de Kinkala), après ajout d'examens
-- et de stages au catalogue :
--     notes     -> can_read = true
--     bulletins -> can_read = true
--     examens   -> AUCUNE LIGNE
--     stages    -> AUCUNE LIGNE
--
-- Les presets de `admin_access_screen.dart` ne s'appliquent qu'à la CRÉATION
-- d'un profil. Un module ajouté au catalogue n'a donc AUCUNE ligne
-- `profile_permissions` pour les profils déjà existants -> verrou 3 fermé ->
-- le module est INVISIBLE dans la sidebar, pour tout le monde.
--
-- ── POURQUOI C'EST UN BUG DE REVENU, PAS D'ERGONOMIE ───────────────────────
-- `examens` et `stages` ne sont vendus que dans les plans `pro` et
-- `institutionnel`. Une école paie la montée en gamme… et ne voit RIEN tant
-- qu'un admin n'a pas rouvert chaque profil d'accès pour cocher le module.
-- Le client paie pour une fonctionnalité invisible : c'est un remboursement et
-- un ticket de support garantis.
--
-- ── LA MÉTHODE : COPIER, PAS DEVINER ───────────────────────────────────────
-- Plutôt qu'une table de droits en dur (qui divergerait des presets Dart au
-- premier changement), on RECOPIE les droits que le profil détient déjà sur un
-- module de RÉFÉRENCE comparable. Pour examens/stages, la référence est
-- `inscriptions` : c'est le même métier (le dossier de l'élève), et les droits
-- y reflètent déjà qui fait quoi —
--     direction -> complet · secrétaire -> gestion · comptable -> lecture ·
--     enseignant -> lecture sur ses classes · consultant -> lecture/export.
-- Aucun droit n'est INVENTÉ : on n'accorde jamais plus que ce que le profil a
-- déjà sur son propre périmètre. Un admin peut élargir ensuite.

BEGIN;

-- Fonction réutilisable : le problème se reposera à CHAQUE nouveau module.
CREATE OR REPLACE FUNCTION grant_module_like(p_new_slug text, p_ref_slug text)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count integer;
BEGIN
  -- ⚠️ can_write est une colonne GÉNÉRÉE : (can_create OR can_update). Elle ne
  -- peut pas être insérée — et ce n'est donc PAS le doublon que l'analyse du
  -- 2026-07-17 (§6.1) lui reprochait : elle est dérivée, donc légitime.
  INSERT INTO profile_permissions (
    profile_id, module_id, group_id,
    can_read, can_create, can_update, can_delete, can_export,
    can_import, can_validate, can_approve, can_manage, data_scope
  )
  SELECT ref.profile_id, m_new.id, ref.group_id,
         ref.can_read, ref.can_create, ref.can_update, ref.can_delete, ref.can_export,
         ref.can_import, ref.can_validate, ref.can_approve, ref.can_manage,
         ref.data_scope
    FROM profile_permissions ref
    JOIN modules m_ref ON m_ref.id = ref.module_id AND m_ref.slug = p_ref_slug
    CROSS JOIN modules m_new
   WHERE m_new.slug = p_new_slug
     -- Idempotent : ne jamais écraser un droit déjà réglé à la main.
     AND NOT EXISTS (
       SELECT 1 FROM profile_permissions pp
        WHERE pp.profile_id = ref.profile_id AND pp.module_id = m_new.id
     );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END $$;

COMMENT ON FUNCTION grant_module_like IS
  'Accorde un module NOUVEAU aux profils d''accès EXISTANTS, en recopiant leurs '
  'droits sur un module de référence comparable. À APPELER À CHAQUE AJOUT DE '
  'MODULE au catalogue : sans cela le module reste invisible (verrou 3 fermé) '
  'même pour les groupes dont le plan l''inclut — donc payé et non délivré.';

SELECT grant_module_like('examens', 'inscriptions') AS profils_examens;
SELECT grant_module_like('stages',  'inscriptions') AS profils_stages;

COMMIT;

-- ── Vérifications ──────────────────────────────────────────────────────────
-- select m.slug, count(pp.id) from modules m
--   left join profile_permissions pp on pp.module_id=m.id
--  where m.slug in ('examens','stages','inscriptions') group by 1;
-- Détection future d'un module orphelin de droits :
-- select m.slug from modules m where m.is_active
--   and not exists (select 1 from profile_permissions pp where pp.module_id=m.id);
