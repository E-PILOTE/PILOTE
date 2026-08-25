-- ════════════════════════════════════════════════════════════════════════════
--  0073 — COLLÈGE PUBLIC DE KINKALA : les cinq modules qui restaient muets
--
--  Présences élèves, Cahier de textes, Cantine, Bibliothèque et Paie étaient
--  livrés et fonctionnels, mais sans une ligne de données : à l'écran, cinq
--  pages vides. Cette migration les peuple pour la SEULE école de Kinkala, sur
--  l'année 2025-2026, dans le 3e trimestre (16 mars → 31 juillet 2026).
--
--  ── CE QUE CES DONNÉES SONT, ET NE SONT PAS ────────────────────────────────
--  Ce sont des données d'EXPLOITATION d'un établissement : des appels, des
--  leçons, des repas, des prêts, des bulletins de paie. Elles sont
--  vraisemblables et cohérentes entre elles, mais elles ne prétendent à aucune
--  valeur officielle — contrairement aux taux proclamés par la DEC, qui, eux,
--  ne s'inventent jamais (cf. migration 0065).
--
--  ── DÉTERMINISME ───────────────────────────────────────────────────────────
--  Aucun `random()` : la variation vient de `hashtext()` sur des clés stables.
--  Rejouer la migration produit exactement le même jeu — et chaque insertion
--  est gardée, donc rejouable sans doublon.
--
--  Période retenue : lundi 6 avril → vendredi 29 mai 2026, jours ouvrés. Huit
--  semaines de vie scolaire ordinaire, avant les épreuves de juin.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

DO $$
DECLARE
  v_group   uuid := 'da3954ca-e2a4-486e-ac07-a2ebf992f2c6';
  v_school  uuid;
  v_year    uuid := 'da000000-0000-4000-8000-0000000000a1';
  v_trim3   uuid := '5ab68657-bdac-478c-97af-789a9e58d787';
  v_from    date := DATE '2026-04-06';
  v_to      date := DATE '2026-05-29';

  -- Acteurs réels de l'établissement (profils déjà semés).
  v_surveillant uuid := 'e0000000-0000-4000-8000-000000007009'; -- Clarisse Nkounkou
  v_comptable   uuid := 'e0000000-0000-4000-8000-000000007010'; -- Gaston Okemba

  v_n integer;
BEGIN
  SELECT id INTO v_school FROM schools WHERE name = 'Collège Public de Kinkala';
  IF v_school IS NULL THEN
    RAISE EXCEPTION 'Collège Public de Kinkala introuvable — rien n''est semé.';
  END IF;

  -- ══════════════════════════════════════════════════════════════════════════
  --  1) PRÉSENCES ÉLÈVES — l'appel du matin
  --
  --  Un appel par classe et par jour ouvré, période AM. Quatre classes
  --  représentatives : une classe d'examen (3ème A), une terminale technique
  --  (Tle F2), une entrée de collège (6ème A) et une fin de primaire (CM2 A).
  --  Faire l'appel de seize classes pendant huit semaines aurait produit un
  --  volume que personne ne lit.
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO attendance_records
    (group_id, school_id, class_id, subject_id, academic_year_id,
     record_date, period, recorded_by, is_finalized)
  SELECT v_group, v_school, c.id, NULL, v_year, d::date, 'AM', v_surveillant, true
    FROM generate_series(v_from, v_to, INTERVAL '1 day') d
    CROSS JOIN classes c
   WHERE c.school_id = v_school
     AND c.name IN ('3ème A', 'Tle F2', '6ème A', 'CM2 A')
     AND EXTRACT(ISODOW FROM d) BETWEEN 1 AND 5   -- lundi → vendredi
  ON CONFLICT (class_id, record_date, period, subject_id) DO NOTHING;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'Appels créés : %', v_n;

  -- Une ligne par élève inscrit dans la classe appelée.
  --
  -- Répartition visée : ~92 % présents, ~5 % absents, ~3 % retards. Le hash
  -- mêle l'élève et le jour, donc l'absentéisme se répartit sans qu'un même
  -- élève soit absent tous les jours — ce qui serait invraisemblable.
  INSERT INTO attendance_entries
    (attendance_record_id, student_id, group_id, school_id, status,
     arrival_time, justification, parent_notified)
  SELECT r.id,
         e.student_id,
         v_group,
         v_school,
         CASE h.v WHEN 0 THEN 'absent' WHEN 1 THEN 'late' ELSE 'present' END
           ::attendance_status,
         CASE WHEN h.v = 1
              THEN (TIME '07:30' + (h.m * INTERVAL '4 minute')) END,
         CASE WHEN h.v = 0 AND h.m < 3
              THEN 'Justifié par la famille — certificat médical remis.' END,
         (h.v = 0 AND h.m >= 3)
    FROM attendance_records r
    JOIN class_enrollments e
      ON e.class_id = r.class_id
     AND e.academic_year_id = v_year
     AND e.status = 'active'
   CROSS JOIN LATERAL (
     SELECT CASE
              WHEN abs(hashtext(e.student_id::text || r.record_date::text)) % 100 < 5  THEN 0
              WHEN abs(hashtext(e.student_id::text || r.record_date::text)) % 100 < 8  THEN 1
              ELSE 2
            END AS v,
            abs(hashtext(r.record_date::text || e.student_id::text)) % 6 AS m
   ) h
   WHERE r.school_id = v_school
     AND r.record_date BETWEEN v_from AND v_to
  ON CONFLICT (attendance_record_id, student_id) DO NOTHING;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'Pointages élèves : %', v_n;

  -- ══════════════════════════════════════════════════════════════════════════
  --  2) CAHIER DE TEXTES — ce qui a été fait en classe
  --
  --  Une séance par semaine et par matière, sur les matières principales de
  --  trois classes. L'intitulé suit une progression annuelle plausible ; le
  --  devoir est renseigné une fois sur deux, comme dans un vrai cahier.
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO lesson_entries
    (group_id, school_id, class_id, subject_id, staff_id, academic_year_id,
     trimester_id, entry_date, lesson_title, content, objectives, homework)
  SELECT v_group, v_school, cs.class_id, cs.subject_id,
         t.staff_id, v_year, v_trim3,
         (v_from + ((w.n * 7) + (abs(hashtext(cs.subject_id::text)) % 5)))::date,
         s.name || ' — séance ' || (w.n + 1),
         'Séance conduite en classe entière. Rappel de la séance précédente, '
         || 'notion nouvelle au tableau, puis exercices d''application.',
         'À l''issue de la séance, l''élève sait appliquer la notion à un '
         || 'exercice simple et justifier sa démarche.',
         CASE WHEN (w.n + abs(hashtext(cs.subject_id::text))) % 2 = 0
              THEN 'Exercices à terminer pour la prochaine séance.' END
    FROM class_subjects cs
    JOIN subjects s ON s.id = cs.subject_id
    JOIN classes  c ON c.id = cs.class_id
   CROSS JOIN generate_series(0, 7) AS w(n)
   CROSS JOIN LATERAL (
     -- Un enseignant de l'établissement, stable pour une matière donnée.
     SELECT sm.id AS staff_id
       FROM staff_members sm
       JOIN profiles p ON p.id = sm.id
      WHERE sm.school_id = v_school AND p.role = 'enseignant'
      ORDER BY md5(sm.id::text || cs.subject_id::text)
      LIMIT 1
   ) t
   WHERE c.school_id = v_school
     AND c.name IN ('3ème A', 'Tle F2', '6ème A')
     AND s.name IN ('Mathématiques', 'Francais', 'Physique-Chimie',
                    'Histoire-Géographie', 'Anglais', 'SVT')
     AND NOT EXISTS (
       SELECT 1 FROM lesson_entries le
        WHERE le.class_id = cs.class_id
          AND le.subject_id = cs.subject_id
          AND le.entry_date =
              (v_from + ((w.n * 7) + (abs(hashtext(cs.subject_id::text)) % 5)))::date
     );

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'Séances de cahier de textes : %', v_n;

  -- ══════════════════════════════════════════════════════════════════════════
  --  3) CANTINE — abonnements puis pointage des repas
  --
  --  Tous les élèves ne mangent pas à la cantine : environ trois sur cinq
  --  s'abonnent, à 15 000 FCFA le mois. Le pointage ne porte que sur eux.
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO canteen_subscriptions
    (group_id, school_id, student_id, academic_year_id, is_subscribed,
     monthly_amount_xaf)
  SELECT v_group, v_school, st.id, v_year, true, 15000
    FROM students st
   WHERE st.school_id = v_school
     AND abs(hashtext(st.id::text)) % 5 < 3
  ON CONFLICT (student_id, academic_year_id) DO NOTHING;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'Abonnements cantine : %', v_n;

  -- Six semaines de déjeuners, jours ouvrés. Un abonné absent de temps en
  -- temps : le pointage sert précisément à ne facturer que les repas servis.
  INSERT INTO canteen_records
    (group_id, school_id, student_id, record_date, meal_type, is_present, notes)
  SELECT v_group, v_school, cs.student_id, d::date, 'dejeuner',
         (abs(hashtext(cs.student_id::text || d::text)) % 100) >= 9,
         CASE WHEN (abs(hashtext(cs.student_id::text || d::text)) % 100) < 9
              THEN 'Absent au service' END
    FROM canteen_subscriptions cs
   CROSS JOIN generate_series(DATE '2026-04-20', v_to, INTERVAL '1 day') d
   WHERE cs.school_id = v_school
     AND cs.academic_year_id = v_year
     AND cs.is_subscribed
     AND EXTRACT(ISODOW FROM d) BETWEEN 1 AND 5
  ON CONFLICT (student_id, record_date, meal_type) DO NOTHING;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'Repas pointés : %', v_n;

  -- ══════════════════════════════════════════════════════════════════════════
  --  4) BIBLIOTHÈQUE — un fonds, puis des prêts
  --
  --  Le fonds mêle programme scolaire congolais, littérature africaine et
  --  ouvrages techniques, cohérent avec un établissement à filières
  --  industrielles et tertiaires.
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO library_items
    (group_id, school_id, title, author, category, quantity,
     available_quantity, location, is_active)
  SELECT v_group, v_school, v.title, v.author, v.cat, v.qty, v.qty, v.loc, true
    FROM (VALUES
      ('Les Soleils des indépendances', 'Ahmadou Kourouma', 'Littérature', 12, 'Rayon A1'),
      ('Le Pleurer-Rire',               'Henri Lopes',      'Littérature', 10, 'Rayon A1'),
      ('La Vie et demie',               'Sony Labou Tansi', 'Littérature',  8, 'Rayon A1'),
      ('L''Anté-peuple',                'Sony Labou Tansi', 'Littérature',  6, 'Rayon A1'),
      ('Une si longue lettre',          'Mariama Bâ',       'Littérature',  9, 'Rayon A2'),
      ('L''Enfant noir',                'Camara Laye',      'Littérature', 11, 'Rayon A2'),
      ('Le Monde s''effondre',          'Chinua Achebe',    'Littérature',  7, 'Rayon A2'),
      ('Mathématiques 3e — Programme national', 'Collectif MEPSA', 'Manuel', 25, 'Rayon B1'),
      ('Mathématiques Terminale — Analyse',     'Collectif MEPSA', 'Manuel', 18, 'Rayon B1'),
      ('Physique-Chimie 3e',            'Collectif MEPSA',  'Manuel',      22, 'Rayon B1'),
      ('Sciences de la Vie et de la Terre 3e', 'Collectif MEPSA', 'Manuel', 20, 'Rayon B2'),
      ('Histoire-Géographie du Congo',  'Collectif MEPSA',  'Manuel',      16, 'Rayon B2'),
      ('Grammaire française — 3e',      'Collectif MEPSA',  'Manuel',      19, 'Rayon B2'),
      ('English for Secondary Schools', 'Collectif MEPSA',  'Manuel',      15, 'Rayon B3'),
      ('Éducation civique et morale',   'Collectif MEPSA',  'Manuel',      14, 'Rayon B3'),
      ('Comptabilité générale — Initiation', 'J. Massamba', 'Technique',    9, 'Rayon C1'),
      ('Techniques quantitatives de gestion', 'A. Nkodia',  'Technique',    7, 'Rayon C1'),
      ('Droit commercial appliqué',     'P. Bemba',         'Technique',    6, 'Rayon C1'),
      ('Électronique — Composants et circuits', 'R. Milandou', 'Technique',  8, 'Rayon C2'),
      ('Électrotechnique industrielle', 'R. Milandou',      'Technique',    8, 'Rayon C2'),
      ('Dessin technique et lecture de plan', 'F. Obami',   'Technique',    6, 'Rayon C2'),
      ('Secrétariat et bureautique',    'C. Bakala',        'Technique',    7, 'Rayon C3'),
      ('Dictionnaire Le Robert Collège', 'Collectif',       'Référence',    5, 'Rayon D1'),
      ('Atlas géographique du Congo',   'Collectif',        'Référence',    4, 'Rayon D1')
    ) AS v(title, author, cat, qty, loc)
   WHERE NOT EXISTS (
     SELECT 1 FROM library_items li
      WHERE li.school_id = v_school AND li.title = v.title
   );

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'Ouvrages au fonds : %', v_n;

  -- Prêts : un ouvrage ne peut avoir qu'UN prêt en cours (index unique posé
  -- par la migration 0072). On tire donc au plus un emprunteur par ouvrage.
  --
  -- Trois états, comme dans une vraie bibliothèque : rendus dans les temps,
  -- en cours, et en retard — c'est ce dernier que le module doit faire voir.
  INSERT INTO library_loans
    (group_id, school_id, item_id, borrower_id, borrow_date, due_date,
     return_date, status, notes)
  SELECT v_group, v_school, x.item_id, x.student_id,
         x.borrow_date, x.borrow_date + 14,
         CASE WHEN x.etat = 0 THEN x.borrow_date + 9 END,
         -- ⚠️ Les valeurs attendues par l'application sont `active` /
         -- `returned` (biblio_provider.dart), pas des libellés français : le
         -- statut est une CLÉ, pas un texte d'affichage.
         CASE WHEN x.etat = 0 THEN 'returned' ELSE 'active' END,
         CASE WHEN x.etat = 2 THEN 'Relance remise à l''élève.' END
    FROM (
      SELECT li.id AS item_id,
             (SELECT st.id FROM students st
               WHERE st.school_id = v_school
               ORDER BY md5(st.id::text || li.id::text) LIMIT 1) AS student_id,
             -- Rendu / en cours / en retard, selon l'ouvrage.
             (abs(hashtext(li.id::text)) % 3) AS etat,
             -- Les dates se calent sur AUJOURD'HUI, pas sur des constantes :
             -- un prêt « dans les délais » emprunté en mai serait en retard
             -- dès qu'on regarde l'écran en juillet. Le module doit montrer
             -- les trois états à la fois, quel que soit le jour.
             CASE abs(hashtext(li.id::text)) % 3
               WHEN 0 THEN CURRENT_DATE - 86   -- rendu, il y a longtemps
               WHEN 1 THEN CURRENT_DATE -  9   -- en cours, échéance à venir
               ELSE        CURRENT_DATE - 30   -- en cours, échéance dépassée
             END AS borrow_date
        FROM library_items li
       WHERE li.school_id = v_school
         AND abs(hashtext(li.id::text || 'pret')) % 4 < 3
    ) x
   WHERE x.student_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM library_loans l WHERE l.item_id = x.item_id
     );

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'Prêts enregistrés : %', v_n;

  -- Le disponible suit les prêts en cours : sans cela, le compteur du module
  -- annoncerait un fonds intact alors que des ouvrages sont sortis.
  UPDATE library_items li
     SET available_quantity = GREATEST(li.quantity - c.n, 0),
         updated_at = now()
    FROM (SELECT item_id, count(*) AS n
            FROM library_loans
           WHERE school_id = v_school AND return_date IS NULL
           GROUP BY item_id) c
   WHERE li.id = c.item_id
     AND li.available_quantity <> GREATEST(li.quantity - c.n, 0);

  -- ══════════════════════════════════════════════════════════════════════════
  --  5) PAIE — quatre mois de bulletins
  --
  --  Mars à juin 2026. Les trois premiers mois sont payés ; juin reste en
  --  attente, comme un mois en cours de traitement — c'est l'état qui donne
  --  son sens à l'écran (ce qu'il reste à mandater).
  --
  --  Primes et retenues sont dérivées du salaire de base : prime d'ancienneté
  --  pour les permanents, retenue sociale pour tous. Le net est calculé, pas
  --  saisi — il doit toujours valoir base + primes − retenues.
  -- ══════════════════════════════════════════════════════════════════════════
  INSERT INTO payroll
    (group_id, school_id, staff_id, period_month, period_year,
     base_salary_xaf, bonuses_xaf, deductions_xaf, net_salary_xaf,
     payment_date, payment_method, payment_reference, status, notes, created_by)
  SELECT v_group, v_school, sm.id, m.mois, 2026,
         sm.base_salary_xaf,
         b.bonus,
         d.retenue,
         sm.base_salary_xaf + b.bonus - d.retenue,
         CASE WHEN m.mois < 6
              THEN make_date(2026, m.mois, 28) END,
         CASE WHEN m.mois < 6
              THEN (CASE WHEN abs(hashtext(sm.id::text)) % 3 = 0
                         THEN 'mtn_money' ELSE 'especes' END)::payment_method
         END,
         CASE WHEN m.mois < 6
              THEN 'PAIE-2026-' || lpad(m.mois::text, 2, '0') || '-'
                   || upper(substr(replace(sm.id::text, '-', ''), 1, 6)) END,
         (CASE WHEN m.mois < 6 THEN 'confirmed' ELSE 'pending' END)
           ::payment_status,
         CASE WHEN m.mois = 6
              THEN 'En attente de mandatement.' END,
         v_comptable
    FROM staff_members sm
    JOIN profiles p ON p.id = sm.id
   CROSS JOIN (VALUES (3), (4), (5), (6)) AS m(mois)
   CROSS JOIN LATERAL (
     SELECT CASE WHEN sm.contract_type = 'permanent'
                 THEN (sm.base_salary_xaf * 0.10)::int
                 ELSE 0 END AS bonus
   ) b
   CROSS JOIN LATERAL (
     SELECT (sm.base_salary_xaf * 0.045)::int AS retenue
   ) d
   WHERE sm.school_id = v_school
     AND sm.is_active
     AND sm.base_salary_xaf IS NOT NULL
  ON CONFLICT (staff_id, period_month, period_year) DO NOTHING;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'Bulletins de paie : %', v_n;
END $$;

COMMIT;
