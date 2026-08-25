-- ════════════════════════════════════════════════════════════════════════════
--  SEED 07 — LES DROITS : ce que chaque profil d'accès a le droit de faire
--
--  ── LE TROU QUE CE FICHIER BOUCHE ──────────────────────────────────────────
--  Le seed 01 crée cinq profils d'accès par groupe ; le seed 03 y rattache
--  trois cent quarante comptes. Mais un profil sans PERMISSION n'ouvre rien :
--  chaque agent se connectait sur un tableau de bord vide, sidebar barrée d'un
--  « Aucun module attribué ». Toute la donnée des seeds 02 à 06 existait, et
--  personne dans l'application ne pouvait la voir.
--
--  ── LA CASCADE À QUATRE VERROUS ────────────────────────────────────────────
--  Un module n'apparaît que si les quatre s'ouvrent :
--    1. le RÔLE      — `_isStaffRole`, décidé à la connexion
--    2. le PLAN      — `plan_modules` : ce que le groupe a souscrit
--    3. le PROFIL    — `profile_permissions` : CE FICHIER
--    4. le PÉRIMÈTRE — `data_scope` : toute l'école, ou ses seules classes
--
--  Les droits sont posés sur TOUT le catalogue, pas sur les seuls modules du
--  plan : le plan est un verrou distinct, et c'est lui qui doit ouvrir ou
--  fermer. Ainsi, faire passer un groupe au plan supérieur révèle aussitôt les
--  modules correspondants — sans repasser par les profils.
--
--  ── LES DROITS NE SONT PAS INVENTÉS ICI ────────────────────────────────────
--  Ils reprennent, à l'identique, les modèles que l'application applique
--  elle-même quand un administrateur crée un profil (`_kPresets` dans
--  `admin_access_screen.dart`). Un jeu de démonstration qui accorderait autre
--  chose que le produit montrerait un produit qui n'existe pas.
-- ════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE v_me uuid;
BEGIN
  SELECT id INTO v_me FROM profiles WHERE role = 'super_admin'
   ORDER BY created_at LIMIT 1;
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Aucun super_admin en base : créez-le avant de semer.';
  END IF;
  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_me)::text, false);
END $$;

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
--  LES SEPT NIVEAUX DE DROIT
--  Mêmes noms et mêmes combinaisons que les raccourcis sémantiques du produit.
-- ────────────────────────────────────────────────────────────────────────────

CREATE TEMP TABLE tmp_droit(
  nom text PRIMARY KEY,
  r bool, c bool, u bool, d bool, e bool, i bool, v bool, a bool, m bool
) ON COMMIT DROP;

INSERT INTO tmp_droit VALUES
--  nom            lire  créer  modif  suppr export import valid approb gérer
  ('full',         true, true,  true,  true, true, true,  true, true,  true),
  ('manageData',   true, true,  true,  true, true, true,  false,false, false),
  ('financial',    true, true,  true,  false,true, true,  true, false, false),
  ('teach',        true, true,  true,  false,true, false, false,false, false),
  ('contribute',   true, true,  true,  false,false,false, false,false, false),
  ('readExport',   true, false, false, false,true, false, false,false, false),
  ('readOnly',     true, false, false, false,false,false, false,false, false);

-- ────────────────────────────────────────────────────────────────────────────
--  QUI PEUT QUOI
--
--  Une règle vise soit une CATÉGORIE entière, soit UN module — et la règle de
--  module l'emporte, exactement comme `grantFor()` côté application.
-- ────────────────────────────────────────────────────────────────────────────

CREATE TEMP TABLE tmp_regle(
  role_type text, cible text, par_module bool, droit text, portee text
) ON COMMIT DROP;

INSERT INTO tmp_regle VALUES
-- ── Direction — autorité complète sur son établissement ────────────────────
  ('directeur','scolarite',    false,'full','own_school'),
  ('directeur','enseignement', false,'full','own_school'),
  ('directeur','evaluation',   false,'full','own_school'),
  ('directeur','examens',      false,'full','own_school'),
  ('directeur','formation-pro',false,'full','own_school'),
  ('directeur','vie-scolaire', false,'full','own_school'),
  ('directeur','finance',      false,'full','own_school'),
  ('directeur','rh',           false,'full','own_school'),

-- ── Secrétariat — les dossiers, pas les notes ──────────────────────────────
  ('secretaire','scolarite',    false,'manageData','own_school'),
  ('secretaire','examens',      false,'manageData','own_school'),
  ('secretaire','formation-pro',false,'manageData','own_school'),
  ('secretaire','enseignement', false,'readExport','own_school'),
  ('secretaire','evaluation',   false,'readExport','own_school'),
  ('secretaire','vie-scolaire', false,'readOnly',  'own_school'),

-- ── Comptabilité — l'argent, et ce qu'il faut pour le rattacher à un élève ──
  ('comptable','finance',   false,'financial','own_school'),
  ('comptable','scolarite', false,'readOnly', 'own_school'),
  ('comptable','examens',   false,'readOnly', 'own_school'),

-- ── Enseignant — ses classes, et rien d'autre ──────────────────────────────
--  ⚠️ `own_classes` n'est pas cosmétique : c'est ce qui empêche un professeur
--  de lire les notes d'une classe qui n'est pas la sienne.
  ('enseignant','enseignement',false,'teach',   'own_classes'),
  ('enseignant','evaluation',  false,'teach',   'own_classes'),
  ('enseignant','scolarite',   false,'readOnly','own_classes'),
  ('enseignant','examens',     false,'readOnly','own_classes'),
  ('enseignant','vie-scolaire',false,'readOnly','own_classes'),

-- ── Vie scolaire — le quotidien : présences, discipline, infirmerie ────────
  ('surveillant','vie-scolaire',    false,'manageData','own_school'),
  ('surveillant','scolarite',       false,'readOnly',  'own_school'),
  -- Il pointe les présences sans pouvoir effacer l'historique.
  ('surveillant','presences-eleves', true,'contribute','own_school');

-- ────────────────────────────────────────────────────────────────────────────
--  RÉSOLUTION
--
--  On ne touche QUE les profils que les seeds possèdent : l'identifiant doit se
--  recalculer depuis le groupe et le `role_type`. Un profil taillé à la main par
--  un établissement n'est jamais réécrit.
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO profile_permissions (
  id, profile_id, module_id, group_id,
  can_read, can_create, can_update, can_delete, can_export,
  can_import, can_validate, can_approve, can_manage, data_scope)
SELECT seed_uuid('perm:' || ap.id::text || ':' || m.id::text),
       ap.id, m.id, ap.group_id,
       d.r, d.c, d.u, d.d, d.e, d.i, d.v, d.a, d.m,
       -- ⚠️ `can_write` n'est PAS écrit ici : c'est une colonne GÉNÉRÉE
       -- (`can_create OR can_update`). La base refuse qu'on lui dicte sa valeur,
       -- et elle a raison — un droit d'écriture qui contredirait le droit de
       -- créer serait un mensonge de plus à maintenir.
       rg.portee::data_scope
FROM access_profiles ap
JOIN school_groups g       ON g.id = ap.group_id AND g.slug IS NOT NULL
CROSS JOIN modules m
JOIN module_categories mc  ON mc.id = m.category_id
JOIN LATERAL (
  SELECT r.* FROM tmp_regle r
   WHERE r.role_type = ap.role_type
     AND ((r.par_module AND r.cible = m.slug)
       OR (NOT r.par_module AND r.cible = mc.slug))
   ORDER BY r.par_module DESC
   LIMIT 1
) rg ON true
JOIN tmp_droit d ON d.nom = rg.droit
WHERE m.is_active
  AND ap.id = seed_uuid('ap:' || g.slug || ':' || ap.role_type)
ON CONFLICT (profile_id, module_id) DO UPDATE SET
  can_read = EXCLUDED.can_read,     can_create = EXCLUDED.can_create,
  can_update = EXCLUDED.can_update, can_delete = EXCLUDED.can_delete,
  can_export = EXCLUDED.can_export, can_import = EXCLUDED.can_import,
  can_validate = EXCLUDED.can_validate, can_approve = EXCLUDED.can_approve,
  can_manage = EXCLUDED.can_manage,
  data_scope = EXCLUDED.data_scope, updated_at = now();

COMMIT;

-- ── Contrôle ────────────────────────────────────────────────────────────────
SELECT ap.role_type AS profil,
       count(*)                                   AS modules_ouverts,
       count(*) FILTER (WHERE pp.can_manage)      AS dont_gestion,
       count(*) FILTER (WHERE pp.data_scope = 'own_classes') AS dont_ses_classes
FROM profile_permissions pp
JOIN access_profiles ap ON ap.id = pp.profile_id
GROUP BY ap.role_type ORDER BY ap.role_type;

-- Aucun agent ne doit rester sans un seul module.
SELECT count(*) AS comptes_sans_aucun_module
FROM profiles p
WHERE p.role NOT IN ('super_admin', 'admin_groupe', 'parent', 'eleve')
  AND p.group_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM profile_permissions pp
                   WHERE pp.profile_id = p.access_profile_id AND pp.can_read);
