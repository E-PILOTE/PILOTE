-- ════════════════════════════════════════════════════════════════════════════
--  0109 — L'EXONÉRATION CESSE D'ÊTRE DÉCORATIVE
--
--  ── LE PROBLÈME ────────────────────────────────────────────────────────────
--  `students.has_scholarship` est saisi dans l'assistant d'inscription, stocké,
--  synchronisé, affiché en pastille sur la fiche de l'élève et dans son tiroir.
--  Il n'entre dans AUCUN calcul. Un boursier à 100 % apparaît donc « Impayé »
--  au même titre qu'une famille qui ne règle pas — et la caisse le relance.
--
--  C'est le pire des deux mondes : l'information est demandée à la famille,
--  elle est conservée, et elle ne sert à rien. Le jour où une école tente de
--  s'en servir, elle n'a d'autre issue que d'inscrire l'enfant sans barème ou
--  d'encaisser un versement fictif pour « solder » le dossier — deux façons de
--  fausser la caisse durablement.
--
--  ── POURQUOI SUR L'INSCRIPTION, ET NON SUR L'ÉLÈVE ─────────────────────────
--  Une bourse se décide POUR UNE ANNÉE. Posée sur `students`, elle suivrait
--  l'enfant indéfiniment : une exonération accordée en 2024 continuerait de
--  réduire son dû en 2028, sans que personne ne l'ait reconduite. Le taux vit
--  donc sur `class_enrollments`, c'est-à-dire là où la décision se renouvelle,
--  au même endroit que la classe, la date et le statut du dossier.
--
--  `students.has_scholarship` garde son rôle : dire que l'enfant EST dans une
--  situation de bourse (statistiques, rapports sociaux, pastille). Il ne
--  devient jamais la source du calcul — c'eût été un second exemplaire du même
--  fait, et l'on connaît la suite (le barème des mentions a vécu en trois
--  exemplaires, deux ont dérivé).
--
--  ── LE MOTIF EST OBLIGATOIRE ───────────────────────────────────────────────
--  Une exonération, c'est de l'argent que l'école renonce à percevoir. Sans
--  justification écrite, elle devient indéfendable devant un contrôle et
--  indistinguable d'une faveur. La contrainte l'exige — pas l'interface, qui se
--  contourne.
--
--  ── PORTÉE DU TAUX (décidée côté application) ──────────────────────────────
--  L'exonération couvre la SCOLARITÉ : inscription, mensualité, cotisation APE.
--  Elle ne couvre NI les frais d'examen (ce sont ceux de l'État, l'école ne
--  peut pas en dispenser), NI les frais annexes (cantine, transport : l'école
--  décaisse réellement des repas et du carburant). Cf. `kFraisScolarite` dans
--  `obligation.dart` — SEULE autorité sur cette liste.
--
--  ── SÛRETÉ ─────────────────────────────────────────────────────────────────
--  Deux colonnes nullables, aucune valeur par défaut : les 9 106 inscriptions
--  existantes restent à NULL, donc sans exonération, donc au dû inchangé.
--  `class_enrollments` descend déjà en entier sur les postes (`SELECT *` dans
--  le bucket `by_school`) : aucun redéploiement de sync-rules.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE public.class_enrollments
  ADD COLUMN IF NOT EXISTS exemption_rate  smallint,
  ADD COLUMN IF NOT EXISTS exemption_motif text;

COMMENT ON COLUMN public.class_enrollments.exemption_rate IS
  'Part de la SCOLARITÉ dont cet élève est dispensé cette année, en %. '
  'NULL = aucune exonération. Ne couvre ni les frais d''examen ni les frais '
  'annexes (cf. kFraisScolarite, obligation.dart).';

COMMENT ON COLUMN public.class_enrollments.exemption_motif IS
  'Pourquoi. Obligatoire dès qu''un taux est posé : une exonération sans '
  'justification est indéfendable devant un contrôle.';

-- 1 à 100. Zéro est refusé À DESSEIN : « exonéré de rien » et « pas exonéré »
-- seraient deux façons d'écrire la même chose, et deux écrans finiraient par
-- les traiter différemment. L'interface enlève l'exonération plutôt que de la
-- mettre à zéro.
ALTER TABLE public.class_enrollments
  ADD CONSTRAINT class_enrollments_exoneration_bornee
  CHECK (exemption_rate IS NULL OR (exemption_rate >= 1 AND exemption_rate <= 100));

ALTER TABLE public.class_enrollments
  ADD CONSTRAINT class_enrollments_exoneration_justifiee
  CHECK (exemption_rate IS NULL OR btrim(COALESCE(exemption_motif, '')) <> '');

COMMIT;
