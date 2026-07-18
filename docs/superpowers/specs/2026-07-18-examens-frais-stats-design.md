# Examens — frais, statistiques, convocations et passage à l'échelle

**Date** : 2026-07-18 · **Branche** : `feat/examens-nationaux` · **Statut** : design validé

## Les problèmes constatés

1. **« Voir les inscrits » ouvre le modal d'INSCRIPTION.** Même widget pour deux
   besoins opposés (`examens_widgets.dart:266`). D'où une liste plate de cases à
   cocher, non virtualisée, sans recherche : à 100 candidats elle est illisible,
   à 500 elle rame.
2. **Pas de bouton retour** sur la page Examens.
3. **Les frais d'examen n'existent pas dans l'app.** `exam_sessions.fee_amount`
   est déclaré dans le schéma local et **utilisé nulle part** — donnée morte.
   Or ces frais sont un revenu de l'école, donc du groupe scolaire (ministère).
4. **Aucune statistique de réussite** — précisément ce qu'un ministre demande.
5. Convocations et attribution des numéros de candidat : absentes.

## Ce que le schéma offrait déjà

L'enum `fee_type` contient **`frais_examens`**, et `student_payments` existe avec
sa chaîne de remontée vers le revenu de l'école puis du groupe. **Aucune table
nouvelle n'est nécessaire.** Le schéma attendait cette fonctionnalité.

## Architecture des frais

### Le lien session ↔ barème

`exam_sessions` est **nationale** (un BET 2025-2026 pour tout le pays) ; un
barème est **par école**. Le lien ne peut donc pas vivre sur la session.

Une seule migration : `fee_structures.exam_session_id uuid NULL`. Chaque école
crée son barème `frais_examens` rattaché à la session nationale. Deux écoles ont
deux barèmes pour le même examen — ce qui est la réalité.

### La dette est DÉRIVÉE, jamais matérialisée

```
attendu   = nombre de candidats inscrits × montant du barème
encaissé  = Σ student_payments (status = confirmed) sur ce barème
reste     = attendu − encaissé
```

Créer une ligne de paiement « en attente » à chaque inscription serait plus
simple à lire, et faux : ces lignes finiraient comptées comme du revenu, ou
devraient être purgées à chaque désinscription. **Le revenu ne compte que
l'argent réellement reçu.** C'est le même principe que `missing_documents` :
on ne stocke jamais deux fois la même vérité.

L'exigence « dus dès l'inscription » est ainsi tenue : la dette apparaît à la
seconde où le candidat est inscrit, sans écrire une ligne de plus.

### Enregistrer un encaissement

Une ligne `student_payments` : `fee_structure_id` (le barème de la session),
`enrollment_id` (inscription active de l'élève dans l'année — NOT NULL),
`amount_xaf`, `payment_method`, `recorded_by`, `status = confirmed`.

Les paiements partiels sont acceptés : un parent paie en deux fois. L'état d'un
candidat est donc **impayé / partiel / soldé**, jamais un simple booléen.

## Statistiques de réussite

Calculées sur les candidats dont le résultat est connu — jamais sur l'effectif
total, sinon un examen non encore proclamé afficherait 0 % de réussite et
alarmerait pour rien.

- Taux d'admission global, et par **classe**, **filière**, **sexe**.
- Répartition des mentions.
- Comparaison avec la session précédente du même examen, si elle existe.

Le dénominateur affiché est toujours explicite (« 42 résultats connus sur 60
candidats ») : un taux sans son assiette est un mensonge commode.

## Convocations

Convocation officielle par candidat (identité, n° candidat, examen, centre,
dates d'épreuves), en-tête République du Congo via `OfficialPdfKit`. Imprimable
à l'unité depuis la fiche, ou **pour toute une classe en un seul PDF**
multi-pages — c'est ainsi qu'une école les distribue.

Une convocation sans numéro de candidat ou sans centre reste imprimable, avec la
mention explicite « à compléter » : l'école distribue souvent avant que la DEC
n'ait tout attribué.

## Numéros de candidat et centre en masse

Attribution du centre d'examen à toute une sélection en un geste, et saisie des
numéros de candidat en liste (collage depuis le tableur de la DEC). Aujourd'hui
c'est un par un, ce qui est intenable pour 300 candidats.

## Passage à l'échelle du modal

Séparation nette de deux intentions :

- **Inscrire** — sélection des élèves non encore inscrits (modal existant).
- **Voir les inscrits** — consultation : liste **virtualisée**, recherche par
  nom ou matricule, état du dossier et des frais par candidat, accès à la fiche.

## Ce que cette spec ne fait pas

- **Pas de rapprochement bancaire ni de reçu numéroté automatique.** Le module
  Paiements a sa propre chaîne ; on y verse les encaissements, on ne la refait pas.
- **Pas de prédiction de réussite.** On compte ce qui est proclamé.

## Tests

- Dérivation des frais : attendu/encaissé/reste ; partiel ; zéro candidat ;
  barème absent (fail-soft, pas de crash).
- État d'un candidat : impayé / partiel / soldé, y compris surpaiement.
- Statistiques : taux calculé sur les résultats CONNUS ; aucun résultat → pas de
  taux affiché plutôt que 0 % ; ventilation par classe/filière/sexe.
