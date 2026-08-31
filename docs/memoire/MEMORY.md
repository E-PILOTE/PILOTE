# E-PILOTE CONGO — Mémoire projet

## Démo METP / examens
- [Barème mentions — source unique](bareme-mention-source-unique.md) — `core/utils/mention.dart` + mig 0059 ; avait dérivé de 2 pts
- [🏛️ Cockpit METP — filière/département](cockpit-metp-pilotage.md) — réussite par filière + dépt, choroplèthe, scénario de démo ; ⚠️ `filiere_label` pas `filiere_id`
- [📦 Archives des publications DEC](archives-publications-dec.md) — mig 0062 ; taux = admis/PRÉSENTS ; DEC publie par établissement (code AAA…AIZ) ; jamais d'extraction PDF
- [⚠️ RÈGLE : DEC vs classes de passage](metp-partage-dec-classes-passage.md) — DEC renvoie des ADMIS sans notes → aucun classement d'examen ; onglet retiré ; trimestre = unité ; ⚠️ `.order()` supabase = DESCENDANT
- [🏆 Ministère — Meilleurs élèves + Dossier de l'élève](ministere-palmares-eleves-reseau.md) — 1 palmarès = 1 EXAMEN ; absence ≠ zéro ; ⚠️ `frame()` PDF ne se scinde pas (TooManyPages) ; ⚠️ `inscription_type` = `new`
- [🎯 Démo METP — seed technique](demo-metp-seed-technique.md) — groupe Ministère existe (14 écoles) ; 80 candidats BET + 52 stages
- [Démo METP — Kinkala](demo-metp-donnees-kinkala.md) — 3ème A = 23 élèves, 74 % admis ; classes dédupliquées
- [📐 Réseau vs national — bande de référence](reseau-vs-national-reference.md) — on ne retouche pas la donnée, on pose l'étalon DEC à côté ; ⚠️ jamais de référence « tous examens »
- [⚠️ Examens METP RÉELS + chiffres DEC](examens-metp-reels-dec.md) — ⚠️ CORRIGÉ 02/08 : la DEC publie DEUX bacs (technique ET professionnel), mig 0079 défait la fusion 0065
- [🏛️ Référentiel d'examens = MINISTÈRE](referentiel-examens-au-ministere.md) — super_admin = opérateur SaaS, il ne peuple pas ; règles d'éligibilité + faille SECURITY DEFINER fermée (migs 0070/0071)
- [🏅 Examens d'État — socle](examens-nationaux-socle.md) — migs 0042-0047 ; classe d'examen DÉRIVÉE par trigger ; faits vérifiés (CEPE≠CEP, 15 dépts)
- [📂 Dossiers examens/stages](examens-stages-dossiers-reels.md) — pièce couverte si attachée OU déclarée ; migs 0056/0057 ; ⚠️ table `levels` inexistante
- [💰 Examens — frais/stats/convocations](examens-frais-stats-convocations.md) — mig 0058 ; taux sur résultats connus (null ≠ 0 %) ; ⚠️ `savePayment` accepte enrollment_id null
- [⚠️ METP — ce qui existe VRAIMENT](metp-dsic-systemes-reels.md) — 1 seule appli réelle ; aucun concurrent sur la vie scolaire
- [👤 User = fonctionnaire DSIC/METP](user-fonctionnaire-dsic-metp.md) — sa parole prime sur mes recherches web

## Abonnement / licence
- [⏰ Alerte d'échéance : 5 j, et visible dans les écoles](alerte-echeance-cinq-jours-et-ecole.md) — mig 0106 ; cloche tôt (30,15,7,1,0) vs bandeau tard (5) ; miroir `school_groups.subscription_alert_days` pour l'offline ; ⚠️ le réglage existait mais n'avait jamais été posé
- [Abonnement — architecture offline-first](abonnement-architecture-offline.md) — Abonnement(serveur) vs Licence(signée) ; 2 horloges
- [Abonnement — audit PowerSync](abonnement-technique-powersync.md) — licence HORS PowerSync (coffre dédié) ; JWS Ed25519
- [⚠️ Infra réelle + hard-lock ADR-0009](abonnement-infra-reelle-hardlock.md) — plans/modules/invoices EXISTENT ; hard-lock livré ; reste claim émetteur
- [Notifications d'échéance](abonnement-notifications-echeance.md) — 🟡 PR #9 non mergée ; pg_cron J-30→J0 ; reste mig 0029 prod
- [⚠️ Référentiel tarifaire — Realtime + périodicité](abonnement-referentiel-tarifaire.md) — migs 0076/0077 ; `REPLICA IDENTITY FULL` obligatoire ; MRR sur `monthlyEquivalent` ; quota personnel = `profiles`
- [État réel + enforcement](abonnement-etat-reel-enforcement.md) — ⚠️ table `subscriptions` INEXISTANTE (vérité = `school_groups`) ; soft-gate livré
- [Workflow réabonnement RÉEL](abonnement-workflow-reel.md) — `mark_invoice_paid` était cassé ; `create_renewal_invoice` mig 0039
- [⚠️ Licence coffre appareil](licence-coffre-appareil-cross-groupe.md) — licence d'un ancien groupe empoisonne le nouveau ; fix bootstrap(expectedGroupId)
- [⚠️ DEUX écrans créaient un groupe — dont un SANS tutelle](copie-tutelle-agrement-forcee.md) — migs 0163/0164 ; `tutelle` NOT NULL ; copies FORCÉES à chaque écriture ; on pouvait ajouter un agrément mais jamais l'enlever (numéro périmé imprimé sur les attestations)
- [🔇 Un poste bloqué le DIT maintenant](blocage-de-file-visible.md) — `42703` rejoué à l'infini en silence = plus rien ne remonte ; `sync_failures.kind = 'blocage'`, effacement automatique ; ⚠️ NE JAMAIS rendre `42703` fatal (ça jetterait les écritures)
- [🚨 CI bloquée par la FACTURATION GitHub + publication manuelle](chaine-livraison-windows.md) — depuis le 30/08 aucune exécution ne démarre (3-5 s, « payments have failed ») ; v3.4.1 construite et publiée à la main ; ⚠️ ISCC est en profil utilisateur ; ⚠️ PS 5.1 double-encode les notes
- [⚠️ PowerSync : DEUX instances](powersync-deux-instances.md) — le parc utilise `…a66759` (Production), PAS `…a66757` que citent toutes les vieilles notes ; Production déjà à jour, Development déployé le 31/08 ; ⚠️ `--sync-config-file-path` obligatoire
- [💰 Prix par ÉCOLE + coûts réels de l'infra](tarif-par-ecole-et-couts-reels.md) — mig 0159 ; falaise ×11,4 supprimée ; 4 fonctions lisaient `price_xaf` en direct ; infra ≈ 45 140 XAF/mois ; ⚠️ le coût suit les APPAREILS, pas les élèves
- [📨 Circulaire de tutelle](circulaire-de-tutelle.md) — mig 0161 ; accusé PAR ÉTABLISSEMENT ; aucune politique d'UPDATE (RPC seules) ; ⚠️ `school_type_enum` ≠ `group_type` (42883 à la publication)
- [🏛️ Licence de TUTELLE — combien on facture un ministère](abonnement-licence-de-tutelle.md) — mig 0160 : système LIVRÉ (montants libres, `/super/economie`) ; 2 lignes exploitant+tutelle, jamais fusionnées ; forfait FIXE ; ⚠️ n'ouvre AUCUN accès ; montants = recommandation non validée
- [Licence — socle client](licence-socle-implemente.md) — `lib/licensing/` hexagonal livré ; enforcement DORMANT ; reste Edge Function émettrice

## Déploiement national (1-2 octobre 2026)
- [🗓️ Calendrier + ruptures de cycle de vie](deploiement-national-octobre.md) — présentation 01/10, déploiement 02/10 ; Windows seul, par vagues ; ⚠️ pas d'INE élève, la mutation d'agent détruit la carrière
- [🔄 Mise à jour du parc](mise-a-jour-du-parc.md) — mig 0087 ; ⚠️ comparer `build_number` ENTIER jamais la chaîne ; SHA-256 vérifié avant install ; CI prête à signer, inerte sans secret
- [🪟 Chaîne de livraison Windows](chaine-livraison-windows.md) — CI + installateur Inno 33,8 Mo ; ⚠️ audioplayers ≥ 6.8.1 et CMake ≥ 3.15 obligatoires
- [🪪 INE — identifiant national de l'élève](ine-identifiant-national-eleve.md) — migs 0080/0081 ; ⚠️ UNIQUE (ine, school_id) et non ine seul ; le SERVEUR attribue
- [🚀 Première heure d'un établissement](premiere-heure-etablissement.md) — parcours de démarrage ; ⚠️ BUG CORRIGÉ `school_levels` joint sur `group_id` seul = 42 niveaux au lieu de 6
- [🧱 Structure d'école — table morte](structure-ecole-table-morte.md) — ⚠️ l'UI écrivait dans `school_education_levels` (0 ligne, 0 lecteur) → école créée = AUCUN niveau ; mig 0089 ; on n'efface jamais un niveau qui porte des classes
- [📥 Import des listes d'élèves](import-listes-eleves.md) — ⚠️ Excel FR = `;` + Windows-1252 ; date/sexe NOT NULL rejetés AVANT écriture sinon le lot PowerSync entier est perdu
- [👔 Statut d'emploi du personnel](statut-emploi-personnel.md) — le STATUT décide du régime d'arrivée ; ⚠️ le bucket `directory` ne projetait aucune colonne de carrière
- [🔑 L'école crée ses propres agents](ecole-provisionne-ses-agents.md) — mig 0088 ; ⚠️ un chef ne crée JAMAIS un chef ; profil d'accès obligatoire ; seul geste EN LIGNE de l'espace école
- [⚖️ L'école CONSTATE une arrivée, elle ne la décide pas](ecole-constate-une-arrivee.md) — mig 0091 ; ⚠️ la 0088 écrivait « recrutement » sans acte = carrière falsifiée ; acte obligatoire en public ; `audit_logs.action` = varchar(20)
- [🔎 Kit d'annuaire partagé](annuaire-filtres-partages.md) — la barre d'outils se tient JUSTE AU-DESSUS de la liste ; ⚠️ KPI par cycle : nommer les enseignants sans classe affectée
- [👔 Carrière de l'agent — mutation, radiation](carriere-agent-mutation.md) — migs 0083/0084 ; ⚠️ `staff_affectations` HORS PowerSync ; « mutation » n'est JAMAIS un motif de départ
- [⚠️ Écrans jumeaux guichet ↔ registre](ecrans-jumeaux-guichet-registre.md) — Inscriptions et Élèves sont deux copies : corriger l'une ne corrige PAS l'autre
- [⚠️ Un graphe et un KPI doivent dire le même nombre](graphe-effectif-vs-kpi.md) — `is_active` + périmètre de classes + mois creux comblés
- [📜 Attestations émises par l'école](attestations-emises.md) — scolarité/radiation/travail ; `AttestationKit` ; ⚠️ `pw.Page` jamais `MultiPage` ; le REFUS est la fonctionnalité
- [🧾 Registre des documents délivrés](registre-documents-delivres.md) — `issued_documents` IMMUABLE par trigger `RETURN OLD` ; ⚠️ l'INSERT n'exige AUCUN verbe (sinon 42501 fatal) ; ⚠️ sans la ligne sync-rules, l'écran MENT
- [📖 Registre matricule — le grand livre](registre-matricule.md) — ⚠️ le filtre `is_active` des sync-rules faisait DISPARAÎTRE les archivés de tous les postes (retiré) ; le registre compte ses LACUNES et les imprime ; `compareMatricule` : M-9 avant M-10
- [📊 État statistique de rentrée](etat-statistique-rentree.md) — ⚠️ âge à la DATE D'OUVERTURE, jamais « aujourd'hui » ; aucun élève réparti au hasard ; part de filles sur le total NON RENSEIGNÉS COMPRIS ; `schools.tutelle` ajoutée au schéma local
- [🔍 Non revenus + exclusion définitive](non-revenus-et-exclusion.md) — 3e onglet du Passage ; ⚠️ garde-fou 30 % ; ⚠️ `academic_years.school_id` est NULL (années portées par le GROUPE)
- [🪪 Carte scolaire — le module](carte-scolaire-module.md) — ISO ID-1, 10/A4, verso MIROITÉ ; import de masse des photos : **exact ou rien**, unicité SYMÉTRIQUE ; ⚠️ garder sur `eleves.update` (RLS `students`), pas sur `cartes.import` ; mig 0148 AVANT le build
- [📷 Photo à la webcam + cadre d'identité](photo-webcam-cadre-identite.md) — ⚠️ RECADRER AVANT `compressAvatar` (~130 dpi → ~232 sur la carte) ; `camera_windows` se déclare À PART (non endossé) ; Linux n'a rien ; demande une NOUVELLE construction
- [🗜️ Compression des octets](compression-des-octets.md) — 3 seuils (256/512/1600) + 3 exceptions écrites ; garde qui échoue si un `uploadBinary` oublie de compresser ; ⚠️ **dans un PDF le coût suit les PIXELS, pas le poids du fichier** : PNG 2 Ko → 95 Ko, JPEG 19 Ko → 20 Ko
- [📡 Relevé du parc — quelle version tourne où](releve-du-parc.md) — mig 0150 ; ⚠️ **le chiffre qui décide est `jamais_signale`, pas `a_jour`** (les builds < 24 ne savent pas se signaler) ; seuil `0146` = build **24**, ni 21 ni 23 ; table HORS PowerSync
- [⚠️ Le Passage n'avait aucun verrou](passage-devient-un-module.md) — slug absent de `_moduleRoutes` = « route native » = zéro verrou ; mig 0147 recopie `conseils` ; ⚠️ `can_write` est GÉNÉRÉE (428C9)
- [🚪 Motifs de sortie d'élève](motifs-de-sortie-eleve.md) — mig 0082 ; abandon économique ≠ abandon familial ; ⚠️ liste à faire valider
- [💾 La base hors ligne quitte Documents](base-hors-ligne-hors-documents.md) — OneDrive corrompt une SQLite ouverte ; le `-wal` part avec la base

## Base de données / architecture
- [🌱 Jeu de démo national — `database/seed/` 00→07](seed-demo-national-pipeline.md) — ⚠️ sans le 07 (droits), l'app est VIDE pour le personnel ; 9 104 élèves, 431 250 notes
- [🧨 Base vidée 2026-08-01 + référentiel restauré](base-videe-et-referentiel-restaure.md) — backup `backups/csv` (103 CSV) ; reste le seed écoles/personnel
- ⛔ **Credentials Supabase** et **Accès système** — RETIRÉS de cette copie : c'étaient des fiches d'identifiants de bout en bout. Voir `README.md` de ce dossier.
- [Vérifier base live](verifier-base-live-vs-schema.md) — schema.sql périmé, interroger le live avant de conclure
- [Enum user_role](db-user-role-enum.md) — ⚠️ PAS de 'utilisateur' ; staff = role≠super_admin/admin_groupe
- [BUG PowerSync role](bug-powersync-role-utilisateur.md) — ✅ résolu par `_isStaffRole()`
- [PowerSync](powersync-status.md) — Cloud configuré
- [🚀 Déployer les sync-rules en CLI](powersync-deploiement-cli.md) — ✅ **déployées le 2026-08-29** sur Production (…66759) : `pull` avant, deploy, `pull` après, puis lancer le binaire pour voir les checkpoints passer ; ⚠️ jeton par `PS_ADMIN_TOKEN` jamais sur disque ; un 500 « Resource does not exist » = jeton révoqué
- [Déploiement sync-rules](sync-config-divergence.md) — LIVE = `bucket_definitions` ; `sync-config.yaml` MORT
- [Sync-rules data-protection](sync-rules-data-protection.md) — tables sensibles gatées
- [Profil = source de vérité des droits](profil-source-de-verite-droits.md) — la donnée sensible suit le PROFIL, pas le rôle
- [Durcissement échelle nationale](db-scale-hardening.md) — index FK, intégrité année/inscription, RLS
- [Dérive registre migrations](migration-ledger-drift.md) — migs 0001-0024 hors ledger Supabase
- [⚠️ Login 500 — NULL tokens](auth-null-token-login-500.md) — comptes RPC bloqués ; fix mig 0036 vérifié prod
- [Audit fondation 55 tables](foundation-schema-audit.md) — schéma local↔live↔sync-rules sain
- [Realtime publication requise](realtime-publication-requirement.md) — ⚠️ table écoutée DOIT être dans `supabase_realtime`
- [Secteur école hérité du groupe](secteur-ecole-herite-groupe.md) — public XOR privé ; « mixte » supprimé, mig 0060

## Perte de données (offline)
- [⚠️ `is_active = 1` rate les lignes écrites par l'app](powersync-is-active-egalite-stricte.md) — vue PowerSync ; utiliser `COALESCE(is_active,1) <> 0` ; sqlite3 ne reproduit PAS
- [💸 Type local ≠ type serveur = lot perdu](type-local-suit-type-serveur.md) — `amount_xaf` en `real` vs `integer` → 22P02, chaque paiement hors ligne perdu ; test garde-fou
- [✅ Perte silencieuse — identifiants vides](perte-silencieuse-identifiants-vides.md) — `?? ''` sur un id → tout le lot PowerSync abandonné sans message
- [✅ Inscription perdue à la sync](inscription-validation-effectif-a-verifier.md) — date de naissance NOT NULL → transaction perdue ; fix = champ obligatoire
- [Journal échecs de sync](sync-failure-journal.md) — table local-only `sync_failures` + bannière acquittable
- [File d'attente d'envoi de fichiers](upload-outbox-fichiers.md) — PowerSync met en file le SQL mais PAS les fichiers
- [⚠️ Verrouiller ≠ Déconnecter](offline-device-enrollment.md) — la purge ne doit jamais détruire du travail non synchronisé
- [🔑 Reprise du poste](reprise-du-poste.md) — jeton miroir au coffre + reprise hors ligne au PIN ; ⚠️ `tokenRefreshed` sans `signedIn` doit reconnecter PowerSync
- [🔥 Une déconnexion SUBIE n'efface plus la base](deconnexion-subie-nefface-pas.md) — ⚠️ `signedOut` n'est pas un ordre ; 98 % des pages libérées, 48 761 lignes à retélécharger ; l'école se retrouve devant un mot de passe que personne ne connaît

## Espaces & modules
- [Super Admin](super-dashboard-status.md) — 19 pages ✅
- [Admin Groupe espace](admin-groupe-espace.md) — 10 écrans + sidebar dynamique
- [Rôle admin_groupe](role-admin-groupe.md) — online/Supabase direct ; attribue les modules sans les utiliser
- [Modules — accès & hiérarchie](modules-acces-hierarchie.md) — cascade 4 verrous (rôle→plan→profil→périmètre)
- [Catalogue modules v2](catalogue-modules-v2.md) — 7 catégories / 29 modules ; slugs hardcodés dans admin_access_screen
- [Modules natifs Communication](modules-natifs-communication.md) — communication = tissu natif hors catalogue
- [Espace école — coquille](espace-ecole-coquille.md) — dashboard adaptatif + sidebar 4 verrous
- [Sidebar modules vide — cause](sidebar-modules-empty-cause.md) — comptes sans profil d'accès
- [⚠️ Sidebar personnel = DÉFILANTE](sidebar-personnel-est-defilante.md) — ne pas « réparer » : 13 modules visibles sur 30, les autres sont sous la ligne de flottaison ; 5 verrous déjà vérifiés
- [Rollout leadership-first](rollout-leadership-first.md) — direction d'ABORD, enseignant EN DERNIER
- [Module Inscription](inscription-module-logique.md) — 1ʳᵉ fonctionnalité offline-first
- [Structure académique](structure-academique-livree.md) — /user/structure Cycle▸Niveau▸Classe
- [Années scolaires — verrou is_current](annees-scolaires-edition-verrou.md) — lecture seule si aucune année courante
- [Scolarité — Classes/Matières/Élèves/Programmes](scolarite-pages-classes-matieres-eleves.md) — matière CANONIQUE (`class_subjects` mig 0014)
- [Scolarité — Transferts/Documents/Annuaire](scolarite-transferts-documents-annuaire.md) — `ScopeDrilldownPanel` partagé
- [Évaluation — Notes/Bulletins/Conseils](evaluation-notes-bulletins.md) — complet, PAS vérifié GUI ; 0 déploiement
- [🎓 Clôture des classes d'examen](cloture-examen-classes.md) — 2e onglet du Passage ; seul écrivain de `graduated` ; ⚠️ le niveau suivant change de CYCLE
- [Vie Scolaire](vie-scolaire-categorie.md) — 6 modules offline + kit `vs_kit`
- [Finance](finance-categorie.md) — 4 modules ; Dépenses→Budget (réalisé dérivé) ; 0 déploiement
- [💰 Frais public vs privé](frais-public-vs-prive.md) — le GROUPE définit tout barème ; pas de barème = pas d'encaissement ; ⚠️ dépassement sur le CUMUL ; lot 0 livré (mig 0094)
- [RH](rh-categorie.md) — l'agent = `profiles` ; mig 0023 + sync-rules déployées
- [Personnel — annuaire](staff-personnel-annuaire.md) — sur `profiles`, pas staff_members
- [EDT calendrier+exceptions](enseignement-emploi-du-temps.md) — vues jour→annuel, migs 0021/0022 déployées
- [EDT — refonte ERP](edt-refonte-v2.md) — 🚧 Vague 0 migs 0015→0019 NON déployée = gate

## Communication & support
- [⚠️ Sonde `%APPDATA%` redirigée](sonde-appdata-redirigee.md) — l'outil Bash de Claude Code Windows lit un AppContainer VIRTUALISÉ : inspecter `epilote_v3.db` via PowerShell, jamais via Bash
- [🟢 Un seul fournisseur : Supabase](un-seul-fournisseur-supabase.md) — Firebase/FCM écarté (2026-08-29) ; la cloche + PowerSync EST le canal ; ⚠️ mig 0146 seulement quand TOUT le parc est en ≥3.3.1+21 (sinon 42703 → synchro bloquée) ; espace élève/parent EN DERNIER
- [Unification communication](communication-unification-plan.md) — 1 jeu de pages scope-aware partagé 3 espaces
- [Refonte feed Annonces](annonces-feed-fixes.md) — causes racines = tables hors realtime + FK vers auth.users
- [Accusés lecture + présence](communication-receipts-presence.md) — last_read_at, ✓✓, Realtime Presence
- [Compression média](communication-media-compression.md) — compression à l'upload ; fix RLS création groupe
- [⚠️ WebP impossible côté client](webp-impossible-cote-client.md) — `image` n'encode pas le WebP ; le redimensionnement capte 99,7 % du gain
- [Chats cross-groupe](cross-group-chat-rls.md) — fix RLS `msg_insert`
- [Support staff offline](staff-support-offline.md) — pièces jointes jsonb+Storage ; login offline durci
- [Pièces jointes tickets](tickets-attachments-sidebar.md) — jsonb ; sidebar super_admin aplatie

## Poste partagé & audit
- [Poste partagé — bascule d'agent](poste-partage-agent-switch.md) — identité APPAREIL + AGENT ACTIF local (PIN haché jamais synchro)
- [Écran-verrou](ecran-verrou-poste-partage.md) — overlay kiosque plein écran ; `/user/agents` supprimé
- [Vitrine sécurité + PIN](poste-vitrine-securite-refonte.md) — PR #16 ; ✅ déployé prod 2026-07-15 (migs 0033/34/35) ; reste release app
- [Journal audit — module partagé](audit-module-partage-scope.md) — `features/audit/` scope-aware ; plancher de visibilité par rôle

## Cartographie & dashboards
- [Vue régionale — Tableau + cockpit](regional-table-mode.md) — bascule Carte/Tableau, Tiers 2-4
- [Cockpit régional — satellite + GPS](regional-satellite-cockpit.md) — mig 0037 temps réel ; Esri Wayback ; Google Maps EXCLU
- [Carte données géo](carte-donnees-geo.md) — congo_places.json = 1532 localités
- [Dashboard adaptatif par charge](dashboard-persona-ordering.md) — accès par permissions, ORDRE par charge
- [Refonte UX/UI dashboard direction](dashboard-direction-uxui.md) — glassmorphism+aurora, lanceur `MenuAnchor`, fix finance year-scope

## Conventions & outillage
- [Règle taille fichier 500](regle-taille-fichier-500.md) — Dart ≤500 lignes
- [🪟 Chrome des modales admin](archives-publications-dec.md) — 3 géométries partagées (boîte/panneau/feuille montante) + `showAdminConfirm` ; `admin_ui.dart` ré-exporte
- [Design anti-redondance](design-gouvernance-anti-redondance.md) — pas de KPI dupliqués ; user délègue mais exige rigueur
- [Formulaires — contexte classe](form-class-context-pattern.md) — `ClassContextBanner` si ouvert depuis une classe
- [Dialogues-formulaires = shrinkWrap](dialog-form-shrinkwrap.md) — jamais pleine hauteur
- [Thèmes Clair·Sombre·Melack](themes-clair-sombre-melack.md) — ⚠️ `kNavy` s'ÉCLAIRCIT en sombre
- [Tester l'app GUI (Linux X11)](gui-testing-linux.md) — import + xdotool coords FENÊTRE + DTD hot_restart
- [⚠️ Overlay/builder — angle mort golden](overlay-builder-golden-blindspot.md) — widget dans `MaterialApp.builder` = pas d'Overlay ancêtre
- [Correctifs rendu desktop dev](desktop-dev-rendering-fixes.md) — sqflite_common_ffi + pdfrx + autoplay mobile-only
- [✅ Remote GitHub](git-remote-unreachable.md) — `gh auth switch -u E-PILOTE`

---

- [⚠️ Cibles = Windows 10/11 + Mac, PAS Linux](plateformes-cibles-windows-mac.md) — Linux = dev seulement → ne pas investir dans ses bugs ; release Windows+macOS non entamée
- [Empaquetage .deb Linux](desktop-packaging-deb.md) — `packaging/build-deb.sh` ; 🐛 « l'app se coupe brutalement » = pilote nouveau, PAS le code → ne rien faire

## Contexte rapide (session suivante)
> Lire d'abord tous les fichiers du dossier memory. **Projet** E-PILOTE CONGO (gestion scolaire offline-first). **App** `cd /home/melack/E-PILOTE/epilote && flutter run -d linux`. **Stack** Flutter + Riverpod + PowerSync Cloud + Supabase.
>
> **Architecture (NON NÉGOCIABLE)** : super_admin + admin_groupe → `supabase.from()` direct (online). Personnel scolaire (tout autre rôle, `_isStaffRole`) → PowerSync offline `db.watch()`/`db.execute()` UNIQUEMENT, jamais `supabase.from()`. Vérifier `information_schema.columns` (base live) avant chaque module.
>
> **État** : super_admin (19 pages) ✅, admin_groupe (12 écrans, + Palmarès et Élèves du réseau) ✅, espace école quasi complet : Scolarité + EDT + Évaluation + Vie scolaire + Finance + RH livrés ; reste Cahier de textes + branchements.
>
> **Conventions** : Dart ≤500 lignes ; `ref.keepAlive()` ; KPI = `GridView.builder` + `mainAxisExtent` (jamais `childAspectRatio`) ; chrome PDF = `OfficialPdfKit` + `showPdfPreviewDialog` ; panneau cycle/niveau/classe = `ScopeDrilldownPanel`. Détails schéma/pièges → [[flutter-tech-notes]].

---

## Points techniques Flutter
Déplacés vers [[flutter-tech-notes]] (schémas de tables, pièges API, Syncfusion, finance, système éducatif).
