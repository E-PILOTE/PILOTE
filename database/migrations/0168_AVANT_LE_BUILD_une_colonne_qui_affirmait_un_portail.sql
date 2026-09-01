-- ═══════════════════════════════════════════════════════════════════════════
--  0168 — UNE COLONNE QUI AFFIRMAIT QU'UN PORTAIL ÉTAIT OUVERT
--
--  `schools.parent_portal_enabled` : `boolean NOT NULL DEFAULT true`.
--  Relevé le 2026-08-31, tranché le 2026-09-01.
--
--  ── CE QU'ELLE DISAIT, ET CE QUI EST VRAI ────────────────────────────────
--  | la colonne | la réalité |
--  |---|---|
--  | portail parents activé sur **37 / 37** écoles | **0** compte `parent` |
--  |  | **0** compte `eleve` |
--  |  | **2** tuteurs déclarés sur **9 106** élèves |
--  |  | `/user/espace-parent` = `StaffComingSoonScreen` |
--
--  Et son défaut étant `true`, CHAQUE école créée naissait en affirmant la
--  même chose. Une colonne qui ment ne fait pas de dégâts tant que personne ne
--  la lit — mais elle sera lue un jour, par un export, un état ou un rapport
--  qui parcourt `schools`, et elle publiera « portail parents : activé » pour
--  trente-sept établissements où il n'existe pas.
--
--  ── POURQUOI LA RETIRER PLUTÔT QUE LA METTRE À `false` ───────────────────
--  Mettre 37 lignes à `false` corrigerait l'affirmation et laisserait le
--  problème : une colonne que personne ne lit, que rien ne maintient, et que
--  le prochain lecteur croira significative. Le jour où l'espace parent sera
--  construit, un interrupteur par école se reposera — avec un défaut `false`,
--  un vrai lecteur, et un écran pour le régler. Ce n'est pas cette colonne-là.
--
--  ── ⚠️ RETIRER UNE COLONNE : LA QUESTION DE 0146 ─────────────────────────
--  Retirer une colonne qu'un poste envoie encore provoque un `42703`, rejoué à
--  l'infini, et le poste cesse SILENCIEUSEMENT de remonter quoi que ce soit
--  (0146, [[blocage-de-file-visible]]). Ici la réponse est prouvée, pas
--  supposée — et elle est plus forte que celle qui manque à 0146 :
--
--   1. la colonne n'est PAS déclarée dans `powersync_schema.dart` : PowerSync
--      ne peut donc structurellement pas l'envoyer ;
--   2. `schools` n'est écrite hors ligne NULLE PART (aucun `UPDATE schools`
--      dans `lib/`) ;
--   3. les six écritures en ligne (`admin_groupe`) portent des champs
--      EXPLICITES, aucune ne la cite, et aucune ne fait de `select('*')` ;
--   4. en base : aucune fonction, vue, politique, contrainte ni index ne la
--      mentionne — vérifié par requête, pas par lecture.
--
--  Ce n'est donc pas le retrait que 0146 attend. Celui-là reste suspendu.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE public.schools DROP COLUMN IF EXISTS parent_portal_enabled;

COMMIT;
