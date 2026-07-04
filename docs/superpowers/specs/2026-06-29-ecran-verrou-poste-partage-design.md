# Écran-verrou « poste partagé » — design

**Date :** 2026-06-29
**Statut :** validé (décisions déléguées à l'assistant — contexte gouvernemental)
**Périmètre :** espace **personnel scolaire** uniquement. `super_admin` et `admin_groupe` **intouchés**.

---

## 1. Contexte & problème

E-PILOTE équipe des écoles publiques du Congo où **un seul PC** est partagé par tout
le personnel (directeur, secrétaire, comptable, enseignants…), souvent **hors-ligne
des semaines**. L'architecture distingue déjà deux identités :

| Identité | Nature | Frontière |
|---|---|---|
| **Appareil** | 1 session Supabase / PC, provisionnée par la direction. Persiste hors-ligne. | Vraie sécurité serveur (JWT + RLS). `auth.signOut()` la tue → ré-login **en ligne** obligatoire. |
| **Agent actif** | Sélection locale (`selectedAgentIdProvider`, en mémoire) déverrouillée par un **PIN court haché en local** (`agent_pin_<id>`, jamais synchronisé). | Verrou d'**attribution** (« qui est au clavier ») : permissions UI + `created_by`/audit. Offline. |

**Deux défauts du flux actuel :**

1. **Trou d'attribution au lancement.** Au démarrage, `selectedAgentId` est nul →
   `activeAgentIdProvider` retombe **silencieusement sur le compte appareil (direction)**.
   Les premières saisies de la journée sont donc attribuées à la direction tant que
   personne n'a basculé. Inacceptable pour un outil d'État (intégrité de l'audit).

2. **Cérémonial faible.** « Changer d'agent » ouvre une page in-shell (`/user/agents`)
   + un dialogue PIN. Pas à la hauteur d'un poste institutionnel partagé.

## 2. Objectif

Transformer le changement d'agent en un **écran-verrou plein écran**, langage visuel
de la page de login, **sobre et institutionnel**, qui :

- s'impose **au lancement** (personne n'entre sans choisir son profil + PIN) **et** sur
  demande (« Changer d'utilisateur ») → **zéro saisie mal attribuée** ;
- **préserve la session Supabase de l'appareil** (100 % offline-safe ; le PIN reste le
  seul secret offline) ;
- réutilise l'existant sans duplication.

**Non-objectif (YAGNI) :** pas de ré-login Supabase par agent (les agents n'ont pas de
compte individuel ; impossible hors-ligne). Pas de comptes multiples par appareil.

## 3. Décisions arrêtées

- **(a) Mécanisme = overlay au-dessus du routeur** (pas de route `/lock`). Un `Consumer`
  dans `MaterialApp.builder` peint `AgentLockScreen` par-dessus tout quand
  `needsAgentUnlock == true`. Anti-contournement, aucun remaniement de `app_router.dart`.
- **(b) Animation = sobriété maximale.** Logo E-PILOTE (`assets/icons/logo.svg`) en
  filigrane ~5–6 % d'opacité, « respiration » lente (échelle 1.0↔1.04, ~7 s) + voile
  tricolore dérivant lentement + `AnimatedTricolorLine` du login. **Aucun clignotement.**
- **(c) Public du verrou = personnel scolaire** hors `super_admin`, `admin_groupe`,
  `parent`, `eleve` (ces deux derniers ne sont pas des agents d'un poste partagé).
- **PIN oublié** = réinitialisable par la direction (différé hors de ce lot ; libellé
  d'attente affiché).

## 4. Architecture

### 4.1 La porte (`needsAgentUnlock`)

Provider dérivé, vrai si **tous** :
- session appareil active (`authNotifierProvider` a un profil) ;
- rôle ∈ personnel scolaire **et** ∉ {`super_admin`, `admin_groupe`, `parent`, `eleve`} ;
- `selectedAgentIdProvider == null`.

Conséquences : lancement → nul ⇒ verrou ; « Changer d'utilisateur » pose `null` ⇒ verrou ;
PIN correct → pose l'id ⇒ verrou s'efface en fondu.

**Repli anti-blocage :** si la liste d'agents est encore vide (1ʳᵉ synchro non terminée),
`needsAgentUnlock` est **faux** (on n'enferme jamais l'utilisateur dehors) et l'écran, s'il
est affiché sur demande, montre un état « Synchronisation… ».

### 4.2 Montage de l'overlay

`MaterialApp.builder: (context, child) => AgentLockGate(child: child)`.
`AgentLockGate` (Consumer) : si `needsAgentUnlock`, `Stack[ child, AgentLockScreen ]`,
sinon `child`. Ne s'affiche jamais sur Login/Splash (pas de session appareil → condition
déjà fausse).

### 4.3 Composants (découpe ≤ 500 l.)

- `lib/features/auth/screens/agent_lock_screen.dart` — orchestration (étape grille ↔ PIN),
  fondu de sortie, action « Déconnecter le poste ».
- `lib/features/auth/screens/widgets/agent_lock_gate.dart` — le Consumer overlay + provider
  `needsAgentUnlock`.
- `lib/features/auth/screens/widgets/agent_lock_background.dart` — fond animé sobre.
- `lib/features/auth/screens/widgets/agent_grid.dart` — sélection (réutilise
  `switchableAgentsProvider`, recherche).
- `lib/features/auth/screens/widgets/agent_pin_pad.dart` — saisie / création PIN
  (clavier numérique stylé ; logique = `agentPinServiceProvider`).

### 4.4 Réutilisation (zéro duplication)

Réutilisés tels quels : `selectedAgentIdProvider`, `activeAgentIdProvider`,
`switchableAgentsProvider`, `agentPinServiceProvider`, `AgentOption`,
`currentSchoolProvider` (logo + nom école offline), tokens `auth_colors.dart`,
`AnimatedTricolorLine`, `login_bg.jpg`, widgets avatar (extraits en partagé si besoin).

### 4.5 Suppressions / modifications

- **Supprimé :** `lib/features/user/screens/staff_agent_switch_screen.dart` (page in-shell)
  et la route `Routes.userAgents` (+ son entrée dans `app_router.dart`). La logique PIN
  utile est portée par `agent_pin_pad.dart`.
- **Modifié :** menu compte `app_header.dart` — « Changer d'agent » → **« Changer
  d'utilisateur »**, ne navigue plus : `ref.read(selectedAgentIdProvider.notifier).state = null`.
  Sa **visibilité suit le public du verrou** (§3c) : masquée pour parent/élève (et,
  comme aujourd'hui, pour super_admin/admin_groupe), pas seulement `isStaff`.

## 5. Écran (mise en page)

```
Fond : gradient navy login + grille de points + logo E-PILOTE filigrane (respiration)
       + voile tricolore lent.
Haut-centre  : [logo école rond, offline]  Nom de l'école · Ville · Année
Centre (carte « login ») :
   Étape 1 — « Qui utilise ce poste ? » + recherche + grille d'agents (avatars).
   Étape 2 — agent choisi → glissement → pavé PIN (avatar+nom, clavier num., ← retour).
             1ʳᵉ fois pour l'agent → création PIN (saisie + confirmation).
Bas          : ligne tricolore animée ; « Rép. du Congo · MEPSA · METP » ;
               action discrète « Déconnecter le poste » (vrai auth.signOut, fin de journée).
```

## 6. Flux de données

1. Lancement → session restaurée, `selectedAgentId == null` → `needsAgentUnlock` vrai →
   overlay.
2. Agent choisi + PIN OK → `selectedAgentId = id` → `needsAgentUnlock` faux → fondu de
   sortie → app avec l'identité agent (permissions + attribution correctes).
3. « Changer d'utilisateur » → `selectedAgentId = null` → overlay réapparaît.
4. « Déconnecter le poste » → `selectedAgentId = null` + `auth.signOut()` → LoginScreen.

## 7. Cas limites & erreurs

| Cas | Comportement |
|---|---|
| 1ʳᵉ synchro, aucun agent | Pas de verrou dur (repli identité appareil) ; état « Synchronisation… » si écran ouvert. |
| Hors-ligne | OK : PIN local, logo école en cache (fix sqflite Linux déjà en place). |
| PIN incorrect | Erreur inline (logique existante). |
| PIN oublié | Libellé « la direction peut réinitialiser » ; geste direction différé. |
| Pas de `logo_url` école | Repli initiales / monogramme E-PILOTE. |
| super_admin / admin_groupe / parent / élève | Jamais de verrou. |

## 8. Sécurité (cadre gouvernemental)

- Le PIN reste un verrou **d'attribution**, pas une auth cryptographique — clairement la
  frontière serveur demeure la session Supabase + RLS. Le design ne change rien à ce
  modèle ; il **renforce l'intégrité de l'audit** (plus d'écriture anonyme « direction »
  par défaut).
- PIN haché local (sha256 salé par `profileId`), jamais synchronisé — inchangé.
- Overlay non contournable (pas de deep-link qui échappe au verrou).

## 9. Tests

- `needsAgentUnlock` : vrai pour staff sans agent ; faux pour super_admin/admin_groupe ;
  faux si liste d'agents vide (repli) ; faux pour parent/élève.
- PIN : vérification OK/KO ; création (saisie ≠ confirmation → erreur).
- Verrou affiché au lancement (staff) ; effacé après sélection.
- `flutter analyze` 0 issue ; `flutter build linux --debug` OK ; vérif GUI réelle
  (étendu + écran-verrou, mode étendu/icônes du shell sans objet ici).

## 10. Hors-périmètre (suites)

- Geste « réinitialiser le PIN d'un agent » côté direction (écran Personnel/agents).
- Verrouillage automatique après inactivité (option écartée pour ce lot).
