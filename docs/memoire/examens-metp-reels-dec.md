---
name: examens-metp-reels-dec
description: "Les examens METP réels du Congo — la DEC publie DEUX baccalauréats distincts, technique et professionnel ; la fusion en « Bac T&P » était une erreur"
metadata: 
  node_type: memory
  type: reference
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-02T20:34:03.289Z
---

# Examens du METP — ce que la DEC proclame réellement

## ⚠️ CORRECTION MAJEURE (2026-08-02, sur reprise du user)

Cette note affirmait qu'il n'existait **qu'un** « baccalauréat technique et
professionnel » (`BAC_TP`), et que `BAC_T`/`BAC_P` étaient fictifs. **C'était
faux**, et la migration 0065 qui les avait fusionnés a été défaite par la **0079**.

Le portail de résultats de la DEC publie **deux palmarès distincts** :
**Baccalauréat technique** et **Baccalauréat professionnel**.

**D'où venait l'erreur** : la presse titre « bac technique et professionnel » —
mais ce libellé désigne **la SESSION commune de juin**, où les deux jurys
siègent ensemble, pas un diplôme unique. J'avais pris un nom de session pour un
nom de diplôme, puis écrit une note affirmative qui a servi de vérité une semaine.

**La leçon, plus large que le bac** : le code Dart n'avait JAMAIS suivi la fusion
(`kExamsRequiringInternship = {'BAC_T','BAC_P'}`, `kPrerequisites['BAC_T']`).
Une constante qui refuse obstinément de suivre une « correction » est un signal —
depuis 0065, l'attestation de stage n'était plus exigée nulle part.

**How to apply :** le user est fonctionnaire DSIC/METP ; sa parole prime
([[user-fonctionnaire-dsic-metp]]). Quand il contredit une de mes notes, la note
est le suspect, pas lui — même quand elle prétend le citer.

## Le référentiel réel

Examens METP : **BAC_T, BAC_P, BET, BEP, BTF, CAP, CQP**, plus **CFEEN, DCAF,
DEMA, DECS, BTS** (ajoutés par la 0079, sans règle d'éligibilité).
MEPSA, autre tutelle : CEPE, BEPC, BAC_G, CONCOURS_6EME, CONCOURS_2NDE.

⚠️ **Le mapping série → bac technique ou professionnel n'est PAS établi.** Les
neuf règles d'éligibilité (F1-F4, F6, F7, G1-G3) sont sur le **Bac technique** ;
le **Bac professionnel est à vide**, comme BEP/BTF/CAP/CQP depuis la 0044. On
n'invente pas de mapping — le ministère l'attache lui-même depuis
`/admin/referentiel-examens` ([[referentiel-examens-au-ministere]]).

## Chiffres officiels publiés — vérifiés, en base

⚠️ `year_label` = ANNÉE SCOLAIRE ; la session se tient en **juin de sa seconde
année**. « 2024-2025 » = session de juin 2025.

| Examen | juin 2023 | juin 2024 | juin 2025 | juin 2026 |
|---|---|---|---|---|
| **BET** | 3 547/5 149 · 68,89 % | 3 835/5 937 · 64,59 % | 5 308/6 841 · **77,59 %** | — |
| **BEP** | 349/436 · 80,05 % | 90,50 % (362 admis) | 315/424 · **74,29 %** | — |
| **BTF** | 119/119 · 100 % | 100 % (97 inscrits) | 59/59 · **100 %** | — |
| **Bac technique** | — | **43,65 %** (7 252 admis) | 7 681/15 843 · **48,48 %** | **51,61 %** |

⚠️ Ces chiffres de bac sont publiés sous le libellé collectif « bac technique et
professionnel ». Ils sont rattachés au **Bac technique** en base — La Congolaise
242 écrivant « 15 843 candidats se sont présentés à l'examen du baccalauréat
technique ». **Si le user confirme qu'ils couvrent les deux jurys, il faut les
détacher** : un chiffre de session ne se rattache pas à un seul diplôme.

Départements publiés (juin 2025, les deux seuls connus) : **Bouenza 99,23 %**
(1er) · **Cuvette-Ouest 19,83 %** (dernier). Les 13 autres ne sont PAS
renseignés — **ne jamais les inventer**.

1er au bac de juin 2025 : Stelie Ruth Landou Soussa, Terminale **F5**, IFTPL
Loudima, 15,63/20. ⚠️ La série **F5 existe** et manque à `education_programs`.

**Why :** ces nombres sont publics et le user les connaît par cœur. Devant un
ministère, un chiffre inventé — ou un diplôme inventé — est disqualifiant.

**How to apply :** tout nouveau chiffre officiel doit être **sourcé**
(`source_label` = la délibération) ; à défaut d'effectifs reconstituant le taux
publié, n'enregistrer que `pass_rate`.

Séries du bac technique : **E, F1–F7, G1–G3**.

Liens : [[examens-nationaux-socle]] · [[archives-publications-dec]] ·
[[referentiel-examens-au-ministere]] · [[user-fonctionnaire-dsic-metp]] ·
[[seed-demo-national-pipeline]]
