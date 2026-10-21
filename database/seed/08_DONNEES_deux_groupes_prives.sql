-- ════════════════════════════════════════════════════════════════════════════
--  DEUX GROUPES SCOLAIRES PRIVÉS DE DÉMONSTRATION (2026-10-21)
--
--  Après la remise à zéro (0208) : un petit promoteur à 2 écoles (technique,
--  METP, plan Standard) et un réseau à 7 écoles (général, MEPSA, plan Pro).
--  Tous deux en période d'essai : la base ouvre la fenêtre d'essai et
--  émet la facture d'ouverture d'elle-même (fn_set_trial_window,
--  fn_auto_create_invoice).
--
--  ⚠️ Aucun compte n'est créé : les adresses sont en `.test` (domaine
--  réservé, jamais délivré). Les comptes d'administration se créent depuis
--  l'espace super_admin, mot de passe choisi par une personne.
--
--  `created_by` = le super_admin : la facture d'ouverture l'exige (NOT NULL)
--  et `auth.uid()` est nul hors session.
-- ════════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_admin uuid := (SELECT id FROM auth.users WHERE email = 'super@admin.cg');
  v_g1 uuid;
  v_g2 uuid;
BEGIN
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'super_admin introuvable';
  END IF;

  -- ── Groupe 1 : 2 écoles techniques, Pointe-Noire ──────────────────────────
  INSERT INTO school_groups (name, slug, tutelle, caractere, department,
                             plan_id, admin_email, phone, address,
                             founded_year, created_by)
  VALUES ('Groupe Scolaire Les Artisans du Kouilou', 'artisans-kouilou',
          'metp', 'laic', 'Pointe-Noire',
          (SELECT id FROM subscription_plans WHERE slug = 'premium'),
          'direction@artisans-kouilou.test', '+242 06 600 10 10',
          'Avenue Charles de Gaulle, Pointe-Noire', 2012, v_admin)
  RETURNING id INTO v_g1;

  INSERT INTO schools (group_id, name, city, department, arrondissement,
                       institution_type_id)
  VALUES
    (v_g1, 'CET Les Artisans — Tié-Tié', 'Pointe-Noire', 'Pointe-Noire',
     'Tié-Tié', (SELECT id FROM institution_types WHERE code = 'CET')),
    (v_g1, 'Lycée technique Les Artisans — Loandjili', 'Pointe-Noire',
     'Pointe-Noire', 'Loandjili',
     (SELECT id FROM institution_types WHERE code = 'LYCEE_TECHNIQUE'));

  -- ── Groupe 2 : 7 écoles d'enseignement général, plusieurs départements ────
  INSERT INTO school_groups (name, slug, tutelle, caractere, department,
                             plan_id, admin_email, phone, address,
                             founded_year, created_by)
  VALUES ('Réseau Scolaire La Colombe', 'la-colombe',
          'mepsa', 'catholique', 'Brazzaville',
          (SELECT id FROM subscription_plans WHERE slug = 'pro'),
          'direction@la-colombe.test', '+242 06 700 20 20',
          'Rue Mbochis, Poto-Poto, Brazzaville', 2004, v_admin)
  RETURNING id INTO v_g2;

  INSERT INTO schools (group_id, name, city, department, arrondissement,
                       institution_type_id)
  SELECT v_g2, n, c, d, a, (SELECT id FROM institution_types WHERE code = t)
  FROM (VALUES
    ('École maternelle La Colombe — Poto-Poto', 'Brazzaville', 'Brazzaville', 'Poto-Poto', 'ECOLE_MATERNELLE'),
    ('École primaire La Colombe — Poto-Poto',   'Brazzaville', 'Brazzaville', 'Poto-Poto', 'ECOLE_PRIMAIRE'),
    ('École primaire La Colombe — Bacongo',     'Brazzaville', 'Brazzaville', 'Bacongo',   'ECOLE_PRIMAIRE'),
    ('Collège La Colombe — Moungali',           'Brazzaville', 'Brazzaville', 'Moungali',  'COLLEGE_GENERAL'),
    ('Lycée La Colombe — Ouenzé',               'Brazzaville', 'Brazzaville', 'Ouenzé',    'LYCEE_GENERAL'),
    ('Collège La Colombe — Dolisie',            'Dolisie',     'Niari',       NULL,        'COLLEGE_GENERAL'),
    ('Lycée La Colombe — Pointe-Noire',         'Pointe-Noire','Pointe-Noire','Lumumba',   'LYCEE_GENERAL')
  ) AS v(n, c, d, a, t);
END $$;
