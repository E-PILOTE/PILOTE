-- 0015_timetable_rooms.sql
-- Registre des SALLES / locaux de l'école. Remplace le champ texte libre
-- `timetable_slots.room` (« Salle 12 » ≠ « salle12 » ≠ « S12 » → conflits ratés).
-- Avec une salle référencée : détection FIABLE des conflits de salle (égalité
-- d'id), capacité (vs effectif de la classe) et type requis par un cours
-- (un TP de chimie exige un labo). Le type reste un varchar libre (souplesse
-- Congo) ; l'app propose un catalogue (ordinaire, labo_physique, labo_chimie,
-- labo_svt, informatique, multimedia, atelier, sport, amphitheatre,
-- bibliotheque, autre).

CREATE TABLE IF NOT EXISTS public.rooms (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  school_id   uuid NOT NULL REFERENCES public.schools(id)       ON DELETE CASCADE,
  code        varchar(30),
  name        varchar(100) NOT NULL,
  room_type   varchar(30)  NOT NULL DEFAULT 'ordinaire',
  capacity    smallint,
  building    varchar(60),
  is_active   boolean      NOT NULL DEFAULT true,
  created_at  timestamptz  NOT NULL DEFAULT now(),
  updated_at  timestamptz  NOT NULL DEFAULT now()
);

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

-- Garde multi-tenant standard (cf. class_subjects) : école pour le personnel,
-- groupe entier pour admin_groupe, tout pour super_admin.
CREATE POLICY rooms_tenant ON public.rooms
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  );

CREATE INDEX IF NOT EXISTS idx_rooms_school ON public.rooms(school_id);
CREATE INDEX IF NOT EXISTS idx_rooms_group  ON public.rooms(group_id);
