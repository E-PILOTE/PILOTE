-- ════════════════════════════════════════════════════════════════════════════
--  0144 — UN JOURNAL QUI NE NOTAIT QUE LES ACTES ADMINISTRATIFS
--
--  ── L'ÉTAT DES LIEUX, MESURÉ ──────────────────────────────────────────────
--  `audit_logs` : 82 lignes, 6 tables, depuis le 4 août — sur 37 écoles.
--  Il est alimenté par 14 fonctions `SECURITY DEFINER` et 3 déclencheurs, tous
--  écrits à la main, et tous du côté ADMINISTRATIF et EN LIGNE : cycle de vie
--  d'un agent, permissions d'un profil, tarifs, calendrier, emploi du temps.
--
--  Rien, ou presque, du côté ÉCOLE — celui où une secrétaire et un professeur
--  agissent chaque jour, hors ligne. Or c'est là que se prennent les décisions
--  qu'on conteste : une note changée après coup, un paiement annulé, un élève
--  retiré d'une classe, une sanction ajoutée à un dossier.
--
--  ── CE QUI EST NOTÉ, ET POURQUOI PAS LE RESTE ─────────────────────────────
--  UPDATE et DELETE seulement, jamais INSERT. Créer une note est le geste
--  normal du métier ; la CHANGER après coup, ou l'effacer, est le geste qu'on
--  vient demander des comptes. Ce choix divise le volume par vingt et garde
--  exactement ce qui se conteste.
--
--    grades                 une note modifiée ou effacée après coup
--    evaluations            supprimer une évaluation détruit toutes ses notes
--    bulletins              publication, dépublication, effacement
--    class_enrollments      retirer un enfant d'une classe
--    students               modifier ou effacer une identité d'élève
--    discipline_incidents   une sanction portée au dossier d'un enfant
--    student_payments       un encaissement annulé ou remboursé
--    payroll                un bulletin de salaire réécrit
--    class_subjects         un coefficient — il repondère toute une moyenne
--    school_levels          `pass_mark` : qui passe et qui redouble
--
--  ── TROIS PROPRIÉTÉS SANS LESQUELLES UN JOURNAL NUIT ──────────────────────
--
--  1. IL NE LÈVE JAMAIS. Tout le corps est sous `EXCEPTION WHEN OTHERS THEN
--     RETURN`. Une erreur du journal remonterait comme un code d'erreur de
--     l'écriture métier — et `23xxx` / `42501` sont FATALS pour le connecteur
--     PowerSync, qui jette le LOT ENTIER en attente. Un journal ne doit jamais
--     coûter la donnée qu'il observe.
--
--  2. IL SE TAIT QUAND PERSONNE N'AGIT. `auth.uid() IS NULL` ⇒ on sort : les
--     tâches serveur et les migrations n'ont pas d'auteur, et les inscrire
--     serait mentir. Cette garde n'est pas théorique — une seule migration a
--     touché 431 250 notes en une minute le 2 août. Sans elle, le journal
--     naîtrait avec un demi-million de lignes que personne n'a écrites.
--
--  3. IL N'ENREGISTRE QUE CE QUI A BOUGÉ. `old_values` et `new_values` ne
--     portent que les colonnes RÉELLEMENT différentes, `updated_at` exclue. Un
--     journal qui recopie la ligne entière à chaque fois devient illisible
--     précisément le jour où on en a besoin.
--
--  ── LA SYNCHRO N'EST PAS TOUCHÉE ──────────────────────────────────────────
--  Les sync-rules ne descendent `audit_logs` que pour les trois tables de
--  l'emploi du temps (`table_name = 'timetable_*'`). Les lignes créées ici ne
--  correspondent à aucun de ces filtres : elles restent au serveur, et aucun
--  poste ne reçoit le journal des autres. Aucune règle de synchro à redéployer.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_audit_metier()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  acteur   uuid;
  r_role   public.user_role;
  j_old    jsonb;
  j_new    jsonb;
  diff_old jsonb := '{}'::jsonb;
  diff_new jsonb := '{}'::jsonb;
  cle      text;
BEGIN
  acteur := auth.uid();
  -- Personne n'agit : migration, tâche serveur, Edge Function. On se tait.
  IF acteur IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT role INTO r_role FROM public.profiles WHERE id = acteur;

  IF TG_OP = 'DELETE' THEN
    j_old := to_jsonb(OLD);
    INSERT INTO public.audit_logs (
      group_id, school_id, user_id, user_role, action, table_name,
      record_id, old_values, new_values
    ) VALUES (
      (j_old ->> 'group_id')::uuid, (j_old ->> 'school_id')::uuid,
      acteur, r_role, 'DELETE', TG_TABLE_NAME,
      (j_old ->> 'id')::uuid, j_old, NULL
    );
    RETURN NULL;
  END IF;

  -- UPDATE : ne garder que les colonnes réellement différentes.
  j_old := to_jsonb(OLD) - 'updated_at';
  j_new := to_jsonb(NEW) - 'updated_at';
  IF j_old = j_new THEN
    RETURN NULL;                       -- rien de significatif n'a bougé
  END IF;

  FOR cle IN SELECT jsonb_object_keys(j_new) LOOP
    IF (j_old -> cle) IS DISTINCT FROM (j_new -> cle) THEN
      diff_old := diff_old || jsonb_build_object(cle, j_old -> cle);
      diff_new := diff_new || jsonb_build_object(cle, j_new -> cle);
    END IF;
  END LOOP;

  IF diff_new = '{}'::jsonb THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.audit_logs (
    group_id, school_id, user_id, user_role, action, table_name,
    record_id, old_values, new_values
  ) VALUES (
    (j_new ->> 'group_id')::uuid, (j_new ->> 'school_id')::uuid,
    acteur, r_role, 'UPDATE', TG_TABLE_NAME,
    (j_new ->> 'id')::uuid, diff_old, diff_new
  );
  RETURN NULL;

EXCEPTION WHEN OTHERS THEN
  -- ⚠️ LE JOURNAL NE COÛTE JAMAIS LA DONNÉE. Toute erreur ici remonterait
  -- comme une erreur de l'écriture métier ; `23xxx` et `42501` sont fatals au
  -- connecteur PowerSync, qui jette le lot entier en attente sur le poste.
  RETURN NULL;
END
$fn$;

COMMENT ON FUNCTION public.fn_audit_metier() IS
  'Journal des actes qui se contestent : UPDATE et DELETE sur les tables où '
  'une décision se réécrit après coup. Ne lève jamais, se tait sans auteur, '
  'et n''enregistre que les colonnes qui ont bougé (migration 0144).';

-- ─── Attachement ───────────────────────────────────────────────────────────
DO $migration$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('grades',               'UPDATE OR DELETE'),
      ('evaluations',          'DELETE'),
      ('bulletins',            'UPDATE OR DELETE'),
      ('class_enrollments',    'DELETE'),
      ('students',             'UPDATE OR DELETE'),
      ('discipline_incidents', 'UPDATE OR DELETE'),
      ('student_payments',     'UPDATE OR DELETE'),
      ('payroll',              'UPDATE OR DELETE'),
      ('class_subjects',       'UPDATE'),
      ('school_levels',        'UPDATE')
    ) AS v(t, quand)
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_metier ON %I', r.t);
    EXECUTE format(
      'CREATE TRIGGER trg_audit_metier AFTER %s ON %I '
      'FOR EACH ROW EXECUTE FUNCTION public.fn_audit_metier()',
      r.quand, r.t);
  END LOOP;
END
$migration$;

-- ─── L'index qui manquait pour lire le journal d'une école ─────────────────
--  Six index existaient, aucun ne servait la requête réelle de l'écran :
--  « le journal de MON école, du plus récent au plus ancien ».
CREATE INDEX IF NOT EXISTS idx_audit_school_date
  ON public.audit_logs (school_id, created_at DESC);
