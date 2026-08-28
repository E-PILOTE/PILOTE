-- ════════════════════════════════════════════════════════════════════════════
--  0145 — LA CLÔTURE SCELLE CE QU'ON DOIT CONSERVER
--
--  Cahier des charges, règle métier n°4 : « Bulletins : conservés 10 ans ·
--  Données financières : 5 ans ». `docs/ANALYSE.md` la marquait en rouge :
--  « Aucune rétention, aucune purge, aucun archivage daté nulle part ».
--
--  ── CE QUE L'OBLIGATION DEMANDE VRAIMENT ──────────────────────────────────
--  « Conservés 10 ans » est un PLANCHER, pas un plafond : le ministère doit
--  pouvoir faire rééditer un bulletin dix ans plus tard. Ce n'est pas une
--  obligation de purger, c'est une obligation de NE PAS PERDRE.
--
--  Or « interdire toute suppression pendant dix ans » serait faux dans l'autre
--  sens : une comptable qui saisit une dépense de travers doit pouvoir la
--  retirer le jour même. Une pièce comptable ne devient une PIÈCE qu'une fois
--  l'exercice arrêté.
--
--  D'où la règle, celle de toute comptabilité : on corrige dans l'exercice
--  ouvert ; une fois l'année CLOSE, plus rien ne s'efface. Le plancher des dix
--  ans est alors tenu par une propriété plus simple et plus sûre qu'une purge :
--  rien, nulle part, ne supprime en masse — aucun cron, aucune tâche, aucun
--  écran (vérifié : `epilote/test/retention_test.dart`).
--
--  ── CE QUE CETTE MIGRATION DONNE À `is_locked` ────────────────────────────
--  `academic_years.is_locked` existait et ne gardait que trois tables de
--  calendrier (`trimesters`, `sequences`, `school_holidays`), via un
--  déclencheur qui LÈVE un 42501. Ici, le sceau passe par `USING` : sans droit,
--  la ligne n'est pas VUE par l'ordre — zéro ligne touchée, aucun code fatal,
--  aucun lot PowerSync perdu.
--
--    bulletins          l'année close, un bulletin ne s'efface plus (10 ans)
--    expenses           l'année close, une dépense est une pièce (5 ans)
--    student_payments   l'année close, un encaissement est une pièce (5 ans)
--
--  ── AUCUN ÉCRAN NE PEUT ÉCHOUER EN SILENCE ────────────────────────────────
--  Vérifié avant d'écrire :
--    • `bulletins` et `student_payments` ne sont supprimés PAR AUCUN code Dart
--      — annuler un paiement change son statut, il ne l'efface pas ;
--    • `depenses_screen` compose déjà `canDelete && !readOnly`, et `readOnly`
--      vaut vrai dès que l'année est verrouillée. L'écran refuse donc avant la
--      base, avec son propre message.
--
--  Et l'état du jour rend le sceau inerte : 14 années scolaires, ZÉRO
--  verrouillée ; la donnée la plus ancienne date du 2 août 2026.
--
--  ── CE QUE CETTE MIGRATION NE FAIT PAS, ET POURQUOI ───────────────────────
--  ⚠️ `payroll` n'est PAS scellée. Elle ne porte pas `academic_year_id` (elle
--  est datée par `period_month`/`period_year`), et `paie_screen` ne lit pas
--  `yearReadOnlyProvider` — à juste titre, puisque la table n'a pas d'année.
--  Un sceau par `USING` y produirait donc une suppression qui ne supprime rien,
--  sans message : exactement le silence qu'on cherche à éliminer. À traiter
--  quand la paie sera rattachée à l'exercice.
--
--  ⚠️ AUCUNE PURGE N'EST INTRODUITE. Effacer des dossiers d'élèves après N mois
--  est un acte juridique, pas un réglage technique — et l'écran « Conservation
--  des données » de l'admin groupe proposait précisément ce réglage sans que
--  rien ne le lise. Le même commit cesse de le prétendre.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.annee_scellee(p_annee uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT COALESCE(
    (SELECT ay.is_locked FROM academic_years ay WHERE ay.id = p_annee),
    false);
$fn$;

COMMENT ON FUNCTION public.annee_scellee(uuid) IS
  'Vrai quand l''année scolaire est déclarée close. Une pièce qui lui '
  'appartient ne s''efface alors plus (migration 0145).';

DO $migration$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('bulletins',        'bulletins_delete'),
      ('expenses',         'expenses_delete'),
      ('student_payments', 'payments_delete')
    ) AS v(t, pol)
  LOOP
    -- On RECOMPOSE la politique existante : le verbe de module reste, le sceau
    -- s'y ajoute. Sans cela, durcir la conservation rouvrirait les droits.
    EXECUTE format(
      'ALTER POLICY %I ON %I USING ((%s) AND NOT (SELECT public.annee_scellee(academic_year_id)))',
      r.pol, r.t,
      (SELECT qual FROM pg_policies
       WHERE schemaname = 'public' AND tablename = r.t AND policyname = r.pol));
  END LOOP;
END
$migration$;

COMMENT ON COLUMN academic_years.is_locked IS
  'Année déclarée close. Depuis la migration 0145, elle SCELLE ses pièces : '
  'bulletins, dépenses et encaissements de cette année ne peuvent plus être '
  'supprimés. C''est ainsi que le plancher de conservation (10 ans / 5 ans) '
  'est tenu — par l''absence de suppression, jamais par une purge.';
