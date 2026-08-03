-- ════════════════════════════════════════════════════════════════════════════
--  0080 — L'IDENTIFIANT NATIONAL DE L'ÉLÈVE (INE)
--
--  ── LE PROBLÈME ────────────────────────────────────────────────────────────
--  `students.matricule` est unique PAR GROUPE — `UNIQUE (group_id, matricule)` —
--  et l'application en tire un neuf à CHAQUE inscription. Un transfert, lui, ne
--  fait que sortir l'élève de son école : il ne crée rien à l'arrivée. L'école
--  d'accueil relance donc l'assistant, et l'enfant devient une SECONDE personne,
--  avec un second dossier et une scolarité coupée en deux.
--
--  Conséquences pour un système national : le parcours d'un élève est
--  incalculable, le taux d'abandon indiscernable d'un transfert non déclaré, et
--  les effectifs — donc les dotations — gonflés par les doublons.
--
--  ── POURQUOI UNE COLONNE DE PLUS, ET PAS UNE REDÉFINITION DU MATRICULE ─────
--  Le matricule a un sens propre et légitime : le numéro d'inscription DANS
--  CETTE ÉCOLE. Il est imprimé sur les listes, les fiches et les documents
--  d'examen. On ne lui change pas sa signification sous les pieds. L'INE vient
--  à côté : l'école garde son numéro, le ministère a le sien.
--
--  ── POURQUOI LE SERVEUR L'ATTRIBUE, ET PAS L'APPAREIL ──────────────────────
--  L'application inscrit HORS LIGNE. Un identifiant tiré sur l'appareil devrait
--  être soit assez aléatoire pour ne jamais collisionner — donc trop long pour
--  être dicté au téléphone — soit séquentiel, et deux postes d'une même école
--  travaillant hors ligne finiraient par tirer le même numéro. Or une violation
--  d'unicité à la remontée fait abandonner à PowerSync le LOT ENTIER : ce
--  projet a déjà perdu des données ainsi.
--
--  Le serveur attribue donc, à l'insertion. L'élève inscrit hors ligne n'a pas
--  d'INE tant que le poste n'a pas synchronisé — et c'est acceptable : il a
--  déjà son matricule d'école pour le quotidien, et l'INE ne sert qu'aux actes
--  nationaux (certificat, examen, transfert), qui supposent de toute façon que
--  l'école soit en ligne.
--
--  Accessoirement, c'est la seule position défendable : un identifiant
--  « national » émis par l'ordinateur portable d'une école privée n'est pas
--  national.
--
--  ── LE FORMAT ──────────────────────────────────────────────────────────────
--    YY NNNNNNNN K   — 11 chiffres, affichés « 26-00000123-4 »
--      YY : deux derniers chiffres de l'année de PREMIÈRE inscription
--      NN… : séquence nationale à 8 chiffres, jamais réinitialisée
--      K  : clé de contrôle de Luhn
--
--  Tout en chiffres, à dessein : un identifiant se dicte au téléphone et se
--  ressaisit depuis un papier. Les lettres apportent de l'entropie dont on n'a
--  pas besoin — la séquence garantit déjà l'unicité — et de la confusion dont
--  on se passe (O/0, I/1). La clé de Luhn fait qu'un chiffre mal recopié est
--  REJETÉ au lieu de désigner silencieusement un autre enfant.
--
--  ⚠️ AUCUN INE N'EST ATTRIBUÉ AUX ÉLÈVES EXISTANTS PAR CETTE MIGRATION.
--  Le format doit d'abord être confirmé par le ministère : s'il existe déjà un
--  identifiant officiel, c'est lui qu'il faut reprendre. Une fois la question
--  tranchée, `SELECT attribuer_ine_manquants();` peuple le parc en une fois.
--  Attribuer maintenant, c'est risquer d'imprimer sur des certificats un numéro
--  qu'il faudra reprendre.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── La séquence nationale ───────────────────────────────────────────────────
-- Globale et jamais réinitialisée : c'est ELLE qui porte l'unicité. L'année
-- dans le préfixe n'est qu'une lecture confortable pour l'œil, pas une clé.
CREATE SEQUENCE IF NOT EXISTS ine_seq START 1;

-- ── La clé de contrôle ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION luhn_cle(p_chiffres text)
RETURNS int
LANGUAGE plpgsql IMMUTABLE STRICT AS $$
DECLARE
  v_somme int := 0;
  v_pos   int;
  v_c     int;
BEGIN
  IF p_chiffres !~ '^[0-9]+$' THEN
    RAISE EXCEPTION 'luhn_cle attend des chiffres, reçu « % »', p_chiffres;
  END IF;
  -- Parcours de DROITE à gauche : on double un chiffre sur deux en partant du
  -- dernier, ce qui est ce qui rend Luhn sensible aux inversions de voisins
  -- (« 21 » saisi pour « 12 »), la faute de frappe la plus fréquente.
  FOR v_pos IN 1 .. length(p_chiffres) LOOP
    v_c := substr(p_chiffres, length(p_chiffres) - v_pos + 1, 1)::int;
    IF v_pos % 2 = 1 THEN
      v_c := v_c * 2;
      IF v_c > 9 THEN v_c := v_c - 9; END IF;
    END IF;
    v_somme := v_somme + v_c;
  END LOOP;
  RETURN (10 - (v_somme % 10)) % 10;
END $$;

COMMENT ON FUNCTION luhn_cle(text) IS
  'Clé de contrôle Luhn. ⚠️ Doit rester identique à luhnKey() dans '
  'lib/core/utils/ine.dart — un INE valide côté serveur et rejeté côté '
  'application serait indébogable au guichet.';

-- ── La fabrique d'INE ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION prochain_ine()
RETURNS text
LANGUAGE plpgsql VOLATILE AS $$
DECLARE
  v_corps text;
BEGIN
  v_corps := to_char(EXTRACT(year FROM now())::int % 100, 'FM00')
          || lpad(nextval('ine_seq')::text, 8, '0');
  RETURN v_corps || luhn_cle(v_corps)::text;
END $$;

-- ── La colonne ──────────────────────────────────────────────────────────────
ALTER TABLE students ADD COLUMN IF NOT EXISTS ine text;

-- ⚠️ L'unicité porte sur (ine, school_id), PAS sur ine seul.
--
-- Une ligne `students` n'est pas une personne : c'est une PERSONNE DANS UNE
-- ÉCOLE. Le transfert ne déplace pas la ligne — il sort l'élève, et l'école
-- d'accueil en crée une autre. Exiger `UNIQUE (ine)` rendrait donc impossible
-- ce que cette migration cherche justement à permettre : qu'un enfant garde
-- son identifiant en changeant d'établissement.
--
-- Avec cette forme, `SELECT * FROM students WHERE ine = ?` rend le PARCOURS
-- complet, école par école — la question qu'un ministère pose en premier.
-- Et l'unicité par école interdit toujours le doublon là où il fait mal :
-- deux dossiers pour le même enfant dans le même établissement.
CREATE UNIQUE INDEX IF NOT EXISTS students_ine_ecole_key
  ON students (ine, school_id) WHERE ine IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_students_ine ON students (ine) WHERE ine IS NOT NULL;

ALTER TABLE students DROP CONSTRAINT IF EXISTS students_ine_format_check;
ALTER TABLE students ADD CONSTRAINT students_ine_format_check
  CHECK (ine IS NULL OR ine ~ '^[0-9]{11}$');

COMMENT ON COLUMN students.ine IS
  'Identifiant national de l''élève — 11 chiffres, attribué UNE FOIS par le '
  'serveur et immuable. Survit au changement d''établissement, contrairement '
  'au matricule qui est propre à l''école. NULL tant que l''inscription '
  'saisie hors ligne n''a pas été synchronisée.';

-- ── L'attribution, et surtout l'immuabilité ─────────────────────────────────
CREATE OR REPLACE FUNCTION students_attribuer_ine()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.ine IS NOT NULL THEN
    -- ⚠️ On IGNORE toute tentative de modification au lieu de lever une
    -- exception. Un poste hors ligne remonte la ligne entière, INE compris —
    -- et sa copie locale porte encore NULL si elle date d'avant la première
    -- synchronisation. Refuser ferait échouer la remontée, donc perdre le lot.
    -- On se contente de restaurer la valeur : l'écriture passe, l'identifiant
    -- ne bouge pas.
    NEW.ine := OLD.ine;

  ELSIF NEW.ine IS NULL THEN
    NEW.ine := prochain_ine();

  ELSIF NOT EXISTS (SELECT 1 FROM students WHERE ine = NEW.ine) THEN
    -- Un INE fourni par un client n'est légitime que s'il EXISTE DÉJÀ : c'est
    -- une reprise, le cas de l'élève transféré dont l'école d'accueil rattache
    -- le nouveau dossier au parcours existant. Un identifiant inconnu est,
    -- lui, une invention — saisie fautive ou client défectueux.
    --
    -- On n'en fait pas une erreur : elle ferait abandonner le lot PowerSync
    -- entier, et l'école perdrait bien plus qu'un numéro. On attribue un INE
    -- neuf, ce qui est exactement ce qui se serait passé sans la tentative.
    -- L'élève existe, son parcours démarre ici : rien n'est perdu, seul le
    -- rattachement a échoué et reste rattrapable.
    NEW.ine := prochain_ine();
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_students_ine ON students;
CREATE TRIGGER trg_students_ine
  BEFORE INSERT OR UPDATE ON students
  FOR EACH ROW EXECUTE FUNCTION students_attribuer_ine();

-- ── Le peuplement du parc existant, à déclencher plus tard ──────────────────
CREATE OR REPLACE FUNCTION attribuer_ine_manquants()
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE v_n int;
BEGIN
  IF NOT is_super_admin() THEN
    RAISE EXCEPTION 'Réservé à l''administration de la plateforme.';
  END IF;
  -- L'ordre compte : on numérote par ancienneté d'inscription, pour que les
  -- INE racontent la même chronologie que les dossiers.
  --
  -- ⚠️ `prochain_ine()` est appelée DANS le sous-select ordonné, pas dans le
  -- UPDATE. Un `UPDATE ... SET ine = prochain_ine() FROM (… ORDER BY …)` ne
  -- garantit rien : PostgreSQL ne promet aucun ordre de traitement des lignes
  -- mises à jour. Ici les valeurs sont produites pendant le parcours trié,
  -- puis simplement recopiées.
  WITH numerotes AS (
    SELECT id, prochain_ine() AS nouvel_ine
    FROM (SELECT id FROM students WHERE ine IS NULL ORDER BY created_at, id) t
  ), fait AS (
    UPDATE students s SET ine = n.nouvel_ine
    FROM numerotes n WHERE s.id = n.id
    RETURNING 1
  )
  SELECT count(*) INTO v_n FROM fait;
  RETURN v_n;
END $$;

COMMENT ON FUNCTION attribuer_ine_manquants() IS
  'Attribue un INE à tout élève qui n''en a pas. À n''exécuter qu''une fois le '
  'format confirmé par le ministère : les INE seront imprimés sur des '
  'certificats, on ne les reprend pas.';

COMMIT;
