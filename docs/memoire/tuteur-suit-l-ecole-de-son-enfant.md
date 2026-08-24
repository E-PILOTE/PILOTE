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

## ⚠️ RESTE À FAIRE — un geste humain

Les sync-rules sont modifiées dans le dépôt (`student_tutors` déplacé de `by_group`
vers `by_school`) mais **PAS DÉPLOYÉES**. Tant qu'elles ne le sont pas, l'ancienne règle
reste active et les coordonnées continuent de descendre par groupe.

> Dashboard PowerSync Cloud → coller `powersync/config/sync-rules.yaml` →
> **Validate** → **Deploy**.

À la première synchro suivante, les tuteurs des autres écoles sont purgés de la SQLite
locale de chaque poste.

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
