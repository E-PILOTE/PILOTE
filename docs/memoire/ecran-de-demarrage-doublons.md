---
name: ecran-de-demarrage-doublons
description: "L'écran de démarrage disait le nom du produit 3 fois, sa vocation 2 fois, le pays 2 fois et le tricolore 5 fois — parce que logo.svg n'est pas une icône mais un bloc complet avec du texte gravé dedans ; et « v3.0 » y était écrit à la main sur un paquet en 3.5.17 (corrigé le 2026-09-06)"
metadata:
  node_type: memory
  type: project
---

# L'écran de démarrage bégayait — 2026-09-06

Remarqué par le fondateur : « il y a un désordre et des doublons d'information
des logos ». Le désordre était réel, et sa cause n'était pas dans le code Dart.

## ⚠️ `logo.svg` n'est PAS une icône

C'est un **bloc complet**. Ouvrir le fichier montre, gravés dedans :

- le texte `E-PILOTE`
- une barre tricolore vert-jaune-rouge
- le texte `CONGO`
- le texte `GESTION SCOLAIRE`

Rien dans `SvgPicture.asset('assets/icons/logo.svg')` ne le dit. **C'est
pourquoi personne ne l'avait vu** : à 46 px — barre de connexion, en-tête de
PDF, barre latérale — ces mots sont illisibles et le bloc se lit comme une
icône. L'écran de démarrage, lui, l'affichait entre 80 et 140 px.

## Ce que l'écran empilait

| | |
|---|---|
| dans le rond | « E-PILOTE » + « CONGO » + « GESTION SCOLAIRE » + tricolore |
| dessous | « E-PILOTE CONGO » jusqu'en 46 px |
| dessous | « Plateforme Nationale de Gestion Scolaire » |
| dessous | \[drapeau\] République du Congo \[drapeau\] — **deux fois, pas même en miroir** |
| dessous | barre de progression tricolore |
| à gauche | liseré vertical tricolore |
| en pied | « … · République du Congo » — le pays une 2ᵉ fois |

**Le nom 3 fois. La vocation 2 fois. Le pays 2 fois. Le tricolore 5 fois.**
Plus quatre cercles concentriques autour d'un logo qui portait déjà les siens.

## La règle tenue depuis

> Une idée, un endroit, une fois. Et le drapeau se dit **une** fois, en entier,
> à sa place. Ailleurs les couleurs nationales sont un **accent**, pas une
> déclaration — le liseré fait 3 px de large, la barre de progression 380 px
> sur 3. Aucun des deux n'a la forme d'un drapeau, et c'est voulu.

| l'idée | son unique endroit |
|---|---|
| la marque | `assets/icons/logo_marque.svg` — le même dessin, **sans un seul mot** |
| le nom | le titre, en typographie |
| la vocation | le sous-titre |
| le pays | le badge, avec **un** drapeau |
| la tutelle | le pied |
| la version | lue dans le binaire |

## ⚠️ `logo_marque.svg` : ce qu'il faut savoir avant d'y toucher

Nouveau fichier, utilisé **uniquement** par l'écran de démarrage. `logo.svg`
n'a pas bougé : il reste la signature des PDF, de la connexion et de la barre
latérale, et il doit garder son texte (une sonde le vérifie).

Trois écarts délibérés avec le bloc complet :

1. **La toque est recentrée et agrandie** — `translate(100,100) scale(1.19)
   translate(-100,-64.5)`. Sans le texte qui tenait le bas du disque, elle
   flottait en hauteur.
2. **Corps et base assombris** (`#1A3050` → `#0A1B2E`, `#152A44` → `#071322`).
   Les teintes d'origine se confondaient avec le dégradé du disque : la toque
   n'apparaissait que par ses lisérés. Le texte la masquait à moitié dans le
   bloc complet, ce qui cachait le défaut.
3. **Les deux ellipses vertes du corps sont retirées.** Ce n'étaient pas des
   bords mais des ellipses *pleines* : leur arc arrière traversait le corps et
   faisait lire la toque comme un **ressort**. Vérifié en rendant le SVG en
   PNG, pas en le relisant.

## 🩸 Et le vrai défaut, trouvé en chemin : la version

`v3.0` était **écrit à la main** — dans le pied de l'écran de démarrage ET en
bas de l'écran de connexion — pendant que le paquet passait de 3.0 à **3.5.17**.
Seize publications. C'est le premier et le dernier chiffre que voit un visiteur
avant d'entrer : un ministre, un directeur, un technicien du support.

`app_constants.dart` avait **déjà** retiré une constante `appVersion` figée
pour cette raison exacte — *« ne rien laisser qu'un lecteur puisse croire
vrai »*. Le défaut avait simplement repoussé ailleurs, dans deux écrans que
cette constante ne touchait pas.

→ `core/widgets/version_installee.dart` : un seul endroit où cette phrase se
fabrique, alimenté par `appVersionCourteProvider` (ressource de version du
binaire). **Une version se lit ; elle ne se tape pas.**

## Ce qui garde tout ça

`test/le_splash_ne_se_repete_pas_test.dart` — 10 tests :

- la marque ne contient **aucun** texte (commentaires XML dépouillés d'abord :
  l'en-tête du fichier *cite* les mots retirés, et la sonde s'y est prise les
  pieds au premier essai) ;
- le bloc complet, lui, garde les siens ;
- l'écran de démarrage n'affiche jamais `logo.svg` ;
- **aucun numéro de version en dur** dans les trois fichiers que voit un
  visiteur — sonde vérifiée en rouge avant d'être gardée ;
- le pied affiche la version réellement installée (monté avec `PackageInfo`
  mocké à 9.9.9) ;
- « E-PILOTE CONGO » et « République du Congo » : **une occurrence chacun** ;
- le tricolore n'est dessiné que **deux** fois, et le test dit lesquelles.

## ⚠️ Reste en suspens — décision du fondateur

Le pied affiche **« Agréée par le Ministère de l'Éducation »**. Wording
d'origine, gardé **mot pour mot** : c'est une affirmation d'agrément, et le
Congo n'a pas de « Ministère de l'Éducation » au singulier — la ligne suivante
nomme d'ailleurs MEPSA *et* METP. Seule la queue redondante « · République du
Congo » a été retirée. À trancher par le fondateur, pas par le code.

## Au passage

- `splash_screen.dart` : 575 → **485 lignes**. Décor et pied sortis dans
  `screens/widgets/`. Cliquet des 500 lignes abaissé 83 → **82**.
- Les boucles d'animation (`_pulse`, `_shimmer`) tournaient **après** la fin de
  la séquence, pendant que le routeur construisait l'écran suivant. Elles
  s'arrêtent maintenant avec les points.

Voir aussi [[identite-etablissement-une-seule-regle]] (l'emblème ne sert jamais
de repli à l'identité d'une école) et [[mise-a-jour-du-parc]].
