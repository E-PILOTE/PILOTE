# E-PILOTE CONGO — Installation Desktop Linux (.deb)

Application de bureau pour Debian / Ubuntu (et dérivés). Paquet natif :
intégration au menu, icône, gestion automatique des dépendances, mise à jour
et désinstallation propres via `apt`/`dpkg`.

> Construit et testé pour **Ubuntu 24.04 LTS et ultérieur** (glibc `t64`).
> Pour Ubuntu 22.04, reconstruire le paquet sur cette génération
> (`./packaging/build-deb.sh`) — les dépendances s'ajustent automatiquement.

---

## 1. Installation (poste utilisateur)

```bash
sudo apt install ./epilote_3.0.0_amd64.deb
```

`apt` télécharge et installe automatiquement les bibliothèques requises
(GTK 3, libsecret, mpv, GStreamer…). **Ne pas** utiliser `dpkg -i` seul : il
n'installe pas les dépendances.

Alternative hors-ligne (dépendances déjà présentes) :

```bash
sudo dpkg -i epilote_3.0.0_amd64.deb
sudo apt-get install -f      # complète les dépendances manquantes si besoin
```

## 2. Lancement

- Menu des applications → **E-PILOTE CONGO**, ou
- Terminal : `epilote`

## 3. Mise à jour

Installer le nouveau `.deb` par-dessus (même commande) — `apt` remplace la
version en place et conserve la configuration utilisateur.

## 4. Désinstallation

```bash
sudo apt remove epilote        # retire l'application
sudo apt purge epilote         # + fichiers résiduels éventuels
```

---

## Déploiement en parc (plusieurs postes)

**Dépôt APT interne (recommandé à l'échelle nationale)** — publier le `.deb`
dans un dépôt (ex. `aptly` ou `reprepro`) ; les postes reçoivent alors les
mises à jour par `apt upgrade`, comme n'importe quel logiciel système.

**Déploiement direct** (petit parc) :

```bash
# copier le .deb puis, sur chaque poste :
sudo apt install ./epilote_3.0.0_amd64.deb
```

**Installation silencieuse** (scripts / MDM) :

```bash
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ./epilote_3.0.0_amd64.deb
```

---

## Ce que le paquet installe

| Chemin | Rôle |
|---|---|
| `/opt/epilote/` | Application autonome (binaire + bibliothèques Flutter + données) |
| `/usr/bin/epilote` | Lanceur en ligne de commande (dans le `PATH`) |
| `/usr/share/applications/cg.epilote.epilote.desktop` | Entrée du menu |
| `/usr/share/icons/hicolor/*/apps/cg.epilote.epilote.png` | Icônes (16→512 px) |

Aucun service en arrière-plan, aucun démon : l'application est offline-first et
se synchronise (PowerSync) quand le réseau est disponible.

---

## Reconstruire le paquet (mainteneur)

```bash
# Prérequis de build
sudo apt-get install -y dpkg-dev imagemagick libsecret-1-dev

# Depuis la racine du dépôt
./packaging/build-deb.sh
# → dist/epilote_<version>_amd64.deb
```

La version est lue depuis `epilote/pubspec.yaml`. Les dépendances runtime sont
calculées automatiquement par `dpkg-shlibdeps` (pas de liste à maintenir à la
main).
