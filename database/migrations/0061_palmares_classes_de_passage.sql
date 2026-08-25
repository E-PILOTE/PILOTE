-- ════════════════════════════════════════════════════════════════════════════
--  0061 — PALMARÈS DES CLASSES DE PASSAGE
--
--  ── LE PARTAGE, ET POURQUOI IL EXISTE ───────────────────────────────────────
--  La plateforme NE CALCULE PAS les résultats des examens d'État : ils sont
--  proclamés par le jury et seulement ENREGISTRÉS ici (`exam_candidates`).
--  Ce qu'elle calcule, ce sont les moyennes des CLASSES DE PASSAGE — celles
--  dont le passage au niveau supérieur se décide sur le travail de l'année,
--  et non sur une épreuve nationale.
--
--  Le mérite se lit donc sur DEUX listes, jamais fondues en une :
--    • lauréats aux examens d'État  → base enregistrée, comparable entre écoles ;
--    • meilleurs des classes de passage → base calculée ici, PAR TRIMESTRE.
--
--  Sans cette fonction, le palmarès du ministère ne couvrait que les candidats
--  aux examens : dans le réseau METP, 81 élèves sur 297. Les 216 autres — ceux
--  dont la plateforme détient précisément les notes — n'apparaissaient nulle
--  part.
--
--  ── DÉFINITION D'UNE CLASSE DE PASSAGE ──────────────────────────────────────
--  Complément exact de la classe d'examen déjà modélisée (trigger
--  `trg_classes_derive_exam`) : aucun examen rattaché, ou examen explicitement
--  écarté. On ne réinvente pas le critère, on le lit.
--
--  ── RÈGLES DE CALCUL — identiques au dossier de l'élève ─────────────────────
--  Toute divergence entre cette fonction et `computeResults()` côté Dart ferait
--  qu'un élève classé 1er ici afficherait une autre moyenne dans son dossier.
--    • seules les évaluations PUBLIÉES comptent (un brouillon n'est pas un
--      résultat) ;
--    • une ABSENCE n'est pas un zéro : elle est exclue, jamais comptée 0 ;
--    • chaque note est ramenée sur 20 via `evaluations.max_score` ;
--    • moyenne par matière pondérée par le coefficient de l'ÉVALUATION ;
--    • moyenne générale pondérée par le coefficient de la MATIÈRE.
--
--  SECURITY INVOKER : les RLS de `grades`/`evaluations` s'appliquent au
--  demandeur. Un groupe ne peut pas lire le palmarès d'un autre.
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public.get_passage_merit(
  p_group_id        uuid,
  p_academic_year_id uuid,
  p_trimester_id    uuid default null,   -- NULL = toute l'année
  p_level_code      text default null,   -- NULL = tous niveaux
  p_limit           int  default 50
)
returns table (
  student_id    uuid,
  full_name     text,
  gender        text,
  school_id     uuid,
  school_name   text,
  department    text,
  class_id      uuid,
  class_name    text,
  level_code    text,
  cycle_code    text,
  filiere_label text,
  average       numeric,
  subject_count int,
  class_average numeric
)
language sql
stable
security invoker
set search_path = public
as $$
  with notes as (
    select
      g.student_id,
      ev.class_id,
      ev.subject_id,
      sub.coefficient::numeric              as coef_matiere,
      ev.coefficient::numeric               as coef_evaluation,
      g.score / nullif(ev.max_score, 0) * 20 as note_sur_20
    from grades g
    join evaluations ev on ev.id = g.evaluation_id
    join subjects   sub on sub.id = ev.subject_id
    join classes      c on c.id  = ev.class_id
    where ev.group_id = p_group_id
      and ev.academic_year_id = p_academic_year_id
      and ev.status = 'published'
      and g.is_absent = false
      and g.score is not null
      and ev.max_score > 0
      and (p_trimester_id is null or ev.trimester_id = p_trimester_id)
      and (p_level_code   is null or c.level_code    = p_level_code)
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
$$;

comment on function public.get_passage_merit is
  'Palmarès des classes de passage (hors classes d''examen), par trimestre. '
  'Mêmes règles de calcul que le dossier de l''élève : évaluations publiées '
  'seulement, absence exclue (jamais 0), notes ramenées sur 20, pondération '
  'coefficient d''évaluation puis coefficient de matière.';

grant execute on function public.get_passage_merit(uuid, uuid, uuid, text, int)
  to authenticated;
