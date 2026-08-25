---
name: secteur-ecole-herite-groupe
description: "Un groupe est public XOR privé ; une école HÉRITE du secteur de son groupe (verrou base + UI lecture seule) ; « mixte » supprimé (enum + partout Flutter), mig 0060"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-23T06:32:10.911Z
---

**Principe métier (confirmé par l'utilisateur, 2026-07-23)** : un **groupe
scolaire** est **public XOR privé** (l'État/ministère vs un promoteur privé).
Une **école appartient à un groupe**, donc son secteur **EST** celui de son
groupe. Un secteur « mixte » n'a pas de sens (le vrai hybride s'appelle
« conventionné », autre chose) — et rien ne devait laisser une école « privée »
vivre sous un groupe public.

**État initial (le bug)** :
- `school_groups.group_type` = `public | prive` ✅ (jamais de mixte, l'écran de
  création de groupe ne proposait que ces deux).
- `schools.school_type` = `public | prive | **mixte**` ❌ (enum + menu du
  formulaire école proposaient « Mixte »). 3 écoles mixtes + 6 privées sous des
  groupes publics = incohérence libre (rien ne liait école↔groupe).

**Correctif (migration 0060 + commit `1087e01`)** :
- **Base** : aligne chaque école sur `group_type` de son groupe (9 recalées) ;
  retire `mixte` de `school_type_enum` (**swap** : rename→create(`public`,`prive`)
  →alter column USING cast→drop old ; PG n'a pas `ALTER TYPE DROP VALUE`) ;
  **triggers d'invariant** : `trg_school_type_from_group` (BEFORE INSERT/UPDATE
  OF group_id, school_type → auto-set `school_type = group_type`) et
  `trg_cascade_group_type` (AFTER UPDATE OF group_type sur school_groups →
  propage aux écoles). Vérifié : forcer une école de groupe public en `prive`
  la remet en `public`. Croisement final : public→20, privé→4, 0 incohérence.
- **Flutter** : formulaire école → champ « Type (hérité du groupe) » en lecture
  seule (`group_type` exposé sur `adminSchoolsProvider`) ; « Mixte » retiré
  PARTOUT (filtres schools/régional/projet, tranches stats dashboard+rapports+
  PDF, légendes carte, branches de libellé mortes ; `mixteCount` supprimé des
  providers dashboard & rapports).

⚠️ **Le secteur d'une école ne se saisit JAMAIS** — il suit le groupe. Toute
nouvelle écriture d'école doit laisser la base le fixer (le trigger écrase de
toute façon). Ne pas ré-introduire de sélecteur de secteur ni de valeur `mixte`.

Note terminologie : « groupe scolaire » au Congo désigne souvent le
*complexe/établissement* physique (= `schools` dans l'app), pas le tenant
propriétaire (= `school_groups`). Voir [[verifier-base-live-vs-schema]].
