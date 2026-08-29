---
name: registre-documents-delivres
description: "📜 Registre des documents délivrés (2026-08-29) — table `issued_documents`, IMMUABLE par trigger RETURN OLD ; ⚠️ l'INSERT n'exige AUCUN verbe (sinon 42501 fatal) ; ⚠️ exige un déploiement des sync-rules sinon l'écran ment"
metadata:
  node_type: memory
  type: project
---

# Le registre des documents délivrés (2026-08-29)

Certificat de scolarité, certificat de radiation, carte scolaire, attestation de
travail : chacun engage l'établissement, et **aucun ne laissait de trace**.

`audit_logs` ne pouvait pas le faire : il journalise les UPDATE/DELETE de tables
(migration 0144). Or délivrer un papier **n'écrit rien** — c'est
exactement pourquoi le geste était invisible. Il fallait une trace qui note un
ACTE, pas une modification de ligne.

## Les décisions, et pourquoi

- **Aucune copie du PDF.** Le registre note l'acte ; le papier est chez la
  famille. Entreposer chaque certificat, ce serait des milliers de pièces
  portant identité, date de naissance et adresse d'enfants, sur le disque de
  chaque poste — un volume inutile et une fuite en attente.
- **Les noms sont FIGÉS** (`recipient_name`, `issued_by_name`), pas joints. Un
  registre qui lit le nom *actuel* change de contenu quand un élève change de
  nom ou quand l'agent quitte l'école. Il doit dire ce qui a été écrit ce
  jour-là.
- **Identifiant aléatoire, jamais déterministe.** Deux certificats le même jour
  au même élève sont DEUX actes — le duplicata après une perte est précisément
  ce que le registre doit montrer (`core/utils/identite_offline.dart`, côté « ce qui
  peut légitimement exister en plusieurs exemplaires »).
- **Une ligne par ÉLÈVE**, même pour une planche de 40 cartes : la question est
  « combien de cartes cet enfant a-t-il reçues ? ».
- **L'agent noté est celui AU CLAVIER** (`activeAgentIdProvider`), pas la
  session de l'appareil. Sur un poste partagé, l'inverse rendrait le registre
  inutile et injuste ([[poste-partage-agent-switch]]).

## ⚠️ Immuable — mais SANS JAMAIS LEVER

Un registre modifiable n'est pas un registre. Les deux façons naturelles de le
refuser sont **des pièges mortels ici** :

| façon naturelle | ce qui arrive |
|---|---|
| ne créer aucune politique UPDATE | le connecteur envoie ses créations en **UPSERT** ; un lot rejoué après coupure entre en conflit, tombe sur l'UPDATE, **42501 fatal** → lot entier jeté |
| lever dans un trigger | même piège, autre code (P0001/23xxx, également fatal) |

**La solution retenue** : l'UPDATE est *autorisé* par la RLS (le rejeu passe) et
rendu **sans effet** par un trigger `BEFORE UPDATE ... RETURN OLD`. Vérifié en
production : `UPDATE ... SET recipient_name = 'PIRATE'` rend « UPDATE 1 » et la
ligne est inchangée.

## ⚠️ L'INSERT n'exige AUCUN verbe de module

Seule écriture du dépôt dans ce cas, et c'est délibéré. Elle **accompagne** la
délivrance : exiger un droit que l'agent n'a pas ferait échouer l'insertion en
42501 — le journal détruirait le travail de la journée pour avoir voulu le
noter. Règle de la 0144 : *un journal ne doit jamais coûter la donnée qu'il
observe*. Côté client, `noterDocumentEmis` est sous `try/catch` et s'abstient si
`buildWriteIdentity` rend `null` (une chaîne vide en colonne `uuid` = 22P02,
fatal aussi).

Le contrôle d'accès reste sur l'écran : `/user/documents/registre` est un
**sous-chemin** de `/user/documents`, donc `moduleSlugForLocation` rend
`documents` et le verrou 3 s'applique — sans une ligne de plus au catalogue
([[passage-devient-un-module]]).

## ⚠️ Deuxième condition de déploiement : les SYNC-RULES

Premier cas du dépôt où une migration ne suffit pas. Sans la ligne
`- SELECT * FROM issued_documents WHERE school_id = bucket.sid` dans `by_school`,
les écritures remontent bien vers Postgres **mais n'appartiennent à aucun
bucket** : la copie locale disparaît au checkpoint suivant et l'écran s'affiche
vide alors que la donnée existe. Rien n'est perdu — **l'écran ment**, ce qui est
pire. Voir `docs/DEPLOIEMENT_ORDRE.md`.

## Où c'est

`students/services/registre_documents.dart` (écriture) ·
`students/providers/registre_provider.dart` (lecture) ·
`students/screens/registre_screen.dart` (écran). Appelé depuis
`attestation_actions.dart`, `cartes/services/cartes_actions.dart` (deux gestes)
et `staff/screens/personnel_dossier_sheet.dart`.

Garde : `test/registre_documents_test.dart` — 17 tests. Il surveille surtout des
**absences**, parce que le défaut de ce registre est le SILENCE : une porte de
délivrance qui ne noterait pas, une colonne d'un seul côté (piège 42703), la
table absente des sync-rules.

## Reste à faire

Le **registre matricule** (le grand livre réglementaire) reste absent — c'est un
autre document, exigé par l'État, et il ne se confond pas avec celui-ci.

Liens : [[attestations-emises]] · [[carte-scolaire-module]] ·
[[passage-devient-un-module]]
