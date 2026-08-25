---
name: desktop-packaging-deb
description: "Empaquetage .deb desktop Linux (packaging/build-deb.sh) + piège crash HiDPI GDK_SCALE + icône depuis logo.svg via Chrome headless"
metadata:
  node_type: memory
  type: project
  originSessionId: ffc12413-1442-4bf8-8470-d36a30e6cfe1
---

**Empaquetage desktop Linux d'E-PILOTE en `.deb`** (2026-07-15, PR #16).

**Scripts versionnés :**
- `packaging/build-deb.sh` — reproductible : `flutter build linux --release` → paquet Debian. App autonome dans `/opt/epilote`, lanceur `/usr/bin/epilote`, `.desktop` (`Exec=/usr/bin/epilote`, `Categories=Education;`, `StartupWMClass=cg.epilote.epilote`), icônes hicolor copiées depuis `packaging/icons/`. Dépendances runtime calculées par **`dpkg-shlibdeps`** (PAS de liste manuelle) → noms `t64` sur Ubuntu 24.04+ (libgtk-3-0t64…). Build root:root. `SKIP_FLUTTER_BUILD=1` réutilise un bundle. Sortie `dist/` (gitignoré).
- `packaging/render-icons.sh` — régénère les icônes depuis `epilote/assets/icons/logo.svg`. Icônes **pré-rendues + versionnées** dans `packaging/icons/` (le build les copie, aucun toolchain SVG requis à l'hôte de build).
- `packaging/INSTALL.md` — guide (poste, parc, dépôt APT, HiDPI).

**🐛 PIÈGE CRASH HiDPI (résolu) :** sur écran HiDPI (scaling ×2) + pilote GL **Nouveau/Mesa** (GPU NVE4 de ce poste), l'app RELEASE plantait au démarrage : `WARNING: Timed out waiting for OpenGL frame of size 2560x1368 (have 1280x720)` → **segfault**. Cause = GDK applique un facteur d'échelle >1, l'embedder Flutter Linux attend une frame GL à la taille scalée jamais fournie. **Fix = lanceur force `GDK_SCALE=1`** (`exec env GDK_SCALE=1 /opt/epilote/epilote "$@"`) — GL matériel conservé, démarrage fiable (vérifié : sans → segfault 139 ; avec → tourne, code 124). `flutter run` (debug) n'exhibait pas le crash. Recoupe la note `GDK_SCALE=1` déjà vue en [[enseignement-emploi-du-temps]].

**🐛 « L'app se coupe brutalement » = PILOTE GPU nouveau, PAS l'app (diagnostiqué 2026-07-17, non corrigé — VOLONTAIREMENT).** Ce poste = GeForce GTX 675MX Mac Edition (Kepler GK104M) sous pilote libre **nouveau**. Le noyau (`sudo dmesg -T | grep nouveau`) nomme la cause sans ambiguïté :
```
nouveau: fifo: fault [READ] ... reason 02 [PTE] on channel 4 [epilote]
nouveau: gr: TRAP ch 4 ...  ->  errored - disabling channel
```
→ le noyau tue le canal GPU, le contexte GL meurt, le **thread raster** de Flutter part en SIGSEGV dans `libgallium`. **Preuves que ce n'est pas le code** : (1) **Chrome plante avec la même signature** sur cette machine ; (2) les coredumps remontent au **20 juin**, un mois avant les thèmes ; (3) rien de Dart dans la pile. Fréquence ~2/jour.

**⚠️ Le rendu logiciel N'EST PAS la solution — piège vérifié :** `LIBGL_ALWAYS_SOFTWARE=1` (llvmpipe) supprime bien la faute GPU, mais **ressuscite le crash de resize** documenté plus bas : maximiser→restaurer tue l'app (segfault `memmove` dans `libgallium`, thread principal, via GTK size-allocate ; aucune trace noyau). **Testé côte à côte : GL matériel survit au max/restore, llvmpipe non.** On échange donc un plantage contre un autre → **inutile**. Un lanceur à bascule automatique (détection `nouveau` via `/sys/class/drm/card*/device/driver`) a été livré puis **reverté** (`18c96a4` → `b4cc606`).

**Pas de remède propre :** `ubuntu-drivers devices` ne propose **aucun** pilote pour ce GPU (Kepler EOL : dernier support = nvidia-470, absent du dépôt — les branches commencent à 550 — et incompilable sur noyau 6.14). Restent 3 options, toutes mauvaises : nouveau (crash en usage) / llvmpipe (crash au resize) / changer de matériel.

**➡️ Décision : ne rien faire.** Les écoles sont sous **Windows/Mac** ([[plateformes-cibles-windows-mac]]) — ce bug ne touchera aucune école. C'est une nuisance de poste de dev. Si ça replante : ce n'est pas une régression du code, ne pas partir en chasse. Vérifier d'abord `dmesg | grep nouveau`.

**🎨 Icône = vrai logo `assets/icons/logo.svg`** (toque dorée + étoile, anneau vert, « E-PILOTE / CONGO », barre tricolore, dégradé navy). Le SVG a du **TEXTE VIVANT en Arial Black/Impact** (polices absentes sous Linux) → ImageMagick le rend MAL (texte clippé hors du cercle). **rsvg-convert absent** (verrou apt `aptk`/aptdaemon bloquait l'install). Solution qui a marché : **Google Chrome headless** (`--headless --screenshot`, wrapper HTML `<img width=1024>`, fond transparent `--default-background-color=00000000`) → rendu fidèle, puis downscale Lanczos. `render-icons.sh` privilégie rsvg-convert → Chrome → ImageMagick.

**Démarrage FENÊTRÉ (pas plein écran)** : `linux/runner/my_application.cc` — retiré `gtk_window_maximize()` (démarrage plein écran jugé peu pro) → `gtk_window_set_default_size(1280,800)` + `GTK_WIN_POS_CENTER`. L'ancien maximize contournait un crash de resize sur GL logiciel, désormais écarté par le GL matériel garanti (GDK_SCALE=1). Commit `32f9c96`.

**🐛 Flash « Aucun module » au dashboard école (résolu, `32f9c96`)** : PowerSync `db.watch()` émet une liste VIDE AVANT la 1ʳᵉ synchro → Riverpod la voit comme valeur résolue (hasValue=true, isLoading=false), donc le squelette `_DashboardSkeleton` (ShimmerPanel/SkeletonBox, DÉJÀ existant) se retirait trop tôt et « Aucun module » + KPI à zéro clignotaient. Fix dans `user_dashboard_screen.dart` : `awaitingFirstSync = !hasModules && !everSynced && !modulesError` où `everSynced = lastSyncedAtProvider != null` (persisté) → shimmer tant que 1ʳᵉ synchro pas aboutie ; relancements offline instantanés ; erreur → `_ModulesErrorCard`. Pattern PowerSync général : ne jamais conclure « vide » sur la première émission d'un watch avant `lastSyncedAt`.

**Vitrine — animations + repos (commits `dbc663c`→`96f41d5`) :** badge = anneau rotatif (CustomPaint sweep bleu→vert Congo, 6 s/tour) ; bouton = halo fluorescent pulsé. **Repos profond** : `VitrineShell` stateful fige les animations après 2 min sans souris/clavier (flag `animate` passé au badge/bouton via `didUpdateWidget` start/stop du controller), reprend au moindre geste → épargne le GPU d'un poste allumé en continu. `_animate = _awake && !disableAnimations` → **reduced-motion (WCAG 2.3.3) respecté**. Curseur main sur cliquables du parcours verrou (MouseRegion + InkWell.mouseCursor) ; nav cœur (nav_tile/sidebar) gérait déjà le curseur → PAS de balayage aveugle des 74 GestureDetector (bcp = glisser/fermer).

**🔒 Auto-lock poste partagé (`058434f`+`96f41d5`) :** `_InactivityAutoLock` (dans `agent_lock_gate.dart`) re-verrouille après inactivité → efface juste `selectedAgentIdProvider` (vitrine revient, PIN requis). **Verrouiller ≠ Déconnecter** : aucune déconnexion Supabase, aucune purge → travail hors-ligne intact (cf [[offline-device-enrollment]]). Délai RÉGLABLE `autoLockMinutesProvider` (SharedPreferences appareil, choix 2/5/10/Jamais, défaut 5), UI `AutoLockTile` (Paramètres › Sécurité, poste partagé only). Pur `shouldArmAutoLock(mode, hasActiveAgent, minutes)` testé. Désarmé en personnel / vitrine affichée / minutes=0.

**Versioning `.deb` :** bump `pubspec` (3.0.0→3.0.1) à chaque release → `apt install ./epilote_<v>.deb` fait une vraie MÀJ sans `--reinstall` (vérifié 3.0.1 sur 3.0.0). `build-deb.sh` lit la version de pubspec.

**Prod validée sur ce poste** : `sudo apt install ./dist/epilote_3.0.0_amd64.deb` OK, 0 dépendance manquante, `.desktop` valide (0 hint), lancement via menu/`epilote` sans crash. Désinstall `sudo apt remove epilote`. Coexiste avec le `flutter run` de dev. cf [[system-access]] (sudo `‹secret — gestionnaire de mots de passe›`).