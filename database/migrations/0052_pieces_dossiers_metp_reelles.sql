-- 0052 — Pièces des dossiers d'examen METP : la note officielle fait foi
--
-- ── POURQUOI ───────────────────────────────────────────────────────────────
-- `exam_sessions.required_documents` a été peuplé (0046/0050) avec MES
-- suppositions. La note officielle METP (cf. docs/superpowers/specs/
-- 2026-07-17-dossiers-examens-metp.md) établit les pièces réelles. Arbitrage
-- utilisateur (fonctionnaire DSIC/METP) : « crois la note officielle ».
--
-- Écarts constatés, tous corrigés ici :
--   • BEP / CAP / BTF : le DIPLÔME ANTÉRIEUR LÉGALISÉ (BEPC, BET) manquait ;
--   • BTF : la NOTE D'ADMISSION AU CONCOURS ENEF manquait (pièce propre au BTF) ;
--   • partout : le CERTIFICAT MÉDICAL d'inaptitude manquait ;
--   • BET : aucun diplôme antérieur n'est dû (il suit la 3e technique) — la
--     liste plate laissait croire le contraire pour les autres examens.
--
-- ── LA STRUCTURE : trois défauts du modèle plat, corrigés ───────────────────
-- Une pièce n'est pas un simple libellé. Elle porte :
--
--   nature     fichier    -> dématérialisable ; dérivable des pièces jointes
--              physique   -> chemise, enveloppe : ne seront JAMAIS un fichier.
--                            Sans cette distinction, « manquant = exigé − fichiers
--                            présents » déclarerait éternellement incomplet TOUT
--                            dossier du pays.
--              financiere -> frais : relève du module Paiements, pas d'un dépôt
--
--   source     eleve       -> permanente, vit dans `student-documents`, ressert à
--                             chaque session (cf. 0008 : « le dossier suit l'ÉLÈVE,
--                             réinscription = rien à re-téléverser »)
--              candidature -> propre à CETTE session (attestation de stage de
--                             l'année, certificat médical, reçu de frais)
--
--   condition  si_inapte_eps -> le certificat médical d'inaptitude n'est dû que
--                              si le candidat est déclaré inapte. L'exiger de
--                              tous rendrait tout dossier incomplet à jamais.
--                              Une pièce conditionnelle ne bloque JAMAIS la
--                              complétude : nous ne pouvons pas savoir qui est
--                              inapte, et la DEC vérifie au comptoir.
--
--   legalise   true -> la légalisation est un ATTRIBUT, pas un détail : c'est le
--                      motif de rejet au comptoir le plus banal. La présence et
--                      la conformité sont deux choses distinctes.
--
-- ⚠️ Rétrocompatibilité : `nature` absente => 'fichier', `source` absente =>
-- 'eleve', `condition` absente => toujours due. Les sessions MEPSA (CEPE, BEPC,
-- BAC_G, concours) ne sont PAS touchées : la note METP ne les couvre pas, et je
-- n'ai pas de source. Ne pas inventer deux fois la même erreur.
--
-- ⚠️ NON REPRIS, faute de source fiable :
--   • l'attestation de stage pour BEP / BTF / CAP : une source l'exige, l'autre
--     ne la liste que pour le bac. Elle reste sur BAC_T / BAC_P uniquement.
--   • la règle « diplôme datant d'au moins 3 ans » (bac) : mes sources se
--     contredisent (« au moins » vs « moins de »). Non modélisée.
--   • CQP : absent de la note. Laissé tel quel.

BEGIN;

-- ── BET — âge 20. AUCUN diplôme antérieur (il suit la 3e technique). ────────
UPDATE exam_sessions s
   SET required_documents = '[
        {"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2,"nature":"fichier","source":"eleve"},
        {"code":"photos","label":"Photos d''identité couleur (au verso : noms, prénoms, spécialité, établissement)","copies":4,"nature":"fichier","source":"eleve"},
        {"code":"certificat_medical","label":"Certificat médical d''inaptitude physique (EPS)","copies":1,"nature":"fichier","source":"candidature","condition":"si_inapte_eps"},
        {"code":"chemise","label":"Chemise cartonnée","copies":1,"nature":"physique"},
        {"code":"enveloppe","label":"Enveloppe kaki format A4","copies":1,"nature":"physique"},
        {"code":"frais","label":"Frais d''inscription","copies":1,"nature":"financiere","source":"candidature"}
       ]'::jsonb,
       updated_at = now()
  FROM national_exams e
 WHERE e.id = s.exam_id AND e.code = 'BET' AND s.year_label = '2025-2026';

-- ── BEP — âge 21. Diplôme antérieur légalisé (BEPC, BET). ───────────────────
UPDATE exam_sessions s
   SET required_documents = '[
        {"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2,"nature":"fichier","source":"eleve"},
        {"code":"diplome_anterieur","label":"Copie légalisée du diplôme (BEPC ou BET)","copies":2,"nature":"fichier","source":"eleve","legalise":true},
        {"code":"photos","label":"Photos d''identité couleur (au verso : noms, prénoms, spécialité, établissement)","copies":4,"nature":"fichier","source":"eleve"},
        {"code":"certificat_medical","label":"Certificat médical d''inaptitude physique (EPS)","copies":1,"nature":"fichier","source":"candidature","condition":"si_inapte_eps"},
        {"code":"chemise","label":"Chemise cartonnée","copies":1,"nature":"physique"},
        {"code":"enveloppe","label":"Enveloppe kaki format A4","copies":1,"nature":"physique"},
        {"code":"frais","label":"Frais d''inscription","copies":1,"nature":"financiere","source":"candidature"}
       ]'::jsonb,
       updated_at = now()
  FROM national_exams e
 WHERE e.id = s.exam_id AND e.code = 'BEP' AND s.year_label = '2025-2026';

-- ── CAP — diplôme antérieur légalisé. Pas de certificat médical dans la note
--    (elle ne le cite que pour BEP et BTF). Ne pas l'ajouter « par symétrie ».
UPDATE exam_sessions s
   SET required_documents = '[
        {"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2,"nature":"fichier","source":"eleve"},
        {"code":"diplome_anterieur","label":"Copie légalisée du diplôme (BEPC ou BET)","copies":2,"nature":"fichier","source":"eleve","legalise":true},
        {"code":"photos","label":"Photos d''identité couleur (au verso : noms, prénoms, spécialité, établissement)","copies":4,"nature":"fichier","source":"eleve"},
        {"code":"chemise","label":"Chemise cartonnée","copies":1,"nature":"physique"},
        {"code":"enveloppe","label":"Enveloppe kaki format A4","copies":1,"nature":"physique"},
        {"code":"frais","label":"Frais d''inscription","copies":1,"nature":"financiere","source":"candidature"}
       ]'::jsonb,
       updated_at = now()
  FROM national_exams e
 WHERE e.id = s.exam_id AND e.code = 'CAP' AND s.year_label = '2025-2026';

-- ── BTF — + la note d'admission au concours d'entrée à l'ENEF (pièce unique
--    au BTF : 71 candidats, 1 centre — c'est l'examen de l'École Nationale
--    des Eaux et Forêts).
UPDATE exam_sessions s
   SET required_documents = '[
        {"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2,"nature":"fichier","source":"eleve"},
        {"code":"diplome_anterieur","label":"Copie légalisée du diplôme (BEPC ou BET)","copies":2,"nature":"fichier","source":"eleve","legalise":true},
        {"code":"photos","label":"Photos d''identité couleur (au verso : noms, prénoms, spécialité, établissement)","copies":4,"nature":"fichier","source":"eleve"},
        {"code":"note_enef","label":"Note d''admission au concours d''entrée à l''ENEF","copies":1,"nature":"fichier","source":"eleve"},
        {"code":"certificat_medical","label":"Certificat médical d''inaptitude physique (EPS)","copies":1,"nature":"fichier","source":"candidature","condition":"si_inapte_eps"},
        {"code":"chemise","label":"Chemise cartonnée","copies":1,"nature":"physique"},
        {"code":"enveloppe","label":"Enveloppe kaki format A4","copies":1,"nature":"physique"},
        {"code":"frais","label":"Frais d''inscription","copies":1,"nature":"financiere","source":"candidature"}
       ]'::jsonb,
       updated_at = now()
  FROM national_exams e
 WHERE e.id = s.exam_id AND e.code = 'BTF' AND s.year_label = '2025-2026';

-- ── BAC_T / BAC_P — âge 24. L'ATTESTATION DE FIN DE STAGE est une pièce du
--    dossier (note officielle) : le module Stages produit une pièce sans
--    laquelle l'élève ne s'inscrit pas au bac.
UPDATE exam_sessions s
   SET required_documents = '[
        {"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2,"nature":"fichier","source":"eleve"},
        {"code":"diplome_anterieur","label":"Copie légalisée du diplôme (BEPC, BEMG, BET ou BEP)","copies":2,"nature":"fichier","source":"eleve","legalise":true},
        {"code":"photos","label":"Photos d''identité couleur (au verso : noms, prénoms, série, établissement)","copies":4,"nature":"fichier","source":"eleve"},
        {"code":"attestation_stage","label":"Attestation de fin de stage","copies":1,"nature":"fichier","source":"candidature"},
        {"code":"certificat_medical","label":"Certificat médical d''inaptitude physique (EPS)","copies":1,"nature":"fichier","source":"candidature","condition":"si_inapte_eps"},
        {"code":"chemise","label":"Chemise cartonnée","copies":1,"nature":"physique"},
        {"code":"enveloppe","label":"Enveloppe kaki format A4","copies":1,"nature":"physique"},
        {"code":"frais","label":"Frais d''inscription","copies":1,"nature":"financiere","source":"candidature"}
       ]'::jsonb,
       updated_at = now()
  FROM national_exams e
 WHERE e.id = s.exam_id AND e.code IN ('BAC_T','BAC_P') AND s.year_label = '2025-2026';

COMMIT;

-- ── Vérifications ──────────────────────────────────────────────────────────
-- select e.code, jsonb_array_length(s.required_documents) as pieces,
--        (select count(*) from jsonb_array_elements(s.required_documents) p
--          where p->>'condition' is not null) as conditionnelles,
--        (select count(*) from jsonb_array_elements(s.required_documents) p
--          where p->>'nature' = 'physique') as physiques
--   from exam_sessions s join national_exams e on e.id = s.exam_id
--  where s.year_label = '2025-2026' order by e.code;
