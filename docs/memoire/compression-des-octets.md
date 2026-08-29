---
name: compression-des-octets
description: "🗜️ Compression (2026-08-29) — ⚠️ dans un PDF le coût suit les PIXELS et le FORMAT, jamais le poids du fichier : un PNG de 2 Ko y pèse 95 Ko, un JPEG de 19 Ko y pèse 20 ; garde `tout_octet_televerse_est_compresse_test.dart` ; 3 exceptions écrites"
metadata:
  node_type: memory
  type: project
---

# Compression — la règle et ses trois exceptions (2026-08-29)

Consigne du fondateur : **toujours compresser quand c'est possible.** Une photo
de téléphone pèse 4 à 8 Mo ; l'application l'affiche sur 38 px et l'imprime sur
22 mm. Sans réduction, ces octets montent, redescendent sur chaque poste qui
synchronise, puis occupent le disque à demeure — au Congo, sur des liaisons
facturées au volume.

## Les trois seuils, et pourquoi ils diffèrent

| usage | fonction | seuil | rendu maximal |
|---|---|---|---|
| avatar / photo d'élève | `compressAvatar` | 256 px | pastille 96 px, carte 22 mm |
| logo (interface) | `compressLogo` | 512 px | pastille 96 px, marge rétine |
| pièce de dossier, pièce jointe | `compressForUpload` | 1600 px | plein écran |
| **logo (dans un PDF)** | `compressLogoForPdf` | **256 px** | emplacement 54 pt |

La compression **ne peut pas** vivre dans `enqueueUpload` : elle dépend de ce
qu'on envoie. Le choix est donc chez l'appelant — donc oubliable. D'où le garde
`test/tout_octet_televerse_est_compresse_test.dart`, qui échoue si un nouveau
`uploadBinary` / `enqueueUpload` apparaît sans compression, **en nommant le
fichier**.

## Les trois exceptions (écrites dans le garde, avec leur raison)

1. `upload_outbox.dart` — la file renvoie des octets **déjà** compressés.
2. `messages_provider.dart` — la compression a lieu en amont, dans
   `comm_attachments.dart`, **avant** le contrôle de taille (une photo de 8 Mo
   tombe à ~400 Ko et repasse sous la limite au lieu d'être refusée).
3. `exam_archives_provider.dart` — **pièce opposable**. L'empreinte SHA-256 est
   calculée sur les octets déposés : ré-encoder le scan d'un procès-verbal
   changerait l'empreinte, donc la seule chose qui prouve qu'on regarde bien le
   document déposé ce jour-là.

## ⚠️ LE PIÈGE : dans un PDF, le poids du fichier ne veut rien dire

Un PDF **n'a pas de filtre PNG**. Une image PNG posée dans un document y est
DÉCODÉE en pixels bruts puis recompressée en Flate. Mesuré (dégradé 512 px) :

| source | dans le PDF |
|---|---|
| PNG 512 px, fichier de **2 Ko** | **95 Ko** |
| le même en 128 px | 34 Ko |
| JPEG 512 px, fichier de 19 Ko | **20 Ko** — embarqué tel quel (DCTDecode) |

Le coût suit le **nombre de pixels** et le **format d'arrivée**, jamais le poids
du fichier de départ. Un logo deux fois trop grand coûte quatre fois trop cher,
dans **chaque** document que l'école produit.

Conséquences, toutes contre-intuitives :

- **Un logo opaque part en JPEG même s'il grossit sur le disque.** Ma première
  version gardait un « ne pas grossir » comparant les octets : il annulait
  exactement l'optimisation qu'il protégeait.
- **Un logo détouré reste en PNG** — aplatir sa transparence sur du blanc
  poserait un carré blanc sur le bandeau tricolore de l'en-tête.
- L'emblème (`OfficialPdfKit.loadLogo`) est **mis en cache** comme les polices
  et rastérisé à 256 px, pas 320. Réutiliser une `pw.MemoryImage` d'un document
  à l'autre est sûr : `ImageProvider.resolve` la reconstruit quand le document
  change.
- Les polices, elles, sont déjà **sous-ensemblées** par le greffon
  (`TtfWriter.withChars`) et `pw.Document(compress: true)` est le défaut. Rien à
  faire de ce côté.

## Autres constats de l'audit

- `assets/images/login_bg.jpg` **supprimé** : 68 Ko référencés nulle part — et
  ce n'était pas un JPEG mais un WebP à l'extension mensongère.
- **232 dpi, pas 295** : les 256 px d'un avatar tombent sur les 28 mm de HAUTEUR
  du cadre de la carte. Le 295 supposait 256 px sur la largeur (22 mm), ce qui
  n'arrive jamais sur un portrait. ⚠️ Ne pas relever `kMaxAvatarEdge` pour
  gagner ces dpi : 320 px donnerait 290 dpi et ~50 % d'octets en plus sur chaque
  avatar de mille écoles. Le vrai levier est le cadrage à la prise de vue
  ([[photo-webcam-cadre-identite]]).
- ⚠️ `same()` ne peut jamais passer sur un retour de `compute` : les octets sont
  recopiés d'un isolat à l'autre. Vérifier l'**égalité**, pas l'identité.

Liens : [[photo-webcam-cadre-identite]] · [[carte-scolaire-module]]
