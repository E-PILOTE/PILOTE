---
name: upload-outbox-fichiers
description: "PowerSync met en file les écritures SQL mais PAS les fichiers — file d'attente `upload_outbox` pour les pièces jointes hors-ligne"
metadata: 
  node_type: memory
  type: project
  originSessionId: ffc12413-1442-4bf8-8470-d36a30e6cfe1
---

**PowerSync met en file les écritures SQL, mais pas les fichiers.** Supabase Storage exige le réseau : avant ce module, joindre une photo hors-ligne faisait échouer l'envoi **ENTIER** du message (le texte, lui, partait très bien).

**Solution (`lib/services/powersync/upload_outbox.dart`, table local-only `upload_outbox`) :**
- le chemin Storage est calculé **en local** (`buildStoragePath` — UUID, aucun réseau) ;
- les octets vont sur le **disque** (jamais de blob en SQLite), la ligne va dans `upload_outbox` ;
- le message référence tout de suite ce chemin → il part normalement via PowerSync ;
- au retour du réseau (`db.statusStream.connected`), `flushUploadOutbox()` téléverse à ce chemin **exact** → l'URL se re-signe seule depuis `path` (le modèle `MessageAttachment` porte déjà `path` + `bucket` ; `url` n'est qu'un cache signé).

**Règle critique (`isTransportFailure`)** : seul un échec de **transport** est mis en file. Un **REFUS** serveur (RLS, quota, MIME → `StorageException`) ne l'est jamais — il se reproduirait à l'identique et la file ne se viderait plus.

`SignedNetworkImage` affiche le fichier local tant qu'il est en attente → l'expéditeur voit sa photo immédiatement. Bandeau `PendingUploadsBanner` dans le shell staff. `purgeUploadOutboxFiles()` nettoie le disque à la purge multi-tenant (`powersync_clear` vide la table mais pas les octets).

**WebP écarté** : le paquet `image` sait le LIRE mais pas l'encoder ; les encodeurs natifs (`flutter_image_compress`) ne couvrent pas le desktop Linux. Pipeline universel = redimensionnement + PNG (si transparence) ou JPEG. Le gain vient du redimensionnement.

Voir aussi [[offline-device-enrollment]], [[sync-failure-journal]], [[communication-media-compression]].
