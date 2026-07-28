-- ════════════════════════════════════════════════════════════════════════════
--  0064 — PALMARÈS DES CLASSES DE PASSAGE : filtrer par TERRITOIRE et FILIÈRE.
--
--  Le palmarès savait se restreindre à un niveau. Il ne savait pas répondre aux
--  deux questions que le ministère technique pose réellement :
--   • « les meilleurs du Niari » — une commission de bourses attribue par
--     département, pas sur un classement national qu'un seul chef-lieu occupe ;
--   • « les meilleurs en Électrotechnique » — la filière est l'axe de pilotage
--     propre au METP, celui sur lequel il ajuste l'offre de formation.
--
--  ⚠️ POURQUOI EN BASE, ET NON DANS L'ÉCRAN.
--  La fonction rend au plus `p_limit` lignes, triées sur le réseau entier.
--  Filtrer côté client APRÈS cette coupe donnerait « les meilleurs du Niari
--  parmi les 200 meilleurs du pays » — silencieusement faux dès qu'un
--  département est sous-représenté en tête. Le filtre doit précéder la coupe.
--
--  Les deux paramètres sont ajoutés en fin de signature avec un défaut NULL :
--  les appels existants (y compris une version antérieure de l'application)
--  continuent de fonctionner à l'identique.
-- ════════════════════════════════════════════════════════════════════════════

-- ⚠️ `create or replace` ne REMPLACE pas ici : une signature différente crée
-- une SURCHARGE. Deux `get_passage_merit` coexisteraient, et PostgREST ne
-- saurait plus laquelle appeler (« function name is not unique »). On retire
-- donc explicitement l'ancienne.
drop function if exists public.get_passage_merit(uuid, uuid, uuid, text, integer);

create or replace function public.get_passage_merit(
  p_group_id         uuid,
  p_academic_year_id uuid,
  p_trimester_id     uuid    default null,
  p_level_code       text    default null,
  p_limit            integer default 50,
  p_department       text    default null,
  p_filiere_label    text    default null
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
  subject_count integer,
  class_average numeric
)
language sql
stable
set search_path to 'public'
as $function$
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

comment on function public.get_passage_merit(
  uuid, uuid, uuid, text, integer, text, text) is
  'Palmarès des classes de passage, filtré AVANT la coupe du classement '
  '(trimestre, niveau, département, filière) — cf. migration 0064.';
