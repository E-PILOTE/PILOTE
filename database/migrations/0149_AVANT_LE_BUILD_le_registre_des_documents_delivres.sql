-- ════════════════════════════════════════════════════════════════════════════
--  0149 — LE REGISTRE DES DOCUMENTS DÉLIVRÉS
--
--  ⚠️ AVANT LE BUILD, et ⚠️ EXIGE UN DÉPLOIEMENT DES SYNC-RULES (voir en bas).
--
--  ── LE TROU ───────────────────────────────────────────────────────────────
--  La plateforme délivre des papiers officiels : certificat de scolarité,
--  certificat de radiation, carte scolaire, attestation de travail. Chacun
--  engage l'établissement, et AUCUN ne laisse de trace. Rien, nulle part, ne
--  répond à « qui a délivré ce certificat, et quand ».
--
--  `audit_logs` ne peut pas le faire : il journalise les UPDATE et DELETE de
--  tables (migration 0144). Or délivrer un certificat n'écrit RIEN — c'est
--  précisément pour cela que le geste est invisible. Il faut donc une trace
--  qui note un ACTE, pas une modification de ligne.
--
--  ── CE QUE LE REGISTRE NOTE, ET CE QU'IL NE GARDE SURTOUT PAS ─────────────
--  Il note l'acte : quel document, pour qui, par qui, quand, pour quel usage.
--  Il ne garde AUCUNE copie du PDF. Conserver chaque certificat, ce serait
--  entreposer, école par école, des milliers de pièces portant identité, date
--  et lieu de naissance et adresse d'enfants — un volume inutile et un risque
--  de fuite que rien ne justifie. Le registre atteste qu'un papier a été fait ;
--  le papier, lui, est chez la famille.
--
--  ── LES NOMS SONT FIGÉS, ET C'EST LE POINT ────────────────────────────────
--  `recipient_name` et `issued_by_name` sont recopiés au moment de l'émission
--  plutôt que joints. Un registre qui lit le nom ACTUEL change de contenu quand
--  un élève change de nom ou quand l'agent quitte l'école : il cesserait de dire
--  ce qui a été écrit ce jour-là, qui est la seule chose qu'on lui demande.
--  Les identifiants (`student_id`, `issued_by`) restent, pour naviguer ; ce sont
--  les noms recopiés qui font foi.
--
--  ── CE QU'IL MESURE VRAIMENT ──────────────────────────────────────────────
--  L'émission du document, pas la sortie du papier de l'imprimante : la
--  plateforme ne peut pas savoir la seconde, et un registre qui prétendrait la
--  connaître mentirait. `issued_at` est l'instant où le document a été produit
--  au nom d'une personne nommée — l'acte dont l'établissement répond.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS public.issued_documents (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         uuid NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  school_id        uuid NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  academic_year_id uuid REFERENCES academic_years(id) ON DELETE SET NULL,

  -- Code métier, en français comme les autres énumérations du domaine
  -- (`non_reinscrit`, `exclusion_definitive`) : certificat_scolarite,
  -- certificat_radiation, carte_scolaire, attestation_travail.
  document_type    text NOT NULL,

  -- Le destinataire. L'un des deux, jamais les deux.
  student_id       uuid REFERENCES students(id) ON DELETE SET NULL,
  staff_profile_id uuid REFERENCES profiles(id) ON DELETE SET NULL,

  -- Figés à l'émission (voir l'en-tête).
  recipient_name   text NOT NULL,
  recipient_ref    text,          -- classe + matricule au jour de l'émission

  issued_by        uuid REFERENCES profiles(id) ON DELETE SET NULL,
  issued_by_name   text,
  issued_at        timestamptz NOT NULL DEFAULT now(),

  -- Ce que la famille est venue chercher (bourse, transport, visa…). Facultatif
  -- et libre : le forcer produirait un champ rempli au hasard.
  purpose          text,

  created_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT issued_documents_recipient_nonempty
    CHECK (length(btrim(recipient_name)) > 0)
);

COMMENT ON TABLE public.issued_documents IS
  'Registre des documents délivrés par l''établissement (certificat de '
  'scolarité, radiation, carte scolaire, attestation de travail). Note l''ACTE, '
  'jamais une copie du PDF. Les noms sont figés à l''émission : un registre '
  'doit dire ce qui a été écrit ce jour-là. Immuable — cf. trigger '
  'trg_issued_documents_immutable.';

CREATE INDEX IF NOT EXISTS idx_issued_documents_school_date
  ON public.issued_documents (school_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_issued_documents_student
  ON public.issued_documents (student_id) WHERE student_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_issued_documents_issuer
  ON public.issued_documents (issued_by);

-- ════════════════════════════════════════════════════════════════════════════
--  IMMUABLE — MAIS SANS JAMAIS LEVER
--
--  ⚠️ Le piège, et il est double.
--
--  Un registre modifiable n'est pas un registre : on doit donc refuser l'UPDATE.
--  La façon naturelle — ne créer aucune politique UPDATE — est un PIÈGE MORTEL
--  ici. `SupabasePowerSyncConnector` envoie ses créations en UPSERT. Si un lot
--  est réémis après une coupure (la ligne étant déjà passée), l'upsert entre en
--  conflit, tombe sur l'UPDATE, se fait refuser en 42501 — code FATAL pour le
--  connecteur, qui abandonne la transaction et JETTE LE LOT ENTIER en attente :
--  les inscriptions du matin, les paiements du guichet, les notes de la journée.
--
--  La seconde façon naturelle — lever une exception dans un trigger — est le
--  même piège sous un autre code (P0001/23xxx, également fatal).
--
--  D'où : l'UPDATE est AUTORISÉ par la RLS (le rejeu passe), et le trigger le
--  rend SANS EFFET en rendant OLD. Une réémission réussit et ne change rien ;
--  une tentative de retouche réussit aussi, et ne change rien non plus.
--  C'est la règle de la migration 0144, appliquée ailleurs : un journal ne doit
--  JAMAIS coûter la donnée qu'il observe.
-- ════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.fn_issued_documents_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
  -- Rendre OLD : la ligne reste telle qu'elle a été écrite, sans erreur.
  RETURN OLD;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_issued_documents_immutable ON public.issued_documents;
CREATE TRIGGER trg_issued_documents_immutable
  BEFORE UPDATE ON public.issued_documents
  FOR EACH ROW EXECUTE FUNCTION public.fn_issued_documents_immutable();

-- ════════════════════════════════════════════════════════════════════════════
--  RLS
--
--  ⚠️ L'INSERT N'EXIGE AUCUN VERBE DE MODULE, et c'est délibéré.
--
--  Partout ailleurs dans ce dépôt, écrire demande un verbe (`auth_module_permet`).
--  Pas ici. L'écriture du registre ACCOMPAGNE la délivrance : elle est faite par
--  quiconque vient de produire le document. Exiger un droit que l'agent n'a pas
--  ferait échouer l'insertion en 42501 — fatal — et le journal détruirait le
--  travail de la journée pour avoir voulu le noter.
--
--  Le contrôle d'accès reste là où il a un sens : l'écran de CONSULTATION vit
--  sous le module `documents` (verrou 3), et la portée de la RLS reste l'école.
-- ════════════════════════════════════════════════════════════════════════════
ALTER TABLE public.issued_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS issued_documents_select ON public.issued_documents;
CREATE POLICY issued_documents_select ON public.issued_documents
  FOR SELECT
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

DROP POLICY IF EXISTS issued_documents_insert ON public.issued_documents;
CREATE POLICY issued_documents_insert ON public.issued_documents
  FOR INSERT
  WITH CHECK (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

-- Autorisée pour que le REJEU d'un lot passe ; rendue sans effet par le
-- trigger. Voir le bloc « IMMUABLE » ci-dessus.
DROP POLICY IF EXISTS issued_documents_update ON public.issued_documents;
CREATE POLICY issued_documents_update ON public.issued_documents
  FOR UPDATE
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  )
  WITH CHECK (true);

-- Aucune politique DELETE : on n'efface pas une ligne de registre, et le client
-- n'en demande jamais la suppression — donc aucun 42501 possible de ce côté.

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
--  ⚠️ SYNC-RULES — À DÉPLOYER, SINON L'ÉCRAN RESTE VIDE POUR TOUJOURS
--
--  Ajouter dans le bucket `by_school` (`powersync/config/sync-rules.yaml`,
--  déjà écrit dans le dépôt) :
--
--      - SELECT * FROM issued_documents WHERE school_id = bucket.sid
--
--  Sans ce déploiement, les lignes écrites hors ligne remontent bien vers
--  Postgres — le téléversement ne dépend pas des sync-rules — mais elles ne
--  redescendent sur AUCUN poste. La copie locale disparaît au checkpoint
--  suivant (elle n'appartient à aucun bucket), et le registre s'affiche vide
--  alors que la donnée existe côté serveur. Rien n'est perdu, mais l'écran ment.
--
--  Le déploiement se fait par le tableau de bord PowerSync Cloud (ou la CLI
--  avec un jeton valide). Il doit précéder la publication du build.
--
--  ── VÉRIFICATIONS ─────────────────────────────────────────────────────────
--  -- l'immuabilité tient sans jamais lever :
--  --   UPDATE issued_documents SET recipient_name = 'X' WHERE id = '...';
--  --   → « UPDATE 1 », et la ligne est inchangée.
--  select document_type, count(*) from issued_documents group by 1;
-- ════════════════════════════════════════════════════════════════════════════
