; ════════════════════════════════════════════════════════════════════════════
;  Installateur Windows — E-PILOTE CONGO
;
;  Produit un unique fichier .exe que l'agent d'un établissement double-clique.
;  C'est la seule forme de distribution réaliste : le dossier « Release » brut
;  fait 108 Mo répartis en vingt-six DLL, et personne, dans une école de
;  Kinkala, ne va le décompresser au bon endroit.
;
;  ── POURQUOI INNO SETUP ET PAS MSIX ────────────────────────────────────────
;  Un paquet MSIX REFUSE de s'installer s'il n'est pas signé par un certificat
;  auquel le poste fait déjà confiance. Tant que la question du certificat
;  n'est pas tranchée, MSIX ne produirait rien d'installable. Inno Setup, lui,
;  s'installe sans signature — au prix d'un avertissement SmartScreen que la
;  signature fera disparaître le jour venu, sans rien changer à ce fichier.
;
;  ── CONSTRUCTION ───────────────────────────────────────────────────────────
;    iscc /DAppVersion=3.1.7 /DSourceDir=..\..\epilote\build\windows\x64\runner\Release ^
;         packaging\windows\epilote.iss
; ════════════════════════════════════════════════════════════════════════════

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\epilote\build\windows\x64\runner\Release"
#endif

#define AppName      "E-PILOTE CONGO"
#define AppPublisher "E-PILOTE CONGO"
#define AppExeName   "E-PILOTE.exe"

[Setup]
; Cet identifiant ne doit JAMAIS changer : c'est lui qui permet à une nouvelle
; version de se reconnaître et de remplacer l'ancienne au lieu de s'installer
; à côté. Le modifier laisserait deux E-PILOTE sur chaque poste du pays.
AppId={{7C4E1A28-3F5B-4D96-9E1C-8A2B6D0F5E33}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
VersionInfoVersion={#AppVersion}

DefaultDirName={autopf}\E-PILOTE
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}

; Installation POUR TOUS LES UTILISATEURS du poste. L'application est pensée
; pour le poste partagé d'un établissement — secrétariat, surveillance,
; direction s'y succèdent. Une installation par profil obligerait à réinstaller
; pour chaque agent.
PrivilegesRequired=admin

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Windows 10 version 1809, plancher de Flutter pour le bureau Windows.
MinVersion=10.0.17763

; LZMA2 au maximum : 108 Mo de charge utile, à télécharger sur des liaisons
; congolaises. Chaque mégaoctet épargné compte plus ici que les quelques
; minutes de compression supplémentaires sur la machine de construction.
Compression=lzma2/max
SolidCompression=yes

OutputDir=..\..\dist
OutputBaseFilename=E-PILOTE-{#AppVersion}-installateur
WizardStyle=modern

[Languages]
; Le français seul. L'application l'est, ses utilisateurs aussi ; proposer un
; choix de langue à l'installation n'ajouterait qu'une étape à franchir.
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; \
  GroupDescription: "Raccourcis :"

[Files]
; `recursesubdirs` est indispensable : `data\` contient les ressources Dart et
; les polices, sans lesquelles l'application démarre sur un écran vide.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Lancer {#AppName}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Les fichiers créés par l'application APRÈS l'installation — cache de rendu,
; journaux — ne sont pas connus de l'installateur et resteraient sinon dans
; « Program Files » après désinstallation.
;
; ⚠️ La base locale PowerSync et le coffre de licence vivent dans le profil de
; l'utilisateur, PAS ici : la désinstallation ne doit pas emporter du travail
; hors ligne non encore synchronisé.
Type: filesandordirs; Name: "{app}"
