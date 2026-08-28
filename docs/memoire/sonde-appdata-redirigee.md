---
name: sonde-appdata-redirigee
description: ⚠️ PIÈGE D'OUTILLAGE (2026-08-29) — sous Claude Code Windows, l'outil Bash lit un %APPDATA% VIRTUALISÉ (AppContainer) : il rend un instantané périmé de la base locale. Toujours inspecter `epilote_v3.db` via PowerShell.
metadata:
  node_type: memory
  type: reference
---

# La sonde lisait une copie fantôme de `%APPDATA%`

## Le symptôme

Après avoir retiré deux colonnes du schéma PowerSync, vérification sur la base
locale réelle du poste (`%APPDATA%\E-PILOTE\epilote_v3.db`) :

```
profiles : 26 col ; fcm_token présent ? True
```

La colonne était toujours là. Quatre fois de suite — y compris après avoir
rejoué le WAL dans une copie, ce qui semblait éliminer l'explication facile.
Conclusion tentante et FAUSSE : « PowerSync ne met pas ses vues à jour quand on
retire une colonne, donc les postes mis à jour garderont l'ancien schéma ».

## La cause

L'outil **Bash** tourne dans un AppContainer Windows. Ses accès à `%APPDATA%`
sont **redirigés** vers
`%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\...`, où
dormait une copie datée du 25 août. Python lancé depuis Bash lisait donc une
base figée, pendant que l'application écrivait dans la vraie.

Le tell était visible et je l'ai regardé sans le voir : une recherche
`Get-ChildItem -Recurse` avait listé **deux jeux** de `epilote_v3.db`, dont un
sous `Packages\Claude_...`. Et `find /c -iname ISCC.exe` depuis Bash ne trouvait
rien alors qu'Inno Setup 6.7.3 était bien installé.

## La règle

**Toute inspection du disque hors du dépôt passe par PowerShell.** Pour lire la
base locale : copier d'abord avec PowerShell vers le scratchpad, puis analyser.

```powershell
Copy-Item "$env:APPDATA\E-PILOTE\epilote_v3.db"     "$sp\ancienne.db"     -Force
Copy-Item "$env:APPDATA\E-PILOTE\epilote_v3.db-wal" "$sp\ancienne.db-wal" -Force
```

Copier le `-wal` mais **jamais le `-shm`** : SQLite reconstruit le `-shm` et
rejoue le journal ; un `-shm` importé d'ailleurs empêche la reprise.

## Ce que la mesure disait vraiment, une fois faite au bon endroit

```
ANCIENNE base, rouverte par 3.3.1 : profiles 25 col, fcm_token ? False
                                    131 élèves, 8 514 notes, 292 bulletins, 0 crud
NEUVE base, créée par 3.3.1       : idem
```

PowerSync migre la base existante **en place**, sans perdre une ligne. C'est
exactement l'inverse de ce que la sonde périmée laissait croire — et cette
conclusion-là conditionnait la migration 0146
([[un-seul-fournisseur-supabase]]).

C'est encore la même leçon, sous un jour nouveau : **une sonde ne prouve que ce
qu'elle interroge** — et il faut d'abord savoir *ce qu'elle interroge vraiment*.
