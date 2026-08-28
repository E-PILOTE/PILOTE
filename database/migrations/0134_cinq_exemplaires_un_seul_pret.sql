-- ════════════════════════════════════════════════════════════════════════════
--  0134 — CINQ EXEMPLAIRES, UN SEUL PRÊT
--
--  `library_loans` portait un index unique PARTIEL :
--
--      CREATE UNIQUE INDEX uq_library_loans_item_en_cours
--        ON library_loans (item_id) WHERE (return_date IS NULL)
--
--  Un seul prêt en cours par OUVRAGE — quel que soit le nombre d'exemplaires.
--  Or le catalogue modélise explicitement les exemplaires : `quantity`,
--  `available_quantity`, et l'écran affiche « 2/5 dispo ». Les deux ne peuvent
--  pas être vrais en même temps.
--
--  Conséquence, aujourd'hui, en production : une école possédant cinq manuels
--  de mathématiques en prête un ; le deuxième élève se voit refuser en 23505 —
--  code FATAL pour le connecteur PowerSync, qui jette le LOT ENTIER en attente.
--  Le prêt, mais aussi les paiements et les notes saisis dans la même heure.
--  Et rien à l'écran ne l'explique : la disponibilité affichait « 4 dispo ».
--
--  ── QUELLE MOITIÉ A TORT ──────────────────────────────────────────────────
--  Le catalogue. Une bibliothèque scolaire congolaise achète des manuels par
--  classes entières ; un catalogue à un exemplaire par titre n'aurait aucun
--  sens, et `quantity` ne serait pas là. C'est donc l'index qui est faux.
--
--  ── CE QUI LE REMPLACE ────────────────────────────────────────────────────
--  La règle qui tient debout : un même élève ne peut pas emprunter DEUX FOIS
--  le même ouvrage tant qu'il ne l'a pas rendu. C'est une règle vraie, et elle
--  attrape en prime le double appui sur « Enregistrer le prêt ».
--
--      UNIQUE (item_id, borrower_id) WHERE return_date IS NULL
--
--  Le PLAFOND par nombre d'exemplaires ne se tient pas par un index — il
--  dépend d'un COMPTE, pas d'une clé. Il se tient là où il est vérifiable :
--  `createLoan` refuse quand `quantity - prêts en cours <= 0`, et le rend en
--  message lisible plutôt qu'en code fatal. Deux postes hors ligne peuvent
--  donc, ensemble, dépasser d'un exemplaire : la disponibilité (0133) redevient
--  juste dès la synchro, et un livre prêté en trop se règle à l'étagère, pas
--  par la perte d'un lot d'écritures.
--
--  ⚠️ CET INDEX N'APPARAISSAIT PAS DANS LE RELEVÉ DES CONTRAINTES du
--  2026-08-28 : `pg_constraint` ne contient pas les index uniques PARTIELS.
--  Le garde `cle_metier_unique_test.dart` couvre désormais les deux familles.
--
--  `library_loans` est vide (0 ligne) : le remplacement est sans reprise.
-- ════════════════════════════════════════════════════════════════════════════

DROP INDEX IF EXISTS uq_library_loans_item_en_cours;

CREATE UNIQUE INDEX IF NOT EXISTS uq_library_loans_ouvrage_emprunteur_en_cours
  ON library_loans USING btree (item_id, borrower_id)
  WHERE (return_date IS NULL);

COMMENT ON INDEX uq_library_loans_ouvrage_emprunteur_en_cours IS
  'Un même emprunteur ne peut pas avoir deux fois le même ouvrage en cours. '
  'Remplace `uq_library_loans_item_en_cours` (migration 0134), qui limitait '
  'chaque OUVRAGE à un seul prêt simultané et rendait le catalogue '
  'multi-exemplaires inutilisable.';
