-- ════════════════════════════════════════════════════════════════════════════
--  0142 — ⚠️ NE PAS APPLIQUER AVANT LA PUBLICATION DU BUILD ⚠️
--
--  Rétablit le verbe sur l'`INSERT` de `subjects` et `school_programs`, que la
--  migration 0141 a dû desserrer en urgence.
--
--  ── POURQUOI 0141 A RECULÉ ────────────────────────────────────────────────
--  Le build publié (3.3.0+20) garde la barre d'outils de Matières et de
--  Programmes par `PermissionGate(create)`, mais pas leur `AdminEmptyState` —
--  et 36 écoles sur 37 sont dans cet état vide. Le profil « Secrétariat » lit
--  ces modules sans détenir `create` : un appui produisait un 42501, code
--  fatal, lot PowerSync entier jeté.
--
--  Le build en attente ferme cette seconde porte (`canCreate` sur l'état vide,
--  gardé par `test/porte_de_creation_test.dart`). Une fois publié, le verbe
--  peut revenir.
--
--  ORDRE : pousser les commits → publier le build → appliquer 0139 PUIS 0142.
-- ════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS subjects_insert ON subjects;
CREATE POLICY subjects_insert ON subjects FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['matieres'], 'create'))))));

DROP POLICY IF EXISTS school_programs_insert ON school_programs;
CREATE POLICY school_programs_insert ON school_programs FOR INSERT WITH CHECK (
  (SELECT is_super_admin())
  OR (group_id = (SELECT auth_group_id())
      AND ((SELECT is_admin_groupe())
           OR (school_id = (SELECT auth_school_id())
               AND (SELECT auth_module_permet(ARRAY['programmes'], 'create'))))));

COMMENT ON TABLE subjects IS
  'Matières de l''établissement. Écriture gardée par le verbe du module '
  '`matieres` (0131, desserrée en 0141 le temps d''un build, rétablie en 0142).';
