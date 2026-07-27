# Scénario de démonstration — E-PILOTE CONGO au METP

> **Version 3.0.4** · Groupe de démo : *Ministère de l'Enseignement Technique et Professionnel* (14 écoles, 8 départements, 297 élèves)
> Compte cockpit : `vianney@epilote.cg` · Compte école : `proviseur@kinkala.cg` — mot de passe commun.

---

## 0. Avant d'entrer dans la salle — check-list (10 min)

| # | Vérification | Pourquoi |
|---|---|---|
| 1 | **Machine Windows ou Mac**, jamais Linux | Le poste Linux a un bug d'affichage carte connu (pilote graphique). Les cibles réelles sont Windows/Mac. |
| 2 | Les **deux comptes déjà connectés** dans deux fenêtres/onglets distincts | Basculer école ↔ ministère sans retaper un mot de passe devant le jury. |
| 3 | **Slide d'ouverture** projetée (`E-PILOTE-slide-demarrage.pptx`) | Plante le cadre avant même de lancer l'outil. |
| 4 | **Wifi actif** et testé, puis repéré : où couper (icône réseau / bouton box) | Le moment fort de la démo dépend d'une coupure franche. |
| 5 | Ouvrir **Examens nationaux** une fois pour préchauffer, puis revenir à l'accueil | Évite un temps de chargement pendant la démo. |
| 6 | Batterie / veille désactivée, notifications coupées | — |

**Trois choses à ne pas faire :**
- ❌ Ne **jamais cliquer sur une fiche élève individuelle** (écran non terminé).
- ❌ Ne pas ouvrir **Abonnement**, **Tickets**, **Modules du groupe**, **Profils d'accès** — ces rubriques cadrent le Ministère comme un client qui paie un logiciel. On veut l'inverse : un propriétaire souverain.
- ❌ Ne pas promettre de fonctionnalité non montrée. Tout ce qui est dans ce script existe et a été vérifié.

---

## 1. Démo « conseillers + techniciens DSIC » — 20 minutes

**Ce qu'ils cherchent :** la faille. Souveraineté des données, sécurité, capacité à tenir 1 000 écoles, articulation avec l'existant.
**Donc : on montre le terrain d'abord, la preuve technique ensuite.**

### Ouverture — 1 min
Slide projetée. Une seule phrase :

> « La donnée naît dans l'école — même sans internet — et remonte en temps réel au cockpit du Ministère. C'est ce que nous allons vous montrer, dans cet ordre. »

### Acte 1 — L'école (8 min) · compte `proviseur@kinkala.cg`

| Temps | Clic | Ce qu'on dit |
|---|---|---|
| 0:00 | **Tableau de bord** | « Voici ce que voit un chef d'établissement le matin. L'écran s'adapte à son rôle et à ses droits. » |
| 1:00 | **Scolarité → Structure** | « Cycle, niveau, classe — et surtout la **filière** : électrotechnique, comptabilité, froid… C'est la maille de l'enseignement technique. » |
| 2:30 | **Examens nationaux → session BET** | « L'établissement inscrit ses candidats au Brevet d'Études Techniques. Chaque dossier a ses pièces obligatoires. » |
| 4:00 | Ouvrir un **dossier de candidat** (pièces) | « La pièce est couverte si elle est **jointe ou déclarée** — on n'invalide jamais un dossier déjà constitué. » |
| 5:00 | **Générer les convocations (PDF)** | « Document officiel, imprimable, prêt pour le centre d'examen. » |
| 6:00 | **Stages** → une attestation | « Pour le bac professionnel, le stage est une **pièce du dossier d'examen**. L'attestation se génère ici. » |

### Acte 2 — LA COUPURE (3 min) · le moment qui vend

> ⚡ **Couper le wifi en direct, devant eux.** Le dire à voix haute : « Je coupe l'internet. »

| Temps | Action | Ce qu'on dit |
|---|---|---|
| 0:00 | Couper le réseau | « Beaucoup de nos établissements n'ont pas une connexion fiable. Regardez. » |
| 0:20 | **Continuer à travailler** : inscrire un candidat, saisir une note | « Tout fonctionne. La donnée est écrite localement, sur la machine de l'école. » |
| 1:30 | Rétablir le réseau | « Je rebranche. » |
| 2:00 | Montrer la synchronisation | « Ce qui a été saisi hors ligne vient de remonter. Aucune ressaisie, aucune perte. » |

> C'est ici qu'on gagne ou qu'on perd. Ne pas se presser, laisser le silence agir.

### Acte 3 — Le cockpit Ministère (6 min) · compte `vianney@epilote.cg`

| Temps | Clic | Ce qu'on dit |
|---|---|---|
| 0:00 | **Tableau de bord** | « Le Ministère voit son réseau : 14 établissements, 297 apprenants, 8 départements couverts. » |
| 1:00 | **Vue régionale** (carte) | « Chaque établissement est localisé. Les départements se colorent selon l'indicateur choisi. » |
| 2:00 | Panneau gauche → **COULEUR DES DÉPARTEMENTS → Réussite** | « Là, la carte affiche le taux d'admission aux examens d'État. **Pointe-Noire ressort en rouge à 46 %.** » |
| 3:00 | **Examens nationaux** | « 80 candidats, 74 % de réussite, 52 stages, 46 attestations. » |
| 4:00 | Descendre → **Réussite par filière** | « **Bâtiment et Génie civil : 46 %.** Hôtellerie : 100 %. Voilà où porter l'effort de formation. » |
| 5:00 | À côté → **Réussite par département** | « Et voilà où le porter géographiquement. Équité territoriale. » |

### Acte 4 — La preuve technique (2 min) — *pour les techniciens DSIC*

| Clic | Ce qu'on dit |
|---|---|
| **Journal d'audit** | « Chaque action est tracée : qui, quoi, quand. » |
| Insister | « Et **cloisonné** : une école ne voit que ses propres actions — jamais celles du niveau au-dessus. Le Ministère voit ses écoles ; l'éditeur n'apparaît nulle part. » |

**Phrases à garder en réserve pour leurs questions :**
- *« Où sont nos données ? »* → « Hébergées et maîtrisées au Congo. Le Ministère est propriétaire. »
- *« Et si le serveur tombe ? »* → « Les écoles continuent de travailler. C'est le principe du hors-ligne d'abord. »
- *« Ça tient combien d'établissements ? »* → « L'architecture est dimensionnée pour plus de 1 000 écoles ; chacune ne synchronise que ses propres données. »
- *« Et l'application d'inscription aux examens qui existe déjà ? »* → « Nous ne la remplaçons pas : nous fournissons la couche qui manque, la vie scolaire quotidienne. Et nous savons produire les listes d'examen à transmettre. »

---

## 2. Démo « ministre » — 7 minutes, pas une de plus

**Ce qu'il achète :** couverture nationale, modernisation du METP, pilotage, souveraineté. **Pas** le détail fonctionnel.

> Inverser l'ordre : **le cockpit d'abord**. Un ministre veut voir son pays, pas un formulaire.

| Temps | Écran | Message unique |
|---|---|---|
| 0:00 | Slide d'ouverture | « Une plateforme nationale, souveraine, qui fonctionne même sans internet. » |
| 0:30 | **Vue régionale**, carte colorée par **Réussite** | « Voici vos établissements techniques, département par département. En rouge, là où la réussite décroche. » |
| 2:00 | **Réussite par filière** | « Et par filière : le Bâtiment est à 46 %, l'Hôtellerie à 100 %. Vous pilotez votre offre de formation avec des chiffres, pas des estimations. » |
| 3:30 | Basculer sur l'école + **couper le wifi** | « Un établissement de l'intérieur du pays, sans connexion. Il travaille quand même. » |
| 5:00 | Rétablir → la donnée remonte | « Et tout remonte jusqu'à cet écran. » |
| 6:00 | Retour au cockpit | « Le Ministère voit son réseau en temps réel. Les données restent au Congo. » |

**Conclusion (30 s), à dire mot pour mot :**

> « Aujourd'hui, aucun outil ne couvre la vie scolaire de l'enseignement technique au Congo. Cette plateforme existe, elle fonctionne hors ligne, elle est déjà déployée sur 14 établissements de démonstration. Nous sommes prêts à passer à l'échelle nationale. »

---

## 3. Chiffres à connaître par cœur

| Donnée | Valeur |
|---|---|
| Établissements du réseau de démo | **14**, sur **8 départements** |
| Apprenants | **297** |
| Candidats aux examens d'État | **80** · **74 %** de réussite |
| Stages en entreprise | **52**, dont **46 attestations** délivrées |
| Filière la plus faible | **Bâtiment et Génie civil — 46 %** |
| Filière la plus forte | **Hôtellerie et Restauration — 100 %** |
| Département le plus faible | **Pointe-Noire — 46 %** |
| Département le plus fort | **Bouenza — 100 %** |
| Départements du Congo couverts par la carte | **15** |

---

## 4. Si quelque chose tourne mal

| Incident | Réaction |
|---|---|
| Un écran met du temps à charger | Ne pas cliquer partout. « Le temps que ça charge, laissez-moi vous dire ce que vous allez voir. » |
| Une donnée paraît fausse | Ne jamais improviser un chiffre. « Je vérifie ce point et je vous reviens dessus. » |
| L'application se ferme | Rouvrir calmement. « C'est la machine de démonstration ; en établissement, l'application tourne sur Windows. » |
| Question sur le prix | Ne pas s'engager. « Le modèle économique se cale avec vos services ; il dépend du périmètre national retenu. » |
| Question qu'on ne sait pas trancher | « Bonne question. Je préfère vous donner une réponse exacte : je vous la fais parvenir. » |

---

## 5. Ce qui n'est pas montré (à savoir, au cas où)

- **Fiche élève détaillée** : écran non terminé — rester au niveau des listes.
- **BEP / BAC technique / CAP** : les sessions existent, mais le réseau de démo est peuplé au collège → on démontre sur le **BET**, qui est bien un diplôme de l'enseignement technique.
- **Rubriques Abonnement / Tickets / Modules / Profils d'accès** : visibles dans le menu, à ne pas ouvrir (posture commerciale, hors sujet devant un ministère).
