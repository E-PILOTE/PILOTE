-- ════════════════════════════════════════════════════════════════════════════
--  0132 — UN JOURNAL MÉDICAL SANS ANNÉE
--
--  `infirmary_visits` n'avait AUCUNE colonne d'année scolaire. Seule table du
--  domaine élève dans ce cas : `discipline_incidents`, `attendance_records`,
--  `class_enrollments`, `bulletins` en portent toutes une.
--
--  Trois conséquences, toutes visibles à l'écran :
--
--    1. Les compteurs cumulent depuis l'ouverture de l'établissement.
--       « Passages : 1 240 au total », « Parents notifiés : 830 sur 1 240 » —
--       des nombres qui mélangent quatre promotions et ne veulent rien dire.
--       Le libellé de l'écran ne prétendait d'ailleurs à aucune année, faute
--       de pouvoir en tenir une.
--
--    2. La CLASSE du passage ne pouvait pas être celle du jour des faits.
--       0131 a corrigé ce point pour la discipline en visant l'inscription de
--       l'année de l'incident ; l'infirmerie a dû se contenter de la plus
--       récente, limite écrite en toutes lettres dans le code. Cette colonne
--       lève la limite.
--
--    3. Aucune rétention possible. `docs/ANALYSE.md` annonce une conservation
--       bornée ; sans année, on ne sait même pas ce qu'on garderait. Du
--       médical sur des mineurs qui s'accumule sans terme.
--
--  ── LE MOMENT ─────────────────────────────────────────────────────────────
--  La table est VIDE (0 ligne, relevé du 2026-08-28). Aucune reprise, aucun
--  remplissage rétroactif : la colonne s'ajoute à coût nul. Dans un an, il
--  aurait fallu deviner l'année de chaque passage à partir de sa date, et se
--  tromper sur ceux de septembre.
--
--  ── NULLABLE, ET CE N'EST PAS UN RELÂCHEMENT ──────────────────────────────
--  `NOT NULL` produirait un 23502 sur toute écriture qui l'oublierait — code
--  FATAL pour le connecteur PowerSync, qui jette le LOT ENTIER en attente : le
--  passage à l'infirmerie, mais aussi les paiements et les notes saisis dans la
--  même heure. `discipline_incidents.academic_year_id` est nullable pour la
--  même raison. C'est l'application qui garantit la valeur ; la base ne
--  transforme pas un oubli en perte de données.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE infirmary_visits
  ADD COLUMN IF NOT EXISTS academic_year_id uuid REFERENCES academic_years(id);

CREATE INDEX IF NOT EXISTS idx_infirmary_visits_academic_year_id
  ON infirmary_visits USING btree (academic_year_id);

COMMENT ON COLUMN infirmary_visits.academic_year_id IS
  'Année scolaire du passage. Ajoutée par la migration 0132 : sans elle, les '
  'compteurs du journal cumulaient toutes les promotions et aucune rétention '
  'n''était exprimable. Nullable à dessein — un 23502 est un code fatal pour '
  'le connecteur PowerSync, qui jetterait le lot d''écritures entier.';
