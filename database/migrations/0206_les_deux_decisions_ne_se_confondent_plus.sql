-- ════════════════════════════════════════════════════════════════════════════
--  0206 — LES DEUX « DÉCISIONS » CESSENT DE POUVOIR S'ÉCHANGER
--
--  ── L'ÉTAT AVANT ──────────────────────────────────────────────────────────
--  Deux colonnes portent une « décision », dans deux tables, avec deux sens :
--
--    bulletins.decision                      varchar, texte libre
--      → la DISTINCTION du conseil de classe, trois fois par an
--        (felicitations, encouragements, tableau_honneur,
--         avertissement_travail, avertissement_conduite, blame)
--
--    class_enrollments.promotion_decision    text, texte libre
--      → le VERDICT ANNUEL de passage, une fois par an
--        (passe, redouble, reoriente)
--
--  Ni l'une ni l'autre n'était contrainte. Écrire un verdict de passage dans
--  la première réussissait sans un mot : `awardFor()` rend `null`, le bulletin
--  s'imprime sans distinction, et les compteurs du module Conseils restent à
--  zéro. Le sens inverse fait disparaître l'élève des listes de fin d'année.
--
--  ── L'ÉTAT DE LA PRODUCTION, VÉRIFIÉ AVANT D'ÉCRIRE CECI ──────────────────
--  bulletins.decision            : 10 616 NULL, tableau_honneur 4 804,
--                                  encouragements 2 792, avertissement_travail
--                                  1 880, felicitations 1 364 — rien d'autre.
--  promotion_decision            : 8 790 NULL, passe 1 224, redouble 350.
--  Aucune ligne en infraction : les deux contraintes se valident sans purge.
--
--  ── ⚠️ POURQUOI CETTE CONTRAINTE NE PEUT PAS CASSER LA SYNCHRO ────────────
--  Une violation de contrainte remonte en `23514`. La classe 23 est FATALE
--  dans `powersync_connector.dart` : PowerSync complète la transaction et
--  JETTE le lot. C'est le bon comportement (rejouer une violation de
--  contrainte ne réussira jamais), mais c'est cher.
--
--  Le client ne PEUT PAS produire une valeur en infraction : les cinq points
--  d'écriture passent par `distinctionConseilValide()` /
--  `verdictPassageValide()` (`lib/core/utils/decisions.dart`), qui lèvent
--  AVANT le `db.execute` — donc avant la file de synchro. La contrainte ne
--  garde que les écrivains hors Flutter : SQL manuel, Edge Function, futur
--  import. Là, un refus franc est exactement ce qu'on veut.
--
--  Miroir Dart : `lib/core/utils/decisions.dart`, tenu par
--  `test/deux_decisions_test.dart`.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.bulletins
  DROP CONSTRAINT IF EXISTS bulletins_decision_check;

ALTER TABLE public.bulletins
  ADD CONSTRAINT bulletins_decision_check
  CHECK (
    decision IS NULL
    OR decision IN (
      'felicitations',
      'encouragements',
      'tableau_honneur',
      'avertissement_travail',
      'avertissement_conduite',
      'blame'
    )
  );

COMMENT ON COLUMN public.bulletins.decision IS
  'DISTINCTION du conseil de classe (trimestrielle) : felicitations, '
  'encouragements, tableau_honneur, avertissement_travail, '
  'avertissement_conduite, blame. NE PAS confondre avec le verdict annuel de '
  'passage, qui vit dans class_enrollments.promotion_decision.';

ALTER TABLE public.class_enrollments
  DROP CONSTRAINT IF EXISTS class_enrollments_promotion_decision_check;

ALTER TABLE public.class_enrollments
  ADD CONSTRAINT class_enrollments_promotion_decision_check
  CHECK (
    promotion_decision IS NULL
    OR promotion_decision IN ('passe', 'redouble', 'reoriente')
  );

COMMENT ON COLUMN public.class_enrollments.promotion_decision IS
  'VERDICT ANNUEL de passage : passe, redouble, reoriente. NE PAS confondre '
  'avec la distinction du conseil de classe, qui vit dans bulletins.decision.';
