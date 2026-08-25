---
name: carriere-agent-mutation
description: "La carrière de l'agent (migs 0083/0084) — staff_affectations HORS PowerSync ; 'mutation' n'est JAMAIS un motif de départ ; setActive retiré"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-03T15:09:27.666Z
---

# Muter un agent ne détruit plus sa carrière (migrations 0083/0084, 2026-08-03)

## Le problème

`profiles` confondait **trois** choses : la PERSONNE, son AFFECTATION
(`school_id`) et son COMPTE (`id` = `auth.users.id`, `is_active`).

- **Muter** = écraser `school_id`. L'école de départ ne pouvait plus dire
  « il a servi chez nous de 2019 à 2026 » — une ancienneté ouvre des droits.
- **Sortir** = `is_active = false`. Retraité, muté, démissionnaire, révoqué et
  mort devenaient le même booléen.

⚠️ Le symétrique exact de l'INE côté élève ([[ine-identifiant-national-eleve]]).

## Les décisions

**`staff_affectations`** dit qui a servi où, quand, **et en vertu de quel acte**
(`acte_reference` + `acte_date`). Dans la fonction publique congolaise aucun
mouvement n'existe sans arrêté : c'est ce qui distingue un registre d'un
pense-bête.

**⚠️ TABLE HORS POWERSYNC, en ligne uniquement.** Délibéré : muter est un acte
de l'autorité de tutelle (groupe/ministère), pas de l'école. L'école en voit la
conséquence via `profiles.school_id`, déjà synchronisé. Conséquence : **aucune
sync-rule touchée** avant le 2 octobre ([[sync-config-divergence]]).

**⚠️ `'mutation'` est ABSENT de `profiles_departure_motif_check`** — c'est le
cœur du correctif : un muté n'a pas quitté le service, il reste `is_active`.
`radier_agent` lève une exception sur ce motif. Test garde-fou dans
`test/mouvement_agent_test.dart`.

**Trois fonctions SECURITY DEFINER** (`search_path` figé) écrivent `profiles`
ET l'affectation dans **la même transaction** : `muter_agent`, `radier_agent`,
`reintegrer_agent`. Le poste quitté ne peut plus se fermer sans que le suivant
s'ouvre. Le poste précédent ferme **la veille** de la prise de fonction, sinon
l'agent compte deux fois le jour de bascule.

- `is_current` = colonne **GENERATED** `(end_date IS NULL)` ; index unique
  partiel `WHERE end_date IS NULL` = un seul poste à la fois.
- Réintégration **refusée** après `revocation` ou `deces` (base + UI).
- `verifier_matricule_agent()` informe d'un doublon, **ne bloque pas** : un
  rejet en pleine saisie de rentrée coûte plus cher qu'un doublon signalé.

**`AdminUsersService.setActive` a été RETIRÉ** (pas déprécié) — le laisser
aurait fait un piège dormant comme `AppConstants.roleUtilisateur`
([[db-user-role-enum]]).

## Pièges rencontrés

- Le chrome partagé n'a **pas** d'état désactivé : `AdminPrimaryButton.onTap`
  est non nullable et `AdminFormDialog` supprime **tout le pied** (Annuler
  compris) si `onSubmit` est null → pied maison `_PiedMouvement`.
- `AdminBadge` prend son texte en **positionnel** (`AdminBadge('x', color:)`).
- `firstOrNull` n'est pas dans le cœur de Dart (paquet `collection`).
- `get_group_users` est un `RETURNS TABLE` : il ne s'étend pas, il se
  **remplace** (mig 0084). C'est un contrat avec `AdminUser.fromMap`.

## Reprise de l'existant

334 affectations créées (342 profils − 8 admins). `hire_date` était **vide sur
toute la base** → date d'entrée = `created_at`, motif `reprise_historique`, et
l'écran l'affiche en orange avec « à corriger au vu du dossier ». Antidater
aurait été inventer une ancienneté.

## ✅ Ce vocabulaire fait foi (user, 2026-08-03)

Les 6 motifs d'arrivée et 11 de départ **sont** la référence nationale : aucun
système antérieur n'existe au Congo, et le user est le ministère
([[user-fonctionnaire-dsic-metp]]). Même statut que [[motifs-de-sortie-eleve]].

## La charge (migration 0085)

`liberer_charge_agent(profile, school)` est appelée par les trois mouvements.
**La distinction qui décide de tout** :

- **CE QUI EST** → libéré : `teacher_subjects` (DELETE), `classes.main_teacher_id`
  (→ NULL), `teacher_availability` (DELETE).
- **CE QUI A ÉTÉ** → intact : `lesson_entries`, `payroll`, `leave_requests`,
  `staff_attendance`, `infirmary_visits`, `grades.created_by`… Effacer la trace
  d'un acte parce que son auteur est parti, c'est réécrire l'histoire.

⚠️ **`timetable_slots` n'est JAMAIS modifié** — `staff_id` est NOT NULL, et
surtout le remplacement est une décision de chef d'établissement. Les créneaux
sont **comptés** et remontés dans une modale (`ChargeLiberee.resume`) : un
silence se lirait « tout est réglé ». Test garde-fou `charge_liberee_test.dart`.

Les trois fonctions renvoient désormais du **jsonb** (elles ont dû être DROP +
CREATE : un type de retour ne s'altère pas).

## Ce qui reste ouvert

`staff_diplomas` / `staff_career` sont scopés `school_id` — ils suivent l'école,
pas la personne : une mutation les laisse derrière. Une école ne peut toujours
pas créer d'agent (R8) ; `inspections` n'a aucun module.

Liens : [[deploiement-national-octobre]] · [[rh-categorie]] ·
[[staff-personnel-annuaire]] · [[role-admin-groupe]]
