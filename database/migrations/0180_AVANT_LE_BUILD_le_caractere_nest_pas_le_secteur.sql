-- ════════════════════════════════════════════════════════════════════════════
--  0180 — LE CARACTÈRE N'EST PAS LE SECTEUR
--
--  ── LE DÉFAUT, VISIBLE DEPUIS L'ÉCRAN ─────────────────────────────────────
--  Le formulaire de création de groupe proposait CINQ types :
--
--      Public · Privé · Catholique · Islamique · Protestant
--
--  L'enum `group_type` n'en accepte que DEUX. Vérifié en production :
--  `'catholique'::group_type` rend **22P02**. Autrement dit, un super_admin
--  qui créait un groupe catholique voyait sa création échouer sur une erreur
--  Postgres. Trois choix sur cinq étaient morts. Les mêmes valeurs fantômes
--  peuplaient le filtre « Type » de la liste — qui ne pouvait donc jamais
--  rendre une seule ligne — ainsi que la palette de couleurs et les icônes.
--
--  ── ⚠️ POURQUOI ON N'AJOUTE **PAS** CES VALEURS À L'ENUM ──────────────────
--  Ce serait la correction évidente, et elle casserait quatre choses. Parce
--  que `group_type` ne dit pas « quel genre de groupe », il dit LE SECTEUR —
--  le binôme juridique public / privé :
--
--   • `school_form_dialog` : « le secteur d'une école suit TOUJOURS celui de
--     son groupe (public XOR privé) » — verrouillé par la migration 0060 ;
--   • `schools.school_type` est lui aussi un enum à deux valeurs : une école
--     héritant de « catholique » ne serait plus insérable du tout ;
--   • `adminGroupePublicProvider` (`groupType == 'public'`) commande le
--     barème de frais public / privé ;
--   • `tutelle_groupes()` rend `group_type` sous le nom `secteur`, d'où
--     découle `estPublic` dans la vue de tutelle, et les rapports comptent
--     « public / privé » sur cette seule colonne.
--
--  Une école catholique EST une école privée. Ranger sa confession dans la
--  colonne du secteur, c'est perdre le secteur.
--
--  ── LE CARACTÈRE, DONC : UN TROISIÈME AXE ─────────────────────────────────
--  Le pays connaît des réseaux confessionnels réels — c'est ce que ces trois
--  valeurs fantômes cherchaient à dire, et elles s'étaient posées sur le
--  mauvais champ faute d'en avoir un. Elles en ont un maintenant.
--
--   • `tutelle`    → de quel MINISTÈRE le groupe relève   (0153)
--   • `group_type` → PUBLIC ou PRIVÉ, et rien d'autre     (0060)
--   • `caractere`  → LAÏC, CATHOLIQUE, PROTESTANT…        (celle-ci)
--
--  Trois questions distinctes, trois colonnes. Un groupe privé catholique
--  relevant du MEPSA se dit maintenant sans qu'aucune des trois mente.
--
--  ── CE QUE CETTE COLONNE NE FAIT PAS ──────────────────────────────────────
--  ⚠️ Elle est DESCRIPTIVE. Aucune politique, aucun quota, aucun tarif ne s'y
--  appuie, et aucun ne doit s'y appuyer : ce serait une règle inventée par
--  nous. Même discipline que l'agrément (0158), qui est une mention et non une
--  procédure.
--
--  Elle est NULLABLE, et `NULL` veut dire « non renseigné » — pas « laïc ».
--  Les sept groupes existants restent à NULL : personne ne leur a posé la
--  question, et y répondre à leur place serait inventer une donnée.
--
--  ⚠️ AUCUNE CONTRAINTE « public ⇒ laïc ». Elle serait probablement juste, et
--  c'est exactement pour ça qu'on s'en méfie : la base refuserait une saisie
--  au nom d'une règle de droit que nous n'avons pas vérifiée. L'écran ne
--  propose le caractère QUE sur un groupe privé ; si le terrain nous détrompe,
--  c'est une ligne d'écran à changer, pas une migration.
--
--  ⚠️ RIEN SUR `schools`. L'école n'en a pas l'usage aujourd'hui. Le jour où
--  elle l'aura, la colonne et son déclencheur d'héritage s'ajouteront comme
--  pour la tutelle et l'agrément — sans aucune migration de données.
--
--  ── ORDRE : AVANT LE BUILD ────────────────────────────────────────────────
--  Additive et nullable : le build déployé, qui ignore la colonne, continue de
--  créer des groupes sans elle. Aucun 23502 possible.
-- ════════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'caractere_groupe') THEN
    CREATE TYPE public.caractere_groupe AS ENUM
      ('laic', 'catholique', 'protestant', 'islamique', 'autre');
  END IF;
END $$;

ALTER TABLE public.school_groups
  ADD COLUMN IF NOT EXISTS caractere public.caractere_groupe;

COMMENT ON COLUMN public.school_groups.caractere IS
  'Caractere du groupe : laic, catholique, protestant, islamique, autre. '
  'DESCRIPTIF — aucune politique, aucun quota, aucun tarif ne s''y appuie. '
  'A NE PAS CONFONDRE AVEC group_type, qui porte le SECTEUR (public/prive) et '
  'dont dependent le bareme de frais, schools.school_type et la vue de '
  'tutelle. NULL = non renseigne, jamais « laic ».';

COMMENT ON COLUMN public.school_groups.group_type IS
  'SECTEUR du groupe : public ou prive, et rien d''autre. L''ecole en herite '
  '(school_type, 0060) et le bareme de frais en depend. La confession vit '
  'dans la colonne caractere (0180) — ne jamais elargir cet enum.';
