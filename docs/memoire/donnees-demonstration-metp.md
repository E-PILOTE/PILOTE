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

## Deuxième vague : les écrans qui s'ouvraient sur rien (même jour)

⚠️ **Vérifier la synchro AVANT de remplir.** L'espace école est offline-first :
une table absente de `powersync_schema.dart` OU de `sync-rules.yaml` n'atteindra
jamais le poste, quoi qu'on écrive dans Postgres. Toutes les tables de ce lot
ont été vérifiées présentes dans les deux — `council_meetings` ne l'était pas.

| Domaine | Posé |
|---|---|
| Emploi du temps | 33 matières, 660 programmes, 70 salles, 660 services, 7 EDT (6 publiés, 1 brouillon), **1 200 créneaux**, 56 aménagements, 140 disponibilités, 42 plages horaires |
| Cahier de textes | **1 200 entrées**, 805 avec devoirs |
| Finance | 12 grilles tarifaires, **6 963 encaissements** (140 M XAF, avec impayés), 70 lignes de budget, 70 dépenses, **567 bulletins de paie** (juin en attente) |
| RH | 63 diplômes, 126 étapes de carrière, 42 congés (12 à traiter), 630 pointages |
| Bibliothèque | 84 ouvrages, 1 064 exemplaires, 175 emprunts dont **56 en retard** |
| Familles | **1 524 tuteurs**, tous les élèves couverts (la table en avait 2) |
| Tutelle | 7 transmissions officielles + 126 lignes, 5 accusées |
| Reste | 34 événements, 17 centres d'examen, 9 trimestres, 18 séquences, 7 conversations, 42 messages, 28 fiches d'annuaire |

**Coût : ~7 Mo.** Tables vides : **50 → 13**.

### 🩸 Trois tables MORTES, découvertes en voulant les remplir

- **`council_meetings`** — l'écran « Conseils » travaille en réalité sur les
  `bulletins` (appréciation, décision, prix). La table n'est ni dans le schéma
  PowerSync ni dans les règles de synchro : rien n'y arriverait jamais.
- **`competence_grades`** et **`school_education_programs`** — zéro fichier
  Dart les mentionne. (Cf. `school_education_levels`, déjà morte, mig 0089.)

### ⚠️ Ce qu'on refuse de remplir, et pourquoi

- **Adossées à des fichiers** : `exam_publications` (`file_path`/`file_name`
  NOT NULL — ce sont les PV de résultats en PDF), `stories` (`media_url`),
  `staff_photo_requests`, `support_ticket_messages`. Y écrire ferait pointer
  l'écran vers des documents absents du Storage : le visiteur cliquerait sur un
  téléchargement qui échoue. **Un écran vide vaut mieux qu'un écran qui ment.**
- **`platform_partners`** alimente le carrousel de l'écran de CONNEXION.
  Y inventer des noms afficherait des partenariats inexistants à tout visiteur.
  Ce n'est pas au code de le décider.
- **`payment_configs`** : les trois fournisseurs sont déclarés en mode test,
  inactifs, **sans la moindre clé d'API**. C'est l'état réel d'un groupe dont
  le compte marchand n'est pas ouvert.

### Contraintes qui ont fait échouer une écriture

`timetable_exceptions.kind` ∈ {`cancelled`,`moved`,`extra`} (pas de vocabulaire
français, contrairement aux écrans) · `inspections.cycle_scope` ∈
{`primaire`,`secondaire`} · `fee_structures.source_reference` NOT NULL — tout
tarif doit citer sa source, et c'est une bonne règle · `day_of_week` : 1 = lundi
(`frDays`) · un `WITH` attaché à un `INSERT` ne couvre QUE cet `INSERT`.

## Ce qui restait vide au premier passage

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

## 🩸 Troisième vague : le cœur du métier était vide (même jour)

Un audit de cohérence après les deux premiers lots a montré le trou : les sept
écoles privées avaient classes, élèves, emploi du temps, cahier de textes,
paiements et bibliothèque — et **zéro évaluation, zéro note, zéro bulletin,
zéro candidat**. Tout était plein autour, et le métier scolaire était vide.

| | |
|---|---|
| Évaluations | **1 320** (devoir surveillé + composition par matière et classe) |
| Notes | **23 254** — moyenne 11,49 ; 3 % d'absents ; de 3,02 à 19,95 |
| Bulletins | **1 057** — 23 redoublements, 4 mentions |
| Lignes de bulletin | **11 615** — moyenne, moyenne de classe, rang, appréciation |
| Candidats | **344** — session CAP 2025-2026 **ouverte**, 99 dossiers incomplets |

### Les bulletins sont CALCULÉS, pas tirés au sort

C'est le point qui compte. Un bulletin fabriqué indépendamment des notes
afficherait 14 là où l'écran des notes montre 11 — et le premier qui croise les
deux écrans perd confiance dans **tout** le reste.

    notes → moyenne par matière → moyenne pondérée par coefficient
          → rang dans la classe → moyenne de classe → mention → décision

Contrôle : moyenne des notes **11,49**, moyenne des bulletins **11,48**.
L'écart vient des absents, exclus du calcul. C'est le *bon* écart — il prouve
que le lien est réel.

### ⚠️ `get_mention()` n'existe pas en base

Le `CLAUDE.md` affirme « mentions alignées sur `get_mention()` en base ».
**Cette fonction n'existe pas** — aucune fonction ne porte « mention » dans son
nom. Le barème a été relevé sur les 18 285 bulletins existants, qui font foi :
Insuffisant < 10 · Passable < 12 · Assez Bien < 14 · Bien < 16 · Très Bien < 18
· Excellent ≥ 18. ⚠️ **Capitale** à « Assez Bien » et « Très Bien » — mes
appréciations de notes portaient une minuscule et ont dû être reprises.

### ⚠️ Publier une version de l'application n'embarque AUCUNE donnée

Demandé le 2026-09-07 : « publie une nouvelle version avec toutes ces données ».
Les données vivent dans Supabase, pas dans l'installateur. Les espaces
`super_admin` et `admin_groupe` les lisent en direct ; le personnel scolaire les
reçoit par PowerSync. **Un poste déjà en 3.5.18 voit tout sans rien installer.**
Republier aurait livré un binaire identique — aucune ligne de Dart n'avait
changé — et fait clignoter le ruban sur tout le parc pour rien.

