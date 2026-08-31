-- ═══════════════════════════════════════════════════════════════════════════
--  0165 — UN BULLETIN PAYÉ NE S'EFFACE PLUS
--
--  ── LA DETTE QUE 0145 AVAIT LAISSÉE OUVERTE, ET POURQUOI ─────────────────
--  La migration 0145 a scellé `bulletins`, `expenses` et `student_payments`
--  sur la clôture de l'année. Elle a EXPLICITEMENT écarté `payroll` :
--
--    « `payroll` n'est PAS scellée. Elle ne porte pas `academic_year_id`
--      (elle est datée par `period_month`/`period_year`) […] Un sceau par
--      `USING` y produirait une suppression qui ne supprime rien, sans
--      message : exactement le silence qu'on cherche à éliminer.
--      À traiter quand la paie sera rattachée à l'exercice. »
--
--  ── CE QU'ON A CHOISI À LA PLACE ─────────────────────────────────────────
--  Rattacher la paie à l'ANNÉE SCOLAIRE serait faux : une paie est datée par
--  mois civil, pas par exercice de septembre à juin. On ne va pas tordre la
--  donnée pour entrer dans un sceau existant.
--
--  L'événement qui rend un bulletin définitif n'est pas la clôture d'une
--  année : c'est LE PAIEMENT. Une fois l'argent parti, c'est une pièce — et
--  une pièce se corrige par une régularisation sur la période suivante,
--  jamais en effaçant l'ancienne. C'est exactement ce que 0145 dit des
--  encaissements : « annuler un paiement change son statut, il ne l'efface
--  pas ».
--
--  ── ⚠️ POURQUOI UN DÉCLENCHEUR QUI LÈVE, ET PAS UNE POLITIQUE `USING` ────
--  `payroll` est une table HORS LIGNE (PowerSync). Un `USING` qui écarte la
--  ligne ne lève rien : zéro ligne côté serveur, réponse 204 — mais la ligne
--  a DÉJÀ disparu du poste. L'écran montre une suppression réussie, le serveur
--  garde le bulletin, et personne n'apprend rien. C'est le défaut nommé dans
--  0145.
--
--  Un `RAISE ... ERRCODE = '42501'` est au contraire FATAL pour le connecteur :
--  la transaction est abandonnée, journalisée dans `sync_failures`, et le
--  bandeau le dit. La ligne revient à la synchro suivante.
--
--  ── LES DEUX MOITIÉS ─────────────────────────────────────────────────────
--  ⚠️ Ce déclencheur ne doit JAMAIS se déclencher en usage normal :
--  `deletePayroll` refuse déjà côté application, avec un message qui explique
--  quoi faire à la place, et l'entrée « Supprimer » du menu est désactivée sur
--  un bulletin payé. La base est le filet, pas la première ligne de défense —
--  parce qu'un écran n'est pas une garantie.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_payroll_paye_ne_seface_pas()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
BEGIN
  -- L'opérateur de la plateforme garde la main : lui seul peut défaire une
  -- écriture qu'une école ne devrait jamais avoir à défaire.
  IF public.is_super_admin() THEN RETURN OLD; END IF;

  IF OLD.status = 'confirmed'::payment_status THEN
    RAISE EXCEPTION
      'Bulletin de paie deja paye (% / %) : il ne peut plus etre supprime. '
      'Saisir une regularisation sur la periode suivante — une piece ne '
      's''efface pas.', OLD.period_month, OLD.period_year
      USING ERRCODE = '42501';
  END IF;
  RETURN OLD;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_payroll_paye_ne_seface_pas ON public.payroll;
CREATE TRIGGER trg_payroll_paye_ne_seface_pas
  BEFORE DELETE ON public.payroll
  FOR EACH ROW EXECUTE FUNCTION public.fn_payroll_paye_ne_seface_pas();

COMMENT ON TABLE public.payroll IS
  'Bulletins de paie. Un bulletin PAYE (status = confirmed) ne se supprime '
  'plus (0165) : l''argent est parti, c''est une piece. Le corriger se fait '
  'par une regularisation sur la periode suivante. La modification, elle, '
  'reste ouverte — corriger une reference de virement n''est pas reecrire '
  'l''histoire.';

COMMIT;
