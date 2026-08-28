-- ════════════════════════════════════════════════════════════════════════════
--  0141 — DESSERRER DEUX `INSERT` QUE LE BUILD PUBLIÉ NE GARDE PAS
--
--  ⚠️ CETTE MIGRATION RECULE. Elle défait une partie de 0131 et 0135, et c'est
--  volontaire : j'ai enfreint ma propre règle (`docs/DEPLOIEMENT_ORDRE.md`) en
--  durcissant ces deux tables avant que le build correspondant ne soit publié.
--
--  ── CE QUE LA MESURE A MONTRÉ ─────────────────────────────────────────────
--  Le build publié (3.3.0+20) garde la barre d'outils de Matières et de
--  Programmes par `PermissionGate(create)` — mais pas leur `AdminEmptyState`,
--  qui n'est gardé que par `readOnly`. L'état vide est donc une seconde porte,
--  ouverte à quiconque peut LIRE le module.
--
--  Relevé sur la base de production, ce jour :
--
--      37 écoles. 36 ont ZÉRO matière et ZÉRO programme.
--
--  L'état vide n'est pas un cas limite : c'est l'écran que voit aujourd'hui la
--  quasi-totalité des établissements. Et le profil « Secrétariat » livré au
--  catalogue LIT ces deux modules sans détenir `create`.
--
--  Conséquence, en production, maintenant : une secrétaire ouvre Matières,
--  appuie sur « Nouvelle matière » au centre de l'écran, enregistre. L'écriture
--  locale réussit. À la remontée, Postgres refuse en 42501 — code FATAL pour le
--  connecteur PowerSync, qui appelle `transaction.complete()` et JETTE LE LOT
--  ENTIER en attente sur le poste.
--
--  ── POURQUOI RECULER PLUTÔT QUE DONNER LE VERBE ───────────────────────────
--  Accorder `matieres.create` / `programmes.create` au Secrétariat ferait
--  disparaître le refus, mais contredirait le catalogue : il donne à ce profil
--  la LECTURE de toute la structure pédagogique (classes, matières,
--  programmes, emploi du temps) et l'ÉCRITURE à la Direction. Ce partage est
--  une décision, pas un accident ; on ne la retourne pas pour rattraper une
--  erreur d'ordre de déploiement.
--
--  ── POURQUOI SEULEMENT CES DEUX TABLES ────────────────────────────────────
--  Les trois autres écrans dont l'état vide était ouvert (`classes`, `eleves`,
--  `inscriptions`) sont hors d'atteinte : les 37 écoles ont toutes des classes
--  ET des élèves. Leur état vide ne s'affiche nulle part. Ils restent gardés.
--
--  ── CE QUI RESTE GARDÉ ICI ────────────────────────────────────────────────
--  Seul l'`INSERT` est desserré. `UPDATE` et `DELETE` gardent leur verbe : ils
--  portent la garde par `USING`, qui filtre les lignes au lieu de lever — zéro
--  ligne touchée, aucun code fatal, aucun lot perdu.
--
--  ── LE CHEMIN DE RETOUR ───────────────────────────────────────────────────
--  `0142_APRES_LE_BUILD_matieres_et_programmes_par_le_verbe.sql` rétablit le
--  verbe. Il s'applique APRÈS la publication du build, avec `0139`.
-- ════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS subjects_insert ON subjects;
CREATE POLICY subjects_insert ON subjects FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR school_id = (SELECT auth_school_id()))));

DROP POLICY IF EXISTS school_programs_insert ON school_programs;
CREATE POLICY school_programs_insert ON school_programs FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR school_id = (SELECT auth_school_id()))));

COMMENT ON TABLE subjects IS
  'Matières de l''établissement. ⚠️ L''INSERT est TEMPORAIREMENT sans verbe '
  '(migration 0141) : le build publié 3.3.0+20 offre la création depuis l''état '
  'vide sans lire `create`, et 36 écoles sur 37 sont dans cet état. Rétabli par '
  '0142, après publication du build.';
