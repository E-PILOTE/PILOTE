---
name: reseau-vs-national-reference
description: "Décision : le taux du réseau ne se retouche pas, il se compare au chiffre proclamé par la DEC"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-07-28T18:49:28.835Z
---

# Réseau vs national — la bande de référence du cockpit examens

Le réseau de démonstration est à **50,55 %** au Bac T&P quand la DEC proclame
**51,61 %** au national. Décision du 2026-07-28 : **ne PAS déplacer la cohorte**
pour effacer l'écart. Les deux nombres sont posés côte à côte
(`ExamNationalReferenceStrip`), avec assiette et session — l'écran affiche
« au niveau national » et l'écart d'un point devient un argument.

**Why:** retoucher la donnée de démo aurait fabriqué un chiffre de plus, dans un
jeu de données qu'on venait justement d'assainir ([[examens-metp-reels-dec]]).
Poser l'étalon à côté est plus rigoureux ET démontre le produit : le chiffre
relevé sur « Résultats & archives » revient éclairer le pilotage.

**How to apply:** deux règles verrouillées par `test/national_reference_test.dart` —
1. **Aucune référence sur « Tous les examens »** : le BET et le bac T&P ne se
   moyennent pas, la DEC ne publie aucun taux tous examens confondus.
2. **La session de la référence est toujours nommée.** À défaut du chiffre de la
   session en cours, on montre la dernière proclamée en le disant
   (BET → « dernière session proclamée : 2024-2025 », −6,0 pt).

Sous 2 points d'écart, la puce dit « au niveau national » plutôt qu'un delta :
en dessous, l'écart est du bruit. L'écart s'exprime en **points**, jamais en %.

Code : `providers/national_reference.dart` (fonction pure `nationalReferenceFor`)
+ `widgets/exam_national_reference_strip.dart`. `OfficialFigure.examCode` a été
ajouté pour rapprocher par CODE (`BAC_TP`) et non par sigle.

## Débordements — la cause était structurelle
`AdminStatCard` (79 emplois) rend désormais la hauteur disponible à son texte
(`LayoutBuilder` + `Flexible` quand la contrainte est bornée) : plus de
« BOTTOM OVERFLOWED ». ⚠️ Ne jamais « corriger » un débordement de KPI en
rehaussant `mainAxisExtent` — le défaut réapparaît au libellé suivant. Le nombre
de colonnes se déduit d'une **largeur minimale de carte** et préfère un diviseur
du lot (six cartes sur quatre colonnes → 4+2, laid ; sur trois → deux rangées
pleines).

Liens : [[examens-metp-reels-dec]] · [[cockpit-metp-pilotage]] ·
[[archives-publications-dec]]
