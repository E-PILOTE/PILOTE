# ⚠️ Écrans jumeaux : le guichet et le registre divergent en silence

**La page Inscriptions et la page Élèves sont deux copies l'une de l'autre.** Corriger
l'une ne corrige PAS l'autre, et rien ne le signale. L'audit d'Élèves (22 août 2026)
a retrouvé, intacts, six défauts déjà réparés côté Inscriptions.

## Les paires à surveiller

| Guichet (`/user/inscriptions`) | Registre (`/user/eleves`) |
|---|---|
| `inscriptions_edit.dart` + `_parts` | `eleves_edit.dart` |
| `inscriptions_screen.dart` | `eleves_screen.dart` + parts |
| `inscriptions_csv.dart` | `exportStudentsCsv` (registry provider) |
| `inscriptions_data_provider` | `students_registry_provider` |

## Ce que la divergence avait produit

1. **`refusEdition` n'était appelée QUE par le guichet.** L'éditeur du registre
   passait `groupId ?? ''` à `addTutor` → chaîne vide dans `student_tutors.group_id`
   (`uuid NOT NULL`) → « Modifications enregistrées », puis PowerSync perd **le lot
   entier**, élève compris. Il sautait aussi toute fiche de tuteur incomplète.
2. **La case « contact principal »** se décochait librement au registre : quatre
   principaux, ou zéro. `primaryTutorProvider` fait `LIMIT 1` et ne rendait plus rien.
3. **L'export CSV** n'avait ni date de naissance ni INE → rejeté à 100 % par notre
   propre import.
4. **La situation familiale** s'affichait en code brut (`monoparentale_pere`) dans le
   tiroir élève.
5. **L'échec de téléversement photo** emportait toute la saisie (pas de `try` local).
6. `_TutorDraft`, `_PhotoPicker`, `_bloodGroups`, la table des mois : 2 à 4 copies.

## La parade posée

- Fiche tuteur + photo + promotion du contact principal → `widgets/tuteur_edit_card.dart`,
  **partagés**. Voir [[contact-principal-unique]].
- `refusEditionRegistre()` à côté de `refusEdition()` dans `edition_eleve_garde.dart`,
  bâties sur les **mêmes** helpers privés. Un test compare les deux verdicts sur les
  mêmes tuteurs (`test/edition_eleve_garde_test.dart`) : elles ne peuvent plus diverger
  sans casser la suite.
- Libellés : `models/eleve_libelles.dart` (`kSituationsFamiliales`, `kGroupesSanguins`)
  et `models/tutor_draft.dart` (`kLiensParente`).
- Rythme mensuel : `construireRythmeInscriptions()` sert **les deux** graphes.

## Règle

> Toute correction sur une de ces paires : **vérifier l'autre dans le même geste**, ou
> mieux, déplacer la règle dans un fichier partagé et la tester.

Voir aussi [[flutter-tech-notes]], [[graphe-effectif-vs-kpi]].
