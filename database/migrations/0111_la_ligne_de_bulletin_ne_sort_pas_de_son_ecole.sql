-- ════════════════════════════════════════════════════════════════════════════
--  0111 — LA LIGNE DE BULLETIN NE SORT PAS DE SON ÉCOLE
--
--  ── LE PROBLÈME ────────────────────────────────────────────────────────────
--  `bulletin_subject_lines` porte le détail matière par matière de chaque
--  bulletin : la moyenne de l'élève, celle de la classe, son rang. C'est la
--  table la plus volumineuse du schéma — 143 569 lignes aujourd'hui, et elle
--  grossit d'environ 56 000 lignes par année et par groupe de 14 écoles.
--
--  Sa règle RLS autorisait TOUT LE GROUPE :
--      is_super_admin() OR group_id = auth_group_id()
--
--  Son parent, `bulletins`, dit exactement l'inverse :
--      group_id = auth_group_id()
--      AND (is_admin_groupe() OR school_id = auth_school_id())
--
--  Autrement dit, l'en-tête du bulletin était protégé école par école, et les
--  NOTES qu'il contient ne l'étaient pas. Un enfant ne peut pas être moins
--  protégé que la couverture de son relevé.
--
--  ⚠️ Les sync-rules, elles, avaient DÉJÀ été corrigées : elles filtrent
--  `WHERE school_id = bucket.sid` depuis que la colonne existe (c'est même la
--  correction qui a fait tomber 55 886 lignes par poste à environ 3 %). La
--  faille n'était donc pas dans ce qui descend sur les appareils, mais dans ce
--  qu'une requête PostgREST authentifiée pouvait demander directement. Deux
--  verrous, un seul avait été tourné.
--
--  ── CE QUE POSE CETTE MIGRATION ────────────────────────────────────────────
--  La règle de l'enfant devient CELLE DU PARENT, mot pour mot : une ligne est
--  lisible exactement quand son bulletin l'est.
--
--  ⚠️ CELA RETIRE AUSSI LA BRANCHE `is_super_admin()`, et c'est délibéré.
--
--   · `bulletins`, `grades` et `evaluations` ne l'ont pas. La garder ici
--     laisserait un super_admin lire les notes de tous les élèves du pays sans
--     pouvoir lire l'en-tête du relevé qui les porte — incohérent, et du
--     mauvais côté : ce sont les LIGNES qui portent la donnée sensible.
--   · Aucun appelant ne la perd. Rien dans l'application n'interroge cette
--     table par Supabase : le seul code qui la touche est
--     `bulletins_provider.dart`, en local (`db.execute`), donc par PowerSync.
--     Les Edge Functions passent par `service_role`, qui ignore la RLS.
--
--  Si un besoin de STATISTIQUES NATIONALES sur les notes apparaît un jour, il
--  se traite par une fonction `SECURITY DEFINER` qui rend des agrégats — pas
--  en rouvrant la lecture nominative de 143 000 lignes à un rôle de console.
--
--  ── CE QUE CETTE MIGRATION NE TOUCHE PAS ───────────────────────────────────
--  · La SYNCHRO. PowerSync réplique par le slot logique et évalue ses propres
--    sync-rules ; la RLS ne s'applique pas à ce chemin. Rien à redéployer.
--  · L'ÉCRITURE. Le personnel écrit ses lignes avec le `school_id` de son
--    école (`bulletins_provider.dart` estampe les deux colonnes depuis les
--    mêmes locales que l'en-tête) : le `WITH CHECK` passe.
--  · Les INDEX. `idx_bsl_school` existe déjà ; le prédicat est couvert.
--
--  État avant : 143 569 lignes, 0 sans école, 0 sans groupe, 0 divergence de
--  `school_id` avec le bulletin parent.
--
--  ── NON FAIT, ET POURQUOI ──────────────────────────────────────────────────
--  On aurait pu DÉRIVER `school_id`/`group_id` du bulletin parent par trigger,
--  comme le fait `student_tutors` depuis 0110. Ce n'est pas repris ici : le
--  client estampe déjà les deux colonnes, elles sont NOT NULL, et la prod ne
--  montre aucune divergence. Ce serait une ceinture en plus d'une bretelle qui
--  tient — à poser le jour où une divergence apparaît, pas avant.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

DROP POLICY IF EXISTS bulletin_subject_lines_tenant ON public.bulletin_subject_lines;

CREATE POLICY bulletin_subject_lines_tenant ON public.bulletin_subject_lines
  FOR ALL
  USING (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))
  );

COMMIT;
