-- ════════════════════════════════════════════════════════════════════════════
--  0133 — UN COMPTEUR QUI DÉRIVE ET NE REVIENT JAMAIS
--
--  `library_items.available_quantity` était tenu par INCRÉMENTS depuis
--  l'application : `available_quantity = available_quantity - 1` au prêt,
--  `+ 1` au retour. C'est faux dans une application offline-first, et le mode
--  de défaillance est silencieux.
--
--  ── POURQUOI UN INCRÉMENT NE SURVIT PAS À LA SYNCHRO ──────────────────────
--  Le connecteur ne rejoue pas le SQL : il envoie la VALEUR RÉSULTANTE de la
--  colonne (`UpdateType.patch` → `.update({available_quantity: 4})`). Donc :
--
--      Poste A, hors ligne : 5 → 4, remonte « 4 »
--      Poste B, hors ligne : 5 → 4, remonte « 4 »
--      Serveur : DEUX prêts enregistrés, available_quantity = 4
--
--  Un exemplaire a disparu du compte, et rien ne le rattrape jamais : le
--  compteur ne se recalcule nulle part. Sur un trimestre, il s'éloigne du réel
--  dans les deux sens — tombé à 0, il refuse de prêter un livre posé sur
--  l'étagère ; monté trop haut, il prête des livres qui n'existent pas.
--
--  ── LA VÉRITÉ EST DÉRIVABLE, ET LE PROJET LA CONNAISSAIT DÉJÀ ─────────────
--  La migration 0073 contient exactement la bonne formule :
--      available_quantity = GREATEST(quantity - <prêts en cours>, 0)
--  Elle y était appliquée UNE FOIS, en remplissage initial, puis la colonne
--  était laissée à la dérive. On en fait une valeur maintenue.
--
--  ── DES DÉCLENCHEURS QUI CORRIGENT, JAMAIS QUI REFUSENT ───────────────────
--  ⚠️ Le déclencheur sur `library_items` ÉCRASE ce que le client envoie au
--  lieu de lever une erreur. C'est délibéré : une exception (23xxx) est un code
--  FATAL pour le connecteur PowerSync, qui jetterait le LOT ENTIER en attente.
--  Une valeur cliente fausse est donc silencieusement remplacée par la valeur
--  vraie — le poste la recevra à la synchro suivante.
--
--  Le client, lui, ne l'écrit plus du tout et la RECALCULE à la lecture, avec
--  la même formule, sur ses prêts locaux : hors ligne, le déclencheur n'a pas
--  encore tourné, et l'écran doit dire vrai tout de suite. Deux endroits, une
--  seule formule — et aucun des deux ne stocke un incrément.
--
--  ── VÉRIFIÉ APRÈS COUP (production, transaction annulée) ──────────────────
--    3 exemplaires, 0 prêt        → available = 3
--    un prêt inséré               → available = 2
--    un second prêt               → available = 1
--    le premier rendu             → available = 2
--    le client écrit « 99 »       → available = 2  (écrasé, sans erreur)
--    quantity passe de 3 à 5      → available = 4
--    le prêt supprimé             → available = 5
-- ════════════════════════════════════════════════════════════════════════════

-- La formule, à un seul endroit.
CREATE OR REPLACE FUNCTION public.library_prets_en_cours(p_item uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT COUNT(*)::int FROM library_loans l
   WHERE l.item_id = p_item
     AND l.return_date IS NULL
     AND COALESCE(l.status, 'active') <> 'returned';
$fn$;

COMMENT ON FUNCTION public.library_prets_en_cours(uuid) IS
  'Nombre d''exemplaires actuellement sortis. Un prêt est en cours tant qu''il '
  'n''a ni date de retour ni statut « returned » — les deux, parce que '
  '`returnLoan` écrit les deux et que le modèle Dart lit les deux. '
  'Migration 0133.';

-- ─── library_items : la colonne ne se subit plus, elle se calcule ───────────
CREATE OR REPLACE FUNCTION public.trg_library_items_disponibilite()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  -- ÉCRASE au lieu de refuser : une exception serait un code fatal pour le
  -- connecteur, qui jetterait tout le lot d'écritures en attente.
  NEW.available_quantity :=
    GREATEST(COALESCE(NEW.quantity, 0) - library_prets_en_cours(NEW.id), 0);
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS library_items_disponibilite ON library_items;
CREATE TRIGGER library_items_disponibilite
  BEFORE INSERT OR UPDATE ON library_items
  FOR EACH ROW EXECUTE FUNCTION public.trg_library_items_disponibilite();

-- ─── library_loans : tout mouvement de prêt recalcule son ouvrage ───────────
CREATE OR REPLACE FUNCTION public.trg_library_loans_disponibilite()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  -- Un prêt peut CHANGER d'ouvrage : l'ancien et le nouveau se recalculent.
  IF TG_OP <> 'INSERT' THEN
    UPDATE library_items SET updated_at = now() WHERE id = OLD.item_id;
  END IF;
  IF TG_OP <> 'DELETE' THEN
    UPDATE library_items SET updated_at = now() WHERE id = NEW.item_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$fn$;

DROP TRIGGER IF EXISTS library_loans_disponibilite ON library_loans;
CREATE TRIGGER library_loans_disponibilite
  AFTER INSERT OR UPDATE OR DELETE ON library_loans
  FOR EACH ROW EXECUTE FUNCTION public.trg_library_loans_disponibilite();

-- L'`UPDATE ... SET updated_at` ci-dessus ne sert qu'à réveiller le
-- déclencheur BEFORE de `library_items`, qui, lui, pose la vraie valeur. Une
-- seule formule, un seul endroit où elle s'écrit.

-- ─── Remise à niveau de l'existant ──────────────────────────────────────────
UPDATE library_items li
   SET available_quantity =
         GREATEST(COALESCE(li.quantity, 0) - public.library_prets_en_cours(li.id), 0)
 WHERE li.available_quantity IS DISTINCT FROM
       GREATEST(COALESCE(li.quantity, 0) - public.library_prets_en_cours(li.id), 0);

COMMENT ON COLUMN library_items.available_quantity IS
  'Exemplaires disponibles. VALEUR DÉRIVÉE, maintenue par déclencheur '
  '(migration 0133) : quantity moins les prêts en cours. Ne jamais l''écrire '
  'depuis un client — la valeur envoyée est écrasée. Tenue par incréments '
  'jusqu''à 0133, elle dérivait à chaque prêt saisi hors ligne sur deux postes.';
