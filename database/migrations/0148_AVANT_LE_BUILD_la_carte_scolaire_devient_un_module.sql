-- ════════════════════════════════════════════════════════════════════════════
--  0148 — MODULE « CARTES SCOLAIRES »
--
--  ⚠️ Comme 0147, elle s'applique **AVANT** le build. Même raison : un module
--     absent du catalogue rend son écran inatteignable une fois que le garde de
--     routes le reconnaît. Voir `docs/DEPLOIEMENT_ORDRE.md`.
--
--  ── LE MANQUE ─────────────────────────────────────────────────────────────
--  La plateforme savait déjà ÉMETTRE des papiers de guichet — certificat de
--  scolarité, certificat de radiation, attestation de travail
--  (`attestation_kit.dart`). Elle ne savait pas produire le seul document que
--  l'élève PORTE : sa carte scolaire. Aucune ligne de code ne la mentionnait ;
--  elle ne figurait que dans la liste des pièces manquantes du relevé de
--  déploiement national.
--
--  Ce n'est pas une variante d'attestation. Une attestation se délivre à la
--  demande, à l'unité, pour une démarche. La carte se fabrique EN MASSE à la
--  rentrée, pour une classe entière, et sert toute l'année : au portail, dans
--  le bus, à la cantine, à l'examen.
--
--  ── LE VERROU « EXPORT » ──────────────────────────────────────────────────
--  L'écran garde l'impression par le verbe `export`, distinct de `read`.
--  Consulter l'avancement des photos d'une classe et fabriquer cent titres
--  d'identité ne sont pas le même geste : une carte scolaire ouvre un portail
--  et obtient un tarif. Le catalogue livré donne `export` aux mêmes profils que
--  pour `documents` — les profils qui délivrent déjà des papiers.
--
--  ── CE QUE CETTE MIGRATION FAIT ───────────────────────────────────────────
--  Comme 0147 : aucun droit inventé. Le module `cartes` reçoit, à l'identique,
--  les plans et les droits de `documents` — le module des pièces du dossier
--  élève, tenu par les mêmes mains, au même guichet.
--
--  ── AUCUNE TABLE NOUVELLE, ET C'EST VOULU ─────────────────────────────────
--  La carte ne stocke rien : elle se recompose à chaque impression depuis
--  `students` + `class_enrollments`. Une table « cartes_emises » serait une
--  vérité de plus à tenir d'accord avec l'inscription — et une carte
--  réimprimée après un changement de classe doit porter la NOUVELLE classe,
--  pas celle qui dormait dans une ligne.
--
--  Le journal des documents délivrés (qui a délivré quoi, quand) reste à
--  faire, pour la carte comme pour les attestations : aucune table ne le trace
--  aujourd'hui. C'est une dette assumée et écrite, pas un oubli.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1) Le module, dans SCOLARITÉ, après Documents ──────────────────────────
INSERT INTO modules (category_id, name, slug, description, icon, display_order, is_active)
SELECT c.id,
       'Cartes scolaires',
       'cartes',
       'Fabrication des cartes scolaires : planches A4 de 10 cartes au format '
       'ISO ID-1 (85,6 × 54 mm), recto-verso, avec repères de découpe. Suivi '
       'de l''avancement des photos, classe par classe.',
       '🪪',
       7,                       -- après les six modules existants de SCOLARITÉ
       true
  FROM module_categories c
 WHERE c.slug = 'scolarite'
   AND NOT EXISTS (SELECT 1 FROM modules WHERE slug = 'cartes');

-- ── 2) Les plans de `documents` ────────────────────────────────────────────
INSERT INTO plan_modules (plan_id, module_id)
SELECT pm.plan_id, np.id
  FROM plan_modules pm
  JOIN modules dm ON dm.id = pm.module_id AND dm.slug = 'documents'
  CROSS JOIN (SELECT id FROM modules WHERE slug = 'cartes') np
 WHERE NOT EXISTS (
   SELECT 1 FROM plan_modules x
    WHERE x.plan_id = pm.plan_id AND x.module_id = np.id
 );

-- ── 3) Les droits de `documents`, recopiés à l'identique ───────────────────
--  ⚠️ `can_write` est GÉNÉRÉE (elle résume create/update/delete) : l'écrire
--  lève un 428C9. Elle se recalcule seule.
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
  JOIN modules dm ON dm.id = pp.module_id AND dm.slug = 'documents'
  CROSS JOIN (SELECT id FROM modules WHERE slug = 'cartes') np
 WHERE NOT EXISTS (
   SELECT 1 FROM profile_permissions x
    WHERE x.profile_id = pp.profile_id AND x.module_id = np.id
 );

COMMIT;

-- ── AUCUNE RLS À TOUCHER ───────────────────────────────────────────────────
--  Le module ne fait que LIRE `students` et `class_enrollments`, déjà couverts
--  par `students_select` / `enrollments_select`. Il n'écrit rien. C'est la
--  raison pour laquelle il ne peut pas produire de 42501, et donc pas de lot
--  d'écritures perdu.
--
-- ── VÉRIFICATIONS ─────────────────────────────────────────────────────────
--  -- deux lignes identiques hors slug :
--  select m.slug, count(*) lignes,
--         count(*) filter (where pp.can_read)   lect,
--         count(*) filter (where pp.can_export) exp
--    from profile_permissions pp join modules m on m.id = pp.module_id
--   where m.slug in ('documents','cartes') group by 1;
--
--  -- combien d'élèves pourront réellement avoir un visage sur leur carte :
--  select count(*) total, count(photo_url) avec_photo from students;
-- ════════════════════════════════════════════════════════════════════════════
