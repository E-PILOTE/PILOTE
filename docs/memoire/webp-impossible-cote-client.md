---
name: webp-impossible-cote-client
description: "⚠️ Pas d'encodeur WebP en Dart pur (image 4.8.0) — la conversion WebP doit se faire à la LIVRAISON, pas à l'upload ; le vrai gain est le redimensionnement"
metadata: 
  node_type: memory
  type: reference
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-01T17:25:43.108Z
---

**Le paquet `image` 4.8.0 ne sait PAS encoder le WebP.** Encodeurs réellement
exposés : `encodeJpg`, `encodePng`, `encodeTga`, `encodeGif`, `encodeTiff`,
`encodeBmp`, `encodeCur`, `encodeIco`, `encodePvr`. Le WebP est **décodable
seulement** (les sources `formats/webp/*` sont commentées à l'export).

**Why:** le user a proposé (2026-08-01) de convertir toutes les images en WebP à
l'upload. Les plugins natifs qui savent le faire (`flutter_image_compress`)
couvrent Android/iOS, **pas le desktop Windows** — or les cibles réelles sont
Windows 10/11 + macOS, cf. [[plateformes-cibles-windows-mac]]. Un pipeline WebP
client casserait donc là où l'application tourne vraiment.

**Ordre de grandeur qui tranche le débat :** un logo de 3 Mo redimensionné à
512 px tombe à ~30 Ko — facteur 100. Le WebP ferait passer ces 30 Ko à ~22 Ko.
**Le redimensionnement capte 99,7 % du gain ; le format en capte 0,3 %.**

**How to apply:**
- Compresser à l'upload avec `lib/core/utils/media_compression.dart` :
  `compressLogo` (512 px), `compressAvatar` (256 px), `compressImage` /
  `compressForUpload` (1600 px, laisse passer les PDF). Voir
  [[communication-media-compression]].
- ⚠️ Un logo **détouré** doit rester en PNG : en JPEG il gagne un fond noir et
  chaque marqueur de la carte nationale devient un carré.
- Utiliser `mimeForImageExtension()` — ne jamais composer `'image/$ext'` à la
  main (`image/jpg` n'est pas un type MIME valide, `.svg` doit donner
  `image/svg+xml`).
- Si le WebP est vraiment voulu : le faire à la **livraison**, via les
  transformations d'image de Supabase Storage (négociation de contenu côté CDN)
  ou une Edge Function — jamais dans le client Flutter. À vérifier : cette
  fonctionnalité dépend du plan Storage.
