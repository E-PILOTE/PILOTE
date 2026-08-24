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

## ⚠️ La photo d'AGENT reste en ligne — et ce n'est PAS un oubli

J'ai d'abord cru le contraire, en lisant le message affiché à l'agent (« une photo doit
atteindre le serveur… ») sans lire l'en-tête du service. La vraie raison tient, et elle
est vérifiée en base :

> `profiles_update` n'autorise que `is_super_admin()`, `is_admin_groupe()` du groupe, ou
> `id = auth.uid()`.

**Un directeur qui corrige la fiche d'un AUTRE agent n'entre dans aucune des trois.** Un
UPDATE de `avatar_url` poussé par PowerSync reviendrait en `42501` — code fatal pour le
connecteur — et emporterait le LOT ENTIER : notes et paiements écrits dans la même
fenêtre. D'où la RPC `corriger_fiche_agent` (migration 0091), en ligne par construction.

⇒ **Mettre les octets en file ne débloquerait rien** : ce qui manque hors ligne n'est pas
le fichier, c'est l'écriture de `avatar_url`. On aurait une photo sur le disque, aucune
fiche modifiée, et l'occasion d'inscrire dans un dossier l'adresse d'un fichier pas
encore arrivé — ce que la séparation octets/fiche interdit précisément.

Le rendre vraiment hors ligne demanderait un autre chemin d'écriture pour `profiles` —
table tampon synchronisée, appliquée côté serveur par trigger. C'est un chantier, pas un
branchement. La note est désormais dans `agent_photo_service.dart` pour qu'on ne refasse
pas le raisonnement à l'envers.

### Deux messages qui mentaient, corrigés au passage

- `_lisible` servait les QUATRE gestes du provider avec une seule phrase hors ligne :
  « la création d'un compte exige le réseau ». Un chef qui corrigeait un numéro de
  téléphone lisait donc qu'il ne pouvait pas créer de compte — il n'en créait aucun. Le
  geste est maintenant nommé par l'appelant.
- Le message de la photo la désignait comme l'exception d'un écran qui, sans réseau, ne
  sait RIEN enregistrer. L'agent renonçait à la photo, remplissait le reste, et se
  heurtait à un second échec formulé autrement. Il dit maintenant les deux d'un coup.

Voir aussi [[communication-media-compression]], [[webp-impossible-cote-client]].
