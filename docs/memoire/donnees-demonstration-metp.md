---
name: donnees-demonstration-metp
description: "Le METP ne voyait AUCUN groupe privé (les 3 existants étaient sous MEPSA) ; 147 Mo récupérés par REINDEX seul ; 5 pièges de déclencheurs rencontrés en peuplant ; agrément porté par le GROUPE et non par l'école (2026-09-07)"
metadata:
  node_type: memory
  type: project
---

# Peupler l'espace du ministère technique — 2026-09-07

## 🩸 D'abord : la base était à 95 %, et c'était de l'index gonflé

Plan **gratuit, 500 Mo**. Mesure de départ : **~475 Mo**. Une base pleine chez
Supabase passe en **lecture seule** — pendant une démonstration ministérielle,
c'est l'accident.

Le diagnostic a montré que ce n'était pas de la donnée mais du **gonflement
d'index**, accumulé par les cycles de génération successifs :

| Table | Données | Index AVANT | Index APRÈS `REINDEX` |
|---|---|---|---|
| `class_enrollments` | 1,7 Mo | **36 Mo** | **2,2 Mo** |
| `students` | 3,3 Mo | **33 Mo** | **2,3 Mo** |
| `grades` | 143 Mo | 103 Mo | 52 Mo |
| `bulletin_subject_lines` | 43 Mo | 30 Mo | 13 Mo |

`students_pkey` pesait 5,4 Mo pour 9 106 UUID — ~590 octets par ligne, quand
une entrée de btree en vaut ~40. **Facteur 10 à 15.**

> **~475 Mo → 315 Mo. 147 Mo récupérés sans toucher à une seule donnée.**

⚠️ **`REINDEX CONCURRENTLY` ne passe PAS par la console MCP** : « cannot run
inside a transaction block ». Le `REINDEX` simple passe (il verrouille, mais
quelques secondes par index — acceptable la nuit, pas en journée).

⚠️ **`pg_size_pretty(pg_database_size(...))` oscille** pendant l'opération
(417 → 432 → 394 → 409) : les fichiers ne sont rendus qu'après coup. Mesurer en
octets, et ne conclure qu'à la fin.

⓵ **Ce que ça évite** : le fondateur avait demandé de SUPPRIMER toutes les
données MEPSA pour faire de la place — 6 groupes, 25 écoles, 7 330 élèves,
326 208 notes et **7 comptes administrateurs sur 10**, irréversiblement (pas de
restauration ponctuelle sur le plan gratuit). Le `REINDEX` a rendu la
destruction inutile. Et elle n'aurait rien apporté : `auth_group_tutelle()`
cloisonne déjà — **l'espace METP ne voit jamais une donnée MEPSA.**

## Ce qui manquait vraiment

Sept groupes, trois privés — **tous les trois sous MEPSA**. L'écran « Réseau »
du METP affichait **une ligne : lui-même**. Or le METP a la tutelle des
établissements techniques PRIVÉS ; c'est là que se joue son métier.

| | avant | après |
|---|---|---|
| Groupes vus par le METP | 1 | **4** (dont 3 privés) |
| Écoles | 12 | **19** |
| Élèves actifs | 1 776 | **2 833** |
| Avec chef d'établissement | **0** | 19 |
| Avec type d'établissement | **0** | 19 |
| Avec circonscription | **0** | 19 |

Plus : 5 circulaires (71 destinataires, accusés partiels), 10 circonscriptions
d'inspection, 40 entreprises partenaires, **342 conventions de stage**, 266
orientations, 602 feuilles d'appel / 10 576 lignes, 126 incidents, 154 passages
à l'infirmerie, 389 abonnés cantine / 3 890 pointages.

**Coût total : ~5 Mo.** La base est à 320 Mo (64 %).

## ⚠️ Les cinq pièges — chacun a fait échouer une écriture

1. **`tutelle_groupes()` filtre sur `schools.tutelle`, pas sur celle du
   groupe.** Un groupe `metp` dont les écoles resteraient `mepsa` serait
   invisible partout. (`fn_school_herite_tutelle` la recopie en fait — mais
   compter dessus sans le savoir est un coup de chance.)

2. 🩸 **`fn_school_herite_agrement` écrase SANS CONDITION l'agrément de
   l'école par celui du groupe**, en BEFORE INSERT **et** UPDATE. Une école ne
   peut pas avoir son propre numéro, ni être non agréée dans un groupe agréé.
   **L'agrément est un attribut du GROUPE.**
   - ⓘ Donc `nb_ecoles_agreees` de `tutelle_groupes()` ne vaut jamais que 0 ou
     `nb_ecoles`. La colonne suggère une finesse que le modèle interdit. À
     revoir le jour où la tutelle voudra suspendre l'agrément d'un seul
     établissement d'un réseau.
   - ⓘ Pour changer l'agrément d'un groupe il faut **toucher les écoles**
     (`UPDATE schools SET updated_at = now()`) : le trigger vit sur `schools`.

3. **`fn_auto_create_invoice`** se déclenche à l'insertion d'un groupe et fait
   `COALESCE(NEW.created_by, auth.uid())` sur une colonne NOT NULL. Depuis une
   console sans session, oublier `created_by` fait échouer avec une erreur qui
   parle de `group_invoices` — pas du groupe qu'on croyait insérer.

4. **`fn_guard_active_requires_payment`** refuse `subscription_status='active'`
   sans facture `paid` couvrant `subscription_end`. Bonne règle, non
   contournée. Séquence : créer en `trial` → facture réglée → activer.

5. **`schools.location_source` ∈ {`gps`,`geocoded`,`manual`}** — pas de valeur
   française. Et **`inspections.cycle_scope` ∈ {`primaire`,`secondaire`}** :
   « technique_professionnel » est refusé.

## ⚠️ 66 comptes de démonstration capables de se connecter

`profiles.id` référence `auth.users(id)` : **impossible de créer un agent sans
compte d'authentification**. On passe donc par `seed_account()`, la routine du
dépôt qui a créé les 346 profils existants — elle porte **son propre mot de
passe de démonstration en dur dans son corps**.

→ **À purger avant le déploiement des cinq premiers établissements réels.**
Voir aussi [[escalade-privileges-profiles]].

## Le référentiel `formation_pro` ne servait à personne

21 filières × 3 années = **63 niveaux nationaux, zéro école reliée**. Les sept
écoles privées y puisent maintenant (3 filières chacune, tirées de façon
déterministe sur `md5(programme || code_ecole)`).

## Ce qui reste vide, et se verra

L'espace école est **entièrement construit** — 94 routes réelles, 2 placeholders
(le `CLAUDE.md` de `C:\PILOTE` qui annonce « espace personnel à construire » est
périmé). Donc chaque table vide = un écran vide :

`timetable_slots` · `lesson_entries` · `rooms` · `teacher_subjects` ·
`expenses` · `budget_lines` · `payroll` · `leave_requests` ·
`staff_attendance` · `staff_career` · `staff_diplomas` · `library_items` ·
`council_meetings` · `conversations` · `events` · `exam_centers` ·
`student_payments` (1 ligne) · `student_tutors` (2)

Liens : [[ecran-de-demarrage-doublons]] · [[mise-a-jour-du-parc]] ·
[[abonnement-licence-de-tutelle]]
