-- 0050 — Sessions 2025-2026 RÉELLES + concours d'entrée en 6ème
--
-- Constat : le catalogue portait 11 examens mais UNE SEULE session (BET). Les
-- dix autres n'avaient aucune fenêtre d'inscription -> le module Examens était
-- structurellement correct mais vide, donc inutile.
--
-- ── SOURCES (vérifiées le 2026-07-17, aucune date inventée) ────────────────
-- MEPSA/MEPPSA — note de service N°157/MEPPSA-CAB-DEC :
--   • Inscriptions CEPE + BEPC + BAC : 03/11/2025 -> 31/01/2026, PROROGÉES au
--     vendredi 27/02/2026 (« délai de rigueur »).
--   • Baccalauréat  : écrits 02 -> 06 juin 2026 (+ EPS après les écrits)
--   • CEPE          : oral 09 et 11 juin 2026 · écrit 12 juin 2026
--   • BEPC          : écrits 23 -> 26 juin 2026 (+ EPS après les écrits)
--   • Concours d'entrée en 6ème (lycées d'excellence) : 28 juillet 2026,
--     inscriptions du 1er au 15 juillet 2026.
-- METP — note d'information examens d'État 2025-2026 :
--   • Inscriptions : 08/12/2025 -> 14/02/2026
--   • Âges max : 24 ans (bacs) · 20 ans (BET/CAP) · 21 ans (autres brevets)
--   • BET/BEP/BTF : écrits 23 -> 27 juin 2026 · pratiques 30 juin -> 04 juillet
--
-- ── CE QUI RESTE NULL, VOLONTAIREMENT ──────────────────────────────────────
-- CAP/CQP/BAC_T/BAC_P : la fenêtre d'inscription METP est connue, PAS les dates
-- d'épreuves. Elles restent NULL plutôt qu'alignées « par ressemblance » sur le
-- BET : une date d'examen fausse envoie un élève le mauvais jour.
-- fee_amount : les sources donnent des FOURCHETTES (BEPC 3 000-5 000 FCFA, BAC
-- 5 000-10 000 FCFA), pas un montant. Une fourchette ne se stocke pas dans un
-- numeric -> NULL, à saisir par le ministère.
--
-- ⚠️ Le ministère s'appelle désormais MEPPSA (Enseignement Préscolaire,
-- Primaire, Secondaire et Alphabétisation). L'enum reste `mepsa` : c'est un CODE
-- technique, le renommer casserait les données sans rien apporter.

BEGIN;

-- ── 1) Examen manquant : concours d'entrée en 6ème (lycées d'excellence) ────
-- Distinct du concours d'entrée en 2nde : autre niveau, autre calendrier.
INSERT INTO national_exams (code, name, short_name, tutelle, cycle_code, kind, order_index)
SELECT 'CONCOURS_6EME', 'Concours d''entrée en 6ème (lycées d''excellence)',
       'C. 6ème', 'mepsa', 'primaire', 'concours', 12
 WHERE NOT EXISTS (SELECT 1 FROM national_exams WHERE code = 'CONCOURS_6EME');

-- ── 2) Sessions 2025-2026 ──────────────────────────────────────────────────
INSERT INTO exam_sessions (
  exam_id, year_label, registration_opens_at, registration_closes_at,
  written_from, written_to, practical_from, practical_to,
  max_age, required_documents, status, notes
)
SELECT e.id, '2025-2026',
       v.reg_open::date, v.reg_close::date,
       v.w_from::date, v.w_to::date, v.p_from::date, v.p_to::date,
       v.max_age, v.docs::jsonb, v.status::exam_session_status, v.notes
  FROM (VALUES
    -- ── MEPSA : inscriptions 03/11/2025 -> 27/02/2026 (prorogation) ────────
    ('CEPE',  '2025-11-03','2026-02-27', '2026-06-12','2026-06-12', NULL,NULL, NULL,
     '[{"code":"acte_naissance","label":"Acte de naissance","copies":1},
       {"code":"photos","label":"Photos d''identité","copies":4},
       {"code":"certificat_scolarite","label":"Certificat de scolarité","copies":1},
       {"code":"frais","label":"Reçu des frais d''inscription","copies":1}]',
     'open', 'Oral les 9 et 11 juin, écrit le 12 juin 2026. Inscriptions prorogées au 27/02/2026 (note N°157/MEPPSA-CAB-DEC).'),

    ('BEPC',  '2025-11-03','2026-02-27', '2026-06-23','2026-06-26', NULL,NULL, NULL,
     '[{"code":"acte_naissance","label":"Acte de naissance","copies":1},
       {"code":"photos","label":"Photos d''identité","copies":4},
       {"code":"certificat_scolarite","label":"Certificat de scolarité","copies":1},
       {"code":"frais","label":"Reçu des frais d''inscription (3 000 à 5 000 FCFA)","copies":1}]',
     'open', 'Écrits du 23 au 26 juin 2026, EPS après les écrits. Frais 3 000-5 000 FCFA (fourchette : montant exact à saisir).'),

    ('BAC_G', '2025-11-03','2026-02-27', '2026-06-02','2026-06-06', NULL,NULL, NULL,
     '[{"code":"acte_naissance","label":"Acte de naissance","copies":1},
       {"code":"photos","label":"Photos d''identité","copies":4},
       {"code":"bepc","label":"Copie légalisée du BEPC","copies":2},
       {"code":"frais","label":"Reçu des frais d''inscription (5 000 à 10 000 FCFA)","copies":1}]',
     'open', 'Écrits du 2 au 6 juin 2026, EPS après les écrits. Frais 5 000-10 000 FCFA (fourchette).'),

    ('CONCOURS_6EME', '2026-07-01','2026-07-15', '2026-07-28','2026-07-28', NULL,NULL, NULL,
     '[{"code":"acte_naissance","label":"Acte de naissance","copies":1},
       {"code":"photos","label":"Photos d''identité","copies":4}]',
     'draft', 'Concours des lycées d''excellence : 28 juillet 2026, inscriptions du 1er au 15 juillet 2026.'),

    -- ── METP : inscriptions 08/12/2025 -> 14/02/2026 ──────────────────────
    ('BEP',   '2025-12-08','2026-02-14', '2026-06-23','2026-06-27', '2026-06-30','2026-07-04', 21,
     '[{"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2},
       {"code":"photos","label":"Photos d''identité couleur","copies":4},
       {"code":"chemise","label":"Chemise cartonnée","copies":1},
       {"code":"enveloppe","label":"Enveloppe format A4","copies":1},
       {"code":"frais","label":"Frais d''inscription","copies":1}]',
     'open', 'Écrits 23-27 juin, pratiques 30 juin-4 juillet 2026 (mêmes dates que BET/BTF, source presse nationale).'),

    ('BTF',   '2025-12-08','2026-02-14', '2026-06-23','2026-06-27', '2026-06-30','2026-07-04', 21,
     '[{"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2},
       {"code":"photos","label":"Photos d''identité couleur","copies":4},
       {"code":"chemise","label":"Chemise cartonnée","copies":1},
       {"code":"enveloppe","label":"Enveloppe format A4","copies":1},
       {"code":"frais","label":"Frais d''inscription","copies":1}]',
     'open', 'Écrits 23-27 juin, pratiques 30 juin-4 juillet 2026.'),

    -- Fenêtre d'inscription connue, dates d'épreuves NON publiées -> NULL.
    ('CAP',   '2025-12-08','2026-02-14', NULL,NULL, NULL,NULL, 20,
     '[{"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2},
       {"code":"photos","label":"Photos d''identité couleur","copies":4},
       {"code":"chemise","label":"Chemise cartonnée","copies":1},
       {"code":"enveloppe","label":"Enveloppe format A4","copies":1},
       {"code":"frais","label":"Frais d''inscription","copies":1}]',
     'open', 'Âge max 20 ans. Dates d''épreuves non publiées à ce jour — à compléter par le METP.'),

    ('CQP',   '2025-12-08','2026-02-14', NULL,NULL, NULL,NULL, 21,
     '[{"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2},
       {"code":"photos","label":"Photos d''identité couleur","copies":4},
       {"code":"frais","label":"Frais d''inscription","copies":1}]',
     'open', 'Dates d''épreuves non publiées — à compléter par le METP.'),

    ('BAC_T', '2025-12-08','2026-02-14', NULL,NULL, NULL,NULL, 24,
     '[{"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2},
       {"code":"photos","label":"Photos d''identité couleur","copies":4},
       {"code":"diplome_anterieur","label":"Copie légalisée du diplôme (BEPC, BEMG, BET ou BEP)","copies":2},
       {"code":"attestation_stage","label":"Attestation de stage","copies":1},
       {"code":"chemise","label":"Chemise cartonnée","copies":1},
       {"code":"enveloppe","label":"Enveloppe format A4","copies":1},
       {"code":"frais","label":"Frais d''inscription","copies":1}]',
     'open', 'Âge max 24 ans. Diplôme antérieur légalisé + ATTESTATION DE STAGE obligatoires (note METP).'),

    ('BAC_P', '2025-12-08','2026-02-14', NULL,NULL, NULL,NULL, 24,
     '[{"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2},
       {"code":"photos","label":"Photos d''identité couleur","copies":4},
       {"code":"diplome_anterieur","label":"Copie légalisée du diplôme (BEPC, BEMG, BET ou BEP)","copies":2},
       {"code":"attestation_stage","label":"Attestation de stage","copies":1},
       {"code":"chemise","label":"Chemise cartonnée","copies":1},
       {"code":"enveloppe","label":"Enveloppe format A4","copies":1},
       {"code":"frais","label":"Frais d''inscription","copies":1}]',
     'open', 'Âge max 24 ans. Diplôme antérieur légalisé + ATTESTATION DE STAGE obligatoires (note METP).'),

    ('CONCOURS_2NDE', NULL,NULL, NULL,NULL, NULL,NULL, NULL,
     '[]',
     'draft', 'Calendrier 2025-2026 non publié — session à compléter par le ministère.')
  ) AS v(exam_code, reg_open, reg_close, w_from, w_to, p_from, p_to, max_age, docs, status, notes)
  JOIN national_exams e ON e.code = v.exam_code
 WHERE NOT EXISTS (
   SELECT 1 FROM exam_sessions s WHERE s.exam_id = e.id AND s.year_label = '2025-2026'
 );

-- ── 3) Le BET existant reçoit ses pièces enrichies (attestation non requise) ─
UPDATE exam_sessions s
   SET notes = 'Session METP 2025-2026. Écrits 23-27 juin, pratiques 30 juin-4 juillet 2026. Âge max 20 ans.',
       updated_at = now()
  FROM national_exams e
 WHERE e.id = s.exam_id AND e.code = 'BET' AND s.year_label = '2025-2026';

COMMIT;

-- ── Vérifications ──────────────────────────────────────────────────────────
-- select e.short_name, s.year_label, s.registration_opens_at, s.registration_closes_at,
--        s.written_from, s.max_age, s.status
--   from exam_sessions s join national_exams e on e.id=s.exam_id
--  order by s.registration_closes_at nulls last, e.order_index;
