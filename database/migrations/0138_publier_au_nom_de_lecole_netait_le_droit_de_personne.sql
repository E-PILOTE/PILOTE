-- ════════════════════════════════════════════════════════════════════════════
--  0138 — PUBLIER AU NOM DE L'ÉCOLE N'ÉTAIT LE DROIT DE PERSONNE
--
--  Le domaine Communication — 55 fichiers, ~21 800 lignes, le plus gros du
--  produit — vivait ENTIÈREMENT HORS du modèle de permissions :
--
--    • aucun module dans `modules` : ni `annonces`, ni `messagerie`, ni
--      `evenements`. La table en comptait 30, aucun pour la communication ;
--    • aucun `ModuleScaffold`, aucun `PermissionGate`, aucun `canProvider`
--      dans les 55 fichiers — il n'y avait rien contre quoi les gader ;
--    • RLS `announcements` / `events` : `FOR ALL` sur la seule appartenance à
--      l'école.
--
--  Conséquence : TOUT membre du personnel — un enseignant, un surveillant, le
--  responsable de la cantine — pouvait publier une annonce au nom de
--  l'établissement, visible de toutes les familles, et SUPPRIMER celle d'un
--  autre. Une annonce est une parole publique de l'école ; elle n'avait pas
--  d'auteur autorisé.
--
--  ── POURQUOI LE TROU EXISTAIT, ET CE QU'IL FAUT EN GARDER ─────────────────
--  Ce n'est pas un oubli distrait : `canProvider` lit `myPermissionsProvider`,
--  qui interroge la base LOCALE PowerSync du profil d'accès de l'agent. Or
--  `super_admin` et `admin_groupe` ne font pas tourner PowerSync (règle
--  centrale du projet) et n'ont pas de profil d'accès : pour eux,
--  `canProvider` rend TOUJOURS faux. Garder les écrans PARTAGÉS avec
--  `canProvider` aurait donc retiré la publication aux deux rôles qui en ont le
--  plus besoin.
--
--  Le garde applicatif est donc SCOPE-AWARE, comme le reste du module : hors
--  périmètre école, la route est déjà gardée par le rôle ; dans le périmètre
--  école, le verbe décide. Voir `peutPublierAnnonceProvider`.
--
--  ── CE QUE CETTE MIGRATION FAIT, ET CE QU'ELLE NE FAIT PAS ────────────────
--  ELLE FAIT : la catégorie, les trois modules, et les permissions des cinq
--  profils du catalogue (5 noms × 7 groupes = 35 profils, aucun profil
--  personnalisé à ce jour — relevé avant écriture).
--
--  ELLE NE TOUCHE PAS LA RLS. Durcir `announcements` / `events` avant que le
--  build qui porte les gardes ne soit publié rendrait la publication fatale
--  pour les profils sans verbe : 42501, code fatal, lot PowerSync entier jeté.
--  C'est exactement la règle de `docs/DEPLOIEMENT_ORDRE.md`. La migration RLS
--  est écrite dans `0139`, et elle part AVEC le build.
--
--  ── LE PARTAGE DES VERBES, ET POURQUOI ────────────────────────────────────
--    annonces / evenements   lecture : les cinq profils — une annonce est faite
--                            pour être lue de tous.
--                            écriture : Direction et Secrétariat. Un professeur
--                            qui doit joindre SA classe a la messagerie ; il
--                            n'a pas à parler au nom de l'établissement.
--    messagerie              lecture ET écriture : les cinq. Écrire à un
--                            collègue n'est pas un privilège, et la RLS de
--                            `messages` borne déjà chacun à ses propres envois
--                            (`sender_id = auth.uid()`).
--
--  ⚠️ C'est un RÉGLAGE, pas une vérité : une école peut décider que sa vie
--  scolaire publie les annonces de discipline. Le catalogue donne un défaut
--  défendable ; l'écran « Profils d'accès » de l'admin groupe fait le reste, et
--  les trois modules y apparaissent d'eux-mêmes.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── 1. La catégorie ───────────────────────────────────────────────────────
INSERT INTO module_categories (name, slug, icon, display_order)
SELECT 'COMMUNICATION', 'communication', 'forum',
       COALESCE((SELECT MAX(display_order) FROM module_categories), 0) + 1
WHERE NOT EXISTS (SELECT 1 FROM module_categories WHERE slug = 'communication');

-- ─── 2. Les trois modules ──────────────────────────────────────────────────
INSERT INTO modules (category_id, name, slug, description, icon, display_order)
SELECT c.id, v.nom, v.slug, v.descr, v.icone, v.ordre
FROM   module_categories c,
       (VALUES
         ('Annonces',    'annonces',    'campaign',
          'Publications de l''établissement, visibles des familles.', 1::smallint),
         ('Messagerie',  'messagerie',  'chat',
          'Échanges entre membres du personnel et avec les familles.', 2::smallint),
         ('Événements',  'evenements',  'event',
          'Agenda public de l''établissement.', 3::smallint)
       ) AS v(nom, slug, descr, icone, ordre)
WHERE  c.slug = 'communication'
  AND  NOT EXISTS (SELECT 1 FROM modules m WHERE m.slug = v.slug);

-- ─── 3. Les permissions des profils du catalogue ───────────────────────────
--  `can_read` pour tous : aucune régression, lire une annonce est le but.
--  L'écriture suit le tableau ci-dessus.
INSERT INTO profile_permissions (
  profile_id, module_id, group_id, can_read, can_create, can_update, can_delete,
  can_export, data_scope
)
SELECT ap.id, m.id, ap.group_id,
       true,
       v.ecrit, v.ecrit, v.ecrit,
       true,
       'own_school'::data_scope
FROM   access_profiles ap
JOIN   modules m ON m.slug IN ('annonces', 'messagerie', 'evenements')
JOIN   LATERAL (
         SELECT CASE
                  WHEN m.slug = 'messagerie' THEN true
                  WHEN ap.name IN ('Direction', 'Secrétariat') THEN true
                  ELSE false
                END AS ecrit
       ) v ON true
WHERE  NOT EXISTS (
         SELECT 1 FROM profile_permissions pp
         WHERE pp.profile_id = ap.id AND pp.module_id = m.id);

COMMENT ON TABLE modules IS
  'Catalogue des modules. Depuis la migration 0138, la communication (annonces, '
  'messagerie, événements) y figure : elle en était absente, et publier au nom '
  'de l''école n''exigeait donc aucun droit.';
