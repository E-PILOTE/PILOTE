---
name: carte-scolaire-module
description: "🪪 Module Cartes scolaires (2026-08-29) — ISO ID-1, 10/A4, verso MIROITÉ ; ⚠️ le vrai sujet est la PHOTO : 0 sur 9 106 élèves ; le refus (`peutDelivrerCarte`) est la partie utile"
metadata:
  node_type: memory
  type: project
---

# La carte scolaire (2026-08-29)

Le seul papier que l'élève **porte**. La plateforme savait déjà émettre des
papiers de guichet ([[attestations-emises]]) ; elle ne savait pas produire
celui-là — il ne figurait nulle part dans le code, seulement dans la liste des
pièces manquantes de [[deploiement-national-octobre]].

Ce n'est pas une variante d'attestation : une attestation se délivre à
l'unité, à la demande, pour une démarche. La carte se fabrique **en masse à la
rentrée**, pour une classe entière, et sert toute l'année.

## ⚠️ Le vrai sujet n'est pas le PDF, c'est la photo

**0 photo sur 9 106 élèves** au moment de l'écriture (9 106 INE, 9 106
matricules, 2 lieux de naissance, 2 groupes sanguins). Un module qui n'offrirait
qu'un bouton « Imprimer » produirait neuf mille silhouettes grises.

L'écran compte donc les visages **avant** de proposer d'imprimer, classe par
classe, et l'annonce en toutes lettres. L'impression n'est jamais interdite —
une école peut vouloir des cartes sans photo (cantine, portail) — mais personne
ne doit le découvrir aux ciseaux.

⚠️ **Deux comptes différents, et c'est voulu.** L'écran compte `photo_url` en
base ; la planche compte ce que **ce poste-ci** a pu charger. Une photo peut
exister sur le serveur et rester introuvable ici. C'est le second chiffre qu'on
annonce avant l'aperçu (`_confirmerSansPhoto`).

## Les octets d'une photo, hors ligne — `core/utils/photo_octets.dart`

Trois sources, dans cet ordre : **file d'envoi** (photo prise ici, pas encore
montée — [[fichiers-hors-ligne-et-compression]]) → **cache disque**
(`flutter_cache_manager`, la photo a été AFFICHÉE ici) → **réseau**. Rien
d'autre : jamais d'image de remplacement, un document officiel n'invente pas un
visage.

Le cache est ce qui rend l'impression possible sans réseau : le secrétariat a
consulté ses listes toute la semaine, les visages sont déjà là.
`flutter_cache_manager` est passé transitif → **dépendance directe** dans
`pubspec.yaml` (on le lit, on le déclare).

⚠️ `compressAvatar` réduit à **256 px**. À 22 × 28 mm sur la carte, cela vaut
≈ 295 dpi — la limite basse de l'impression propre. **Ne pas descendre cette
compression.**

## Les trois pièges, tous invisibles à l'écran

1. **Le verso miroité.** La feuille se retourne sur son bord long : la colonne
   de gauche au recto revient à droite au verso. Une planche verso dans le même
   ordre donne cent cartes dont le dos appartient au voisin — et **l'aperçu PDF
   ne le montre pas**, les deux pages semblent correctes séparément. Seule la
   feuille retournée le révèle, après la découpe. D'où `rangeesPlanche(lot,
   verso:)`, isolée et publique pour être testée comme ce qu'elle est : une
   permutation.
2. **La hauteur de la planche.** Cinq cartes de 54 mm = 270 mm sur les 297
   d'une A4 : il reste 27 mm pour deux marges et quatre gouttières. Ma première
   version prenait 12 mm de marge et 3 mm après **chaque** rangée, dernière
   comprise → 807 pt de contenu pour 774 pt de page, cinquième rangée hors du
   papier. **C'est le test qui l'a trouvé**, pas l'œil. Réglage retenu : marge
   8 mm, gouttière 2 mm entre rangées (294 mm, 3 mm de battement).
3. **Le refus.** `peutDelivrerCarte(status)` → **`active` uniquement**. Une
   carte pour un élève radié est un laissez-passer : elle ouvre un portail,
   obtient un tarif, atteste d'une qualité perdue. Test : la carte et
   `peutDelivrerScolarite` disent toujours la même chose, et aucun statut ne
   rend carte et radiation délivrables ensemble.

## Décisions

- **Format ISO/CEI 7810 ID-1** (85,6 × 54 mm) — ce qui entre dans un
  portefeuille et dans les pochettes du marché. 10 par A4 avec liseré de coupe :
  la quasi-totalité du parc découpe aux ciseaux.
- **Verbe `export`**, distinct de `read` : consulter l'avancement des photos et
  fabriquer cent titres d'identité ne sont pas le même geste.
- **Aucune table `cartes_emises`.** La carte se recompose à chaque impression
  depuis `students` + `class_enrollments` : une carte réimprimée après un
  changement de classe doit porter la NOUVELLE classe.
- **Le QR ne porte que l'INE** (ou le matricule à défaut) — c'est-à-dire ce qui
  est déjà imprimé en clair à côté. Cette carte vit dans la poche d'un enfant.

## Où c'est

`features/cartes/` (providers, screens, services) + `students/services/
carte_scolaire_pdf_service.dart`. Module `cartes` créé par la migration
**0148**, qui recopie à l'identique les plans et droits de `documents` (35/35/14
— vérifié). Comme [[passage-devient-un-module]], elle s'applique **AVANT** le
build.

## L'import de masse des photos (2026-08-29, même jour)

`features/cartes/services/appariement_photos.dart` (pur, testé) +
`providers/import_photos_provider.dart` (l'écriture) +
`screens/import_photos_dialog.dart` / `_parts.dart` (quatre temps : choix →
revue → écriture → rapport).

**⚠️ LA RÈGLE : EXACT, OU RIEN.** Une photo posée sur le mauvais élève est pire
que pas de photo — la carte devient un faux qui circule, et *personne ne le
cherche* : elle a l'air normale. Donc **aucune** distance d'édition, aucun
préfixe, aucun « meilleur candidat ». Et l'unicité est **symétrique** : il ne
suffit pas qu'un fichier désigne un seul élève, il faut qu'aucun autre fichier
ne désigne le même (deux homonymes, deux prises → on n'en écrit aucune).

Correspondance sur matricule / INE / nom (les deux ordres), via
`normaliserEntete` — la normalisation de l'import de listes, pas une seconde.
Chaque clé est indexée espacée **et** compactée : `M-2024/0137`, `M 2024 0137`
et `m20240137` sont la même chaîne écrite autrement, pas de l'approximation.

**Le chemin principal est manuel**, et c'est assumé : l'école vide sa carte
mémoire et obtient quarante `IMG_0042.JPG`. L'écran de revue les met **en
premier**, vignette à côté d'un menu des élèves encore libres.

⚠️ **`withData: false`** au sélecteur : six cents photos de téléphone tiennent
plusieurs gigaoctets, et l'appariement n'a besoin que du **nom**. Les octets se
lisent un par un au moment d'écrire.

⚠️ **Le bouton se garde sur `eleves.update`, pas sur un verbe du module.**
L'import écrit `students.photo_url`, et `students_update` exige
`auth_module_permet(['eleves','inscriptions'], 'update')`. Le garder sur le seul
`cartes.import` laisserait un profil écrire en local puis se faire refuser au
téléversement — **42501, fatal, tout le lot en attente part avec**. Les deux
droits sont exigés : le module dit qu'on importe ici, la base dit qu'on peut
toucher un élève.

Autres garde-fous : plafond de **15 Mo** par fichier (`compressAvatar` retombe
en silence sur les octets d'origine quand elle ne sait pas décoder — à l'unité
c'est le bon choix, sur six cents fichiers c'est des Go sur le disque d'une
école) ; un échec isolé n'emporte pas le lot ; le rapport **nomme** les fichiers
qui ont manqué.

## Reste à faire

- **Le journal des documents délivrés** — qui a délivré quoi, quand. Aucune
  table ne le trace, ni pour la carte ni pour les attestations.
- Prise de photo **à la webcam** depuis la fiche élève (aujourd'hui : fichier
  seulement).

Liens : [[attestations-emises]] · [[ine-identifiant-national-eleve]] ·
[[fichiers-hors-ligne-et-compression]] · [[passage-devient-un-module]]
