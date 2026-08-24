-- ════════════════════════════════════════════════════════════════════════════
--  0110 — LE TUTEUR APPARTIENT À L'ÉCOLE DE SON ENFANT
--
--  ── LE PROBLÈME ────────────────────────────────────────────────────────────
--  `student_tutors` porte ce que la plateforme détient de plus identifiant sur
--  des familles : nom et prénom des parents, deux numéros de téléphone, une
--  adresse électronique, une adresse postale, une profession.
--
--  La table n'avait pas de colonne `school_id`. Deux conséquences, toutes deux
--  invisibles depuis l'application :
--
--   1. LA SYNCHRO. `powersync/config/sync-rules.yaml` ne pouvait filtrer que
--      sur ce qui existe : `student_tutors WHERE group_id = bucket.gid`. Chaque
--      poste d'une école recevait donc, sur son disque, les coordonnées des
--      familles de TOUTES les écoles du groupe. L'écran, lui, n'en montrait
--      rien — l'annuaire joint `students` et filtre sur l'école — mais la
--      donnée était bien là, en clair, sur un poste partagé d'établissement.
--
--      C'est le défaut déjà rencontré sur `bulletin_subject_lines`, corrigé de
--      la même façon : la table ne pouvait pas descendre par école faute de
--      colonne, PowerSync n'acceptant pas de JOIN dans une data-query.
--
--   2. LA RÈGLE RLS. `student_tutors_tenant` autorisait tout le groupe :
--        is_super_admin() OR group_id = auth_group_id()
--      quand `students` — la table PARENTE, celle de l'enfant — dit :
--        is_super_admin()
--        OR (group_id = auth_group_id()
--            AND (is_admin_groupe() OR school_id = auth_school_id()))
--
--      Autrement dit : l'enfant était protégé école par école, et le numéro de
--      téléphone de sa mère ne l'était pas. Sur une plateforme d'État qui
--      traite des mineurs, c'est l'écart qu'on ne peut pas laisser passer une
--      rentrée de plus.
--
--  ── CE QUE POSE CETTE MIGRATION ────────────────────────────────────────────
--  Une colonne `school_id`, DÉRIVÉE et jamais saisie librement : un tuteur
--  appartient à l'école de son enfant, par définition. Le trigger la recalcule
--  à chaque écriture depuis `students` — le client peut donc l'omettre ou se
--  tromper, la base rétablit la vérité.
--
--  ⚠️ Le client la renseigne QUAND MÊME (`addTutor`). Ce n'est pas une
--  redondance : une fiche saisie hors ligne vit dans la SQLite du poste avant
--  d'atteindre le serveur, et le trigger ne s'exécute pas là. Sans valeur
--  locale, la ligne n'existerait pour aucune requête filtrant sur l'école
--  jusqu'au retour du réseau — c'est le piège `is_active` déjà rencontré.
--
--  ── ÉTAT AU MOMENT DE POSER ────────────────────────────────────────────────
--  2 lignes en base, 0 orpheline, 0 divergence de `group_id`. Le déploiement
--  national n'a pas eu lieu : c'est le dernier moment où cette migration coûte
--  deux lignes plutôt qu'un million.
--
--  ── CONTREPARTIE OBLIGATOIRE, HORS BASE ────────────────────────────────────
--  Cette migration ne suffit PAS à elle seule. Trois gestes l'accompagnent :
--   · `epilote/lib/services/powersync/powersync_schema.dart` — déclarer
--     `school_id` sur la table locale, sinon la colonne n'existe pas sur le
--     poste et toute requête qui la joint lève `no such column`.
--   · `powersync/config/sync-rules.yaml` — déplacer `student_tutors` du bucket
--     `by_group` vers `by_school`, puis **DÉPLOYER via le dashboard PowerSync
--     Cloud**. Tant que ce n'est pas fait, l'ancienne règle reste active et les
--     coordonnées continuent de descendre par groupe.
--   · `addTutor` (Dart) — estamper `school_id` à l'insertion.
--
--  À la première synchro suivant le déploiement des règles, les tuteurs des
--  autres écoles sont PURGÉS de la SQLite locale de chaque poste.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. La colonne ───────────────────────────────────────────────────────────
-- `REFERENCES schools(id)` sans action : même forme que `students_school_id_fkey`.
-- Une école ne se supprime pas, elle se désactive ; poser un CASCADE ici
-- inventerait un chemin d'effacement de dossiers d'élèves qui n'existe pas.
ALTER TABLE public.student_tutors
  ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id);

COMMENT ON COLUMN public.student_tutors.school_id IS
  'École de l''élève rattaché. DÉRIVÉE par trigger — ne jamais la saisir '
  'indépendamment de student_id. Sert le filtrage sync-rules ET la règle RLS.';

-- ── 2. Reprise de l'existant ────────────────────────────────────────────────
UPDATE public.student_tutors t
   SET school_id = s.school_id
  FROM public.students s
 WHERE s.id = t.student_id
   AND t.school_id IS DISTINCT FROM s.school_id;

-- Garde-fou : `SET NOT NULL` échouerait plus bas sans dire pourquoi. Un tuteur
-- sans élève ne devrait pas exister (`student_id` est NOT NULL et cascade),
-- mais si la reprise laisse une ligne derrière, on veut le savoir ICI.
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.student_tutors WHERE school_id IS NULL;
  IF n > 0 THEN
    RAISE EXCEPTION
      '0110 — % tuteur(s) sans école après reprise : leur élève est '
      'introuvable. Les traiter avant de reposer cette migration.', n;
  END IF;
END $$;

-- ── 3. La colonne se maintient seule ────────────────────────────────────────
-- Elle est dérivée : le client n'a pas à être cru sur parole, et un client
-- ancien qui l'ignore ne doit pas produire de ligne invalide (un refus
-- serveur fait abandonner à PowerSync le LOT ENTIER des écritures, en silence).
--
-- ⚠️ PAS de `SECURITY DEFINER`. La fonction s'exécute donc sous les droits de
-- l'appelant, et la règle RLS de `students` s'applique à sa lecture. C'est
-- voulu : qui ne voit pas l'élève ne peut pas lui attacher un tuteur, et la
-- fonction ne peut pas servir à deviner à quelle école appartient un élève
-- qu'on n'a pas le droit de voir. Un `SECURITY DEFINER` aurait ouvert les deux.
CREATE OR REPLACE FUNCTION public.student_tutor_derive_school()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  SELECT s.school_id, s.group_id
    INTO NEW.school_id, NEW.group_id
    FROM public.students s
   WHERE s.id = NEW.student_id;

  IF NEW.school_id IS NULL THEN
    RAISE EXCEPTION 'Tuteur rattaché à un élève introuvable (%).', NEW.student_id;
  END IF;
  RETURN NEW;
END $$;

COMMENT ON FUNCTION public.student_tutor_derive_school() IS
  'Un tuteur appartient à l''école ET au groupe de son enfant. Recalculé à '
  'chaque écriture : le `group_id` envoyé par le client était déjà, lui aussi, '
  'un champ de confiance.';

DROP TRIGGER IF EXISTS trg_student_tutor_derive_school ON public.student_tutors;
CREATE TRIGGER trg_student_tutor_derive_school
  BEFORE INSERT OR UPDATE OF student_id, school_id, group_id
  ON public.student_tutors
  FOR EACH ROW EXECUTE FUNCTION public.student_tutor_derive_school();

ALTER TABLE public.student_tutors
  ALTER COLUMN school_id SET NOT NULL;

-- ── 4. L'index qui sert la règle RLS et la sync-rule ────────────────────────
CREATE INDEX IF NOT EXISTS idx_student_tutors_school
  ON public.student_tutors (school_id);

-- ── 5. La règle RLS s'aligne sur celle de l'élève ───────────────────────────
-- Mot pour mot `students_tenant` / `student_documents_tenant` : l'admin de
-- groupe garde sa vue d'ensemble (il pilote en ligne, par école), le personnel
-- d'établissement est ramené à la sienne.
DROP POLICY IF EXISTS student_tutors_tenant ON public.student_tutors;
CREATE POLICY student_tutors_tenant ON public.student_tutors
  FOR ALL
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  )
  WITH CHECK (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

COMMIT;
