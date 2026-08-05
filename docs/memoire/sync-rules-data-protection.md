---
name: sync-rules-data-protection
description: "P4 résolu — sync-rules gatées par rôle pour les tables sensibles (paie, RH, médical, discipline)"
metadata: 
  node_type: memory
  type: project
  originSessionId: fbfd7c02-473f-415b-b6e1-a21454a8de92
---

P4 RÉSOLU côté config (2026-06-06). `powersync/config/sync-rules.yaml` : les tables sensibles ne sont plus synchronisées vers TOUT le personnel de l'école mais **restreintes par rôle** (`AND p.role IN (...)` ajouté au join `profiles`) — data-minimization pour plateforme gouvernementale (mineurs + RH).

**Politique appliquée (6 streams) :**
- Finance (`payroll`, `expenses`, `budget_lines`, `staff_members`) → `comptable, directeur, proviseur`
- Médical (`infirmary_visits`, données de mineurs) → `infirmier, directeur, proviseur`
- Discipline (`discipline_incidents`) → `cpe, surveillant, directeur, proviseur`

**Fuite la plus grave corrigée :** `staff_members` contient `base_salary_xaf` + `iban` et était diffusé à tout le personnel. (Pas de colonne `profile_id`/`user_id` sur `staff_members` → pas de chemin « sa propre fiche » via sync-rules.)

**Laissé en suspens (flag dans le YAML) :** `student_payments` — à restreindre finance/admin + parent (son enfant via `student_tutors`) une fois l'Espace Parent implémenté ; non gaté pour ne pas casser ce futur chemin.

**⚠️ LIMITATION POWERSYNC (piège) :** `colonne IN ('a','b')` (liste de littéraux) **N'EST PAS supportée** dans les data queries → erreur « This expression is not supported by PowerSync ». Solution appliquée : **une requête par rôle** dans le `queries:` du stream (les requêtes sont unionnées ; `p.role = 'littéral'` est supporté). Ex. payroll = 3 requêtes (comptable/directeur/proviseur), discipline = 4. NE PAS réintroduire `IN (liste)`.

**⚠️ DÉPLOIEMENT REQUIS :** ces règles ne prennent effet qu'après **redéploiement via le dashboard PowerSync Cloud** (instance `https://6a185941234fa2bf51a66757.powersync.journeyapps.com`) → coller le YAML, **Validate**, **Deploy**. À la prochaine sync, les tables restreintes sont purgées du SQLite local des rôles non habilités. Tant que non déployé, l'ancienne règle (tout visible) reste active. Pattern technique = join `profiles` inline (edition 3 streams). Lié : [[powersync-status]], [[bug-powersync-role-utilisateur]].