# Dossiers d'inscription aux examens METP — pièces réelles et modèle

**Date** : 2026-07-17 · **Statut** : référentiel établi (aucun code)
**Autorité** : la **note officielle METP** — arbitrage de l'utilisateur : *« crois la note officielle »*.
**Remplace** : le contenu de `exam_sessions.required_documents`, aujourd'hui rempli de mes suppositions.

---

## 1. Les pièces, examen par examen

| Pièce | Bac (T & P) | BET | BEP / CAP | BTF |
|---|---|---|---|---|
| Photocopies acte de naissance | 2 | 2 | 2 | 2 |
| **Âge limite** | **24 ans** | **20 ans** | **21 ans** (BEP officiels) | — |
| Diplôme antérieur **légalisé** | 2 — BEPC, BEMG, BET ou BEP, **datant d'au moins 3 ans** | **aucun** | 2 — BEPC, BET | 2 — BEPC, BET |
| Photos identité couleur | 4 | 4 | 4 | 4 |
| Certificat médical d'inaptitude | **si** inapte EPS | ✓ | **si** inapte (BEP) | **si** inapte |
| **Attestation de fin de stage** | **✓** | — | ✓ ⚠️ | ✓ ⚠️ |
| Note d'admission concours ENEF | — | — | — | **✓** |
| Chemise cartonnée | 1 | 1 | 1 | 1 |
| Enveloppe kaki format A4 | 1 | 1 | 1 | 1 |
| Frais d'inscription | ✓ | ✓ | ✓ | ✓ |

**Au verso de chaque photo** : noms, prénoms, **série ou spécialité**, établissement.

**Vérifié** : les âges **24 / 20 / 21** sont exactement ceux codés dans `exam_age_at_session()`
(migration 0046). Le contrôle d'âge existant est conforme.

**Le BET n'exige aucun diplôme antérieur** — logique, il suit la 3e technique. La liste varie
donc fortement d'un examen à l'autre : **une checklist unique serait fausse pour tous**.

⚠️ **Incertitudes assumées** :
- L'attestation de stage pour **BEP / BTF / CAP** : une source l'exige, l'autre ne la liste que
  pour le bac. **À confirmer auprès de la DEC.**
- La **demande manuscrite** est **abandonnée** : absente des deux notes officielles, PDF source
  en 404, arbitrage utilisateur (*« laisse la demande manuscrite »*).

---

## 2. Ce que ces pièces cassent dans le modèle actuel

### 2.1 Une pièce peut être PHYSIQUE — et le rester

Une **chemise cartonnée** et une **enveloppe kaki A4** ne seront **jamais** un fichier.

Or `exam_candidates.missing_documents` suppose implicitement que toute pièce se matérialise en
document. La règle « manquant = exigé − fichiers présents » déclarerait **éternellement**
incomplet tout dossier du pays.

→ Une pièce porte une **nature** :
- **dématérialisable** (acte de naissance, diplôme, certificat, attestation) → dérivée des fichiers ;
- **physique** (chemise, enveloppe) → cochée à la main, jamais déduite ;
- **financière** (frais) → rattachée au module Paiements.

### 2.2 Une pièce peut être CONDITIONNELLE

- Certificat médical : **seulement si** le candidat est déclaré inapte à l'EPS.
- Note ENEF : **seulement** pour le BTF.

→ `required_documents` **ne peut pas être une liste plate**. Chaque pièce porte une condition.

### 2.3 La légalisation est un ATTRIBUT, pas un détail

Le diplôme n'est pas « fourni » : il est **fourni légalisé**. C'est le motif de rejet au comptoir
le plus banal.

→ Une pièce a un état de **conformité** distinct de sa **présence**.

### 2.4 `missing_documents` est SAISI — il mentira

C'est aujourd'hui une colonne `jsonb` que quelqu'un doit tenir à jour. Le jour où un agent
téléverse l'acte de naissance sans penser à retirer la ligne, **le dossier ment**. Et il mentira,
parce que c'est toujours ce qui arrive.

→ **Dériver**, comme `resolve_class_exam()` : la règle vit à un seul endroit, le client lit. Ce
qui suppose la pièce manquante d'aujourd'hui : **un lien entre la pièce attendue et le fichier
réel**. `missing_documents` liste des codes ; rien ne pointe vers un fichier du bucket.

---

## 3. Deux natures de pièces — la distinction structurante

**Pièces de l'ÉLÈVE** — acte de naissance, photos, diplôme antérieur légalisé.
Permanentes, vivent dans `student-documents`, **resservent à chaque session**. On ne les
redemande jamais. C'est déjà l'intention de la migration 0008 : *« Le dossier suit l'ÉLÈVE
(réinscription = pièces déjà présentes, rien à re-téléverser) »*.

**Pièces de la CANDIDATURE** — attestation de stage de l'année, reçu de frais, certificat médical
de la session.
Propres à **cette** session. Elles appartiennent à la candidature, pas à l'élève.

Mélanger les deux, c'est soit redemander l'acte de naissance chaque année, soit réutiliser une
pièce périmée.

---

## 4. L'état d'une pièce

Vérification **par les deux** (arbitrage utilisateur) : l'**école avant dépôt**, la **DEC au
comptoir**. Notre pré-contrôle n'est donc pas redondant — il évite le renvoi.

```
attendue → fournie → vérifiée (par qui, quand)
                  ↘ rejetée (motif)
```

Intérêt concret : la DEC vérifie le 13 février à 17 h. Si l'école a vérifié **avant**, elle n'est
pas renvoyée. C'est le seul moment où c'est réparable.

---

## 5. Le « mieux » : l'éligibilité se vérifie toute seule

**Le BET légalisé pour s'inscrire au bac : nous savons déjà s'il l'a.** S'il a passé son BET chez
nous, le résultat est dans notre base.

L'app peut donc afficher *« BET obtenu — session 2023, admis »* et **signaler d'elle-même**
l'élève qui n'y a pas droit, sans attendre le rejet de la DEC. La photocopie légalisée reste due
— c'est un objet physique — mais **l'éligibilité est vérifiable sans personne**.

C'est le chaînage réclamé depuis le début : **le résultat ne repart pas dans le vide, il
conditionne l'inscription suivante.**

⚠️ La règle « diplôme datant **d'au moins** 3 ans » (Seconde → Première → Terminale) est
également dérivable — mais **à confirmer** avant d'être codée : mes deux sources se contredisent
(« au moins » vs « moins de »), et la note officielle fait foi.

---

## 6. Deux pièges déjà documentés — ne pas y retomber

**Le téléversement hors ligne.** Une pièce photographiée par une école sans réseau : **PowerSync
met en file le SQL, pas les fichiers** — c'est la raison d'être de l'`upload_outbox`. Toute pièce
doit y passer, sinon elle disparaît silencieusement au retour du réseau. Une pièce perdue = une
année perdue.

**Aucun rejet serveur.** Il sera tentant d'interdire l'inscription tant que le dossier est
incomplet. **Non** : une contrainte serveur qui refuse une écriture provoque la **perte
silencieuse à la synchro** — le bug qui a déjà détruit une inscription entière ici. Le dossier
incomplet se **signale**, il n'**interdit** pas.

---

## 7. Ce que ça implique pour le module Stages

**L'attestation de fin de stage est une pièce du dossier du baccalauréat** — c'est dans la note.

Le module Stages n'est donc pas un module de confort : **il produit une pièce sans laquelle
l'élève ne s'inscrit pas au bac**. Le chaînage codé en dur (`kExamsRequiringInternship =
{'BAC_T','BAC_P'}`, `stages_provider.dart`) est **conforme à la source**.

Et ça éclaire le défaut actuel : l'écran Stages affiche une alerte « dossiers bloqués faute
d'attestation » — **et n'offre aucun moyen d'en délivrer une** (zéro écriture dans
`lib/features/stages/`). Le module signale un problème qu'il rend impossible à résoudre.

---

## 8. À obtenir

1. **La liste des pièces confirmée par la DEC** (l'utilisateur est dedans).
2. **Attestation de stage** pour BEP / BTF / CAP : due ou non ?
3. **« Au moins » ou « moins de » 3 ans** pour le diplôme antérieur au bac ?
4. **Photos et badges** : téléversés dans l'appli DEC, ou uniquement au dossier papier ?

## Sources

- [Dossiers, période d'inscription et lieux de dépôt — examens METP 2024-2025](https://ecolesaucongo.com/article-3-dossiers-periode-d-inscription-et-lieux-de-depots-de-dossiers-aux-examens-metp-2024-2025.html)
- [Note d'information — Inscription aux examens d'État 2025-2026 METP](https://ecolesaucongo.com/article-64-note-d-information-inscription-aux-examens-d-etat-2025-2026-metp.html)
- Migrations concernées : `0008_student_documents_storage.sql`, `0046_sessions_centres_candidatures.sql`
