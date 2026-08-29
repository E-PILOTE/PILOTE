-- ════════════════════════════════════════════════════════════════════════════
--  0147 — LA DÉLIBÉRATION DE FIN D'ANNÉE DEVIENT UN MODULE
--
--  ⚠️ CELLE-CI S'APPLIQUE **AVANT** LE BUILD, à l'inverse de 0139/0142/0146.
--     La raison est expliquée en bas ; s'y tromper rend la délibération
--     INACCESSIBLE à toute l'école.
--
--  ── LE TROU ───────────────────────────────────────────────────────────────
--  L'écran Passage (`/user/passage`) rend le verdict annuel : il écrit
--  `class_enrollments.promotion_decision` — qui passe, qui redouble — puis
--  réinscrit en masse dans l'année suivante. C'est l'écriture la plus lourde
--  de conséquence de toute l'année scolaire.
--
--  Il n'était dans AUCUN catalogue. Le parc compte 33 modules ; `passage` n'en
--  fait pas partie. Or le garde de routes (`app_router`, verrous 2/3/4) ne
--  s'arme que si `moduleSlugForLocation()` reconnaît la page. Slug inconnu =
--  « route native » = traitée comme le Tableau de bord ou le Profil :
--
--    • aucun verrou de profil d'accès — le droit `conseils.update` gardait le
--      BOUTON, pas la PAGE ;
--    • aucun verrou de plan — le module n'est vendu dans aucun plan ;
--    • aucun verrou d'impayé — la seule page que le mur de renouvellement
--      laisse passer alors qu'elle décide de l'avenir des élèves ;
--    • et pas de ligne dans la barre latérale : la délibération n'était
--      atteignable que par un bouton au fond de l'écran Conseils de classe.
--
--  La RLS, elle, tenait (`enrollments_update` exige un verbe sur l'un de
--  inscriptions/eleves/conseils/transferts/discipline). Le danger n'était donc
--  pas l'écriture illégitime en base : c'est qu'un poste SANS ce verbe écrivait
--  quand même EN LOCAL, voyait le verdict s'afficher, et se le faisait jeter au
--  téléversement. Le conseil croit avoir délibéré. Rien n'est parti.
--
--  ── CE QUE CETTE MIGRATION FAIT ───────────────────────────────────────────
--  Elle ne DONNE aucun droit nouveau à personne. Elle recopie, à l'identique,
--  ce que chaque profil détient déjà sur `conseils` — le module qui garde
--  aujourd'hui l'accès à la délibération. Qui pouvait délibérer hier le peut
--  encore demain, ni plus ni moins. C'est la seule recopie qui ne change le
--  pouvoir de personne, et c'est pour cela qu'elle est choisie plutôt qu'un
--  jeu de droits « raisonnable » écrit à la main.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1) Le module, à côté des Conseils de classe ────────────────────────────
INSERT INTO modules (category_id, name, slug, description, icon, display_order, is_active)
SELECT c.id,
       'Passage en classe supérieure',
       'passage',
       'Délibération de fin d''année : moyenne annuelle des trois trimestres, '
       'verdict (passe / redouble / réorienté), réinscription en masse dans '
       'l''année suivante, clôture des classes d''examen et détection des '
       'élèves non revenus.',
       '🎓',
       4,                       -- après notes (1), bulletins (2), conseils (3)
       true
  FROM module_categories c
 WHERE c.slug = 'evaluation'
   AND NOT EXISTS (SELECT 1 FROM modules WHERE slug = 'passage');

-- ── 2) Les plans : exactement ceux qui vendent déjà `conseils` ─────────────
--  Sans cette ligne, le verrou de plan (entitlement) barre la page à tout le
--  monde dès que les clés de licence seront provisionnées.
INSERT INTO plan_modules (plan_id, module_id)
SELECT pm.plan_id, np.id
  FROM plan_modules pm
  JOIN modules cm ON cm.id = pm.module_id AND cm.slug = 'conseils'
  CROSS JOIN (SELECT id FROM modules WHERE slug = 'passage') np
 WHERE NOT EXISTS (
   SELECT 1 FROM plan_modules x
    WHERE x.plan_id = pm.plan_id AND x.module_id = np.id
 );

-- ── 3) Les droits : la recopie à l'identique de `conseils` ─────────────────
--  Les verbes ET le périmètre de données (`data_scope`) sont repris tels
--  quels. Un enseignant limité à `own_classes` sur les conseils reste limité
--  à ses classes sur la délibération.
--
--  ⚠️ `can_write` est une colonne GÉNÉRÉE (elle résume create/update/delete) :
--  l'écrire lève un 428C9. Elle se recalcule seule, et c'est heureux — la
--  recopier aurait pu la désaccorder de ses trois sources.
INSERT INTO profile_permissions (
  profile_id, module_id, group_id,
  can_read, can_create, can_update, can_delete, can_export,
  can_import, can_validate, can_approve, can_manage,
  data_scope
)
SELECT pp.profile_id, np.id, pp.group_id,
       pp.can_read, pp.can_create, pp.can_update, pp.can_delete, pp.can_export,
       pp.can_import, pp.can_validate, pp.can_approve, pp.can_manage,
       pp.data_scope
  FROM profile_permissions pp
  JOIN modules cm ON cm.id = pp.module_id AND cm.slug = 'conseils'
  CROSS JOIN (SELECT id FROM modules WHERE slug = 'passage') np
 WHERE NOT EXISTS (
   SELECT 1 FROM profile_permissions x
    WHERE x.profile_id = pp.profile_id AND x.module_id = np.id
 );

-- ── 4) La RLS doit connaître le nouveau nom ────────────────────────────────
--  `enrollments_insert/update` énumère les modules qui autorisent à toucher une
--  inscription. `passage` doit y figurer, sinon un profil à qui l'on donnerait
--  demain « Passage » SANS « Conseils » écrirait en local et se ferait jeter en
--  42501 — code fatal, qui EMPORTE tout le lot d'écritures en attente du poste.
--  Ce n'est pas un desserrage : `passage` ne sera jamais accordé plus largement
--  que `conseils` par l'étape 3, et un profil qui détient `conseils` passait
--  déjà.
DROP POLICY IF EXISTS enrollments_insert ON class_enrollments;
CREATE POLICY enrollments_insert ON class_enrollments
  FOR INSERT
  WITH CHECK (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe())
             OR (school_id = (SELECT auth_school_id())
                 AND (SELECT auth_module_permet(
                        ARRAY['inscriptions', 'eleves', 'conseils', 'passage',
                              'transferts', 'discipline'], 'create')))))
  );

DROP POLICY IF EXISTS enrollments_update ON class_enrollments;
CREATE POLICY enrollments_update ON class_enrollments
  FOR UPDATE
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe())
             OR (school_id = (SELECT auth_school_id())
                 AND (SELECT auth_module_permet(
                        ARRAY['inscriptions', 'eleves', 'conseils', 'passage',
                              'transferts', 'discipline'], 'update')))))
  )
  WITH CHECK (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
--  ── POURQUOI « AVANT LE BUILD » ET NON « APRÈS » ──────────────────────────
--  Les deux ordres ne coûtent pas la même chose :
--
--    base d'abord (CE QU'IL FAUT FAIRE)
--      Ancien build : une entrée « Passage » apparaît dans la barre latérale et
--      mène au gîte générique `/user/m/passage` (« en cours de développement »).
--      Le vrai écran reste atteignable par le bouton des Conseils de classe.
--      Coût : une entrée redondante pendant l'intervalle. Rien ne casse.
--
--    build d'abord (CE QU'IL NE FAUT PAS FAIRE)
--      Le nouveau build reconnaît `/user/passage` comme module et exige
--      `passage.can_read` — que personne ne possède encore. Le bouton « Ouvrir
--      la délibération » renvoie tout le monde au tableau de bord.
--      Coût : la délibération est impossible dans toutes les écoles.
--
--  ── VÉRIFICATIONS ─────────────────────────────────────────────────────────
--  -- doit rendre deux lignes RIGOUREUSEMENT identiques (hors slug) :
--  select m.slug, count(*) lignes,
--         count(*) filter (where pp.can_read)   lect,
--         count(*) filter (where pp.can_update) maj,
--         count(*) filter (where pp.data_scope = 'own_classes') mes_classes
--    from profile_permissions pp join modules m on m.id = pp.module_id
--   where m.slug in ('conseils','passage') group by 1;
--
--  -- doit rendre les mêmes plans :
--  select m.slug, string_agg(p.slug, ', ' order by p.slug)
--    from modules m join plan_modules pm on pm.module_id = m.id
--    join subscription_plans p on p.id = pm.plan_id
--   where m.slug in ('conseils','passage') group by 1;
-- ════════════════════════════════════════════════════════════════════════════
