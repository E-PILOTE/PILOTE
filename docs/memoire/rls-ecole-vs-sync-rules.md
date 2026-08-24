# 🔐 Deux verrous, et on n'en tournait qu'un (0111)

Une table nominative a **deux** filtres d'école, pas un :

| Verrou | Qui l'applique | Ce qu'il protège |
|---|---|---|
| **sync-rules** | le service PowerSync | ce qui **descend** sur les postes |
| **RLS** | Postgres | ce qu'une requête PostgREST authentifiée peut **demander** |

Ils sont indépendants. Corriger l'un laisse l'autre ouvert, et rien ne le signale — la
sync marche, l'écran est correct, et la faille ne se voit qu'en interrogeant l'API
directement avec un jeton d'agent valide.

## Le cas `bulletin_subject_lines`

Sa sync-rule filtrait `WHERE school_id = bucket.sid` depuis longtemps (c'est la
correction qui a fait tomber 55 886 lignes par poste à ~3 %). Sa **RLS**, elle, disait
encore `is_super_admin() OR group_id = auth_group_id()` — tout le groupe.

Son parent `bulletins` était déjà restreint par école. **L'en-tête du relevé était
protégé, les notes qu'il contient ne l'étaient pas.**

Mesuré avant/après sur un agent d'école réel, en se mettant dans sa peau
(`set_config('request.jwt.claims', …)` + `SET LOCAL ROLE authenticated`) :

> **55 886 lignes lisibles → 5 467**, l'effectif exact de son école.

Écriture vérifiée dans la foulée : dans sa propre école, acceptée ; dans l'école
voisine, refusée (`insufficient_privilege`).

## ⚠️ `is_super_admin()` a été RETIRÉ, délibérément

Ne pas le « restaurer » en croyant réparer un oubli.

- `bulletins`, `grades` et `evaluations` ne l'ont pas. Le garder ici laisserait un
  super_admin lire les notes de tous les élèves du pays sans pouvoir lire l'en-tête du
  relevé qui les porte — et du mauvais côté : ce sont les LIGNES qui portent la donnée.
- Aucun appelant ne le perd : rien n'interroge cette table par Supabase. Le seul code
  qui la touche est `bulletins_provider.dart`, en local, donc par PowerSync. Les Edge
  Functions passent par `service_role`, qui ignore la RLS.

Besoin de statistiques nationales sur les notes un jour ⇒ fonction `SECURITY DEFINER`
rendant des **agrégats**, jamais une réouverture de la lecture nominative.

⚠️ **La RLS ne concerne pas la synchro** : PowerSync réplique par le slot logique et
évalue ses propres règles. Une migration RLS seule n'a rien à redéployer.

## Le balayage — ce qui reste

Tables du bucket `by_school` dont la RLS ne mentionne pas `school_id` :

- **Référentiels de calendrier** — `academic_years`, `trimesters`, `sequences`,
  `school_cycles`. **Normal, pas un défaut** : le calendrier national vit en
  `school_id IS NULL` et doit être lisible par toutes les écoles du groupe ; l'écriture
  est déjà bornée à `is_admin_groupe()`.
- **`exam_candidates` et `internships` — MÊME DÉFAUT, non corrigé.** Données
  nominatives d'élèves (candidatures aux examens d'État, stages), `group_id` seul, en
  **lecture ET en écriture**. À trancher : vérifier d'abord si un cockpit ministère /
  DEC lit les candidatures au-delà de l'école avant de resserrer — `transmissions`, le
  dépôt DEC, est déjà par école, ce qui plaide pour resserrer.

## Non fait, et pourquoi

Dériver `school_id`/`group_id` du bulletin parent par trigger, comme
[[tuteur-suit-l-ecole-de-son-enfant]] le fait pour les tuteurs : le client estampe déjà
les deux colonnes depuis les mêmes locales que l'en-tête, elles sont NOT NULL, et la
prod montre 0 divergence sur 143 569 lignes. Ceinture sur une bretelle qui tient — à
poser le jour où une divergence apparaît.

Voir aussi [[sync-rules-data-protection]], [[evaluation-notes-bulletins]].
