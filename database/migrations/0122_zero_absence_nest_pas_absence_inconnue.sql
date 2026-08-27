-- ════════════════════════════════════════════════════════════════════════════
--  0122 — « ZÉRO ABSENCE » N'EST PAS « ABSENCES INCONNUES »
--
--  `bulletins.total_absences` et `total_lates` étaient NOT NULL DEFAULT 0, et
--  l'application y écrivait 0 EN DUR — jamais calculé, jamais affiché. La base
--  affirmait donc, pour chaque élève de chaque trimestre, qu'il n'avait manqué
--  aucune heure. Un fait sur un enfant, écrit sans l'avoir observé.
--
--  Les données existent pourtant : `attendance_records` / `attendance_entries`,
--  alimentées par l'appel quotidien (module `presences-eleves`). Le bulletin
--  les compte désormais sur la fenêtre du trimestre, et les affiche — à
--  l'écran comme sur le PDF officiel, où l'assiduité ne figurait pas du tout.
--
--  Mais tant qu'aucun appel n'a été fait, la réponse honnête n'est pas « 0 » :
--  c'est « on ne sait pas ». D'où NULL, qui n'était pas exprimable. Le bulletin
--  affiche alors « — » plutôt qu'un zéro rassurant et faux.
--
--  Rétrocompatible : un poste ancien qui écrit toujours une valeur reste
--  accepté. Aucune ligne existante n'est modifiée — les 18 208 bulletins déjà
--  publiés gardent leur 0, qui n'a jamais été affiché nulle part.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE bulletins
  ALTER COLUMN total_absences DROP NOT NULL,
  ALTER COLUMN total_absences DROP DEFAULT,
  ALTER COLUMN total_lates DROP NOT NULL,
  ALTER COLUMN total_lates DROP DEFAULT;

COMMENT ON COLUMN bulletins.total_absences IS
  'Demi-journées d''absence comptées sur la fenêtre du trimestre depuis '
  'attendance_entries. NULL = aucun appel enregistré pour cet élève sur la '
  'période : inconnu, et surtout PAS « aucune absence » (migration 0122).';

COMMENT ON COLUMN bulletins.total_lates IS
  'Retards comptés de la même façon. NULL = inconnu (migration 0122).';
