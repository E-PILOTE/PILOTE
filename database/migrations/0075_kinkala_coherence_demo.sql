-- ════════════════════════════════════════════════════════════════════════════
--  0075 — COHÉRENCE DES DONNÉES DE DÉMONSTRATION (Collège Public de Kinkala)
--
--  La démonstration se fait devant des gens qui connaissent le métier. Un
--  détail faux coûte plus cher qu'une fonctionnalité manquante : personne ne
--  reproche à un logiciel jeune de ne pas tout faire, tout le monde retient
--  qu'il montrait un élève de onze ans candidat au BET.
--
--  Six incohérences constatées sur la base live, et ce que chacune donnait à
--  voir à l'écran :
--
--  1. LES ANNÉES ÉTAIENT MÉLANGÉES. Les 32 inscriptions de 2024-2025
--     pointaient sur des classes appartenant à 2025-2026 — parce qu'aucune
--     classe n'existait pour 2024-2025. C'étaient les 32 SEULES lignes de
--     toute la base dans ce cas. La conséquence visible : un élève « passait »
--     de la 3ème à la 6ème.
--
--  2. VINGT NOMS POUR SOIXANTE ÉLÈVES. Chaque paire prénom+nom revenait trois
--     fois — dont deux « Rachel Bantsimba » dans le même tableau de candidats
--     au BET, l'une née en 2011 et l'autre en 2015.
--
--  3. LES DATES DE NAISSANCE IGNORAIENT LE NIVEAU. Elles suivaient le numéro
--     de matricule : la 6ème accueillait un élève né en 2009 (seize ans) et la
--     3ème un élève né en 2014 (onze ans, candidat au BET).
--
--  4. HUIT CANDIDATS AU BET N'ÉTAIENT PAS EN 3ème. Inscrits en 6ème A pour
--     2025-2026, ils portaient une candidature déclarée en 3ème A. Le BET
--     sanctionne la fin du collège : la candidature est impossible.
--
--  5. CENT VINGT-HUIT NOTES ENJAMBAIENT DEUX ANNÉES. Portées par une
--     inscription de 2024-2025, elles s'attachaient à des évaluations de la
--     3ème A de 2025-2026. Elles gonflaient l'effectif noté des évaluations de
--     la 3ème A : vingt-trois copies pour quinze élèves.
--
--  6. LES VINGT-DEUX BULLETINS FIGEAIENT UN EFFECTIF DE 22. Ils datent d'avant
--     la déduplication de la classe. Tous à l'état « brouillon », jamais
--     validés, jamais publiés : ils annonçaient « rang 3 sur 22 » dans une
--     classe de quinze. Le bulletin se recalcule à la demande
--     (`bulletinComputationProvider`) ; la table n'en garde qu'un instantané au
--     moment de la soumission. Supprimer des brouillons ne perd donc rien.
--
--  CE QUE CETTE MIGRATION NE FAIT PAS : elle ne supprime AUCUNE inscription et
--  AUCUN élève. Les notes de l'année courante, les paiements et les
--  candidatures légitimes ne sont pas touchés. Les inscriptions de 2024-2025
--  sont recollées sur les bonnes classes, pas effacées — l'historique de
--  scolarité du dossier élève garde donc sa matière.
--
--  DÉTERMINISME : aucun `random()`, aucun `now()` dans les valeurs produites.
--  Rejouer cette migration redonne exactement le même résultat. C'est ce qui
--  permet de la relancer sans peur la veille d'une présentation.
--
--  Si l'école de démonstration est absente (autre environnement), toutes les
--  requêtes portent sur zéro ligne : la migration ne fait rien et n'échoue pas.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- Les identifiants d'années sont écrits en clair : plusieurs groupes peuvent
-- avoir une année « 2025-2026 », le libellé ne suffit pas à désigner la bonne.
CREATE TEMP TABLE _demo ON COMMIT DROP AS
SELECT s.id                                       AS school_id,
       s.group_id                                 AS group_id,
       'da000000-0000-4000-8000-0000000000a0'::uuid AS y2425,
       'da000000-0000-4000-8000-0000000000a1'::uuid AS y2526
FROM schools s
WHERE s.name = 'Collège Public de Kinkala';


-- ─────────────────────────────────────────────────────────────────────────────
--  1. LES CLASSES DE 2024-2025 N'EXISTAIENT PAS
--
--  On reconduit la structure de 2025-2026 vers l'année précédente. Ni le
--  professeur principal (il se désigne chaque année) ni `exam_id`/`exam_status`
--  (dérivés par le trigger `classes_derive_exam`) ne se recopient.
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO classes (group_id, school_id, academic_year_id, level_id, name,
                     capacity, room, cycle_code, level_code, level_order,
                     filiere_code, filiere_label, exam_override_id,
                     exam_excluded, is_active)
SELECT c.group_id, c.school_id, d.y2425, c.level_id, c.name,
       c.capacity, c.room, c.cycle_code, c.level_code, c.level_order,
       c.filiere_code, c.filiere_label, c.exam_override_id,
       c.exam_excluded, true
FROM classes c
JOIN _demo d ON d.school_id = c.school_id
WHERE c.academic_year_id = d.y2526
ON CONFLICT (school_id, academic_year_id, name) DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
--  2. RECOLLER LES INSCRIPTIONS DE 2024-2025 SUR LE NIVEAU PRÉCÉDENT
--
--  `level_order` repart à 1 à chaque cycle : on ne peut donc pas prendre
--  « level_order - 1 » pour trouver le niveau précédent, sinon la 6ème n'a pas
--  de prédécesseur alors qu'elle en a un — le CM2. La table ci-dessous nomme
--  la progression réelle, franchissements de cycle inclus.
--
--  Quand deux classes partagent un niveau (1ère F2 et 1ère G2), on privilégie
--  celle de la même filière : un élève de G2 ne recule pas en F2 par défaut de
--  tri.
-- ─────────────────────────────────────────────────────────────────────────────
WITH pred(level_code, prev_code) AS (
  VALUES ('CP2','CP1'), ('CE1','CP2'), ('CE2','CE1'), ('CM1','CE2'),
         ('CM2','CM1'), ('6e','CM2'),  ('5e','6e'),   ('4e','5e'),
         ('3e','4e'),   ('2nde','3e'), ('1ere','2nde'), ('Tle','1ere')
),
cible AS (
  SELECT ce25.student_id,
         (SELECT c24.id
            FROM classes c24
           WHERE c24.school_id        = d.school_id
             AND c24.academic_year_id = d.y2425
             AND c24.level_code       = p.prev_code
           ORDER BY (c24.filiere_label IS NOT DISTINCT FROM c25.filiere_label) DESC,
                    c24.name
           LIMIT 1) AS class_2425
  FROM _demo d
  JOIN class_enrollments ce25
    ON ce25.school_id = d.school_id AND ce25.academic_year_id = d.y2526
  JOIN classes c25 ON c25.id = ce25.class_id
  JOIN pred p      ON p.level_code = c25.level_code
)
UPDATE class_enrollments ce
   SET class_id          = cible.class_2425,
       enrollment_date   = DATE '2024-09-16',
       is_repeating      = false,
       previous_class_id = NULL
FROM cible, _demo d
WHERE ce.school_id        = d.school_id
  AND ce.academic_year_id = d.y2425
  AND ce.student_id       = cible.student_id
  AND cible.class_2425 IS NOT NULL;


-- ─────────────────────────────────────────────────────────────────────────────
--  3. CHAÎNER L'ANNÉE COURANTE SUR LA PRÉCÉDENTE
--
--  Un élève qui a une inscription l'an dernier dans le même établissement est
--  une RÉINSCRIPTION, pas une inscription neuve. `previous_class_name` est
--  conservé en clair à côté de l'identifiant : c'est ce libellé qui s'imprime,
--  et il doit survivre même si la classe est renommée plus tard.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE class_enrollments ce25
   SET inscription_type    = 'reinscription',
       previous_class_id   = ce24.class_id,
       previous_class_name = c24.name
FROM class_enrollments ce24
JOIN classes c24 ON c24.id = ce24.class_id
JOIN _demo   d   ON d.school_id = ce24.school_id
WHERE ce25.school_id        = d.school_id
  AND ce25.academic_year_id = d.y2526
  AND ce24.academic_year_id = d.y2425
  AND ce24.student_id       = ce25.student_id;


-- ─────────────────────────────────────────────────────────────────────────────
--  4. SOIXANTE NOMS DISTINCTS
--
--  Deux réservoirs de prénoms DISJOINTS par sexe : `students.gender` est NOT
--  NULL et déjà renseigné, un prénom qui le contredit serait une nouvelle
--  incohérence à la place de l'ancienne.
--
--  L'unicité des paires est arithmétique, pas espérée : la paire du k-ième
--  élève d'un sexe est (PRÉNOMS[k mod 20], NOMS[(7k) mod 30]). Deux rangs k et
--  k' collident seulement si k ≡ k' (mod 20) ET 7k ≡ 7k' (mod 30) ; comme
--  pgcd(7,30) = 1 la seconde condition impose k ≡ k' (mod 30), donc
--  k ≡ k' (mod 60). Avec au plus 34 élèves par sexe, aucune collision.
--  Chaque prénom et chaque nom ressort ainsi deux ou trois fois sur soixante
--  élèves : c'est ce qu'on observe dans une vraie école, sans jamais deux fois
--  la même personne.
--
--  Les élèves saisis à la main pendant les essais (matricule « 2026-… ») ne
--  sont pas renommés : ce sont les inscriptions de l'utilisateur.
-- ─────────────────────────────────────────────────────────────────────────────
WITH pools AS (
  SELECT ARRAY['Rachel','Sandra','Marie','Bénédicte','Divine','Chancelle',
               'Grâce','Naomi','Esther','Merveille','Glory','Clarisse',
               'Nadège','Prisca','Ornella','Lydie','Carine','Sylvie',
               'Aurélie','Mireille']::text[] AS pf,
         ARRAY['Prince','Christ','Patrick','Brel','Cédric','Josué','Jean',
               'Dieumerci','Exaucé','Rodrigue','Fabrice','Boris','Wilfrid',
               'Armel','Gildas','Serge','Aristide','Alphonse','Ghislain',
               'Franck']::text[] AS pm,
         ARRAY['Bakala','Bantsimba','Bouanga','Ekani','Goma','Itoua','Loemba',
               'Mabiala','Makaya','Massamba','Mavoungou','Mouanda','Moukala',
               'Ngakosso','Ngoma','Nkounkou','Okemba','Ondongo','Samba',
               'Tchicaya','Bemba','Kimbembé','Loubaki','Malonga','Mbemba',
               'Ndinga','Obambi','Poaty','Tati','Yoka']::text[] AS pn
),
rang AS (
  SELECT s.id, s.gender,
         row_number() OVER (PARTITION BY s.gender ORDER BY s.matricule) - 1 AS k
  FROM students s
  JOIN _demo d ON d.school_id = s.school_id
  WHERE s.matricule LIKE 'MAT-07-%'
)
UPDATE students s
   SET first_name = CASE WHEN r.gender = 'F'
                         THEN p.pf[(r.k % 20) + 1]
                         ELSE p.pm[(r.k % 20) + 1] END,
       last_name  = p.pn[((r.k * 7) % 30) + 1]
FROM rang r, pools p
WHERE s.id = r.id;

-- Un nom de famille tout en minuscules trahit une saisie d'essai. Les noms
-- entièrement en capitales sont, eux, un usage administratif courant : on les
-- laisse tels quels.
UPDATE students s
   SET last_name = initcap(s.last_name)
FROM _demo d
WHERE s.school_id = d.school_id
  AND s.last_name = lower(s.last_name);


-- ─────────────────────────────────────────────────────────────────────────────
--  5. DES DATES DE NAISSANCE QUI TIENNENT AU NIVEAU
--
--  Âge normal congolais : CP1 à six ans, donc 6ème à douze et 3ème à quinze.
--  L'année de naissance se déduit du niveau de 2025-2026.
--
--  Le mois décale l'année d'un cran (septembre-décembre → cohorte précédente),
--  ce qui reproduit exactement l'étalement qu'une rentrée de septembre produit
--  dans une classe réelle : deux années civiles se côtoient, sans que personne
--  ne soit hors d'âge. Un même niveau ne montre donc pas soixante élèves nés le
--  même mois, ce qui se voit tout de suite.
-- ─────────────────────────────────────────────────────────────────────────────
WITH base(level_code, annee) AS (
  VALUES ('CP1',2019), ('CP2',2018), ('CE1',2017), ('CE2',2016), ('CM1',2015),
         ('CM2',2014), ('6e',2013),  ('5e',2012),  ('4e',2011),  ('3e',2010),
         ('2nde',2009), ('1ere',2008), ('Tle',2007)
),
rang AS (
  -- `row_number()` rend un bigint ; `make_date` n'accepte que des int.
  SELECT ce.student_id, b.annee,
         (row_number() OVER (PARTITION BY ce.class_id ORDER BY s.matricule) - 1)::int AS k
  FROM _demo d
  JOIN class_enrollments ce
    ON ce.school_id = d.school_id AND ce.academic_year_id = d.y2526
  JOIN classes  c ON c.id = ce.class_id
  JOIN students s ON s.id = ce.student_id
  JOIN base     b ON b.level_code = c.level_code
)
UPDATE students s
   SET date_of_birth = make_date(
         CASE WHEN 1 + ((r.k * 7) % 12) >= 9 THEN r.annee - 1 ELSE r.annee END,
         1 + ((r.k * 7)  % 12),
         1 + ((r.k * 11) % 28))
FROM rang r
WHERE s.id = r.student_id;


-- ─────────────────────────────────────────────────────────────────────────────
--  6. LES NOTES QUI ENJAMBAIENT DEUX ANNÉES
--
--  Une note relie une INSCRIPTION (donc une année) à une ÉVALUATION (donc une
--  classe, donc une année). Quand les deux années diffèrent, la note n'est
--  d'aucune année : elle fausse l'effectif noté de l'évaluation sans apparaître
--  dans aucun bulletin. On la supprime avant de toucher aux candidatures, car
--  c'est le même lot d'élèves.
-- ─────────────────────────────────────────────────────────────────────────────
DELETE FROM grades g
USING class_enrollments ce, evaluations e, classes c, _demo d
WHERE g.enrollment_id = ce.id
  AND ce.school_id    = d.school_id
  AND e.id            = g.evaluation_id
  AND c.id            = e.class_id
  AND c.academic_year_id IS DISTINCT FROM ce.academic_year_id;


-- ─────────────────────────────────────────────────────────────────────────────
--  7. LES BULLETINS BROUILLONS À L'EFFECTIF PÉRIMÉ
--
--  Ils figent « sur 22 » une classe qui compte quinze élèves. Aucun n'a été
--  validé ni publié. Le bulletin se recalcule à la demande : ces instantanés
--  périmés ne portent aucune information qui ne se retrouve dans les notes.
-- ─────────────────────────────────────────────────────────────────────────────
DELETE FROM bulletins b
USING _demo d
WHERE b.school_id = d.school_id
  AND b.status    = 'draft';


-- ─────────────────────────────────────────────────────────────────────────────
--  8. LES CANDIDATURES SANS INSCRIPTION CORRESPONDANTE
--
--  Règle : on ne présente un élève à un examen que depuis la classe où il est
--  RÉELLEMENT inscrit cette année. Les huit candidatures visées déclaraient la
--  3ème A pour des élèves inscrits en 6ème A.
--
--  Les dépendances partent d'abord : la pièce jointe et la ligne de
--  transmission n'ont pas de sens sans la candidature.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TEMP TABLE _cand_hs ON COMMIT DROP AS
SELECT ec.id
FROM exam_candidates ec
JOIN _demo d ON d.school_id = ec.school_id
WHERE NOT EXISTS (
        SELECT 1 FROM class_enrollments ce
         WHERE ce.student_id       = ec.student_id
           AND ce.academic_year_id = d.y2526
           AND ce.class_id         = ec.class_id);

DELETE FROM transmission_items ti USING _cand_hs h WHERE ti.candidate_id     = h.id;
DELETE FROM student_documents  sd USING _cand_hs h WHERE sd.exam_candidate_id = h.id;
DELETE FROM exam_candidates    ec USING _cand_hs h WHERE ec.id                = h.id;

COMMIT;
