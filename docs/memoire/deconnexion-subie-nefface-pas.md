---
name: deconnexion-subie-nefface-pas
description: "⚠️ `signedOut` Supabase n'est PAS un ordre de l'agent — il ne doit JAMAIS déclencher disconnectAndClear() ; constaté en vrai : 75 Mo de base hors ligne effacés"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-04T09:37:04.537Z
---

# Une déconnexion subie n'efface plus la base hors ligne (2026-08-04)

## Ce qui s'est passé pour de vrai

Sur le poste de recette, la session Supabase est morte (jeton de
rafraîchissement perdu — l'app avait été tuée pendant une rotation). Supabase a
émis `signedOut` **tout seul**. Le code a répondu `disconnectAndClear()` :

- base passée de pleine à **18 105 pages libres sur 18 453** (98 %) ;
- 0 bucket, 0 ligne d'`ps_oplog` ; le fichier de 75 Mo reste (SQLite ne rétrécit
  pas) — d'où l'illusion que « tout va bien » ;
- il a fallu retélécharger **48 761 lignes** (≈ 53 s ici, sur bonne liaison).

L'ancienne garde ne conservait la base que s'il **restait des écritures à
remonter**. Une école parfaitement à jour — le cas normal — perdait tout.

## ⚠️ Pourquoi c'est grave au Congo, au-delà du retéléchargement

Le poste retombe sur l'écran **e-mail + mot de passe**. Sur un poste PARTAGÉ,
les agents ne connaissent que leur **code à quatre chiffres**. Personne sur
place ne connaît le mot de passe : l'établissement est enfermé dehors, ses
données intactes de l'autre côté.

## La règle

`signedOut` → **`disconnect()` seulement, jamais de purge.** Supabase l'émet
après un week-end hors ligne, une rotation perdue, une coupure longue.

La purge multi-tenant garde son seul moment légitime : le `signedIn` d'un
utilisateur **DIFFÉRENT**. Isolée dans `doitPurgerPourChangementDeCompte()`
(`powersync_service.dart`), fonction pure dont la **signature ne comporte aucun
paramètre de déconnexion** — la garantie est dans le type, pas dans un `if`.
6 tests : `test/purge_base_locale_test.dart`.

La déconnexion VOLONTAIRE reste distincte et déjà avertie
(`logout_guard.dart`, [[offline-device-enrollment]]).

## Comment le diagnostiquer

```bash
cp ~/.local/share/cg.epilote.epilote/epilote_v3.db* /tmp/  # les 3 fichiers !
sqlite3 /tmp/epilote_v3.db "select count(*) from ps_oplog; \
  pragma page_count; pragma freelist_count;"
```
⚠️ Les vues PowerSync (`profiles`, `classes`…) renvoient 0 depuis un `sqlite3`
externe même quand la base est pleine : **compter `ps_oplog`**, pas les vues.
Un `freelist_count` proche du `page_count` = base vidée.

Dans le journal : `Sync Isolate exit`, puis un « Validated and applied
checkpoint » en moins d'une seconde = accusé VIDE.

Liens : [[base-hors-ligne-hors-documents]] · [[offline-device-enrollment]] ·
[[powersync-status]]
