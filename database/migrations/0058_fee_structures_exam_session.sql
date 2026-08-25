-- ════════════════════════════════════════════════════════════════════════════
-- 0058 — Rattacher un barème de frais à une SESSION D'EXAMEN.
--
-- Les frais d'examen sont un revenu de l'école, donc du groupe scolaire. Le
-- schéma les attendait déjà : l'enum `fee_type` contient `frais_examens` et
-- `student_payments` remonte au revenu. Il ne manquait que le lien.
--
-- Pourquoi la colonne va sur `fee_structures` et PAS sur `exam_sessions` :
-- une session est NATIONALE (un BET 2025-2026 pour tout le pays) alors qu'un
-- barème est PAR ÉCOLE. Deux écoles ont deux barèmes pour le même examen —
-- c'est la réalité, et poser le lien sur la session la rendrait fausse.
--
-- La DETTE n'est pas matérialisée : elle se dérive (inscrits × montant −
-- encaissé). Créer une ligne de paiement « en attente » par candidat la
-- rendrait plus simple à lire et FAUSSE — ces lignes finiraient comptées comme
-- du revenu, ou devraient être purgées à chaque désinscription. Le revenu ne
-- compte que l'argent réellement reçu.
--
-- `fee_structures` est déjà synchronisée par les sync-rules : aucun
-- redéploiement. Colonne à déclarer dans powersync_schema.dart.
--
-- Idempotente.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE fee_structures
  ADD COLUMN IF NOT EXISTS exam_session_id uuid NULL
    REFERENCES exam_sessions(id) ON DELETE SET NULL;

-- Un seul barème d'examen par école et par session : sans cela, deux barèmes
-- concurrents feraient diverger l'attendu et le recouvrement.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_fee_structure_exam_session
  ON fee_structures (school_id, exam_session_id)
  WHERE exam_session_id IS NOT NULL;

COMMENT ON COLUMN fee_structures.exam_session_id IS
  'Session d''examen dont ce barème porte les frais. NULL pour les barèmes ordinaires (inscription, mensualité).';
