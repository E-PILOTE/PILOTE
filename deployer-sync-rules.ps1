# ═══════════════════════════════════════════════════════════════════════════
#  DÉPLOIEMENT DES SYNC-RULES POWERSYNC — E-PILOTE CONGO
#
#  Rien de ce qui est écrit dans `powersync/config/sync-rules.yaml` n'est actif
#  tant que ce script n'a pas tourné. Une règle éditée et non déployée est une
#  panne muette : la base est correcte, l'espace groupe affiche la donnée, et
#  les postes des écoles ne la reçoivent jamais.
#
#  UTILISATION — depuis C:\E-PILOTE :
#      powershell -ExecutionPolicy Bypass -File .\deployer-sync-rules.ps1
#
#  La CLI vous demandera votre jeton PowerSync si vous n'êtes pas connecté.
#  Il part en stockage sécurisé du poste ; les fois suivantes, plus de question.
# ═══════════════════════════════════════════════════════════════════════════

# On ne s'arrête PAS au premier bruit : la CLI écrit ses avertissements sur la
# sortie d'erreur même quand tout va bien, et PowerShell 5.1 transforme cela en
# erreur terminante. Chaque étape vérifie donc son propre code de retour.
$ErrorActionPreference = 'Continue'

# Se placer à la racine du dépôt, quel que soit l'endroit d'où l'on lance.
# `--directory=powersync` est RELATIF au dossier courant : lancé depuis
# C:\WINDOWS\system32, la CLI cherche C:\WINDOWS\system32\powersync et répond
# « Directory "powersync" not found », ce qui ressemble à tort à un problème
# d'authentification.
Set-Location $PSScriptRoot

# ─── 1. Retrouver Node sans dépendre du PATH ────────────────────────────────
#  Le lanceur `powersync.cmd` appelle `node` en première ligne. Un terminal
#  ouvert AVANT l'installation de Node porte un PATH périmé et échoue avec un
#  « powersync n'est pas reconnu » qui accuse la mauvaise coupable.
$node = $null
$c = Get-Command node -ErrorAction SilentlyContinue
if ($c) { $node = $c.Source }
if (-not $node) {
  foreach ($p in @("$env:ProgramFiles\nodejs\node.exe",
                   "${env:ProgramFiles(x86)}\nodejs\node.exe",
                   "$env:LOCALAPPDATA\Programs\nodejs\node.exe")) {
    if (Test-Path $p) { $node = $p; break }
  }
}
if (-not $node) {
  Write-Host "Node.js est introuvable. Installez-le depuis https://nodejs.org" -ForegroundColor Red
  exit 1
}

# ─── 1 bis. Localiser la CLI SANS supposer le profil ────────────────────────
#  `%APPDATA%\npm` est l'emplacement par défaut, mais APPDATA change dès que le
#  script tourne en tant qu'administrateur ou sous un autre compte : la CLI,
#  installée pour l'utilisateur courant, devient alors introuvable et le script
#  annonce à tort qu'elle n'est pas installée. On la demande donc à npm.
$npm = $null
$c = Get-Command npm -ErrorAction SilentlyContinue
if ($c) {
  $npm = $c.Source
} else {
  $p = Join-Path (Split-Path $node) 'npm.cmd'
  if (Test-Path $p) { $npm = $p }
}

$candidats = @()

# Copie LOCALE AU PROJET, en premier et pour une bonne raison :
#   npm install -g --prefix .tools powersync
# L'application Claude est un paquet Windows à système de fichiers redirigé :
# ce qu'elle écrit dans %APPDATA% atterrit en réalité sous
# AppData\Local\Packages\Claude_…\LocalCache\Roaming\. Une CLI installée depuis
# l'assistant y est donc invisible depuis un vrai terminal, et réciproquement.
# `.tools\` n'est redirigé pour personne : les deux y voient la même chose.
$candidats += (Join-Path $PSScriptRoot '.tools\node_modules\powersync\bin\run.js')

if ($npm) {
  $root = & $npm root -g 2>$null | Select-Object -Last 1
  if ($root) { $candidats += (Join-Path $root.Trim() 'powersync\bin\run.js') }
}
$candidats += (Join-Path $env:APPDATA 'npm\node_modules\powersync\bin\run.js')
$candidats += (Join-Path (Split-Path $node) 'node_modules\powersync\bin\run.js')

$runjs = $null
foreach ($x in $candidats) {
  if ($x -and (Test-Path $x)) { $runjs = $x; break }
}

if (-not $runjs) {
  Write-Host "CLI PowerSync introuvable. Chemins essayés :" -ForegroundColor Red
  foreach ($x in $candidats) { Write-Host "    $x" }
  Write-Host ""
  Write-Host "APPDATA = $env:APPDATA"
  Write-Host "Si ce n'est pas C:\Users\HP\AppData\Roaming, ce terminal tourne"
  Write-Host "sous un autre compte : relancez-le en utilisateur normal."
  Write-Host ""
  Write-Host "Sinon, installez la CLI dans le projet :" -ForegroundColor Yellow
  Write-Host "    npm install -g --prefix .tools powersync" -ForegroundColor Yellow
  exit 1
}

function Invoke-PowerSync { & $node $runjs @args }

Write-Host ""
Write-Host "Node   : $node"
Write-Host "CLI    : $runjs"
Write-Host "Version: " -NoNewline; Invoke-PowerSync --version

# ─── 2. Vérifier l'instance visée AVANT de publier quoi que ce soit ─────────
#  Le piège documenté dans powersync/cli.yaml : déployer sur « Development »
#  (…66757) publie la règle sur une instance que personne n'utilise. La
#  modification paraît appliquée et tout le parc reste en panne.
$kProduction = '6a185943234fa2bf51a66759'
$cli = Join-Path $PSScriptRoot 'powersync\cli.yaml'
$instance = (Select-String -Path $cli -Pattern '^\s*instance_id:\s*(\S+)').Matches[0].Groups[1].Value

Write-Host ""
Write-Host "Instance visée : $instance"
if ($instance -ne $kProduction) {
  Write-Host "ATTENTION : ce n'est PAS l'instance de production ($kProduction)." -ForegroundColor Red
  Write-Host "Déployer ici publierait la règle sur une instance inutilisée." -ForegroundColor Red
  $rep = Read-Host "Continuer quand même ? (oui/non)"
  if ($rep -ne 'oui') { Write-Host "Abandonné."; exit 1 }
} else {
  Write-Host "  -> production, celle que cible l'application. OK." -ForegroundColor Green
}

# ─── 3. Authentification (seule étape qui vous demande quelque chose) ───────
Write-Host ""
Write-Host "--- Authentification ---"

# Sonde FIABLE : `fetch config` est un vrai appel Cloud. Il rend 1 tant que le
# poste n'est pas authentifié, et ne rend 0 que si le jeton est valide ET
# l'instance liée réellement atteignable — soit exactement les conditions du
# déploiement.
#
# Ce qu'il ne faut PAS utiliser : `fetch instances`. Il écrit son avertissement
# « Not logged in » sur la sortie d'ERREUR et rend malgré tout 0, en affichant
# au passage l'instance lue dans cli.yaml, en local. Toute sonde bâtie dessus
# annonce « déjà connecté » à un poste qui ne l'est pas, puis fait échouer le
# déploiement sans avoir jamais demandé le jeton.
Invoke-PowerSync fetch config --directory=powersync | Out-Null

if ($LASTEXITCODE -ne 0) {
  Write-Host "Non connecté. La CLI va vous demander votre jeton PowerSync." -ForegroundColor Yellow
  Write-Host "(Dashboard PowerSync -> Personal Access Token)" -ForegroundColor Yellow
  Write-Host ""
  Invoke-PowerSync login
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Échec de l'authentification. Rien n'a été déployé." -ForegroundColor Red
    exit 1
  }
  # On revérifie : un `login` qui rend 0 sans ouvrir l'accès à l'instance
  # ferait échouer le déploiement plus loin, avec un message obscur.
  Invoke-PowerSync fetch config --directory=powersync | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Connecté, mais l'instance $instance reste inaccessible." -ForegroundColor Red
    Write-Host "Le jeton appartient peut-être à une autre organisation." -ForegroundColor Red
    exit 1
  }
  Write-Host "Authentifié, instance accessible." -ForegroundColor Green
} else {
  Write-Host "Déjà connecté, instance accessible." -ForegroundColor Green
}

# ─── 4. Déploiement ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "--- Déploiement des sync-rules ---"
Invoke-PowerSync deploy sync-config `
  --directory=powersync `
  --sync-config-file-path=powersync/config/sync-rules.yaml
if ($LASTEXITCODE -ne 0) {
  Write-Host "Le déploiement a échoué. Rien n'a changé sur l'instance." -ForegroundColor Red
  exit 1
}

# ─── 5. Contrôle : le live correspond-il au fichier ? ──────────────────────
#  On ne se fie pas au « succès » annoncé : on relit la config publiée et on
#  cherche la ligne neuve. `school_holidays` doit apparaître DEUX fois —
#  une dans by_group (school_id IS NULL, le calendrier national hérité),
#  une dans by_school (school_id = bucket.sid, les fermetures de l'école).
Write-Host ""
Write-Host "--- Contrôle de la configuration publiée ---"
$live = Invoke-PowerSync fetch config --directory=powersync --output=json | Out-String
if ($LASTEXITCODE -ne 0) {
  Write-Host "Impossible de relire la config publiée : contrôle non concluant." -ForegroundColor Red
  exit 1
}

# On aplatit AVANT de chercher. Le premier jet filtrait ligne à ligne : la
# sortie YAML replie les lignes longues, « AND school_id IS NULL » se
# retrouvait sur la ligne suivante — qui ne contient pas « school_holidays » —
# et le contrôle criait à l'anomalie sur un déploiement pourtant réussi.
$plat = $live -replace '\\r\\n', ' ' -replace '\\n', ' ' -replace '\s+', ' '

$national = [regex]::IsMatch($plat,
  'school_holidays\s+WHERE\s+group_id\s*=\s*bucket\.gid\s+AND\s+school_id\s+IS\s+NULL')
$ecole = [regex]::IsMatch($plat,
  'school_holidays\s+WHERE\s+school_id\s*=\s*bucket\.sid')

Write-Host ""
foreach ($m in [regex]::Matches($plat, 'SELECT[^-]*?FROM school_holidays[^-]*?(?=\s+#|\s+- |$)')) {
  Write-Host ("  " + $m.Value.Trim())
}

Write-Host ""
if ($national -and $ecole) {
  Write-Host "DÉPLOYÉ ET VÉRIFIÉ." -ForegroundColor Green
  Write-Host "Les 126 jours fériés nationaux descendront sur les postes à leur"
  Write-Host "prochaine synchronisation."
} else {
  Write-Host "ANOMALIE : la règle attendue n'est pas dans la config publiée." -ForegroundColor Red
  Write-Host ("  by_group  (school_id IS NULL)      : " +
              $(if ($national) { 'présente' } else { 'ABSENTE' }))
  Write-Host ("  by_school (school_id = bucket.sid) : " +
              $(if ($ecole) { 'présente' } else { 'ABSENTE' }))
  exit 1
}
