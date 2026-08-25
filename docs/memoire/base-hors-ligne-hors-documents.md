---
name: base-hors-ligne-hors-documents
description: "La base PowerSync ne doit JAMAIS vivre dans Documents — sous Windows c'est OneDrive qui la corrompt et l'agent qui la supprime"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-03T08:24:23.603Z
---

# La base hors ligne quitte « Documents » (2026-08-03)

`initPowerSync()` ouvrait `epilote_v3.db` dans
`getApplicationDocumentsDirectory()`. Sous Linux, en développement, sans
conséquence. **Sous Windows, deux façons de perdre du travail :**

1. L'agent **voit** un fichier au nom technique au milieu de ses documents
   personnels. Tôt ou tard il le supprime — avec tout ce que la synchronisation
   n'avait pas encore remonté.
2. « Documents » est très souvent **redirigé vers OneDrive**. Une SQLite dans un
   dossier synchronisé est une cause classique de corruption : le client
   verrouille et téléverse pendant que la base écrit son journal, et le fichier
   principal se désynchronise de son `-wal`.

**Désormais** : `lib/services/powersync/local_storage_dir.dart` — dossier de
support applicatif (`%APPDATA%\...` sous Windows), invisible, non synchronisé,
propre à chaque utilisateur du poste (ce qui reste juste pour un poste partagé).
La file d'attente d'envoi de fichiers ([[upload-outbox-fichiers]]) suit.

## Les règles du déplacement — elles portent du travail non synchronisé

- Le `-wal` **part avec la base**. Il contient les transactions les plus
  récentes, non encore reportées dans le fichier principal — donc exactement
  celles qui ne sont pas synchronisées.
- Une base **déjà présente** dans le nouvel emplacement n'est jamais écrasée.
- En cas d'échec, on **continue sur l'ancien emplacement** : mieux vaut un
  fichier mal placé qu'une base vide ouverte à côté d'une base pleine.
- Les fichiers voisins de l'agent ne sont pas emportés (filtre sur le préfixe
  `epilote_v3.db`).

7 tests dans `test/local_storage_dir_test.dart`, qui couvrent surtout les cas
où il ne faut **pas** déplacer. La CI Windows exige en plus que la base soit
réellement créée sous `%APPDATA%` après démarrage du binaire — ce qui prouve du
même coup que l'extension SQLite native de PowerSync se charge.

**Why :** cette famille de bugs — [[type-local-suit-type-serveur]],
[[perte-silencieuse-identifiants-vides]], [[powersync-is-active-egalite-stricte]] —
a déjà coûté cher. Un emplacement de fichier en fait partie : il ne se voit
qu'au moment où la donnée a disparu.

Liens : [[chaine-livraison-windows]] · [[upload-outbox-fichiers]] ·
[[offline-device-enrollment]]
