-- ════════════════════════════════════════════════════════════════════════════
--  0123 — MARQUER UN ENFANT ABSENT EST UN DROIT, PAS UNE APPARTENANCE
--
--  `attendance_records` et `attendance_entries` n'avaient qu'UNE politique,
--  `FOR ALL`, ne vérifiant que l'appartenance à l'école. N'importe quel membre
--  du personnel — le comptable, l'infirmier, le responsable de cantine — a
--  donc pu, côté serveur, créer, modifier et SUPPRIMER l'appel de n'importe
--  quelle classe. L'application, elle, ne montre le bouton qu'à qui détient
--  `presences-eleves.update` : le cadenas était fermé dans l'écran, ouvert
--  dans la base. Même défaut que celui corrigé en 0114 (paiements) puis 0118
--  (notes et bulletins).
--
--  Ce n'est pas anodin : la ligne d'absence est la pièce qui justifie où était
--  un enfant. Elle nourrit la discipline, la convocation des parents, et
--  désormais le bulletin (migration 0122).
--
--  ── LA RÈGLE ───────────────────────────────────────────────────────────────
--  Lecture : à l'échelle de l'école (le périmètre par classe vit dans
--  l'application — un surveillant fait le tour de plusieurs classes).
--  Écriture : gâtée par le module `presences-eleves`, verbe par verbe.
--
--  ⚠️ Un seul module écrit ces tables — vérifié par relevé des appels, il n'y
--  a qu'un écran (`presences_roll.dart`). Pas de second module à admettre,
--  contrairement aux bulletins que le conseil de classe écrit aussi (0116).
--
--  ⚠️ L'application ne SUPPRIME jamais une ligne d'appel : `delete` est gâté
--  par prudence, sans rien fermer d'existant. Et aucun 42501 n'est introduit :
--  l'écran gardait déjà ses boutons sur `update`, y compris dans le binaire
--  déployé (build 20).
--
--  ── VÉRIFIÉ APRÈS COUP (production, transaction annulée) ───────────────────
--      Direction      lit ✓  déclare absent OUI  finalise OUI  efface OUI
--      Vie scolaire   lit ✓  déclare absent OUI  finalise OUI  efface non
--      Enseignant     lit ✓  déclare absent refusé
--      Secrétariat    lit ✓  déclare absent refusé
--
--  ⚠️ À DÉCIDER, HORS CODE : dans le catalogue livré, l'ENSEIGNANT n'a AUCUN
--  droit d'écriture sur les présences — l'appel revient à la Vie scolaire.
--  C'est un choix d'organisation défendable (le surveillant fait le tour),
--  mais `docs/ANALYSE.md` §7 pose l'inverse : « Notes et absences (enseignant
--  → sync auto) » y est la raison d'être du hors-ligne. Ces droits sont de la
--  configuration de groupe, pas du code : à trancher par l'admin groupe.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── attendance_records ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS att_records_tenant ON attendance_records;

CREATE POLICY att_records_select ON attendance_records
  FOR SELECT
  USING (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))
  );

CREATE POLICY att_records_insert ON attendance_records
  FOR INSERT
  WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (school_id = (SELECT auth_school_id())
          AND (SELECT auth_module_permet(ARRAY['presences-eleves'], 'create')))
    )
  );

CREATE POLICY att_records_update ON attendance_records
  FOR UPDATE
  USING (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (school_id = (SELECT auth_school_id())
          AND (SELECT auth_module_permet(ARRAY['presences-eleves'], 'update')))
    )
  )
  WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))
  );

CREATE POLICY att_records_delete ON attendance_records
  FOR DELETE
  USING (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (school_id = (SELECT auth_school_id())
          AND (SELECT auth_module_permet(ARRAY['presences-eleves'], 'delete')))
    )
  );

-- ─── attendance_entries ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS att_entries_tenant ON attendance_entries;

CREATE POLICY att_entries_select ON attendance_entries
  FOR SELECT
  USING (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))
  );

CREATE POLICY att_entries_insert ON attendance_entries
  FOR INSERT
  WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (school_id = (SELECT auth_school_id())
          AND (SELECT auth_module_permet(ARRAY['presences-eleves'], 'create')))
    )
  );

CREATE POLICY att_entries_update ON attendance_entries
  FOR UPDATE
  USING (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (school_id = (SELECT auth_school_id())
          AND (SELECT auth_module_permet(ARRAY['presences-eleves'], 'update')))
    )
  )
  WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))
  );

CREATE POLICY att_entries_delete ON attendance_entries
  FOR DELETE
  USING (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (school_id = (SELECT auth_school_id())
          AND (SELECT auth_module_permet(ARRAY['presences-eleves'], 'delete')))
    )
  );
