# 🔐 Le tuteur suit l'école de son enfant (migration 0110)

`student_tutors` n'avait pas de `school_id`. Deux conséquences, aucune visible depuis
l'application :

- **La synchro.** `sync-rules.yaml` ne pouvait filtrer que sur `group_id` — PowerSync
  n'accepte pas de JOIN dans une data-query. Chaque poste d'une école recevait donc sur
  son disque les noms, téléphones, e-mails, adresses et professions des familles de
  **toutes les écoles du groupe**. L'annuaire n'en montrait rien (il joint `students` et
  filtre sur l'école), mais la donnée était là, en clair, sur un poste partagé.
- **La règle RLS.** `student_tutors_tenant` autorisait tout le groupe, quand `students`
  — la table de l'**enfant** — était déjà restreinte école par école. L'enfant était
  protégé, le numéro de sa mère ne l'était pas.

Même défaut, même correction que [[bulletin-subject-lines]] : la table ne pouvait pas
descendre par école faute de colonne.

## Ce que pose 0110

`school_id uuid NOT NULL`, **dérivée** — un tuteur appartient à l'école de son enfant,
par définition. Le trigger `trg_student_tutor_derive_school` la recalcule (avec
`group_id`) à chaque écriture depuis `students` : le client peut l'omettre ou se
tromper, la base rétablit. Pas de `SECURITY DEFINER` — qui ne voit pas l'élève ne peut
pas lui attacher un tuteur, et la fonction ne sert pas à deviner l'école d'un élève
qu'on n'a pas le droit de voir.

RLS réécrite mot pour mot comme `students_tenant` / `student_documents_tenant`.

⚠️ **Le client estampe `school_id` QUAND MÊME** (`addTutor`). Ce n'est pas une
redondance : une fiche saisie hors ligne vit dans la SQLite du poste avant d'atteindre
le serveur, où aucun trigger ne tourne. Sans valeur locale, elle disparaîtrait de toute
requête filtrant sur l'école jusqu'au retour du réseau — le piège `is_active` à nouveau.

## ✅ Sync-rules DÉPLOYÉES (2026-08-24)

`npx powersync deploy sync-config --directory=powersync
--sync-config-file-path=…/config/sync-rules.yaml` sur l'instance **Production**
`6a185943234fa2bf51a66759`. Validation passée, `Initial replication done: true`,
`Replication lag: 0 bytes`, `student_tutors` répliquée.

Pré-vérification faite avant de pousser, et c'est elle qui compte : `fetch config`
(lecture seule) pour garder une copie du live, puis diff des tables live↔dépôt. **Zéro
table ajoutée, zéro retirée** — le seul écart sémantique était `student_tutors` passant
de `WHERE group_id = bucket.gid` à `WHERE school_id = bucket.sid`. Le snapshot d'avant
est le retour arrière.

À la première synchro de chaque poste, les tuteurs des autres écoles sont purgés de la
SQLite locale. Les écritures en attente ne sont pas touchées : la file CRUD est séparée
des buckets.

⚠️ **Les comptes `admin_groupe` n'ont pas de `school_id`** : `by_school` ne leur ouvre
aucun bucket, ils ne reçoivent donc aucun tuteur par PowerSync. C'est déjà le cas pour
`students`, et c'est cohérent — ils travaillent en ligne, sur Supabase direct. Ne pas
lire ça comme une panne.

`schoolTutorsProvider` garde volontairement sa jointure sur `students` : elle écarte les
tuteurs hors école **même avant** ce déploiement.

## Le troisième jumeau

`annuaire_form.dart` passait encore `groupId ?? ''` — chaîne vide dans une colonne
`uuid NOT NULL`, `22P02` au serveur, lot PowerSync abandonné après un « Contact ajouté »
parfaitement vert. C'est le défaut n°1 de [[ecrans-jumeaux-guichet-registre]], réparé au
guichet et au registre, **jamais ici**. Corrigé dans le même geste : la garde exige
maintenant groupe ET école, et `test/edition_eleve_garde_test.dart` compare les verdicts
des deux gardes sur les cinq combinaisons d'identifiants manquants.

État au moment de poser : 2 lignes en base, 0 orpheline. Le déploiement national n'avait
pas eu lieu — c'était le dernier moment où cette migration coûtait deux lignes.

Voir aussi [[sync-rules-data-protection]], [[perte-silencieuse-identifiants-vides]].
