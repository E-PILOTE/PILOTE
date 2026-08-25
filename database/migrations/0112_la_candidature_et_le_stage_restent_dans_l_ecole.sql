-- ════════════════════════════════════════════════════════════════════════════
--  0112 — LA CANDIDATURE ET LE STAGE RESTENT DANS L'ÉCOLE
--
--  ── LE PROBLÈME ────────────────────────────────────────────────────────────
--  Suite du balayage ouvert par 0111 : `exam_candidates` et `internships`
--  descendent par ÉCOLE dans les sync-rules (`WHERE school_id = bucket.sid`),
--  mais leur RLS n'autorisait que `group_id` — en LECTURE comme en ÉCRITURE.
--
--  Le groupe, ici, c'est le ministère. Un enseignant ou un surveillant d'une
--  école, avec son jeton valide, pouvait donc demander à l'API les
--  candidatures aux examens d'État de TOUTES les écoles du pays : élève,
--  école, état du dossier. Son appareil ne les recevait pas ; l'API les
--  rendait. Deux verrous, un seul tourné — cf. [[rls-ecole-vs-sync-rules]].
--
--  ⚠️ CHAQUE TABLE A DEUX POLITIQUES, et la seconde est `FOR ALL`. Permissives,
--  elles s'additionnent : ne resserrer que `_select` n'aurait RIEN fermé,
--  puisque `_write` accorde aussi la lecture. Les deux sont réécrites.
--
--  ── POURQUOI `is_super_admin()` RESTE ICI ──────────────────────────────────
--  0111 l'a retiré des lignes de bulletin parce que RIEN ne les lisait. Ce
--  n'est pas le cas ici : `super_exams_provider.dart` interroge les deux
--  tables pour la page examens de la plateforme, et ses chiffres sont
--  nationaux par construction.
--
--  Il les lit PSEUDONYMEMENT — `group_id, school_id, student_id,
--  dossier_status` d'un côté, `student_id, attestation_issued_at` de l'autre.
--  Pas un nom, pas un INE. La branche reste donc, et la minimisation tient au
--  choix des colonnes plutôt qu'à la fermeture du verrou.
--
--  ── CE QUE ÇA CHANGE POUR LE MINISTÈRE ─────────────────────────────────────
--  Rien. `is_admin_groupe()` garde la vue d'ensemble : c'est par elle que le
--  cockpit et les écrans `admin_groupe` lisent les candidatures de leurs
--  écoles.
--
--  ── LA CONSÉQUENCE ASSUMÉE ─────────────────────────────────────────────────
--  Un élève qui change d'école DANS le groupe : l'école d'accueil ne lira plus
--  sa candidature ni son stage antérieurs, donc son éligibilité au bac.
--
--  Cette limite EXISTE DÉJÀ — les sync-rules l'imposent au transport depuis
--  toujours, et `student_history_provider` calcule l'éligibilité en LOCAL, sur
--  ce que le bucket a livré. Cette migration ne la crée pas : elle met le
--  second verrou d'accord avec le premier.
--
--  Le jour où ce besoin devient réel, il se traite par une fonction
--  `SECURITY DEFINER` rendant les BOOLÉENS d'éligibilité — jamais en rouvrant
--  la lecture nominative. `has_internship_attestation(p_student)` a déjà
--  exactement cette forme, à `SECURITY DEFINER` près ; elle n'est aujourd'hui
--  appelée par aucun code Dart.
--
--  ── ÉTAT AVANT ─────────────────────────────────────────────────────────────
--  exam_candidates : 2 126 lignes · school_id NOT NULL · 0 nulle · 0 divergence
--                    avec l'école de l'élève.
--  internships     : 0 ligne.
--
--  Rien à redéployer côté PowerSync : la RLS ne s'applique pas au chemin de
--  réplication.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

DROP POLICY IF EXISTS exam_candidates_select ON public.exam_candidates;
CREATE POLICY exam_candidates_select ON public.exam_candidates
  FOR SELECT
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

DROP POLICY IF EXISTS exam_candidates_write ON public.exam_candidates;
CREATE POLICY exam_candidates_write ON public.exam_candidates
  FOR ALL
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  )
  WITH CHECK (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

DROP POLICY IF EXISTS internships_select ON public.internships;
CREATE POLICY internships_select ON public.internships
  FOR SELECT
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

DROP POLICY IF EXISTS internships_write ON public.internships;
CREATE POLICY internships_write ON public.internships
  FOR ALL
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  )
  WITH CHECK (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

COMMIT;
