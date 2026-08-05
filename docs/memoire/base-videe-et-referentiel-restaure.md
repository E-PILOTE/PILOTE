---
name: base-videe-et-referentiel-restaure
description: 2026-08-01 — base Supabase entièrement vidée à la demande du user ; référentiel + 7 groupes restaurés depuis backups/csv ; reste à reseeder écoles/personnel/scolarité
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-01T15:47:09.752Z
---

Le **2026-08-01**, sur demande explicite et réitérée du user, la base Supabase a
été **entièrement vidée** : 98 tables `public` en `TRUNCATE … CASCADE` +
`DELETE FROM auth.users` (119 comptes). Schéma intact (98 tables, 94 fonctions,
81 triggers, 167 policies RLS). La base locale PowerSync du poste
(`~/Documents/epilote_v3.db`) a été détruite dans la foulée — sans quoi le poste
pousse des écritures orphelines vers un serveur vide.

**Sauvegarde complète** : `/home/melack/E-PILOTE/backups/csv/` — 103 CSV, 9,2 Mo,
une table par fichier (+ `auth_users`, `auth_identities`…). ⚠️ `pg_dump` local est
en 16 et le serveur en 17 : le dump SQL est impossible, d'où l'export `\copy` CSV.

**Restauré ensuite** (données réelles, vérifiées, à ne jamais retaper) :
15 départements · 5 cycles / 79 niveaux / 39 programmes · 11 examens d'État /
30 sessions / 17 règles d'éligibilité · **14 résultats officiels DEC** ·
8 catégories / 30 modules / 4 plans / 81 plan_modules · 7 groupes scolaires +
6 factures. Compte plateforme recréé : `adminpilote@gmail.com` / `‹secret — gestionnaire de mots de passe›`.

**Why:** les données de démo étaient incohérentes (un « Collège » hébergeant du
CP1 au Tle F3, classes à 0 élève, matricules de deux formats, une note « Je suis
en dev »). Le user a tranché pour la table rase.

**How to apply:**
- ⚠️ `school_groups` porte un garde-fou `trg_guard_active_requires_payment` qui
  REFUSE `subscription_status='active'` sans reçu payé. Pour restaurer :
  `ALTER TABLE school_groups DISABLE TRIGGER trg_guard_active_requires_payment,
  trg_guard_active_requires_payment_ins, trg_auto_create_invoice;` puis
  réactiver. Voir [[abonnement-infra-reelle-hardlock]].
- `subjects` (115) est **tenant** (tous ont un `group_id`), pas référentiel :
  à recréer par le seed, pas à restaurer.
- `exam_official_results.recorded_by` pointait un profil supprimé → réimporté
  avec la colonne vidée.
- **Reste à faire** : seed écoles + personnel + scolarité, scripté et idempotent
  dans `database/seed/` (un fichier par tutelle : METP, MEPSA, privé), avec
  DEUX années scolaires (une close, une ouverte) pour pouvoir montrer passage,
  clôture et réinscription. Voir [[cloture-examen-classes]].
