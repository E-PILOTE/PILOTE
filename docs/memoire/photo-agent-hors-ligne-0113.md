# 🪪 La photo d'un agent se DEMANDE (migration 0113)

Dernier fichier de l'espace école à exiger le réseau — et pour une raison qui, elle,
tenait vraiment.

## Le mur, et pourquoi la file d'envoi ne suffisait pas

```
profiles_update : is_super_admin()
               OR (is_admin_groupe() AND group_id = auth_group_id())
               OR id = auth.uid()
```

**Un directeur qui corrige la fiche d'un AUTRE agent n'entre dans aucune des trois.** Un
UPDATE d'`avatar_url` poussé par PowerSync reviendrait en `42501` — code que le
connecteur tient pour fatal — et ferait abandonner la transaction ENTIÈRE : les notes et
les paiements saisis dans la même fenêtre partiraient avec.

⚠️ J'avais d'abord conclu l'inverse, en lisant le message affiché à l'agent (« une photo
doit atteindre le serveur… ») sans lire l'en-tête du service. Mettre les octets en file
ne débloquait rien : ce qui manque hors ligne n'est pas le fichier, c'est **l'écriture
de `avatar_url`**.

## La forme retenue : une demande, pas une écriture

L'école n'écrit pas dans `profiles` : elle dépose une ligne dans `staff_photo_requests`,
table qui lui appartient et se synchronise comme le reste. Un trigger l'applique côté
serveur avec **l'autorité exacte de `corriger_fiche_agent`** (0091), recopiée mot pour
mot. Aucun droit n'est relâché ; seul le MOMENT change.

`auth.uid()` est bien l'agent qui a fait le geste, même en différé : le connecteur
téléverse avec SON jeton.

### ⚠️ La règle qui décide de tout : le trigger ne lève JAMAIS

Une exception remontée à PostgREST devient un code fatal → lot entier abandonné. On
aurait reproduit, par le remède, la panne qu'on soigne. Un refus s'INSCRIT donc dans
`refus`, `applied_at` reste nul, et la demande redescend sur le poste avec sa raison.

Vérifié en prod (tout annulé) : chef → appliqué, `profiles.avatar_url` réellement
changé ; enseignant → refusé **sans exception** ; URL hors de notre stockage → refusée ;
fiche d'élève → refusée. Zéro ligne, zéro audit résiduel.

## Les deux gestes du client, et pourquoi ils sont deux

1. `preparerPhotoAgent` → compresse, met les OCTETS en file (`upload_outbox`), rend
   l'URL publique définitive. Aucun réseau : `getPublicUrl` est une concaténation.
2. `deposerDemandePhotoAgent` → écrit la DEMANDE, en local.

Les séparer permet de ne jamais promettre dans un dossier un fichier qui n'aurait pas
été mis en file. La demande part **avant** la RPC qui porte le reste de la fiche : si
celle-ci échoue faute de réseau, au moins la photo est acquise.

⚠️ **`p_avatar_url` / `p_effacer_photo` ont été retirés de l'appel Dart à
`corriger_fiche_agent`.** La RPC les accepte encore ; les repasser appliquerait la photo
deux fois et inscrirait deux corrections au journal d'audit pour un seul geste.

## Ce qui n'est pas cosmétique : l'affichage

Hors ligne, `profiles.avatar_url` local ne bouge pas — c'est le serveur qui l'écrit.
Sans le lot d'affichage, le chef prend une photo et voit encore l'ancienne : il
recommence, croyant son geste perdu.

- `photoAffichee(ref, profileId, avatarUrl)` → la demande en attente prime sur la fiche.
- `UserAvatarCircle` accepte un `profileId` optionnel et résout lui-même — ses parents
  restent des `StatelessWidget`, rien à convertir.
- `fichierLocalEnAttente` → tant que les octets attendent, on montre le **fichier du
  disque** plutôt qu'un rond cassé. Partagé avec `PhotoAvatar` : les deux pastilles de
  l'application répondent pareil à la même URL.

⚠️ **La file se lit en UNE requête** (`pendingUploadPathsProvider`,
`demandesPhotoAgentProvider`). Interroger par pastille ferait deux cents requêtes sur
une liste de personnel, et autant à chaque reconstruction.

Et le **refus s'affiche** dans la fiche : c'est le seul endroit où l'agent peut
apprendre que sa demande n'a pas abouti, puisque le trigger ne lève pas.

## Garde

`test/photo_agent_hors_ligne_test.dart` (7 tests) — interdit d'écrire `profiles`
directement, de repasser la photo à la RPC, de revenir à une requête par pastille, et
exige que le refus remonte à l'écran.

Voir aussi [[fichiers-hors-ligne-et-compression]], [[ecole-constate-une-arrivee]],
[[upload-outbox-fichiers]].
