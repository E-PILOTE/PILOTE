---
name: import-listes-eleves
description: Import CSV des élèves — ⚠️ Excel FR écrit en ; et Windows-1252 ; date+sexe NOT NULL rejetés AVANT écriture sinon le lot PowerSync entier est perdu
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-04T00:11:39.997Z
---

# Importer les listes que les écoles ont déjà (2026-08-03)

Aucun fichier ministériel n'existe : chaque école saisit. Mais presque toutes
tiennent déjà un classeur Excel ou une liste papier. Retaper 300 noms dans un
formulaire, c'est deux jours — et le moment où l'on renonce au système.

## ⚠️ Les pièges qui cassent un import au Congo

1. **Excel francophone sur Windows écrit le CSV avec `;`**, pas `,`.
   → `detecterSeparateur()` prend celui qui découpe le plus de colonnes
   (`;` `,` tab `|`).
2. **Il l'encode en Windows-1252**, pas UTF-8. → `decoderTexte()` tente UTF-8
   **d'abord**, latin-1 en repli. ⚠️ **Jamais l'inverse** : latin-1 accepte
   n'importe quels octets, n'échoue jamais, et transformerait silencieusement
   tous les accents d'un fichier UTF-8.
3. BOM `EF BB BF` retiré, sinon il colle au premier nom.
4. Dates : `12/03/2011` = **jour d'abord**. Année sur 2 chiffres **REFUSÉE**
   (1911 vs 2011). `DateTime(2011,2,31)` déborde en 3 mars → contrôle
   `d.year/month/day` obligatoire.

## ⚠️ LA RÈGLE : rejeter AVANT d'écrire

`students.date_of_birth` et `gender` sont **NOT NULL**. Une ligne incomplète
acceptée localement serait refusée par le serveur → **PowerSync abandonne le
LOT ENTIER**, pas la ligne ([[inscription-validation-effectif-a-verifier]],
[[type-local-suit-type-serveur]]). Donc : date manquante/illisible ou sexe
non compris = ligne bloquée, avec le format attendu dans le motif.

Autres refus, **jamais de rapprochement d'office** :
- classe du fichier introuvable → rejet nommant la classe (mettre un enfant
  en 6ᵉ B au lieu de 6ᵉ A ne se découvre qu'au conseil de classe) ;
- doublon interne au fichier (nom|prénom|date normalisés) → nomme la ligne
  d'origine ; doublon en base → « déjà inscrit ».

## Décisions

- **`ChampImport`** reconnaît les en-têtes normalisés (minuscules, sans
  accent). ⚠️ « N° » / « Num » **non devinés** : rang ≠ matricule.
- **Colonnes ignorées NOMMÉES à l'écran** — un « Téléphone parent » abandonné
  en silence fait croire que les numéros sont entrés. (Les tuteurs ne sont
  pas importés.)
- **L'INE du fichier n'est PAS repris** : il sert au dédoublonnage seulement.
  C'est le serveur qui attribue ([[ine-identifiant-national-eleve]]).
- « NOM Prénom » collé : les **capitales** désignent le nom ; sans capitales
  on coupe au 1ᵉʳ espace avec `nomDevine = true` → ligne « à relire ».
- `cleClasse()` : l'ordinal ne se retire **que s'il suit un chiffre**
  (`6ème A` = `6e A`), sinon « 6 E » perdrait sa section.
- Écriture **ligne par ligne** (un échec n'emporte pas les 299 autres),
  statut `pending_validation` comme une saisie manuelle.

## ⚠️ Défaut introduit PUIS corrigé (relecture, mig 0090 le même soir)

L'écriture faisait `profile.groupId ?? ''` — le motif exact de
[[perte-silencieuse-identifiants-vides]]. `students.group_id` est
`uuid NOT NULL` : chaîne vide acceptée en local, 22P02 à la remontée, **lot
PowerSync entier perdu**. Corrigé par `buildWriteIdentity` +
`writeIdentityMessage` (`core/utils/write_identity.dart` — le garde-fou
existait, je ne m'en étais pas servi). `executerImport` revérifie date/sexe/
classe **au bord de l'écriture**, car l'invariant se lisait dans 3 fichiers.

Leçon : **relire ses propres chemins d'écriture contre `write_identity.dart`
avant de commiter**, systématiquement.

## Fichiers

`students/services/import_liste_eleves.dart` (pur, testable) ·
`providers/import_eleves_provider.dart` (résolution + écriture) ·
`screens/import_eleves_dialog.dart` + `import_eleves_parts.dart` ·
bouton dans l'écran Inscriptions. 30 tests.

Liens : [[inscription-module-logique]] · [[premiere-heure-etablissement]] ·
[[perte-silencieuse-identifiants-vides]]
