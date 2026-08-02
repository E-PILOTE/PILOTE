-- ════════════════════════════════════════════════════════════════════════════
--  SEED 03 — LE PERSONNEL : administrateurs de groupe, direction, enseignants
--
--  ── UN COMPTE, C'EST DEUX LIGNES ───────────────────────────────────────────
--  `auth.users` porte l'identité (email, mot de passe) ; `profiles` porte le
--  métier (rôle, école, profil d'accès). Le trigger `trg_on_auth_user_created`
--  crée le profil SANS groupe ; c'est un UPDATE qui l'y rattache ensuite.
--  Cette séquence n'est pas un détail : c'est elle qui décide où se déclenche
--  le quota de personnel (cf. migration 0076).
--
--  ── ⚠️ LE PROFIL D'ACCÈS N'EST PAS FACULTATIF ──────────────────────────────
--  Un agent sans `access_profile_id` ouvre l'application sur une barre latérale
--  VIDE. C'est la première cause de « l'espace personnel ne montre rien ».
--  Chaque compte créé ici en reçoit un, cohérent avec son rôle.
--
--  ── LES DONNÉES SENSIBLES SUIVENT LE PROFIL ────────────────────────────────
--  `sync_finance`, `sync_discipline`, `sync_medical` décident de ce qui
--  DESCEND sur l'appareil hors ligne. Un enseignant ne doit pas emporter la
--  comptabilité de l'école dans sa sacoche : ces trois drapeaux ne sont ouverts
--  qu'à qui en a l'usage.
--
--  ── MOT DE PASSE DE DÉMONSTRATION ──────────────────────────────────────────
--  Tous les comptes semés partagent `Demo@2026!`. C'est acceptable pour une
--  démonstration et inacceptable ailleurs : ces comptes portent tous un email
--  en `@epilote.cg`, ce qui les rend identifiables et supprimables d'un coup
--  (`99_purge.sql`).
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
--  1. LA FABRIQUE DE COMPTES
--
--  Une seule fonction, pour que la séquence auth.users → profiles ne soit
--  jamais réécrite de travers. Elle est idempotente : rejouée, elle met à jour
--  le profil sans recréer l'identité.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.seed_account(
  p_key         text,
  p_email       text,
  p_first       text,
  p_last        text,
  p_role        user_role,
  p_group       uuid,
  p_school      uuid,
  p_access      uuid DEFAULT NULL,
  p_finance     boolean DEFAULT false,
  p_discipline  boolean DEFAULT false,
  p_medical     boolean DEFAULT false,
  p_employee_no text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'extensions', 'pg_temp'
AS $$
DECLARE v_id uuid := seed_uuid('account:' || p_key);
BEGIN
  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    role, aud, created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token, recovery_token, email_change,
    email_change_token_new, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token)
  VALUES (
    v_id, '00000000-0000-0000-0000-000000000000', p_email,
    crypt('Demo@2026!', gen_salt('bf')), now(),
    'authenticated', 'authenticated', now(), now(),
    jsonb_build_object('provider','email','providers',array['email']),
    jsonb_build_object('first_name',p_first,'last_name',p_last,'role',p_role::text),
    false, '', '', '', '', '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO auth.identities (
    provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at)
  VALUES (
    v_id::text, v_id,
    jsonb_build_object('sub', v_id::text, 'email', p_email,
                       'email_verified', true, 'phone_verified', false),
    'email', now(), now(), now())
  ON CONFLICT (provider, provider_id) DO NOTHING;

  -- Le profil existe déjà (créé par `trg_on_auth_user_created`), sans groupe.
  UPDATE profiles SET
    first_name = p_first, last_name = p_last, role = p_role,
    group_id = p_group, school_id = p_school, access_profile_id = p_access,
    employee_number = p_employee_no, is_active = true,
    sync_finance = p_finance, sync_discipline = p_discipline,
    sync_medical = p_medical, updated_at = now()
  WHERE id = v_id;

  RETURN v_id;
END $$;

-- ────────────────────────────────────────────────────────────────────────────
--  2. UN ADMINISTRATEUR PAR GROUPE
--
--  Sans lui, l'espace admin_groupe — dix écrans déjà livrés — n'a personne pour
--  l'ouvrir, et les notifications d'abonnement n'ont aucun destinataire.
-- ────────────────────────────────────────────────────────────────────────────

SELECT seed_account(
  'admin:' || g.slug, 'admin.' || g.slug || '@epilote.cg',
  a.first, a.last, 'admin_groupe'::user_role, g.id, NULL,
  seed_uuid('ap:' || g.slug || ':directeur'), true, true, false, NULL)
FROM school_groups g
JOIN (VALUES
  ('metp','Aimé','Ngoma'), ('mepsa','Clarisse','Bakala'),
  ('savorgnan','Gilbert','Mabiala'), ('edec','Sylvie','Loubaki'),
  ('saint-pierre','Anicet','Mouko'), ('horizon','Prosper','Ondongo'),
  ('bethel','Rachel','Nkodia')
) AS a(slug, first, last) ON a.slug = g.slug;

-- ────────────────────────────────────────────────────────────────────────────
--  3. LA DIRECTION ET LES ÉQUIPES
--
--  Le chef d'établissement est `proviseur` au lycée, `directeur` ailleurs :
--  c'est la nomenclature congolaise, et l'application ouvre des écrans
--  différents selon le cas.
--
--  Le comptable n'apparaît qu'au-delà de 400 places : une petite école rurale
--  n'en a pas, son secrétaire tient la caisse. Reproduire cette réalité évite
--  de présenter au ministère un organigramme d'établissement français.
-- ────────────────────────────────────────────────────────────────────────────

-- ── DEUX HOMONYMES DANS UNE MÊME ÉCOLE, ET LA DÉMO EST MORTE ───────────────
--  Première version : seize identités complètes, tirées au hasard pour chacun
--  des dix agents d'une école. Le paradoxe des anniversaires a fait le reste —
--  soixante-deux collisions, jusqu'à QUATRE « Alphonsine Kimbembé » dans le même
--  établissement, alignées dans le sélecteur de poste partagé. Un ministère y
--  lit un bug d'unicité, pas une coïncidence.
--
--  Désormais : seize prénoms × trente-deux noms = 512 identités, et surtout
--  chaque agent reçoit un RANG dans son école (0 pour le chef, 1 à 3 pour
--  l'encadrement, 4 à 9 pour les enseignants). L'identité se déduit du rang par
--  incrément, donc deux rangs différents ne peuvent PAS retomber sur le même
--  prénom : l'unicité n'est plus une chance, c'est une conséquence.
CREATE TEMP TABLE tmp_prenom(idx int, first text) ON COMMIT DROP;
INSERT INTO tmp_prenom VALUES
  (0,'Jean-Claude'), (1,'Alphonsine'), (2,'Rodrigue'),  (3,'Véronique'),
  (4,'Serge'),       (5,'Bernadette'), (6,'Firmin'),    (7,'Adèle'),
  (8,'Pascal'),      (9,'Léontine'),  (10,'Hervé'),    (11,'Chantal'),
  (12,'Norbert'),   (13,'Josiane'),   (14,'Guy-Blaise'),(15,'Micheline');

-- Les mêmes patronymes que les élèves (seed 04) : dans un pays, le personnel
-- porte les noms des familles qu'il scolarise.
CREATE TEMP TABLE tmp_nom(idx int, last text) ON COMMIT DROP;
INSERT INTO tmp_nom VALUES
  (0,'Mabiala'),(1,'Ngoma'),(2,'Bakala'),(3,'Loubaki'),(4,'Mouko'),
  (5,'Ondongo'),(6,'Nkodia'),(7,'Massamba'),(8,'Kimbembé'),(9,'Bantsimba'),
  (10,'Ossébi'),(11,'Mavoungou'),(12,'Tchicaya'),(13,'Okemba'),(14,'Ngouabi'),
  (15,'Ibara'),(16,'Samba'),(17,'Milandou'),(18,'Makosso'),(19,'Ekondi'),
  (20,'Bouity'),(21,'Malonga'),(22,'Ondzé'),(23,'Moukala'),(24,'Nzaba'),
  (25,'Kouka'),(26,'Bemba'),(27,'Itoua'),(28,'Gackosso'),(29,'Mfoutou'),
  (30,'Ngakosso'),(31,'Obami');

-- L'identité de l'agent de rang `p_rang` dans l'école `p_school`.
--
-- ⚠️ Le pas est 17, pas 1. Avancer d'un cran ne changeait que le prénom — le
-- nom, lui, vit dans la division par 16 et restait figé : dix agents, dix
-- prénoms différents et un seul patronyme pour toute l'école. Avec 17, le
-- prénom avance de 1 (17 mod 16) ET le nom d'un cran : les deux bougent, et
-- l'unicité des prénoms reste garantie sur les dix rangs.
CREATE OR REPLACE FUNCTION pg_temp.identite(p_school uuid, p_rang int)
RETURNS TABLE(first text, last text)
LANGUAGE sql STABLE AS $f$
  SELECT pr.first, nm.last
  FROM (SELECT (abs(hashtext(p_school::text)) + p_rang * 17) % 512 AS k) c
  JOIN tmp_prenom pr ON pr.idx = c.k % 16
  JOIN tmp_nom    nm ON nm.idx = (c.k / 16) % 32
$f$;

-- Chef d'établissement
SELECT seed_account(
  'head:' || s.id::text, 'dir.' || lower(s.school_code) || '@epilote.cg',
  p.first, p.last,
  (CASE WHEN EXISTS (SELECT 1 FROM classes c
                      WHERE c.school_id = s.id AND c.cycle_code = 'lycee')
        THEN 'proviseur' ELSE 'directeur' END)::user_role,
  s.group_id, s.id,
  seed_uuid('ap:' || g.slug || ':directeur'), true, true, true,
  'DIR-' || s.school_code)
FROM schools s
JOIN school_groups g ON g.id = s.group_id
JOIN LATERAL pg_temp.identite(s.id, 0) p ON true
WHERE s.school_code IS NOT NULL;

-- Secrétariat, surveillance générale, comptabilité
SELECT seed_account(
  r.tag || ':' || s.id::text,
  r.tag || '.' || lower(s.school_code) || '@epilote.cg',
  p.first, p.last, r.role::user_role, s.group_id, s.id,
  seed_uuid('ap:' || g.slug || ':' || r.ap),
  r.fin, r.disc, false,
  upper(r.tag) || '-' || s.school_code)
FROM schools s
JOIN school_groups g ON g.id = s.group_id
CROSS JOIN (VALUES
  ('sec',  'secretaire',  'secretaire',  false, false, 0,   1),
  ('vs',   'surveillant', 'surveillant', false, true,  1,   2),
  ('cpt',  'comptable',   'comptable',   true,  false, 400, 3)
) AS r(tag, role, ap, fin, disc, min_cap, rang)
JOIN LATERAL pg_temp.identite(s.id, r.rang) p ON true
WHERE s.capacity >= r.min_cap;

-- Enseignants : cinq par établissement, six au-delà de 600 places.
SELECT seed_account(
  'ens:' || n.i || ':' || s.id::text,
  'ens' || n.i || '.' || lower(s.school_code) || '@epilote.cg',
  p.first, p.last, 'enseignant'::user_role, s.group_id, s.id,
  seed_uuid('ap:' || g.slug || ':enseignant'), false, false, false,
  'ENS' || n.i || '-' || s.school_code)
FROM schools s
JOIN school_groups g ON g.id = s.group_id
JOIN generate_series(1, 6) AS n(i)
  ON n.i <= (CASE WHEN s.capacity >= 600 THEN 6 ELSE 5 END)
-- Rangs 4 à 9 : à la suite de la direction, jamais sur elle.
JOIN LATERAL pg_temp.identite(s.id, 3 + n.i) p ON true;

-- ────────────────────────────────────────────────────────────────────────────
--  4. LE PROFESSEUR PRINCIPAL DE CHAQUE CLASSE
--
--  Une classe sans titulaire n'a pas de conseil de classe, et le bulletin sort
--  sans signataire.
-- ────────────────────────────────────────────────────────────────────────────

UPDATE classes c SET main_teacher_id = t.id, updated_at = now()
FROM (
  SELECT p.id, p.school_id,
         row_number() OVER (PARTITION BY p.school_id ORDER BY p.employee_number) AS rn,
         count(*)     OVER (PARTITION BY p.school_id) AS n
    FROM profiles p WHERE p.role = 'enseignant'
) t
WHERE t.school_id = c.school_id
  AND t.rn = 1 + (abs(hashtext(c.id::text)) % t.n)
  AND c.main_teacher_id IS NULL;

COMMIT;

-- ── Contrôle ────────────────────────────────────────────────────────────────
SELECT p.role, count(*) AS comptes,
       count(*) FILTER (WHERE p.access_profile_id IS NULL) AS sans_profil_acces
FROM profiles p GROUP BY p.role ORDER BY count(*) DESC;

SELECT count(*) AS classes_sans_titulaire FROM classes WHERE main_teacher_id IS NULL;
