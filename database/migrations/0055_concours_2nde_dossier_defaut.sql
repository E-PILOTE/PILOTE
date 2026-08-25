-- ════════════════════════════════════════════════════════════════════════════
-- 0055 — Dossier du CONCOURS D'ENTRÉE EN 2NDE : défaut prudent.
--
-- La migration 0052 a semé les pièces réelles de 11 examens sur 12 (note METP).
-- Le CONCOURS_2NDE était resté à `[]`. Faute de liste officielle publiée pour ce
-- concours du secondaire (recherche 2026-07 non concluante), on pose un défaut
-- MINIMAL et non inventé, calqué sur le CONCOURS_6EME déjà validé (acte de
-- naissance + photos d'identité). À AFFINER dès que la DEC communique la liste
-- exacte — ce défaut vaut mieux qu'un dossier vide, sans prétendre à l'exactitude.
--
-- Idempotent : ne touche que les sessions dont le dossier est vide/NULL.
-- ════════════════════════════════════════════════════════════════════════════

UPDATE exam_sessions s
SET required_documents = '[
  {"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":1,"nature":"fichier","source":"eleve"},
  {"code":"photos","label":"Photos d''identité","copies":4,"nature":"fichier","source":"eleve"}
]'::jsonb
FROM national_exams e
WHERE s.exam_id = e.id
  AND e.code = 'CONCOURS_2NDE'
  AND (s.required_documents IS NULL OR jsonb_array_length(s.required_documents) = 0);
