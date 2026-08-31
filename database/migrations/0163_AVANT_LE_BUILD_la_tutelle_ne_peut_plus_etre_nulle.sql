-- ═══════════════════════════════════════════════════════════════════════════
--  0163 — LA TUTELLE NE PEUT PLUS ÊTRE NULLE
--
--  ── LA DETTE QU'ON SOLDE ─────────────────────────────────────────────────
--  La migration 0153 a introduit `school_groups.tutelle` en NULLABLE, le temps
--  que le build qui la renseigne soit publié. Il l'est (3.4.1, build 25), et
--  les deux colonnes sont peuplées PARTOUT : 0 groupe et 0 école sans tutelle.
--
--  ── POURQUOI CE N'EST PAS COSMÉTIQUE ─────────────────────────────────────
--  Un groupe sans tutelle n'apparaît dans le réseau d'AUCUN ministère. Ses
--  écoles héritent d'une tutelle nulle par le déclencheur de 0153, et sortent
--  donc de `tutelle_ecoles()` (0158) et de toute circulaire (0161). C'est
--  précisément la brèche que 0155 et 0158 ont fermée : un établissement réel,
--  invisible de sa propre tutelle, sans que rien ne le signale.
--
--  ⚠️ ET CE N'ÉTAIT PAS THÉORIQUE. L'écran des ABONNEMENTS créait un second
--  groupe scolaire, avec un formulaire qui ne demandait ni tutelle, ni
--  agrément, ni secteur. Ce chemin a été retiré le même jour (un seul écran
--  crée un groupe, gardé par `test/tutelle_du_groupe_test.dart`). Cette
--  contrainte est la seconde moitié : l'écran ne le fait plus, la base ne le
--  PEUT plus.
--
--  ── POURQUOI C'EST SÛR CÔTÉ POSTES ───────────────────────────────────────
--  `schools.tutelle` est posée par `trg_school_herite_tutelle`, déclencheur
--  **BEFORE INSERT OR UPDATE** : un poste qui envoie une école sans tutelle la
--  reçoit avant le contrôle. Aucun `NOT NULL` ne peut donc le surprendre.
--  `school_groups`, lui, n'est écrit que depuis un écran en ligne.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- Le garde AVANT la contrainte : `SET NOT NULL` sur une colonne qui contient
-- des NULL échoue avec un message qui ne dit pas COMBIEN ni LESQUELS.
DO $garde$
DECLARE g integer; e integer;
BEGIN
  SELECT count(*) INTO g FROM school_groups WHERE tutelle IS NULL;
  SELECT count(*) INTO e FROM schools       WHERE tutelle IS NULL;
  IF g > 0 OR e > 0 THEN
    RAISE EXCEPTION
      'Tutelle manquante : % groupe(s) et % ecole(s). Les renseigner AVANT '
      'la contrainte — un groupe sans tutelle est invisible de son ministere.',
      g, e;
  END IF;
END;
$garde$;

ALTER TABLE public.school_groups ALTER COLUMN tutelle SET NOT NULL;
ALTER TABLE public.schools       ALTER COLUMN tutelle SET NOT NULL;

COMMENT ON COLUMN public.school_groups.tutelle IS
  'Ministere de tutelle. NOT NULL depuis 0163 : un groupe sans tutelle '
  'n''apparait dans le reseau d''aucun ministere, et ses ecoles non plus.';
COMMENT ON COLUMN public.schools.tutelle IS
  'COPIE de school_groups.tutelle, tenue par trg_school_herite_tutelle '
  '(BEFORE INSERT OR UPDATE). Ne jamais l''ecrire depuis un ecran d''ecole : '
  'la copie divergerait le temps d''un rapport. NOT NULL depuis 0163.';

COMMIT;
