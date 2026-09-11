-- ════════════════════════════════════════════════════════════════════════════
--  0205 — LE PALMARÈS LISAIT LE COEFFICIENT PAR DÉFAUT, PAS CELUI DE LA CLASSE
-- ════════════════════════════════════════════════════════════════════════════
--
--  ── LE DÉFAUT ──────────────────────────────────────────────────────────────
--  TROIS moteurs calculent la moyenne générale d'un élève, et ils ne lisaient
--  pas le même coefficient de matière :
--
--    • le BULLETIN (offline, `evaluation/providers/bulletins_provider.dart`)
--        → COALESCE(cs.coefficient, subj.coefficient)   ← l'EFFECTIF
--    • le DOSSIER RÉSEAU (online, `admin_groupe/.../student_results_provider`)
--        → subjects.coefficient                         ← le DÉFAUT
--    • cette FONCTION, qui produit le palmarès du réseau
--        → sub.coefficient                              ← le DÉFAUT
--
--  Or `subjects.coefficient` n'est qu'un coefficient PAR DÉFAUT, proposé — le
--  modèle Dart le dit noir sur blanc (`data/models/subject_model.dart:7`). Le
--  coefficient qui compte vit sur `class_subjects`, parce qu'une Terminale C
--  ne pondère pas les mathématiques comme une Terminale A. L'écran qui l'édite
--  existe et écrit vraiment (`class_subjects_provider.dart:188`).
--
--  ── POURQUOI MAINTENANT ────────────────────────────────────────────────────
--  Mesuré le 2026-09-09 sur cette base :
--
--      select count(*) filter (where cs.coefficient is distinct from s.coefficient)
--      from class_subjects cs join subjects s on s.id = cs.subject_id;
--      → 0 divergent sur 4 564 lignes
--
--  Aucune classe n'a encore surchargé un coefficient : les trois moteurs
--  tombent d'accord PAR ACCIDENT. Cette migration est donc, aujourd'hui, un
--  NO-OP exact — elle ne change aucune valeur affichée.
--
--  À la première surcharge, en revanche, le bulletin que reçoit la famille et
--  le palmarès que lit le ministère auraient annoncé deux moyennes différentes
--  pour le même élève, le même trimestre. Corrigé après coup, il aurait fallu
--  reprendre les données. La fenêtre pour le faire proprement est celle-ci.
--
--  ── LA CORRECTION ──────────────────────────────────────────────────────────
--  Une seule jointure et un COALESCE. Le reste de la fonction est INCHANGÉ,
--  volontairement : filtres, classe de passage, absence ignorée, moyenne de
--  classe, ordre, limite. On ne touche qu'à ce qui est faux.
--
--  ⚠️ DÉPLOIEMENT : le pendant côté client part dans le même lot
--  (`student_results_provider.dart` lit désormais `class_subjects`). Les deux
--  moitiés peuvent partir dans n'importe quel ordre — tant que la divergence
--  est à zéro, chacune est un no-op prise isolément.
--
--  Cf. `docs/analyse-2026-09/20-transversal-doublons.md` §B.1.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_passage_merit(
  p_group_id uuid,
  p_academic_year_id uuid,
  p_trimester_id uuid DEFAULT NULL::uuid,
  p_level_code text DEFAULT NULL::text,
  p_limit integer DEFAULT 50,
  p_department text DEFAULT NULL::text,
  p_filiere_label text DEFAULT NULL::text
)
RETURNS TABLE(
  student_id uuid, full_name text, gender text,
  school_id uuid, school_name text, department text,
  class_id uuid, class_name text, level_code text, cycle_code text,
  filiere_label text, average numeric, subject_count integer,
  class_average numeric
)
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
  with notes as (
    select
      g.student_id,
      ev.class_id,
      ev.subject_id,
      -- ⚠️ LE COEFFICIENT EFFECTIF (0205). `class_subjects.coefficient` prime
      -- sur `subjects.coefficient`, qui n'est qu'un défaut proposé. Même règle
      -- que le bulletin : COALESCE(cs.coefficient, subj.coefficient).
      coalesce(cs.coefficient, sub.coefficient)::numeric as coef_matiere,
      ev.coefficient::numeric               as coef_evaluation,
      g.score / nullif(ev.max_score, 0) * 20 as note_sur_20
    from grades g
    join evaluations ev on ev.id = g.evaluation_id
    join subjects   sub on sub.id = ev.subject_id
    -- LEFT : une matière que la classe n'a pas explicitement pondérée garde le
    -- coefficient par défaut. Un INNER JOIN ferait DISPARAÎTRE ses notes de la
    -- moyenne — c'est-à-dire changerait le résultat au lieu de le corriger.
    left join class_subjects cs
           on cs.class_id   = ev.class_id
          and cs.subject_id = ev.subject_id
    join classes      c on c.id  = ev.class_id
    join schools      s on s.id  = c.school_id
    where ev.group_id = p_group_id
      and ev.academic_year_id = p_academic_year_id
      and ev.status = 'published'
      and g.is_absent = false
      and g.score is not null
      and ev.max_score > 0
      and (p_trimester_id  is null or ev.trimester_id  = p_trimester_id)
      and (p_level_code    is null or c.level_code     = p_level_code)
      and (p_department    is null or s.department     = p_department)
      and (p_filiere_label is null or c.filiere_label  = p_filiere_label)
      -- CLASSE DE PASSAGE : complément exact de la classe d'examen.
      and (coalesce(c.exam_override_id, c.exam_id) is null or c.exam_excluded)
  ),
  par_matiere as (
    select
      student_id, class_id, subject_id,
      max(coef_matiere) as coef_matiere,
      sum(note_sur_20 * coef_evaluation) / nullif(sum(coef_evaluation), 0) as moyenne
    from notes
    group by student_id, class_id, subject_id
  ),
  par_eleve as (
    select
      student_id, class_id,
      sum(moyenne * greatest(coef_matiere, 1))
        / nullif(sum(greatest(coef_matiere, 1)), 0) as moyenne,
      count(*)::int as nb_matieres
    from par_matiere
    group by student_id, class_id
  ),
  -- Moyenne de la classe : l'étalon sans lequel une moyenne ne se lit pas.
  -- 14/20 dans une classe à 15 n'est pas 14/20 dans une classe à 9.
  --
  -- ⚠️ Elle reste calculée sur les élèves RETENUS par les filtres. Restreindre
  -- à un département ne change pas la composition d'une classe — une classe
  -- appartient à une seule école, donc à un seul département et à une seule
  -- filière. L'étalon est donc le même, filtré ou non.
  par_classe as (
    select class_id, avg(moyenne) as moyenne_classe
    from par_eleve
    group by class_id
  )
  select
    e.student_id,
    trim(concat(st.first_name, ' ', st.last_name))          as full_name,
    st.gender,
    s.id, s.name, s.department,
    c.id, c.name, c.level_code, c.cycle_code, c.filiere_label,
    round(e.moyenne, 2),
    e.nb_matieres,
    round(pc.moyenne_classe, 2)
  from par_eleve e
  join students st on st.id = e.student_id and st.is_active
  join classes   c on c.id  = e.class_id
  join schools   s on s.id  = c.school_id
  join par_classe pc on pc.class_id = e.class_id
  where e.moyenne is not null
  order by e.moyenne desc, full_name asc
  limit greatest(p_limit, 1);
$function$;

COMMENT ON FUNCTION public.get_passage_merit(uuid, uuid, uuid, text, integer, text, text)
IS 'Palmarès des classes de passage. Le coefficient de matière est celui de '
   'class_subjects quand la classe l''a posé, sinon celui de subjects (0205) — '
   'la même règle que le bulletin.';
