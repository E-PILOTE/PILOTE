# Pilote sur deux écoles — dossier de préparation

> Établi le 2026-09-01, à quatre semaines du déploiement national.
> Sonde d'accompagnement : `database/checks/0172_sante_du_pilote.sql`.

## Pourquoi, et ce que ça sert à trouver

Le logiciel tient : 168 migrations, RLS sur 109 tables sur 109, 1 962 tests,
0 issue d'analyse, l'espace école complet à un écran près. Ce qu'on ignore est
ailleurs.

**Aucun établissement n'a jamais utilisé E-PILOTE.** Une installation déclarée
en tout — la machine de développement. Dix comptes ont ouvert une session, tous
avant le 27 août. Tout ce qu'on sait du produit, on le sait par des tests et
des sondes.

Un pilote ne cherche donc pas des bugs : il cherche **ce qu'aucune sonde ne
trouve** — ce qui bloque une secrétaire le lundi matin, ce qu'un directeur
n'ose pas cliquer, le fichier d'élèves qui n'a pas la forme attendue, la
connexion qui tombe au milieu d'un appel.

## ⚠️ La question à trancher avant tout le reste

**Les deux écoles sont-elles réelles, ou prend-on deux des 37 écoles semées ?**

La base ne contient aujourd'hui que des données de démonstration — 37 écoles
uniformément dotées de 10 agents, 1 chef, 6 enseignants, 1 secrétaire. Un
pilote sur ces écoles-là ne teste que le logiciel ; il ne teste pas la
rencontre avec un établissement.

Un pilote qui vaut la peine suppose : deux établissements réels, leurs vrais
personnels, leurs vrais élèves. Le reste de ce dossier suppose ce choix.

## Choisir les deux — les profils à couvrir

Deux écoles, pas une, et pas cinq. Une seule ne distingue pas « le produit a un
défaut » de « cette école a une particularité ». Cinq consomment un
accompagnement qu'on n'a pas.

Les deux doivent différer sur ce qui compte, et se ressembler sur le reste :

| axe | pourquoi il compte | recommandation |
|---|---|---|
| **tutelle** | MEPSA et METP n'ont pas les mêmes écrans (filières, examens) | une de chaque |
| **connectivité** | le produit est hors-ligne d'abord : Brazzaville ne prouve rien sur la Likouala | une urbaine, une éloignée |
| **secteur** | le privé encaisse, le public non — la Finance ne se teste que dans le privé | au moins une privée |
| taille | une école ingérable masque tout le reste | 150 à 400 élèves |

⚠️ **Ne pas prendre deux écoles du même groupe** : on ne verrait jamais ce qui
casse quand deux tutelles écrivent le même référentiel.

## Avant le jour 1 — ce qui doit exister

La sonde `0172` répond à cette liste, section 5. **Une case à zéro ici explique
la plupart des « ça ne marche pas » qui n'en sont pas.**

| | pourquoi |
|---|---|
| année scolaire **courante** | sans elle, la structure est en lecture seule |
| classes | rien ne s'accroche sans elles |
| élèves importés | voir l'import ci-dessous |
| matières | pas de matière, pas de note |
| **barème de frais** | ⚠️ pas de barème = **aucun encaissement possible** |
| agents créés | le chef crée les siens ; le groupe crée le chef |
| créneaux d'EDT | facultatif au jour 1, nécessaire pour l'appel par cours |

⚠️ **L'import des élèves est le geste qui tue un pilote au jour 1.** Les listes
arrivent en Excel français : séparateur `;`, encodage Windows-1252. Date de
naissance et sexe sont NOT NULL et doivent être rejetés AVANT écriture — sinon
c'est tout le lot qui est perdu. Faire un import à blanc sur une copie du
fichier réel **avant** le jour 1, pas devant l'école.

## Le jour 1 — la première heure

1. Installer depuis le dépôt public de distribution, pas par clé USB anonyme.
   Vérifier l'empreinte SHA-256 (`packaging/windows/INSTALL.md`).
2. ⚠️ **Prévenir de l'avertissement SmartScreen.** L'application n'est pas
   signée : Windows affichera « éditeur inconnu ». Un chef d'établissement qui
   découvre ça seul referme la fenêtre et n'y revient pas.
3. Première connexion du chef, **en ligne** — c'est le seul moment où le réseau
   est indispensable.
4. Laisser la synchro initiale se faire en entier avant de fermer.
5. Débrancher le réseau, rouvrir, vérifier que tout est là. **C'est la
   démonstration qui emporte l'adhésion**, et elle prend deux minutes.

## Ce qu'on observe, tous les matins

`psql "$DATABASE_URL" -f database/checks/0172_sante_du_pilote.sql`

| section | la question |
|---|---|
| 1 | le poste est-il vivant, sur quelle version, **vu quand** |
| 2 | qui s'est connecté — et qui ne s'est **jamais** connecté |
| 3 | l'école produit-elle quelque chose, jour par jour |
| 4 | quels gestes le journal d'audit a retenus |
| 5 | ce qui manque encore pour que l'usage soit possible |

### ⚠️ L'angle mort qu'il faut connaître

**`sync_failures` est une table locale.** Si le poste d'une école se bloque —
désaccord de schéma, file d'envoi arrêtée — le bandeau s'affiche à l'école et
**le serveur n'en sait rien**.

Le seul signal côté serveur est le **silence** : `last_seen_at` qui cesse
d'avancer. C'est pourquoi la colonne « vu le » de la section 1 est la plus
importante du tableau, avant même le nombre de lignes créées.

> **Trois jours de silence sur une école qui travaillait = on appelle.**
> Un poste muet ne se diagnostique pas à distance, il se téléphone.

## Ce qui compte comme réussite

Pas « aucun bug » — il y en aura. Trois choses :

1. **L'école continue** au bout de deux semaines sans qu'on l'ait relancée.
2. **Quelqu'un d'autre que le chef** s'en sert — un enseignant, une secrétaire.
   Un produit que seul le directeur ouvre n'a pas franchi la porte.
3. **Un travail hors ligne remonte** après une coupure. C'est la promesse
   centrale ; si elle tient une fois pour de vrai, elle tient.

## Ce qui déclenche l'arrêt

- Une perte de données **quelle qu'elle soit**, même récupérée.
- Un poste bloqué plus de 48 h sans cause comprise.
- Un refus d'usage : l'école demande à revenir au papier.

Dans les trois cas : arrêter, comprendre, ne pas élargir. Le pilote existe pour
que ça arrive à deux écoles plutôt qu'à mille.

## Ce qu'il faut dire aux deux écoles, d'avance

Ne pas laisser découvrir ces limites au pire moment :

- **« Éditeur inconnu » au premier lancement** — normal, non signé à ce stade.
- **Pas d'espace parent ni élève** : c'est le seul écran non construit.
- **L'accusé de lecture d'une circulaire exige le réseau** — la circulaire, elle,
  se lit hors ligne. Le bouton le dit.
- **Le journal d'audit se consulte en ligne** ; hors ligne il l'annonce au lieu
  de paraître vide.
- **Sans barème de frais saisi, aucun encaissement** n'est possible. Ce n'est
  pas une panne, c'est une règle.

## Ce qui reste à faire côté plateforme, en parallèle

| | échéance |
|---|---|
| **certificat de signature de code** | délai d'obtention incompressible — à lancer maintenant |
| CI GitHub | débloquée en dépôt public ; la repasser en privé la rebloque |
| décisions ouvertes (audit hors ligne, audit des créations, `0146`) | sans effet sur le pilote |
