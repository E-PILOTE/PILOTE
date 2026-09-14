# Conformité export / aperçu / impression — balayage global

> **GÉNÉRÉ le 2026-09-08** par balayage de `epilote/lib/`.
> ⚠️ Les commentaires de ligne et de bloc sont **retirés avant analyse** :
> plusieurs fichiers NOMMENT les appels bannis dans le commentaire qui
> explique leur suppression. Une première passe sans ce filtre annonçait
> 9 fichiers à polices réseau ; il n'y en a **qu'un**.
>
> Complète les sections D.4 des rapports par catégorie : celles-ci voient un
> périmètre, celui-ci voit l'ensemble.

Doctrine de référence : §4 de `00-METHODE.md`.

## Le compte

| Mesure | Valeur |
|---|---|
| Fichiers produisant un PDF | **41** |
| — utilisant `OfficialPdfKit` | **41** |
| — **sans** le kit | 0 |
| Fichiers appelant `showPdfPreviewDialog` | 41 |
| ⛔ Appels actifs à `Printing.layoutPdf(` | **9** dans **8** fichiers |
| ⚠️ Tables à la main (sans `tableSection`) | **3** |
| ⚠️ Polices téléchargées (`PdfGoogleFonts`) | **1** |

**L'adoption du kit est totale : 41 producteurs sur 41.** Le socle documentaire
est sain — le problème n'est pas l'absence d'infrastructure, mais les
**contournements ponctuels** ci-dessous.

## ⛔ Violation 1 — `Printing.layoutPdf(` : 9 appels, TROIS situations distinctes

> ⚠️ **Correction du 2026-09-09.** La première rédaction de cette section
> annonçait « 9 appels qui ouvrent la boîte d'impression système au lieu de
> l'aperçu ». C'était **trop large**. En ouvrant chaque site d'appel, les neuf
> se répartissent en trois cas de gravité très différente. Un balayage
> automatique compte des occurrences ; il ne lit pas le chemin de l'utilisateur.

### A. Vraie violation — impression aveugle d'une pièce comptable (5 sites)

`printReceipt` et `printInvoice` étaient appelés **directement** depuis un
bouton de ligne ou de fiche, **sans aucun aperçu**. Sur un poste Windows dont
l'imprimante par défaut est « Microsoft Print to PDF » — le cas courant —
cliquer « Imprimer » sur un **reçu** ou une **facture** produisait un fichier
que personne n'avait vu, à un emplacement que personne n'avait choisi.

| Site d'appel | Espace | Pièce |
|---|---|---|
| `features/super_admin/screens/receipts_screen.dart:416` | Fondateur | reçu (action de ligne) |
| `features/super_admin/screens/receipts_screen.dart:785` | Fondateur | reçu (fiche détail) |
| `features/super_admin/screens/factures/facture_detail.dart:163` | Fondateur | facture |
| `features/admin_groupe/screens/admin_subscription_billing.dart:231` | Réseau | facture d'abonnement |
| `features/admin_groupe/screens/admin_subscription_billing.dart:235` | Réseau | reçu d'abonnement |

**CORRIGÉ le 2026-09-09** : `printReceipt` / `printInvoice` remplacés par
`ReceiptPdfService.apercuRecu(context, …)` et
`InvoicePdfService.apercuFacture(context, …)`, qui passent par
`showPdfPreviewDialog` (aperçu, puis Imprimer ou Enregistrer).

### B. Méthode morte portant le geste banni (2 sites)

Aucun appelant — les écrans concernés étaient déjà passés à l'aperçu partagé.
Le danger n'était pas l'exécution mais la **recopie** : le prochain écran qui
cherche « comment imprimer un bilan ? » trouvait la méthode et la rebranchait.

| Méthode | Fichier |
|---|---|
| `AcademicYearPdfService.printReport` | `features/admin_groupe/services/admin_year_pdf_service.dart:331` |
| `ProgrammesPdfService.printDoc` | `features/structure/services/programmes_pdf_service.dart:209` |

**CORRIGÉ le 2026-09-09** : les deux méthodes sont retirées, avec la note qui
dit pourquoi. C'étaient les deux derniers `Printing.layoutPdf` de l'espace
école et de l'espace réseau.

### C. Derrière un aperçu maison — pas un défaut, une duplication (2 sites, 5 méthodes)

`printAdmin`, `printGroup`, `printModule`, `printPlan`, `printSubscription`
sont appelés **depuis l'intérieur** d'une modale `*_print_preview.dart` qui
affiche déjà un `PdfPreview` (avec `allowPrinting: false`). L'utilisateur **a
vu** le document avant que la boîte système ne s'ouvre. La doctrine « aperçu
obligatoire » est donc respectée **sur le fond**.

Ce qui reste est une **dette de duplication** : cinq modales d'aperçu écrites à
la main (~300 lignes chacune) là où `showPdfPreviewDialog` existe. Elles ont
leur propre barre d'actions, leur propre gestion d'erreur, leur propre bouton
« Copier ». C'est une **décision produit**, pas une correction : les unifier
change l'aspect de cinq écrans du fondateur. **Laissé en l'état, à arbitrer.**

## ⚠️ Violation 2 — polices téléchargées

| Fichier | Ligne | Appel |
|---|---|---|
| `features/super_admin/services/module_pdf_service.dart` | 54 | `emojiFont = await PdfGoogleFonts.notoColorEmoji()` |

**Un seul cas, et c'est la police d'émoji, pas la police de texte** : les
accents ne sont donc pas en jeu. Reste qu'un poste d'école congolaise hors
ligne verra les émojis du document disparaître sans message. À trancher :
embarquer la police, ou retirer les émojis du document officiel — la
seconde option est probablement la bonne pour un papier d'État.

## ⚠️ Violation 3 — table construite à la main

`OfficialPdfKit.tableSection` découpe en blocs. Sans lui, une section longue
fait boucler `MultiPage` jusqu'à `TooManyPagesException` : **aucun document**
n'est produit, pas même tronqué.

| Fichier | Lignes | Utilise le kit par ailleurs ? |
|---|---|---|
| `features/students/services/etat_rentree_pdf_service.dart` | 475 | oui |
| `features/structure/services/emploi_du_temps_pdf_service.dart` | 342 | oui |
| `features/students/services/registre_matricule_pdf_service.dart` | 269 | oui |

## Écrans de liste sans aucune sortie — 23 sur 90

Un écran qui affiche une liste et n'offre ni PDF, ni export, ni fiche
imprimable. **À qualifier un par un par l'agent de la catégorie** : toute
donnée n'a pas vocation à sortir sur papier. Les colonnes suivantes donnent
en même temps la profondeur UI (§8 du socle).

| Écran | Lignes | Recherche | État vide | État erreur | `catch(_){}` |
|---|---|---|---|---|---|
| `features/super_admin/screens/ai_screen.dart` | 1102 | oui | oui | oui | — |
| `features/super_admin/screens/reports_screen.dart` | 1043 | **non** | oui | oui | — |
| `features/admin_groupe/screens/admin_module_screen.dart` | 887 | **non** | oui | oui | — |
| `features/super_admin/screens/national_map_screen.dart` | 808 | **non** | **non** | oui | — |
| `features/super_admin/screens/payment_methods_screen.dart` | 791 | oui | oui | oui | — |
| `features/super_admin/screens/tickets_screen.dart` | 652 | oui | oui | oui | — |
| `features/user/screens/user_dashboard_screen.dart` | 614 | **non** | **non** | **non** | — |
| `features/communication/screens/support_requester_screen.dart` | 545 | oui | oui | oui | — |
| `features/staff/screens/conges_screen.dart` | 479 | oui | oui | oui | — |
| `features/classes/screens/classes_screen.dart` | 393 | **non** | oui | oui | **1** |
| `features/classes/screens/classe_detail_screen.dart` | 387 | **non** | oui | oui | — |
| `features/structure/screens/school_calendar_screen.dart` | 386 | **non** | oui | oui | — |
| `features/admin_groupe/screens/admin_fees_screen.dart` | 382 | **non** | oui | oui | — |
| `features/vie_scolaire/screens/bibliotheque_screen.dart` | 371 | oui | oui | **non** | — |
| `features/admin_groupe/screens/admin_modules_screen.dart` | 335 | **non** | oui | oui | — |
| `features/cartes/screens/cartes_screen.dart` | 303 | **non** | oui | oui | — |
| `features/examens/screens/examens_screen.dart` | 297 | **non** | oui | oui | — |
| `features/admin_groupe/screens/admin_rattachement_screen.dart` | 284 | **non** | oui | oui | — |
| `features/structure/screens/cahier_textes_screen.dart` | 280 | **non** | oui | oui | — |
| `features/students/screens/registre_screen.dart` | 255 | oui | oui | oui | — |
| `features/user/screens/user_settings_screen.dart` | 243 | **non** | **non** | **non** | — |
| `features/structure/screens/academic_structure_screen.dart` | 234 | **non** | oui | oui | — |
| `features/profil/screens/mon_profil_screen.dart` | 140 | **non** | oui | oui | — |

## `catch (_) {}` — recensement du zéro menteur

**116 occurrences actives dans 59 fichiers.** Un `catch` qui avale transforme
une lecture ratée en zéro affiché comme un fait. La règle : « — », jamais 0,
et un bandeau nomme les mesures manquantes AVANT les chiffres.

| Fichier | Occurrences |
|---|---|
| `features/admin_groupe/providers/admin_access_provider.dart` | 7 |
| `features/audit/providers/audit_data.dart` | 6 |
| `features/super_admin/providers/modules_provider.dart` | 6 |
| `features/admin_groupe/providers/admin_module_provider.dart` | 5 |
| `features/super_admin/providers/plans_provider.dart` | 5 |
| `features/super_admin/providers/subscriptions_provider.dart` | 5 |
| `features/admin_groupe/providers/admin_nav_provider.dart` | 4 |
| `features/admin_groupe/providers/admin_users_provider.dart` | 4 |
| `features/auth/services/session_keeper.dart` | 4 |
| `features/communication/widgets/audio_recorder_button.dart` | 4 |
| `features/communication/providers/announcements_provider.dart` | 3 |
| `features/super_admin/providers/administrators_provider.dart` | 3 |
| `features/super_admin/providers/school_groups_provider.dart` | 3 |
| `services/powersync/upload_outbox.dart` | 3 |
| `features/auth/screens/reprise_poste_screen.dart` | 2 |
| `features/communication/providers/announcement_interactions_provider.dart` | 2 |
| `features/communication/providers/stories_provider.dart` | 2 |
| `features/super_admin/services/admin_pdf_service.dart` | 2 |
| `features/super_admin/services/group_pdf_service.dart` | 2 |
| `features/super_admin/services/module_pdf_service.dart` | 2 |
| `features/super_admin/services/subscription_pdf_service.dart` | 2 |
| `services/powersync/powersync_connector.dart` | 2 |
| `services/powersync/powersync_service.dart` | 2 |
| `core/utils/media_compression.dart` | 1 |
| `features/admin_groupe/providers/admin_dashboard_provider.dart` | 1 |
| `features/admin_groupe/providers/admin_regional_provider.dart` | 1 |
| `features/admin_groupe/providers/admin_schools_provider.dart` | 1 |
| `features/admin_groupe/providers/admin_support_provider.dart` | 1 |
| `features/admin_groupe/providers/regional_table_provider.dart` | 1 |
| `features/admin_groupe/providers/subscription_access_provider.dart` | 1 |
| `features/admin_groupe/screens/schools/school_detail_dialog.dart` | 1 |
| `features/admin_groupe/services/exam_statistics_pdf_service.dart` | 1 |
| `features/admin_groupe/services/group_students_pdf_service.dart` | 1 |
| `features/admin_groupe/services/passage_merit_pdf_service.dart` | 1 |
| `features/admin_groupe/services/regional_pdf_service.dart` | 1 |
| `features/admin_groupe/services/reports_pdf_service.dart` | 1 |
| `features/admin_groupe/services/student_dossier_pdf_service.dart` | 1 |
| `features/admin_groupe/widgets/exam_publication_dialog.dart` | 1 |
| `features/classes/screens/classes_screen.dart` | 1 |
| `features/communication/providers/conversation_read_provider.dart` | 1 |
| `features/communication/providers/events_provider.dart` | 1 |
| `features/communication/providers/group_chat_provider.dart` | 1 |
| `features/communication/providers/message_unread_provider.dart` | 1 |
| `features/communication/providers/messages_provider.dart` | 1 |
| `features/communication/providers/notifications_provider.dart` | 1 |

*(14 fichiers supplémentaires, 1 occurrence chacun ou presque.)*

## Fichiers > 500 lignes — dette de structure

**82 fichiers** dépassent la cible du projet (alerte à 400, cible 500).

| Fichier | Lignes |
|---|---|
| `services/powersync/powersync_schema.dart` | **1709** |
| `features/classes/screens/classes_parts.dart` | **1279** |
| `features/super_admin/screens/settings_screen.dart` | **1197** |
| `features/super_admin/screens/receipts_screen.dart` | **1149** |
| `features/communication/screens/messagerie_staff_thread.dart` | **1145** |
| `features/super_admin/screens/ai_screen.dart` | **1102** |
| `features/admin_groupe/screens/regional/regional_map.dart` | **1045** |
| `features/super_admin/screens/reports_screen.dart` | **1043** |
| `features/communication/providers/messages_provider.dart` | **1003** |
| `features/evaluation/providers/passage_provider.dart` | **915** |
| `features/admin_groupe/providers/admin_settings_provider.dart` | **897** |
| `features/evaluation/screens/cloture_examen_section.dart` | **895** |
| `features/admin_groupe/screens/regional_table_mode.dart` | **894** |
| `features/admin_groupe/providers/admin_reports_provider.dart` | **890** |
| `features/admin_groupe/screens/admin_module_screen.dart` | **887** |
| `features/communication/screens/announcements_feed.dart` | **885** |
| `features/evaluation/screens/passage_parts.dart` | **844** |
| `features/admin_groupe/providers/exam_archives_provider.dart` | **810** |
| `features/super_admin/screens/national_map_screen.dart` | **808** |
| `core/services/official_pdf_kit.dart` | **806** |
| `features/super_admin/screens/payment_methods_screen.dart` | **791** |
| `core/router/app_router.dart` | **781** |
| `features/super_admin/providers/super_dashboard_provider.dart` | **773** |
| `features/communication/widgets/feed_right_rail.dart` | **756** |
| `features/auth/screens/widgets/vitrine_shell.dart` | **737** |
| `features/admin_groupe/providers/admin_subscription_provider.dart` | **732** |
| `features/classes/providers/class_provider.dart` | **723** |
| `features/evaluation/providers/cloture_examen_provider.dart` | **720** |
| `features/admin_groupe/providers/admin_dashboard_provider.dart` | **719** |
| `features/students/screens/add_inscription_steps_1_2.dart` | **711** |
| `features/finance/providers/paiements_provider.dart` | **708** |
| `features/communication/screens/announcements_feed_social.dart` | **696** |
| `features/communication/screens/group_settings_dialog.dart` | **694** |
| `core/widgets/app_shell/app_header.dart` | **690** |
| `features/students/widgets/inscription_form_kit.dart` | **684** |
| `features/admin_groupe/screens/admin_fee_form_dialog.dart` | **679** |
| `features/admin_groupe/screens/admin_year_department_sheet.dart` | **656** |
| `features/super_admin/screens/tickets_screen.dart` | **652** |
| `features/super_admin/screens/economie_screen.dart` | **643** |
| `features/super_admin/services/financial_pdf_service.dart` | **642** |
| `core/widgets/list_chrome.dart` | **636** |
| `features/communication/providers/announcements_provider.dart` | **630** |
| `features/communication/widgets/feed_media.dart` | **629** |
| `features/evaluation/screens/passage_screen.dart` | **627** |
| `features/admin_groupe/screens/admin_licence_card.dart` | **626** |

*(37 fichiers supplémentaires entre 501 et 624 lignes.)*
