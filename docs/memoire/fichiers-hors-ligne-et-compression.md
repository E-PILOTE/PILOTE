# 📦 Tout fichier part hors ligne, et pèse le moins possible

Deux règles pour tout ce qui quitte un poste vers Supabase Storage.

## 1. Aucun fichier n'exige le réseau

PowerSync met en file les écritures SQL, **pas les fichiers**. Le rattrapage vit dans
`upload_outbox` : chemin Storage calculé en LOCAL, octets sur le disque, ligne écrite
tout de suite, envoi au retour du réseau — à ce chemin exact, donc sans jamais corriger
une ligne déjà synchronisée. Voir [[upload-outbox-fichiers]].

Les trois portes, et une seule règle par forme de stockage :

| Ce qu'on joint | Fonction | Pourquoi elle existe |
|---|---|---|
| Pièce du dossier, l'élève existe | `attachStudentDocumentOffline` | octets **+** ligne `student_documents` |
| Pièce du dossier, dans l'assistant | `queueStudentDocumentFile` | octets **seuls** — l'élève n'existe pas encore |
| Photo (bucket public `avatars`) | `queueAvatarUpload` | pas de ligne : une **colonne** porte l'URL |

⚠️ **Pourquoi l'assistant n'écrit que les octets.** La ligne écrite à l'étape 4 se
placerait dans la file PowerSync AVANT l'insertion de `students` ; le serveur refuserait
sur la clé étrangère (`23503`), code que le connecteur tient pour fatal → **lot entier
abandonné**, l'élève et ses tuteurs avec.

⚠️ **Pourquoi la photo a son propre chemin.** `getPublicUrl` est une concaténation, pas
un appel réseau : l'URL définitive se calcule avant que le fichier n'existe, on l'écrit
dans `students.photo_url`, et la file la rend valide plus tard. Un `await` sur le client
Storage dans `avatar_upload.dart` casserait tout — un test l'interdit.

Entre-temps l'URL pointe sur un objet absent : `PhotoAvatar`
(`core/widgets/photo_avatar.dart`) affiche le **fichier local** tant qu'il attend, via
`pendingFileForPublicUrl`. Sans ça, l'agent qui vient de prendre la photo voit un avatar
cassé et croit son geste raté. C'est pour cette raison que les quatre copies privées de
`_Avatar` ont fusionné : une copie qui ignore la règle rouvre le défaut.

## 2. On compresse tout ce qui peut l'être — et rien d'autre

État après balayage des 8 points de téléversement :

- **7 compressent déjà** : avatars (256 px), logos (512 px), pièces jointes de
  messagerie, pièces du dossier. La compression a lieu **avant la mise en file**, jamais
  à l'envoi : hors ligne ces octets dorment sur le disque, parfois des jours.
- **Note vocale — corrigé.** `compressForUpload` ne traite que ce qu'il sait décoder
  (images, vidéo) : un AAC déjà encodé lui passe entre les doigts. Le seul levier est
  l'ENCODAGE. 96 kbps stéréo → **32 kbps mono** : une minute passe d'environ 700 Ko à
  120 Ko, sans perte audible sur de la parole. `sampleRate` reste au défaut, l'abaisser
  fait échouer l'encodeur sur certaines plateformes de bureau.
- **Archive d'examen — NE PAS compresser.** `exam_archives_provider` calcule un
  SHA-256 sur les octets déposés : c'est lui qui prouve, des années plus tard, que la
  pièce opposable n'a pas bougé. Ré-encoder changerait les octets, donc l'empreinte,
  donc la valeur probante. Un test verrouille l'exception pour qu'un futur « on
  compresse tout » ne l'emporte pas par mégarde.
- **Logos dans les PDF** : déjà réduits au téléversement, rien à refaire à la
  génération.

Garde : `test/dossier_eleve_offline_test.dart` (12 tests).

## ⚠️ Reste en ligne seulement : la photo d'AGENT

`features/staff/services/agent_photo_service.dart` refuse encore explicitement le
hors-ligne : « Une photo doit atteindre le serveur pour que les autres postes la
voient : elle ne peut pas être ajoutée hors ligne. »

Le raisonnement ne tient plus — la file **la fait** atteindre le serveur. Et
`queueAvatarUpload` a été écrite avec un paramètre `folder` précisément pour servir
`staff/` aussi. Non basculé faute de demande : c'est un message produit délibéré, pas un
oubli technique. Une ligne à changer le jour où on le décide.

Voir aussi [[communication-media-compression]], [[webp-impossible-cote-client]].
