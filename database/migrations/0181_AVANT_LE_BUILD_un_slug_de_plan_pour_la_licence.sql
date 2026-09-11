-- ════════════════════════════════════════════════════════════════════════════
--  0181 — UN SLUG DE PLAN POUR LA LICENCE
--
--  `subscription_plans.slug` est un ENUM (`plan_slug`), pas du texte : créer le
--  plan « Licence de tutelle » suppose d'abord d'ouvrir la valeur.
--
--  ⚠️ POURQUOI CETTE MIGRATION EST SEULE. `ALTER TYPE ... ADD VALUE` ajoute la
--  valeur, mais PostgreSQL INTERDIT de l'UTILISER dans la même transaction —
--  « unsafe use of new value of enum type ». Le plan se crée donc en 0182.
--  Deux fichiers pour deux lignes : c'est la contrainte du moteur, pas un
--  découpage de confort.
--
--  ── ORDRE : AVANT LE BUILD. Purement additif. ─────────────────────────────
-- ════════════════════════════════════════════════════════════════════════════

ALTER TYPE public.plan_slug ADD VALUE IF NOT EXISTS 'licence';
