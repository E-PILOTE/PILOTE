---
name: presences-appel-identite-deduite
description: Module Présences élèves — l'appel s'écrit de façon idempotente (UUID v5 déduit de la clé), RLS gâtée par module (0123), et le bulletin compte enfin les absences (0122)
metadata:
  node_type: memory
  type: project
---

# MODULE PRÉSENCES ÉLÈVES — audit du 2026-08-27

`presences-eleves` (catégorie VIE SCOLAIRE). Tables `attendance_records`
(classe × date × période) + `attendance_entries` (1 par élève : present /
absent / late + heure d'arrivée + justification). 100 % offline.
Écrans : `vie_scolaire/screens/presences_screen.dart` + `presences_roll.dart`.
Le périmètre par module (verrou 4) était DÉJÀ correct : `kSlugPresences` +
`classesForModuleProvider`.

## 🩸 L'IDENTIFIANT TIRÉ AU SORT FAIT DIVERGER DEUX APPAREILS

C'est LE défaut structurel de l'offline-first, et il apparaît ici en premier.

**Un appel est un fait unique** : la 6ᵉ A, le 12 mars, au matin. Le professeur
principal et le surveillant le saisissaient chacun hors ligne, chacun avec son
`Uuid().v4()` → DEUX `attendance_records` pour un seul appel.

La contrainte serveur ne les rattrape PAS :
`UNIQUE (class_id, record_date, period, subject_id)` porte aussi sur
`subject_id`, resté NULL — et **deux NULL ne sont pas égaux en SQL**. Encore un
verrou fermé sur rien.

Conséquence visible : `classRollProvider` joint les deux enregistrements et
affiche **chaque élève deux fois**, avec deux statuts contradictoires.

**Et le double appui jetait le lot.** `setAttendance` décidait d'insérer d'après
`existingEntryId`, lu dans un instantané du flux. « Absent » puis « Présent » en
deux appuis rapides — le geste ordinaire d'un appel — arrivaient tous deux avec
`entryId` nul et inséraient deux fois. Or
`UNIQUE (attendance_record_id, student_id)` existe, elle : **23505, code FATAL**
pour le connecteur, qui jette le LOT ENTIER en attente (l'appel, mais aussi les
paiements et les notes saisis dans la même heure).

### La parade : `core/utils/identite_offline.dart`

`idDeterministe(type, cle)` = **UUID v5** sur un espace de noms figé. Même clé
métier ⇒ même identifiant, sur tous les appareils, sans coordination. Le
connecteur fait `upsert` par `id` : les deux saisies convergent sur une ligne.

- appel  : `idDeterministe('attendance_record', [classId, date, period])`
- entrée : `idDeterministe('attendance_entry', [recordId, studentId])`
- `setAttendance` **relit la base locale** au lieu de croire l'instantané ;
- `markAllPresent` aussi — il écrasait en « présent » un élève déclaré absent
  la seconde d'avant.

⚠️ **Pourquoi PAS une contrainte d'unicité de plus ?** Parce qu'elle changerait
la convergence en PERTE : un 23505 de plus = un lot de plus jeté. On rend
l'écriture idempotente, pas interdite.

⚠️ **N'employer `idDeterministe` que si la clé métier est stable et non
révisable.** PAS pour un paiement, une évaluation, un incident : deux versements
de 5 000 F le même jour sont deux versements, et les confondre effacerait de
l'argent.

⚠️ **Migration 0124** : la seule ligne d'appel existante (3 août 2026, 5 élèves)
a été RECLÉE sur son identité déduite. Sans cela, le correctif aurait produit
sur cette classe exactement le défaut qu'il corrige.

Garde : `test/identite_offline_test.dart`.

## 🔒 0123 — marquer un enfant absent est un droit, pas une appartenance

`attendance_records` / `attendance_entries` n'avaient qu'UNE politique `FOR ALL`
vérifiant la seule appartenance à l'école : **tout membre du personnel** — le
comptable, l'infirmier — pouvait créer, modifier et **supprimer** l'appel de
n'importe quelle classe côté serveur. Même défaut que 0114 (paiements) et 0118
(notes/bulletins). Vérifié après (production, transaction annulée) :

| | lit | déclare absent | finalise | efface |
|---|---|---|---|---|
| Direction | ✓ | oui | oui | oui |
| Vie scolaire | ✓ | oui | oui | non |
| Enseignant | ✓ | **refusé** | non | non |
| Secrétariat | ✓ | **refusé** | non | non |

## 📄 0122 — le bulletin comptait « 0 absence » sans avoir regardé

`bulletins.total_absences` / `total_lates` étaient NOT NULL DEFAULT 0 et
l'application y écrivait **0 en dur**, jamais calculé et **jamais affiché**. La
base affirmait sur chaque enfant un fait que personne n'avait observé.

Désormais : comptés depuis `attendance_entries` sur la fenêtre du trimestre,
affichés à l'écran ET sur le PDF officiel — qui ne portait aucune assiduité.
Colonnes rendues NULLABLES : sans appel enregistré, la réponse honnête est
« — », pas « 0 ».

## ⚠️ OUVERT, NOMMÉ

- **QUI FAIT L'APPEL ? À TRANCHER.** Dans le catalogue livré, l'**enseignant n'a
  AUCUN droit d'écriture** sur les présences — l'appel revient à la Vie scolaire.
  Choix d'organisation défendable (le surveillant fait le tour), mais
  `ANALYSE.md` §7 pose l'inverse : « Notes et absences (enseignant → sync auto) »
  y est la raison d'être du hors-ligne. C'est de la CONFIGURATION de groupe, pas
  du code : décision admin_groupe. Sur 1 000 écoles, le défaut livré compte.
- **Appel par MATIÈRE non implémenté.** `attendance_records.subject_id` existe
  (et figure dans la contrainte d'unicité), toujours NULL : l'app ne fait l'appel
  que par demi-journée. Au collège et au lycée, un élève peut sécher UNE heure —
  invisible aujourd'hui.
- **`parent_notified` est écrit 0 et n'est jamais lu** : aucune notification aux
  familles (même trou que le FCM du §8.3).

## 🚨 TROUVÉ EN PASSANT — L'AUDIT N'EXISTE QUASIMENT PAS

`ANALYSE.md` §9 annonce « **Audit logs** : toutes les actions sensibles (CREATE,
UPDATE, DELETE) ». Relevé en base le 2026-08-27 : **UN SEUL déclencheur d'audit
dans toute la base** (`trg_log_fee_structure_change` sur `fee_structures`),
82 lignes dans `audit_logs` couvrant 6 tables, et **aucun code Flutter n'écrit
`audit_logs`** — les 9 références sont toutes des lectures.

L'espace admin_groupe affiche donc une page « Audit » rassurante au-dessus d'un
journal que presque rien n'alimente. Ni les notes, ni les bulletins, ni les
paiements, ni les présences n'y laissent de trace. **Chantier transverse à
décider** (volume, non-synchro vers les appareils, rétention).

Voir [[evaluation-notes-bulletins]], [[modules-acces-hierarchie]],
[[vie-scolaire-categorie]].
