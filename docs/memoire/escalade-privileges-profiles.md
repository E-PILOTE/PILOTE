---
name: escalade-privileges-profiles
description: "⛔ CRITIQUE — un compte enseignant pouvait s'écrire role='super_admin' sur sa propre ligne profiles et prendre toute la plateforme ; fermé par 0125 (déclencheur qui RAMÈNE les colonnes de pouvoir)"
metadata:
  node_type: memory
  type: project
---

# ⛔ L'ESCALADE DE PRIVILÈGES (trouvée et fermée le 2026-08-27)

**Le défaut le plus grave de tout l'audit.** Il ne vivait dans aucun module :
il vivait dans la table qui PORTE les droits.

## Le mécanisme

`profiles_update` autorise un membre à mettre à jour SA propre ligne
(`id = auth.uid()`), et son `WITH CHECK` était **NUL** — Postgres retombe alors
sur le `USING`, qui reste vrai puisque c'est toujours sa ligne. **Aucune colonne
n'était protégée.** Or tout le contrôle d'accès de la plateforme se lit dans
cette table :

```
is_super_admin()  = profiles.role = 'super_admin'
is_admin_groupe() = profiles.role = 'admin_groupe'
auth_school_id()  = profiles.school_id
auth_group_id()   = profiles.group_id
les 4 verrous     = profiles.access_profile_id
```

Mesuré en production avec un compte **enseignant**, transaction annulée :

```
AVANT  role=enseignant  finance=f
  se donner le profil DIRECTION      : OUI
  se déclarer SUPER_ADMIN            : OUI     ← toute la plateforme
  se transférer dans une AUTRE école : OUI
APRÈS  role=super_admin  finance=t
```

Et le déclencheur `profiles_sensitive_flags` — qui DÉRIVE `sync_finance` /
`sync_medical` / `sync_discipline` du profil d'accès — **achevait le travail** :
il ouvrait de lui-même la paie, le médical et la discipline. Un garde-fou
retourné en amplificateur.

## La parade — 0125

Déclencheur `aa_profiles_garde_pouvoir` (BEFORE UPDATE). Un membre garde le
droit de corriger son état civil ; les colonnes de pouvoir (`role`,
`access_profile_id`, `school_id`, `group_id`, `is_active`, `sync_*`) sont
**RAMENÉES** à leur valeur d'origine.

**Ramenées, pas refusées** — et c'est le point de conception : un refus lèverait
42501, code FATAL pour le connecteur PowerSync, qui jette le LOT ENTIER en
attente. L'appareil remonte ses lignes en `upsert` complet : un poste dont la
copie locale de `profiles` a vieilli renverrait un `role` périmé sans aucune
intention de nuire, et perdrait au passage les notes et les paiements du même
lot. On neutralise l'écriture au lieu de l'interdire.

⚠️ Le préfixe `aa_` n'est pas décoratif : Postgres exécute les déclencheurs de
même moment par ORDRE ALPHABÉTIQUE, et celui-ci doit passer avant
`profiles_sensitive_flags`.

⚠️ `auth.uid()` nul ⇒ on ne touche à rien (migrations, Edge Functions en
`service_role`).

Vérifié après : la requête d'escalade **passe** (1 ligne, donc aucun 42501,
aucun lot jeté) mais ne change rien ; le prénom du même UPDATE, lui, change ; et
l'admin groupe administre toujours.

## 📐 Ce que ce défaut apprend sur la forme de la base

Relevé du 2026-08-27 sur les tables portant `school_id` :

- **3 familles de gardes** coexistent : `auth_module_permet` (verrou 3 par
  module, posé par 0114/0118/0121/0123), `auth_sync_*` (drapeaux
  médical/finance/discipline dérivés du profil), et **rien du tout**.
- **52 tables** n'ont ni l'un ni l'autre : une seule politique `FOR ALL` qui ne
  vérifie que l'appartenance à l'école.

Les plus lourdes, par volume réel : `students` (9 106), `class_enrollments`
(9 106), `class_subjects` (3 904 — les coefficients, donc les moyennes),
`exam_candidates` (2 126), `classes` (494), `audit_logs` (82),
`exam_official_results` (14).

⚠️ **Ne PAS les gâter en bloc.** La leçon 0116 tient : un droit d'écriture se
déduit des ÉCRANS QUI ÉCRIVENT, pas du nom d'une table. C'est précisément ce
que produit l'audit module par module — chaque module apporte la liste de ses
écrans, donc la liste juste des modules à admettre.

## ✅ Ce qui a été refermé dans la foulée

- **0126 — `students` + `class_enrollments`** (9 106 lignes chacune). La liste
  des modules a été déduite des écrans qui écrivent : `class_enrollments` est
  écrite par **cinq** modules (`inscriptions`, `eleves`, `conseils`,
  `transferts`, `discipline` — l'exclusion pose `status='withdrawn'`).
  N'admettre que `inscriptions` aurait cassé la Vie scolaire qui exclut et
  l'enseignant qui pose une décision de passage — 42501, lot jeté.
  ⚠️ Résidu nommé : une politique porte sur la TABLE, pas sur la COLONNE.
- **0127 — `audit_logs` en lecture seule côté client.** Tout membre du
  personnel pouvait insérer de fausses traces et effacer les siennes. Aucune
  écriture client n'est légitime : le seul écrivain est un déclencheur
  `SECURITY DEFINER`, qui ne passe pas par RLS. Vérifié : insertion refusée,
  déclencheur intact (19 → 20 lignes).

## 🔎 Déjà protégées — ne pas y retoucher

`academic_years`, `trimesters`, `exam_official_results` ont déjà un
`*_write_ministry` réservé à admin_groupe. `fee_structures` a ses quatre
politiques. `infirmary_visits`, `discipline_incidents`, `payroll` sont gâtées
par les drapeaux `auth_sync_medical / _discipline / _finance`, dérivés du profil
d'accès par le déclencheur `profiles_sensitive_flags`.

## ⏳ Restent ouvertes, par ordre de poids

`class_subjects` (3 904 — les coefficients, donc les moyennes) ·
`exam_candidates` (2 126 — inscription au BEPC/BAC) · `classes` (494) ·
`subjects` (62) · et le reste des 52, presque toutes vides aujourd'hui.

## 🚨 Deux trous nommés, non refermés

1. **L'audit n'existe quasiment pas** (cf. 0127). Un seul déclencheur dans
   toute la base.
2. **`/user/audit` viole la règle centrale** : l'écran d'audit partagé
   (`features/audit/providers/audit_data.dart`) lit par `SupabaseClient` +
   realtime, alors qu'il est routé dans l'espace PERSONNEL, qui doit être
   PowerSync uniquement. Hors ligne, cette page ne montre rien.

Voir [[evaluation-notes-bulletins]], [[presences-appel-identite-deduite]],
[[modules-acces-hierarchie]], [[sync-rules-data-protection]].
