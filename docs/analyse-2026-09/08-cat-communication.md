# COMMUNICATION — analyse

**Slug catégorie** : `communication` · **Modules** : 3 catalogués + 1 non catalogué
**Code** : `features/communication/` — 57 fichiers, 22 237 lignes, 18 écrans
**Date** : 2026-09-09 · analyse conduite directement (sans agent)

> **Périmètre déclaré** : 22 237 lignes ne se lisent pas intégralement. J'ai
> balayé mécaniquement les 57 fichiers (taille, `catch`, `valueOrNull`,
> marqueurs, accès données, sorties) et lu en profondeur les points que le
> socle et la mémoire projet désignent. **Zone non couverte** : le détail du
> rendu des fils de discussion (`messagerie_staff_thread.dart`, 1 145 l.) et du
> lecteur média (`media_viewer.dart`, 532 l.).

## A. Vue d'ensemble de la catégorie

Quatre surfaces — Annonces, Messagerie, Événements, Notifications — servies par
**un seul code** pour les trois espaces (école, réseau, fondateur), le
périmètre étant déduit du rôle.

**La question centrale de cette catégorie était : le module est-il vraiment
scope-aware, ou y a-t-il des copies par espace ?** Réponse mesurée : **il l'est
vraiment.** Sur l'ensemble de `super_admin/` et `admin_groupe/`, **un seul**
fichier nomme un concept de communication sans importer
`features/communication/` — et c'est `admin_groupe/screens/reglages/reglages_notifications.dart`,
un onglet de *préférences*, pas une copie de la messagerie. C'est une réussite
d'architecture qu'il faut dire : 22 237 lignes non dupliquées trois fois.

**Le mélange online/offline est correct** : 92 appels `supabase.from(` (pour
les espaces fondateur et réseau) **et** 48 lectures PowerSync (pour l'école).
C'est la seule catégorie où les deux cohabitent, et c'est la définition même du
scope-aware.

**Ce qui ne va pas** : c'est la deuxième catégorie la plus lourde en dette de
structure (11 fichiers > 500 lignes), la deuxième en marqueurs d'inachèvement
(19), et elle porte **20 `catch (_) {}`**.

---

## B. Fiche par module

### Annonces — `annonces` *(natif)*

| | |
|---|---|
| Routes | `/user/annonces` · `/admin/annonces` · `/super/messagerie/annonces` |
| Écrans | `announcements_feed.dart` (885 l.) + `_social` (696 l.) + `_form` (612 l.) + `_cards` (582 l.) + `feed_right_rail.dart` (756 l.) + `feed_media.dart` (629 l.) |
| Tables | `announcements` (⚠️ `is_published`, **jamais** `status`) |
| Sortie | aucune |

**Ce qu'il fait** — un fil d'actualité complet : publication, médias, réactions
et interactions (`announcement_interactions_provider.dart`, 525 l.), stories
(`stories_provider.dart`).

**Ce qui manque / inquiète**
- **6 `catch (_) {}`** rien que sur ce module (`announcements_provider:158,176,188`,
  `announcement_interactions_provider:136,291`, `stories_provider:130,266`).
  Sur un fil, un `catch` qui avale fait qu'une publication ratée **paraît
  publiée**.
- **Aucune sortie.** Discutable pour un fil social — mais une annonce
  officielle d'établissement (fermeture, convocation générale) devrait pouvoir
  s'afficher au mur, donc s'imprimer.
- **3 des 4 plus gros fichiers de la catégorie** sont ici.

---

### Messagerie — `messagerie` *(natif)*

| | |
|---|---|
| Routes | `/user/messagerie` · `/admin/messagerie` · `/super/messagerie` |
| Écrans | `messagerie_staff.dart` (540 l.) + `_thread` (**1 145 l.**) + `_bubble` (519 l.) · `group_chat_provider.dart` (536 l.) · `messages_provider.dart` (**1 003 l.**) |
| Sortie | aucune |

**Ce qu'il fait** — fils individuels et de groupe, accusés de lecture
(`last_read_at`, ✓✓), présence, pièces jointes, audio, vidéo.

⛔ **C'est par la messagerie que la tutelle écrit à son réseau** — la circulaire
a été supprimée au profit de ce canal (migration 0174). Ce module porte donc un
**acte administratif**, pas seulement de la conversation.

**Ce qui manque / inquiète**
- ⚠️ **Conséquence directe du point ci-dessus** : une instruction de tutelle
  transmise par messagerie **ne peut pas être imprimée ni archivée**. Une
  circulaire se classe ; un fil de discussion, non. C'est le manque le plus
  structurant de la catégorie.
- `messagerie_staff_thread.dart` à **1 145 lignes** et `messages_provider.dart`
  à **1 003** : les deux plus gros fichiers, et ceux qu'on touche le plus
  souvent.
- ⚠️ **La vidéo n'est PAS compressée sous Windows** (fiche
  `communication-media-compression`) et `image` n'encode pas le WebP côté
  client. Sur une école congolaise à faible bande passante, une vidéo envoyée
  telle quelle est un envoi qui n'aboutit pas.

---

### Événements — `evenements` *(natif)*

| | |
|---|---|
| Routes | `/user/evenements` · `/admin/evenements` |
| Provider | `events_provider.dart` |
| Sortie | aucune |

Le plus discret des quatre. **1 `catch (_) {}`** (`events_provider:109`).
**Aucun calendrier imprimable** — or un calendrier d'événements de trimestre est
typiquement ce qu'une école affiche et distribue.

⚠️ Ce module n'a **pas de route dans l'espace fondateur** (`/super/*`), au
contraire des deux autres. Asymétrie à qualifier : oubli ou décision ?

---

### Notifications — *(aucun slug au catalogue)* ⚠️

| | |
|---|---|
| Routes | `/user/notifications` · `/admin/notifications` · `/super/notifications` |
| Provider | `notifications_provider.dart` |

⛔ **Trois pages dans les trois espaces, et aucune ligne dans la table
`modules`.** Les trois autres natifs (`annonces`, `messagerie`, `evenements`) y
figurent bien, avec `is_active = false` — la marque explicite d'un natif non
vendable. Notifications n'y est pas du tout.

**Verdict** : ce n'est pas un simple oubli cosmétique. La ligne `modules`, même
inactive, est ce qui déclare l'existence du module au catalogue, aux profils
d'accès et aux rapports d'usage. Sans elle, Notifications est invisible de la
gouvernance : on ne peut ni le décrire, ni en régler l'accès, ni en mesurer
l'usage. **À créer, avec `is_active = false` comme ses trois voisins.**

---

## C. Relations entre les modules DE cette catégorie

```
   annonces ──┐
   messagerie ─┼──► le MÊME code, trois espaces (école / réseau / fondateur)
   evenements ─┤     périmètre déduit du RÔLE — pas de copie par espace ✅
   notifications┘     … mais Notifications n'existe pas au catalogue ⚠️

   tutelle ──(0174 : la circulaire supprimée)──► messagerie   ← acte administratif
                                                    │
                                                    └─╳► aucune archive imprimable
```

## D. Synthèse de la catégorie

### D.1 Fonctionnalités manquantes

| # | Module | Manque | Preuve | Impact | Effort |
|---|---|---|---|---|---|
| 1 | `messagerie` | Impression / archivage d'une instruction de tutelle | 0 sortie dans `features/communication/` ; la circulaire a été supprimée au profit de ce canal (0174) | Un acte administratif d'État qui ne se classe pas | **M** |
| 2 | `notifications` | **Ligne au catalogue `modules`** | base live : 3 lignes COMMUNICATION, pas de `notifications` | Module invisible de la gouvernance et des profils d'accès | **XS** (une ligne SQL) |
| 3 | `annonces` | Sortie d'une annonce officielle | 0 sortie | L'affichage mural se retape | **S** |
| 4 | `evenements` | Calendrier de trimestre imprimable | 0 sortie | Ce qu'une école distribue aux familles | **S** |
| 5 | `evenements` | Absence de route `/super/evenements` | `00-CATALOGUE.md` §9 | Asymétrie non expliquée entre les trois natifs | **XS** (à qualifier) |
| 6 | `messagerie` | Compression vidéo sous Windows | fiche `communication-media-compression` | Envoi qui n'aboutit pas en faible bande passante | **M** |

### D.2 Doublons et redondances

| # | Constat | Verdict |
|---|---|---|
| 1 | **Aucune copie par espace.** Un seul fichier hors `communication/` nomme ces concepts sans l'importer, et c'est un onglet de préférences | ✅ **Le scope-aware est réel.** À dire comme une réussite |
| 2 | `announcements_feed.dart` (885 l.) et `announcements_feed_social.dart` (696 l.) — deux rendus du même fil | À qualifier : deux présentations légitimes, ou une bifurcation non résorbée ? **Non tranché** — hors de ma zone de lecture profonde |

### D.3 Données partagées HORS catégorie

| Donnée | Producteur | Consommateurs | Contrat | Risque |
|---|---|---|---|---|
| `announcements` | `annonces` | les 3 espaces | `is_published`, **jamais** `status` | Se tromper de colonne = feed vide |
| messages de tutelle | `tutelle` → `messagerie` | groupes supervisés (0174) | Une instruction est un message | Pas d'archive |
| `conversations`, `last_read_at` | `messagerie` | cloche de notification | Realtime requis | ⚠️ Une table écoutée DOIT être dans la publication `supabase_realtime` — c'était la cause racine des pannes de feed |

### D.4 Conformité export / aperçu / impression

| Module | Sortie | Verdict |
|---|---|---|
| les 4 | **aucune** | 0 producteur PDF, 0 aperçu dans 22 237 lignes |

Comme Vie scolaire : rien à corriger dans l'existant, tout à ajouter. La
différence est qu'ici **une seule** sortie compte vraiment — l'archivage d'une
instruction de tutelle (D.1 #1).

### D.5 Cases mortes et zéros menteurs

**20 `catch (_) {}`** dans la catégorie. Répartition :

| Fichier | Occurrences | Nature probable |
|---|---|---|
| `widgets/audio_recorder_button.dart` | 4 (l. 107, 113, 126, 143) | cycle de vie d'un enregistreur — **probablement légitime** |
| `providers/announcements_provider.dart` | 3 (l. 158, 176, 188) | ⚠️ à qualifier : une publication ratée ne doit pas paraître publiée |
| `providers/announcement_interactions_provider.dart` | 2 (l. 136, 291) | ⚠️ réactions perdues en silence |
| `providers/stories_provider.dart` | 2 (l. 130, 266) | ⚠️ |
| `providers/messages_provider.dart` | 1 (l. 297) | ⚠️ **le plus sensible** — un message avalé |
| 6 autres fichiers | 1 chacun | à qualifier |

**Non corrigés** : chacun demande de lire son contexte, et l'audio en particulier
a de bonnes raisons d'avaler. C'est le gisement à traiter en une passe dédiée,
pas au fil d'une analyse.

### D.6 Dette de structure

**11 fichiers > 500 lignes**, dont les deux plus gros de la catégorie :

| Fichier | Lignes | Couture |
|---|---|---|
| `screens/messagerie_staff_thread.dart` | **1 145** | le fil, la barre de saisie, les pièces jointes, l'audio |
| `providers/messages_provider.dart` | **1 003** | lectures / écritures / présence |
| `screens/announcements_feed.dart` | **885** | déjà partiellement découpé (`_social`, `_form`, `_cards`) — finir |
| `widgets/feed_right_rail.dart` | 756 | colonne de droite : sections indépendantes |
| `screens/announcements_feed_social.dart` | 696 | |
| `screens/group_settings_dialog.dart` | 694 | |
| `providers/announcements_provider.dart` | 630 | |
| `widgets/feed_media.dart` | 629 | |
| `screens/announcements_feed_form.dart` | 612 | |
| `widgets/staff_feed_ui.dart` | 589 | |
| `screens/announcements_feed_cards.dart` | 582 | |
| `screens/support_requester_screen.dart` | 545 | |
| `widgets/media_viewer.dart` | 532 | |
| `providers/group_chat_provider.dart` | 536 | |
| `providers/announcement_interactions_provider.dart` | 525 | |
| `screens/messagerie_staff_bubble.dart` | 519 | |

⚠️ Rappel du projet : **découper un fichier rend les sondes aveugles** — les
tests de source doivent suivre dans le même commit.

### D.7 Désalignements catalogue ↔ code

1. ⛔ **Notifications n'a aucune ligne dans `modules`** — cf. D.1 #2.
2. **Les 3 natifs sont `is_active = false`** au catalogue : c'est **voulu**
   (livrés à tous les plans, Gratuit compris, hors levier d'abonnement). Ne
   jamais lire cela comme « modules désactivés ».
3. **`evenements` n'a pas de route `/super/*`** alors que ses deux voisins en
   ont une.
4. **19 marqueurs d'inachèvement** dans la catégorie — le deuxième gisement de
   la plateforme après le réseau.

## E. Les cinq choses à faire en premier

1. **Créer la ligne `notifications` au catalogue** (`is_active = false`, comme
   ses trois voisins). Une ligne SQL. Sans elle, un module servi dans les trois
   espaces reste invisible de la gouvernance.
   *Effort : XS.*

2. **Rendre archivable une instruction de tutelle.** La circulaire a été
   supprimée au profit de la messagerie ; il manque la contrepartie — un
   document que le destinataire peut classer et opposer.
   *Effort : M · Entrée : `features/communication/providers/messages_provider.dart`.*

3. **Passer les 20 `catch (_) {}` en revue**, en commençant par
   `messages_provider:297` et les trois d'`announcements_provider`. Une
   publication ou un message avalé est un défaut de confiance, pas de confort.
   *Effort : M.*

4. **Découper `messagerie_staff_thread.dart` (1 145 l.) et
   `messages_provider.dart` (1 003 l.)** — les deux fichiers les plus touchés
   de la catégorie, tests de source à faire suivre dans le même commit.
   *Effort : M.*

5. **Trancher la compression vidéo sous Windows.** Pour une école à faible
   bande passante, un envoi non compressé est un envoi qui échoue.
   *Effort : M.*
