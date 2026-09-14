-- ════════════════════════════════════════════════════════════════════════════
--  LE MINISTÈRE TECHNIQUE NE VOYAIT AUCUN ÉTABLISSEMENT PRIVÉ
--
--  ⚠️ LOT DE DONNÉES DE DÉMONSTRATION — pas un changement de schéma.
--  Rejouable : toutes les clés passent par `seed_uuid()`, tous les INSERT
--  portent `ON CONFLICT DO NOTHING`.
--
--  ── CE QUI A ÉTÉ CONSTATÉ (2026-09-07) ────────────────────────────────────
--  Sept groupes en base. Trois privés — TOUS LES TROIS sous MEPSA. L'écran
--  « Réseau » du METP affichait donc UNE ligne : lui-même. Or le METP a la
--  tutelle des établissements techniques PRIVÉS, et c'est là que se joue
--  l'essentiel de son travail : agréer, inspecter, retirer un agrément.
--
--  Trois colonnes étaient vides sur la totalité du parc et se voyaient à
--  l'écran : `director_id` (la SEULE donnée nominative que la tutelle a le
--  droit de voir), `institution_type_id` (référentiel CET / lycée technique /
--  lycée pro / centre de métiers, zéro école reliée) et `inspection_id`
--  (circonscriptions inexistantes).
--
--  ════════════════════════════════════════════════════════════════════════
--   LES CINQ PIÈGES RENCONTRÉS — chacun a fait échouer une première écriture
--  ════════════════════════════════════════════════════════════════════════
--
--  1. ⚠️ `tutelle_groupes()` FILTRE SUR `schools.tutelle`, PAS SUR CELLE DU
--     GROUPE :  `WHERE (v_tutelle IS NULL OR s.tutelle = v_tutelle)`
--     Un groupe en `metp` dont les écoles resteraient en `mepsa` serait
--     INVISIBLE. (En pratique `fn_school_herite_tutelle` la recopie depuis le
--     groupe — mais compter là-dessus sans le savoir, c'est un coup de chance.)
--
--  2. ⚠️ `fn_school_herite_agrement` ÉCRASE SANS CONDITION l'agrément de
--     l'école par celui de son groupe, en BEFORE INSERT **ET** UPDATE. Une
--     école ne peut donc PAS avoir son propre numéro, ni être non agréée dans
--     un groupe agréé. L'agrément est un attribut du GROUPE ; on s'y range.
--     ⓘ Conséquence à connaître : `nb_ecoles_agreees` de `tutelle_groupes()`
--     ne peut valoir que 0 ou `nb_ecoles`. La colonne suggère une finesse que
--     le modèle n'autorise pas. À revoir si la tutelle demande un jour à
--     suspendre l'agrément d'un seul établissement d'un réseau.
--     ⓘ Corollaire : pour changer l'agrément d'un groupe, il faut TOUCHER les
--     écoles (`UPDATE schools SET updated_at = now()`) — le trigger est sur
--     `schools`, il ne se déclenche pas quand on modifie le groupe.
--
--  3. ⚠️ `fn_auto_create_invoice` se déclenche à l'insertion d'un groupe et
--     fait `COALESCE(NEW.created_by, auth.uid())` sur une colonne NOT NULL.
--     Depuis une console (pas de session, `auth.uid()` nul), OUBLIER
--     `created_by` fait échouer l'insertion avec une erreur qui parle de
--     `group_invoices` — pas du groupe qu'on croyait insérer.
--
--  4. ⚠️ `fn_guard_active_requires_payment` REFUSE `subscription_status =
--     'active'` tant qu'aucune facture `paid` ne couvre `subscription_end`.
--     C'est une bonne règle : on ne la contourne pas. Séquence correcte —
--     créer en `trial`, émettre la facture réglée, PUIS activer.
--
--  5. ⚠️ `schools.location_source` n'accepte que `gps | geocoded | manual`.
--     Pas de valeur française. Sans coordonnées ET sans source valide, une
--     école n'apparaît pas sur la carte du tableau de bord.
--
--  ── ⚠️ LES COMPTES CRÉÉS PEUVENT SE CONNECTER ─────────────────────────────
--  `profiles.id` référence `auth.users(id)` : impossible de créer un agent
--  sans compte d'authentification. On passe donc par `seed_account()`, la
--  routine du dépôt qui a créé les 346 profils existants — elle porte SON
--  PROPRE mot de passe de démonstration en dur dans son corps.
--  → 66 comptes de démonstration ajoutés ici. À PURGER avant le déploiement
--    des cinq premiers établissements réels.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── 1. Trois groupes privés, trois états d'agrément ────────────────────────
-- définitif / provisoire / aucun. Un écran qui n'affiche que des cas conformes
-- ne prouve pas qu'il sait montrer un manquement — et « non agréé » est
-- exactement ce qu'une tutelle cherche dans sa liste.
-- (Créés en `trial` — voir piège n°4 ; activés plus bas, après règlement.)
INSERT INTO school_groups
  (id, name, slug, group_type, tutelle, caractere, department, plan_id,
   subscription_status, subscription_start, subscription_end, admin_email, phone,
   address, is_active, founded_year, agrement_numero, agrement_type, agrement_date,
   payment_confirmed, billed_schools, created_by)   -- ⚠️ created_by : piège n°3
VALUES
  (seed_uuid('group:metp_saint_joseph'), 'Groupe Scolaire Technique Saint-Joseph',
   'gst-saint-joseph', 'prive', 'metp', 'catholique', 'Brazzaville',
   (SELECT id FROM subscription_plans WHERE name = 'Pro'),
   'trial', DATE '2025-10-01', DATE '2026-09-30', 'direction@gst-saintjoseph.cg',
   '+242 06 512 40 18', 'Avenue de la Paix, Moungali, Brazzaville', true, 1978,
   'METP/AG/2019-0147', 'definitif', DATE '2019-03-12', true, 3,
   '9e706bea-b4a2-49db-9dcd-4cd1e7c1b6db'),
  (seed_uuid('group:metp_fraternite'), 'Complexe Professionnel La Fraternité',
   'cp-la-fraternite', 'prive', 'metp', 'protestant', 'Pointe-Noire',
   (SELECT id FROM subscription_plans WHERE name = 'Standard'),
   'trial', DATE '2025-10-01', DATE '2026-09-30', 'secretariat@cp-fraternite.cg',
   '+242 05 334 71 92', 'Boulevard de Loango, Tié-Tié, Pointe-Noire', true, 1994,
   'METP/AG/2021-0233', 'provisoire', DATE '2021-07-05', true, 2,
   '9e706bea-b4a2-49db-9dcd-4cd1e7c1b6db'),
  -- Sans agrément : dossier en cours d'instruction. C'est le cas non conforme.
  (seed_uuid('group:metp_nsangu'), 'Centre de Formation Technique Nsangu',
   'cft-nsangu', 'prive', 'metp', 'laic', 'Niari',
   (SELECT id FROM subscription_plans WHERE name = 'Standard'),
   'trial', DATE '2026-01-15', DATE '2026-10-31', 'contact@cft-nsangu.cg',
   '+242 06 887 25 40', 'Quartier Mbounda, Dolisie', true, 2015,
   NULL, NULL, NULL, true, 2, '9e706bea-b4a2-49db-9dcd-4cd1e7c1b6db')
ON CONFLICT (id) DO NOTHING;

-- ─── 2. Sept établissements ─────────────────────────────────────────────────
-- ⚠️ `location_source = 'manual'` (piège n°5). Les coordonnées sont celles des
-- chefs-lieux réels : sans elles, l'école n'existe pas sur la carte.
-- L'agrément n'est PAS renseigné ici : il est hérité du groupe (piège n°2).
WITH d(cle, grp, nom, code, ville, dept, type_code, adr, mail, tel, an, cap, lat, lon) AS (VALUES
 ('school:sj_industriel','group:metp_saint_joseph','Lycée Technique Saint-Joseph Industriel','SJ-IND','Brazzaville','Brazzaville','LYCEE_TECHNIQUE','Avenue de la Paix, Moungali','industriel@gst-saintjoseph.cg','+242 06 512 40 20',1978,520,-4.2634,15.2429),
 ('school:sj_commercial','group:metp_saint_joseph','Lycée Professionnel Saint-Joseph Commercial','SJ-COM','Brazzaville','Brazzaville','LYCEE_PROFESSIONNEL','Rue Mbochis, Ouenzé','commercial@gst-saintjoseph.cg','+242 06 512 40 21',1991,380,-4.2489,15.2836),
 ('school:sj_metiers','group:metp_saint_joseph','Centre de Métiers Saint-Joseph','SJ-CM','Kinkala','Pool','CENTRE_METIERS','Route de Kinkala','metiers@gst-saintjoseph.cg','+242 06 512 40 22',2008,240,-4.3614,14.7644),
 ('school:fr_technique','group:metp_fraternite','Collège d''Enseignement Technique La Fraternité','FR-CET','Pointe-Noire','Pointe-Noire','CET','Boulevard de Loango, Tié-Tié','cet@cp-fraternite.cg','+242 05 334 71 93',1994,430,-4.7889,11.8636),
 ('school:fr_hotellerie','group:metp_fraternite','École Hôtelière La Fraternité','FR-HOT','Pointe-Noire','Kouilou','CENTRE_METIERS','Avenue Charles de Gaulle','hotellerie@cp-fraternite.cg','+242 05 334 71 94',2011,190,-4.7692,11.8664),
 ('school:ns_dolisie','group:metp_nsangu','Centre Technique Nsangu de Dolisie','NS-DOL','Dolisie','Niari','CENTRE_METIERS','Quartier Mbounda','dolisie@cft-nsangu.cg','+242 06 887 25 41',2015,210,-4.1997,12.6667),
 ('school:ns_ouenze','group:metp_nsangu','Centre Technique Nsangu de Ouenzé','NS-OUE','Brazzaville','Brazzaville','CENTRE_METIERS','Rue Bounda, Ouenzé','ouenze@cft-nsangu.cg','+242 06 887 25 42',2024,120,-4.2431,15.2903))
INSERT INTO schools (id, group_id, name, school_type, tutelle, school_code, city,
  department, department_id, institution_type_id, address, email, phone,
  founded_year, capacity, latitude, longitude, location_source, is_active)
SELECT seed_uuid(d.cle), seed_uuid(d.grp), d.nom, 'prive', 'metp', d.code, d.ville, d.dept,
       (SELECT id FROM departments WHERE name = d.dept),
       (SELECT id FROM institution_types WHERE code = d.type_code AND tutelle = 'metp'),
       d.adr, d.mail, d.tel, d.an, d.cap, d.lat, d.lon, 'manual', true
FROM d
ON CONFLICT (id) DO NOTHING;

-- ─── 3. Règlement puis activation (piège n°4, dans cet ordre) ───────────────
INSERT INTO group_invoices
  (group_id, invoice_number, amount_xaf, period_start, period_end, plan_id,
   status, paid_at, payment_method, payment_reference, receipt_number, notes, created_by)
VALUES
  (seed_uuid('group:metp_saint_joseph'), 'INV-2026-0051', 1800000,
   DATE '2025-10-01', DATE '2026-09-30', (SELECT id FROM subscription_plans WHERE name='Pro'),
   'paid', TIMESTAMPTZ '2025-10-04 10:22:00+01', 'especes', 'Versement caisse Brazzaville',
   'REC-2026-0051', 'Assiette : 3 ecole(s). Annee scolaire 2025-2026.',
   '9e706bea-b4a2-49db-9dcd-4cd1e7c1b6db'),
  (seed_uuid('group:metp_fraternite'), 'INV-2026-0052', 720000,
   DATE '2025-10-01', DATE '2026-09-30', (SELECT id FROM subscription_plans WHERE name='Standard'),
   'paid', TIMESTAMPTZ '2025-10-09 14:05:00+01', 'mtn_money', 'MTN-8842013975',
   'REC-2026-0052', 'Assiette : 2 ecole(s). Annee scolaire 2025-2026.',
   '9e706bea-b4a2-49db-9dcd-4cd1e7c1b6db')
ON CONFLICT DO NOTHING;

-- Nsangu reste en `trial` avec sa facture en attente : le troisième cas, celui
-- d'un groupe qui n'a pas encore réglé. L'écran Abonnements a besoin de le voir.
UPDATE school_groups SET subscription_status = 'active'
 WHERE id IN (seed_uuid('group:metp_saint_joseph'), seed_uuid('group:metp_fraternite'));

-- ─── 4. Les trois colonnes qui étaient vides sur TOUT le parc ───────────────
-- a) Type d'établissement : déduit du nom, qui le porte déjà. Rien n'est
--    inventé — on relie ce qui était écrit.
UPDATE schools s SET institution_type_id = (
  SELECT it.id FROM institution_types it
   WHERE it.tutelle = 'metp'
     AND it.code = CASE WHEN s.name ILIKE 'Collège d%Enseignement Technique%'
                        THEN 'CET' ELSE 'LYCEE_TECHNIQUE' END)
WHERE s.tutelle = 'metp' AND s.institution_type_id IS NULL;

-- b) Circonscriptions d'inspection technique. ⚠️ `cycle_scope` n'accepte que
--    `primaire | secondaire` (contrainte `inspections_cycle_scope_chk`) —
--    « technique_professionnel » est refusé.
INSERT INTO inspections (id, department_id, code, name, tutelle, cycle_scope, chef_lieu, is_active)
SELECT seed_uuid('insp:' || d.name), d.id,
       'IET-' || upper(substr(translate(d.name, 'ÉÈÊÀÂÔÛÇ- ', 'EEEAAOUC'), 1, 4)),
       'Inspection de l''Enseignement Technique — ' || d.name,
       'metp', 'secondaire', d.name, true
FROM departments d
WHERE d.name IN ('Brazzaville','Pointe-Noire','Niari','Pool','Kouilou','Bouenza',
                 'Sangha','Cuvette','Plateaux','Lékoumou')
ON CONFLICT (id) DO NOTHING;

UPDATE schools s SET inspection_id = (
  SELECT i.id FROM inspections i
   WHERE i.tutelle = 'metp' AND i.department_id = s.department_id LIMIT 1)
WHERE s.tutelle = 'metp' AND s.inspection_id IS NULL;

-- c) Chef d'établissement des écoles PUBLIQUES : choisi parmi leur propre
--    personnel dirigeant. On ne crée personne — on nomme quelqu'un qui
--    existait déjà et que l'écran ignorait.
UPDATE schools s SET director_id = (
  SELECT p.id FROM profiles p
   WHERE p.school_id = s.id AND p.is_active AND p.role IN ('proviseur','directeur')
   ORDER BY CASE p.role WHEN 'proviseur' THEN 0 ELSE 1 END, p.created_at LIMIT 1)
WHERE s.tutelle = 'metp' AND s.school_type = 'public' AND s.director_id IS NULL;

-- ⚠️ Le reste du lot — personnel des écoles privées (66 comptes via
-- `seed_account`), niveaux tirés du référentiel `formation_pro`, classes,
-- 1 057 élèves, circulaires, stages, orientations, appel, discipline,
-- infirmerie et cantine — a été appliqué le 2026-09-07 par la même session.
-- Volumes et raisonnement : docs/memoire/donnees-demonstration-metp.md
