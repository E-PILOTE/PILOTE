-- 0047 — Catalogue : catégorie EXAMENS & CERTIFICATION + module examens
--
-- Ajoute la 7e catégorie du catalogue et le module « examens » (espace école).
-- Rattachement aux plans : pro + institutionnel (le suivi des examens d'État est
-- un besoin d'établissement à classes terminales — argument commercial fort, et
-- cohérent avec le gating existant : gratuit 7 · premium 16 · pro 26 · inst. 28).
--
-- Déplace aussi « orientation » de VIE SCOLAIRE vers SCOLARITÉ : l'orientation
-- décide de la filière, donc de l'examen préparé — elle appartient au continuum
-- scolarité/examens, pas au domaine santé/cantine/discipline.
-- Sans impact sur les droits : profile_permissions pointe le MODULE, pas la
-- catégorie.
--
-- ⚠️ Les slugs de catégorie sont codés en dur côté Dart (admin_access_screen.dart)
-- -> la mise à jour du Dart accompagne cette migration dans le même commit.

BEGIN;

-- ── 1) Place la nouvelle catégorie après ÉVALUATION ────────────────────────
UPDATE module_categories SET display_order = display_order + 1, updated_at = now()
 WHERE display_order >= 4;

INSERT INTO module_categories (name, slug, icon, display_order)
SELECT 'EXAMENS & CERTIFICATION', 'examens', '📜', 4
 WHERE NOT EXISTS (SELECT 1 FROM module_categories WHERE slug = 'examens');

-- ── 2) Module ──────────────────────────────────────────────────────────────
INSERT INTO modules (category_id, name, slug, description, icon, display_order, is_active)
SELECT c.id,
       'Examens',
       'examens',
       'Classes d''examen, candidatures aux examens d''État (CEPE, BEPC, BET, '
       'Bac…), dossiers, convocations et résultats des élèves de l''école.',
       '🏅',                 -- icon = varchar(10) et TOUTES les icônes de modules
                             -- sont des emoji (pas des noms Material) : vérifié.
       1,
       true
  FROM module_categories c
 WHERE c.slug = 'examens'
   AND NOT EXISTS (SELECT 1 FROM modules WHERE slug = 'examens');

-- ── 3) Rattachement aux plans pro + institutionnel ─────────────────────────
INSERT INTO plan_modules (plan_id, module_id)
SELECT p.id, m.id
  FROM subscription_plans p
  CROSS JOIN modules m
 WHERE m.slug = 'examens'
   AND p.slug IN ('pro', 'institutionnel')
   AND NOT EXISTS (
     SELECT 1 FROM plan_modules pm WHERE pm.plan_id = p.id AND pm.module_id = m.id
   );

-- ── 4) Orientation -> SCOLARITÉ ────────────────────────────────────────────
UPDATE modules m
   SET category_id = (SELECT id FROM module_categories WHERE slug = 'scolarite'),
       updated_at = now()
 WHERE m.slug = 'orientation'
   AND m.category_id <> (SELECT id FROM module_categories WHERE slug = 'scolarite');

COMMIT;

-- ── Vérifications ──────────────────────────────────────────────────────────
-- select c.name, count(m.id) from module_categories c left join modules m on m.category_id=c.id group by 1,c.display_order order by c.display_order;
-- select p.slug, count(*) from subscription_plans p join plan_modules pm on pm.plan_id=p.id group by 1;
