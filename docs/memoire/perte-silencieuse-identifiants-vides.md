---
name: perte-silencieuse-identifiants-vides
description: "Le motif « ?? '' » sur un identifiant fait rejeter la ligne par Postgres et abandonne tout le lot PowerSync ; ✅ TOUS les chemins d'écriture corrigés (fc1cc8b + c2dcb69, 2026-07-23) ; restants = lectures/fonctions pures"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-23T02:07:35.669Z
---

**Mécanisme de la panne** (audit du 2026-07-18) : `group_id`, `school_id`,
`recorded_by`, `created_by`, `enrollment_id`… sont `uuid` **NOT NULL** en base.
Le SQLite local **n'impose rien** → une chaîne vide s'écrit sans broncher,
l'écran dit « enregistré ». Le refus arrive à la remontée :
`22P02 invalid input syntax for type uuid` — et un refus abandonne le **lot
PowerSync ENTIER**, emportant présences/notes/paiements saisis dans la même
fenêtre, **sans aucun message**.

Le coupable est le motif **`p?.groupId ?? ''`** : il transforme une ABSENCE en
VALEUR et fait passer le typage Dart au vert alors que la donnée est invalide.

⚠️ **Ce n'est pas théorique** : **20 comptes enseignants sur 67** ont
`school_id` ET `group_id` à **NULL** en production (vérifié en base).

**Correctif** : `lib/core/utils/write_identity.dart` — `isUsableId()` (une
chaîne vide/blanche est une absence), `buildWriteIdentity()`,
`missingWriteIds()` qui **nomme** ce qui manque, `writeIdentityMessage()`.
10 tests. Les écrans refusent franchement et expliquent (« votre compte n'est
rattaché à aucune école ») au lieu d'un `return` muet.

**État — TOUS les chemins d'écriture couverts (2026-07-23).**
- Finance (4), **students** (inscription) et **evaluation** (note, éval,
  bulletins×2) : corrigés + **vérifiés en GUI** (commit `fc1cc8b`) — arrivée
  serveur confirmée, UUID réels, données purgées.
- **structure + vie_scolaire + RH + classes** : les 26 chemins restants
  corrigés (commit `c2dcb69`) — EDT (créneaux/salles/fériés/dispo/exceptions/
  duplication), cahier de textes, création de classe, pointage présences
  (choke-point `_ensureRecord`), cantine, biblio, discipline, infirmerie,
  orientation, congés (demande+décisions), paie (bulletin+report), dossier
  (carrière+diplômes), présences personnel. flutter analyze 0, 374 tests OK.
  ⚠️ Non vérifiés en GUI (le refus ne se déclenche que pour un compte sans
  rattachement ; Aline en a un). Couverts par les 10 tests unitaires.
- Restants = **mappings de lecture** (`m['group_id'] ?? ''` en parsant une
  requête) et **fonctions pures** (détection de conflits EDT `_staffId ?? ''`)
  → PAS des écritures, ne causent pas de perte de lot. Laissés tels quels.

**Recette appliquée** : `missingWriteIds(groupId/schoolId/actorId)` +
`writeIdentityMessage` avant l'écriture ; `?? ''` → `p!.groupId!` (promotion
par null-assertion) ; dans une closure, **capturer** `final gid = p!.groupId!…`
AVANT (la promotion ne traverse pas la closure) ; garde gated `!_isEdit` quand
seule la création touche l'identité ; année active vérifiée via `isUsableId`.

**`enrollment_id`** : seul paramètre nullable de `savePayment` pointant vers une
colonne NOT NULL. Risque **latent, pas actif** — la requête source
(`classPaymentsProvider`) part **de** `class_enrollments`, donc l'identifiant ne
peut y être nul ; le `String?` est une sur-déclaration défensive. Désormais
vérifié explicitement pour qu'un futur appelant ne le réintroduise pas.

Compter les chemins réellement exposés (et non les simples occurrences) :
chercher un `[A-Za-z]*[Ii]d:.*\?\? *''` dans les 14 lignes suivant un appel
`(save|create|insert|add|record|assign|register|upsert|update)[A-Z]\w*\(`.

Voir [[sync-failure-journal]], [[upload-outbox-fichiers]],
[[inscription-validation-effectif-a-verifier]], [[examens-frais-stats-convocations]].
