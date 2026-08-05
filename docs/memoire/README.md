# Mémoire du projet — copie versionnée

Ce dossier est la **mémoire de travail** accumulée sur E-PILOTE : les décisions
prises, les pièges déjà payés, ce que la base contient vraiment. Elle vivait
jusqu'ici hors du dépôt (`~/.claude/projects/…/memory/`), donc elle ne suivait
pas quand on change de machine. Elle est désormais versionnée ici pour que le
contexte traverse le changement de poste du 5 août 2026.

`MEMORY.md` est l'index : une ligne par fiche. Le reste est un fichier par fait.

## Remettre cette mémoire en service sur le nouveau poste

```powershell
# Windows
$dest = "$env:USERPROFILE\.claude\projects\-home-melack-E-PILOTE\memory"
New-Item -ItemType Directory -Force -Path $dest
Copy-Item docs\memoire\*.md $dest
```

Le nom du dossier projet dépend du chemin où le dépôt est cloné ; si Claude Code
n'y trouve rien, laisser la mémoire ici et lui demander de lire
`docs/memoire/MEMORY.md` en début de session — c'est le même contenu.

## ⚠️ Ce qui a été RETIRÉ de cette copie, et pourquoi

Le dépôt est privé, mais un dépôt privé se clone, se sauvegarde, entre en CI et
garde tout dans son historique — un secret qui y entre n'en ressort plus. Deux
fiches étaient des identifiants de bout en bout et ne sont donc **pas** ici :

| Fiche | Ce qu'elle contenait | Où la retrouver |
|---|---|---|
| `supabase-credentials.md` | clés `anon` et **`service_role`**, mot de passe PostgreSQL master | Supabase Dashboard → Settings → API ; le mot de passe master se réinitialise depuis Settings → Database |
| `system-access.md` | mot de passe sudo de l'ancien poste Linux | sans objet sur le nouveau poste Windows |

Dans les autres fiches, les valeurs sensibles rencontrées au fil du texte
(jetons, mots de passe de comptes de démonstration, PAT) ont été remplacées par
`‹secret — gestionnaire de mots de passe›`. Le raisonnement autour reste intact :
c'est lui qui a de la valeur, pas la chaîne de caractères.

## Ce qui n'a pas été emporté non plus

- **`.remember/`** (3,4 Mo) — journal de sessions, brut et redondant. Ce qu'il
  contenait d'utile est déjà distillé dans les fiches ci-dessus et dans
  l'historique git, qui est plus fidèle.
- **`backups/`** (9,2 Mo) — dumps CSV de la base de production : noms d'élèves
  mineurs, personnels, paiements. Des données personnelles réelles n'ont pas à
  entrer dans un historique git, et la source de vérité reste la base Supabase
  live. Si une copie locale est voulue, elle voyage sur clé USB.
