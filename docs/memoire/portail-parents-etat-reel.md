---
name: portail-parents-etat-reel
description: "L'état RÉEL du portail parents : 0 compte parent, 0 compte élève, 2 tuteurs sur 9 106 élèves — et `schools.parent_portal_enabled` RETIRÉE (0168) parce qu'elle affirmait le contraire"
metadata:
  node_type: memory
  type: project
---

**2026-09-01.** Relevé en base, pas déduit.

| ce qu'on croit parfois | ce qui est vrai |
|---|---|
| un portail parents existe | `/user/espace-parent` = `StaffComingSoonScreen` |
| des parents s'y connectent | **0** compte `parent`, **0** compte `eleve` |
| les tuteurs sont saisis | **2** tuteurs déclarés sur **9 106** élèves |

## ⚠️ Une colonne affirmait le contraire — retirée par 0168

`schools.parent_portal_enabled` valait `boolean NOT NULL DEFAULT true`, donc
**`true` sur les 37 écoles**, et chaque école créée naissait en l'affirmant.
Elle n'était lue ni écrite **nulle part** : ni en Dart, ni dans
`powersync_schema.dart`, ni dans les sync-rules, ni par une fonction, une vue,
une politique ou un index.

Sans lecteur elle ne faisait pas de dégât — jusqu'au premier export ou état qui
parcourt `schools` et publie « portail parents : activé » pour trente-sept
établissements où il n'existe pas.

**Pourquoi retirer plutôt que passer à `false`** : mettre 37 lignes à `false`
aurait corrigé l'affirmation et laissé une colonne morte que le prochain
lecteur croira significative. Le jour où le portail existera, l'interrupteur se
reposera — avec un défaut `false`, un vrai lecteur, et un écran pour le régler.

## ⚠️ Ce retrait n'est PAS celui que 0146 attend

Retirer une colonne qu'un poste envoie encore provoque un `42703` rejoué à
l'infini, et le poste cesse silencieusement de remonter quoi que ce soit
([[blocage-de-file-visible]]). Ici c'était **prouvé, pas supposé** :

1. absente de `powersync_schema.dart` → PowerSync ne peut pas l'envoyer ;
2. `schools` n'est écrite hors ligne nulle part (aucun `UPDATE schools` dans `lib/`) ;
3. les six écritures en ligne portent des champs explicites, aucune ne la cite,
   aucun `select('*')` ;
4. aucun objet de la base ne la mentionne — vérifié par requête.

C'est une preuve plus forte que celle qui manque à `0146`, qui reste suspendue.

## Quand le portail se construira

L'ordre est **direction d'abord, enseignant en dernier, familles après**
([[rollout-leadership-first]]). Deux préalables se voient déjà dans les
chiffres : sans saisie des tuteurs (2 sur 9 106), un portail parents n'a
personne à qui ouvrir ; et l'espace élève suppose un identifiant élève stable
([[ine-identifiant-national-eleve]]).

Voir [[un-seul-fournisseur-supabase]] · [[rollout-leadership-first]]
