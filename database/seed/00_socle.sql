-- ════════════════════════════════════════════════════════════════════════════
--  SEED 00 — LE SOCLE : identifiants reproductibles
--
--  Tous les fichiers de seed s'appuient sur `seed_uuid()`. Un même libellé
--  donne toujours le même identifiant, ce qui rend l'ensemble IDEMPOTENT : on
--  rejoue un fichier, il met à jour au lieu de dupliquer. Sans ça, une seconde
--  exécution créerait un second « Lycée Technique de Dolisie » et toutes les
--  statistiques départementales doubleraient en silence.
--
--  Ces identifiants sont préfixés `epilote:seed:` : aucune collision possible
--  avec une donnée saisie par un établissement réel.
--
--  ORDRE D'EXÉCUTION (chaque fichier suppose le précédent) :
--    00_socle.sql            → la fonction d'identifiants
--    01_ecoles_et_annees.sql → écoles, années scolaires, profils d'accès
--    02_structure.sql        → cycles/niveaux/matières/classes des deux années
--    03_personnel.sql        → direction et enseignants
--    04_eleves.sql           → élèves et inscriptions
--    05_evaluation.sql       → notes, bulletins, décisions de fin d'année
--    06_examens.sql          → candidatures et résultats proclamés
--
--  Pour tout effacer : `database/seed/99_purge.sql`.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.seed_uuid(p_key text)
RETURNS uuid
LANGUAGE sql
IMMUTABLE
AS $$ SELECT md5('epilote:seed:' || p_key)::uuid $$;

COMMENT ON FUNCTION public.seed_uuid(text) IS
  'Identifiant reproductible pour les données de démonstration. '
  'Permet de rejouer les seeds sans dupliquer (database/seed/).';
