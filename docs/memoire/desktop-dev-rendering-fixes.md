---
name: desktop-dev-rendering-fixes
description: "Correctifs init main.dart pour le rendu sur Linux/Windows desktop (avatars, PDF, vidéo) — sinon repli silencieux"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d4bb948-3b74-4035-ad23-3f3b70cbe1b4
---

Trois pièges de rendu spécifiques au **desktop Linux/Windows** (cible réelle = mobile, mais le dev se fait sur Linux). Tous corrigés dans `main.dart` (2026-06-17) :

1. **`cached_network_image` cassé sur desktop** → tous les avatars/logos tombaient sur leur repli (initiales) malgré des `avatar_url` valides (HTTP 200). Cause : `flutter_cache_manager` utilise `sqflite`, qui n'a **aucune implémentation native** sur Linux/Windows → pas de `databaseFactory`. **Fix** : dépendance `sqflite_common_ffi` + dans `main()` :
   ```dart
   if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
     sqfliteFfiInit();
     databaseFactory = databaseFactoryFfi;
   }
   ```
   (C'était la cause du bug « photos de profil page Administrateurs ».)

2. **pdfrx** : `PdfDocument.openUri()` en direct (aperçu 1re page PDF rasterisé+caché dans le feed) échoue silencieusement si l'init n'a pas tourné. Seuls les **widgets** pdfrx auto-initialisent. **Fix** : `await pdfrxFlutterInitialize();` dans `main()`. Rendu via `page.render(fullWidth)` → BGRA → `ui.decodeImageFromPixels(bgra8888)` → cache statique `Map<cacheKey, ui.Image>` (évite re-render/scintillement).

3. **Vidéo autoplay (media_kit/libmpv)** plante sur Linux desktop (`EGL display invalid → S/W rendering → Callback invoked after deleted → Lost connection`) quand plusieurs lecteurs se créent/détruisent au scroll. **Fix** : `feedAutoplaySupported = !kIsWeb && (Platform.isAndroid || Platform.isIOS)` dans `feed_video_player.dart` → autoplay réservé mobile ; sur desktop vignette tap-pour-lire (un seul lecteur). Voir [[gui-testing-linux]].

⚠️ Une nouvelle dépendance NATIVE (sqflite_common_ffi, media_kit) impose un **rebuild complet** (`flutter run`), pas un hot restart.
