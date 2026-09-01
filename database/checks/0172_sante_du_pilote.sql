-- ════════════════════════════════════════════════════════════════════════════
--  SANTÉ DU PILOTE — à rejouer chaque matin pendant la phase pilote.
--
--  Lecture seule. Aucun ROLLBACK nécessaire : rien n'est écrit.
--
--  Usage :
--    psql "$DATABASE_URL" -f database/checks/0172_sante_du_pilote.sql
--
--  ── ⚠️ CE QUE LE SERVEUR NE PEUT PAS VOIR ─────────────────────────────────
--  `sync_failures` est une table LOCAL-ONLY : elle vit sur le poste et ne
--  remonte JAMAIS. Si le poste d'une école se bloque — désaccord de schéma,
--  file d'envoi arrêtée —, le bandeau s'affiche à l'école et le serveur n'en
--  sait RIEN.
--
--  Le seul signal côté serveur est donc le SILENCE : `last_seen_at` qui cesse
--  d'avancer. C'est pourquoi la colonne « vu il y a » ci-dessous est la plus
--  importante du tableau — pas le nombre de lignes créées.
--
--  ⚠️ Corollaire pour le pilote : un poste muet doit être APPELÉ, pas attendu.
--  Trois jours de silence sur une école qui travaillait est une alerte, même
--  si tout le reste paraît normal.
-- ════════════════════════════════════════════════════════════════════════════

\echo '── 1. LES POSTES : qui est installé, sur quelle version, vu quand ──'
SELECT s.name                                    AS ecole,
       i.version || ' (build ' || i.build_number || ')' AS version,
       to_char(i.first_seen_at, 'DD/MM HH24:MI') AS installe_le,
       to_char(i.last_seen_at,  'DD/MM HH24:MI') AS vu_le,
       CASE
         WHEN i.last_seen_at > now() - interval '1 day'  THEN 'ok'
         WHEN i.last_seen_at > now() - interval '3 days' THEN 'silencieux'
         ELSE                                                 'MUET — APPELER'
       END                                       AS etat
  FROM app_installations i
  JOIN schools s ON s.id = i.school_id
 ORDER BY i.last_seen_at;

\echo ''
\echo '── 2. LES GENS : qui s''est connecté, et qui ne s''est JAMAIS connecté ──'
SELECT s.name                                     AS ecole,
       p.role,
       p.first_name || ' ' || p.last_name         AS agent,
       COALESCE(to_char(u.last_sign_in_at, 'DD/MM HH24:MI'), 'JAMAIS') AS derniere_session
  FROM profiles p
  JOIN schools s     ON s.id = p.school_id
  LEFT JOIN auth.users u ON u.id = p.id
 WHERE p.is_active
   AND s.id IN (SELECT school_id FROM app_installations)
 ORDER BY s.name, (u.last_sign_in_at IS NOT NULL), p.role;

\echo ''
\echo '── 3. LE TRAVAIL RÉEL : ce que l''école a produit, par jour ──'
-- ⚠️ C'est le seul chiffre qui dise si le produit SERT. Un poste allumé qui
-- ne produit rien est un poste que personne n'utilise — et c'est une issue
-- de pilote aussi instructive qu'une panne.
SELECT s.name AS ecole, j.jour::date AS jour,
       j.eleves, j.notes, j.presences, j.paiements, j.bulletins
  FROM schools s
  JOIN LATERAL (
    SELECT d::date AS jour,
      (SELECT count(*) FROM students        x WHERE x.school_id=s.id AND x.created_at::date=d::date) AS eleves,
      (SELECT count(*) FROM grades          x WHERE x.school_id=s.id AND x.created_at::date=d::date) AS notes,
      (SELECT count(*) FROM attendance_records x WHERE x.school_id=s.id AND x.created_at::date=d::date) AS presences,
      (SELECT count(*) FROM student_payments x WHERE x.school_id=s.id AND x.created_at::date=d::date) AS paiements,
      (SELECT count(*) FROM bulletins       x WHERE x.school_id=s.id AND x.created_at::date=d::date) AS bulletins
      FROM generate_series(current_date - 13, current_date, interval '1 day') d
  ) j ON true
 WHERE s.id IN (SELECT school_id FROM app_installations)
   AND (j.eleves + j.notes + j.presences + j.paiements + j.bulletins) > 0
 ORDER BY s.name, j.jour DESC;

\echo ''
\echo '── 4. LES GESTES TRACÉS : ce que le journal d''audit a retenu ──'
SELECT s.name AS ecole, a.table_name, a.action, a.user_role,
       count(*) AS n,
       to_char(max(a.created_at), 'DD/MM HH24:MI') AS dernier
  FROM audit_logs a
  JOIN schools s ON s.id = a.school_id
 WHERE a.school_id IN (SELECT school_id FROM app_installations)
   AND a.created_at > now() - interval '14 days'
 GROUP BY s.name, a.table_name, a.action, a.user_role
 ORDER BY s.name, n DESC;

\echo ''
\echo '── 5. CE QUI DEVRAIT EXISTER ET N''EXISTE PAS ──'
-- Les manques qui bloquent un usage reel, ecole par ecole. Une case a 0 ici
-- explique souvent un « ca ne marche pas » qui n'est pas une panne.
--
-- ⚠️ CORRIGE LE 2026-09-01, APRES DEUX FAUSSES ALERTES. La premiere version
-- filtrait `subjects` et `fee_structures` sur `school_id` — or 61 matieres sur
-- 62 et la TOTALITE des baremes sont portes par le GROUPE, jamais par l'ecole
-- (« un bareme n'est pas une donnee de l'ecole : dans le public il vient d'un
-- arrete, dans le prive du siege ; l'ecole recoit et applique », mig 0096).
-- La sonde annoncait donc « 0 » la ou tout etait en place, sur toutes les
-- ecoles. Une sonde qui crie au loup envoie un technicien chasser un probleme
-- inexistant le jour 1 — c'est pire que pas de sonde.
SELECT s.name AS ecole,
       (SELECT count(*) FROM academic_years y
         WHERE y.group_id = s.group_id AND y.is_current)              AS annee_courante,
       (SELECT count(*) FROM classes c
         WHERE c.school_id = s.id AND c.is_active)                    AS classes,
       (SELECT count(*) FROM students e WHERE e.school_id = s.id)     AS eleves,
       -- disponible = la sienne OU celle de son groupe
       (SELECT count(*) FROM subjects m
         WHERE m.school_id = s.id
            OR (m.school_id IS NULL AND m.group_id = s.group_id))     AS matieres_dispo,
       -- ce qui compte vraiment pour noter : les matieres RATTACHEES aux classes
       (SELECT count(*) FROM class_subjects cs WHERE cs.school_id = s.id) AS matieres_rattachees,
       (SELECT count(*) FROM fee_structures f
         WHERE f.is_active
           AND (f.school_id = s.id
             OR (f.school_id IS NULL AND f.group_id = s.group_id)))   AS bareme_applicable,
       (SELECT count(*) FROM profiles p
         WHERE p.school_id = s.id AND p.is_active)                    AS agents,
       (SELECT count(*) FROM timetable_slots t WHERE t.school_id = s.id) AS creneaux_edt
  FROM schools s
 WHERE s.id IN (SELECT school_id FROM app_installations)
 ORDER BY s.name;
