-- ════════════════════════════════════════════════════════════════════════════
--  0072 — LA BIBLIOTHÈQUE PRÊTE À DES ÉLÈVES, PAS À DES COMPTES
--
--  ── LE DÉFAUT ──────────────────────────────────────────────────────────────
--  `library_loans.borrower_id` référençait `profiles(id)` — un compte
--  utilisateur. Or l'application ne propose QUE des élèves à l'emprunt :
--    • le sélecteur « Emprunteur » est alimenté par `vsStudentsProvider`
--      (biblio_forms.dart) ;
--    • la lecture joint `students s ON s.id = l.borrower_id`
--      (biblio_provider.dart) — un élève, jamais un profil.
--
--  Conséquence : tout prêt enregistré par une école partait avec un
--  `student_id` dans une colonne qui attendait un `profile_id`. SQLite local
--  n'applique pas les clés étrangères, l'écriture semblait réussir ; le
--  serveur la refusait en 23503 et PowerSync ABANDONNAIT LA TRANSACTION
--  ENTIÈRE — le prêt perdu, et avec lui les écritures du même lot. Exactement
--  la panne silencieuse corrigée sur `student_payments.amount_xaf`.
--
--  ── POURQUOI ALIGNER LA BASE SUR LE PRODUIT, ET PAS L'INVERSE ─────────────
--  Une bibliothèque scolaire prête aux élèves : c'est le geste métier. Faire
--  emprunter aussi le personnel demanderait un emprunteur POLYMORPHE (élève ou
--  agent), donc une colonne de discriminant — un changement de conception, pas
--  un correctif. On ne le fait pas ici.
--
--  Aucune donnée à reprendre : la table est vide (vérifié avant écriture).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

DO $$
DECLARE v_orphelins integer;
BEGIN
  -- Garde-fou : si un déploiement avait déjà des prêts rattachés à des
  -- profils, la contrainte nouvelle les casserait. On refuse plutôt que de
  -- détruire en silence.
  SELECT count(*) INTO v_orphelins
    FROM library_loans l
   WHERE NOT EXISTS (SELECT 1 FROM students s WHERE s.id = l.borrower_id);

  IF v_orphelins > 0 THEN
    RAISE EXCEPTION
      'Migration interrompue : % prêt(s) ont un emprunteur qui n''est pas un '
      'élève. Reprendre ces lignes à la main avant de rejouer.', v_orphelins;
  END IF;
END $$;

ALTER TABLE library_loans
  DROP CONSTRAINT IF EXISTS library_loans_borrower_id_fkey;

ALTER TABLE library_loans
  ADD CONSTRAINT library_loans_borrower_id_fkey
  FOREIGN KEY (borrower_id) REFERENCES students(id) ON DELETE RESTRICT;

COMMENT ON COLUMN library_loans.borrower_id IS
  'ÉLÈVE emprunteur (students.id). Le personnel n''emprunte pas dans cette '
  'version : l''ouvrir demanderait un emprunteur polymorphe.';

-- Un même ouvrage ne peut pas être prêté deux fois en même temps. Index
-- partiel : la contrainte ne porte que sur les prêts EN COURS.
CREATE UNIQUE INDEX IF NOT EXISTS uq_library_loans_item_en_cours
  ON library_loans(item_id)
  WHERE return_date IS NULL;

COMMIT;
