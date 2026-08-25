---
name: metp-partage-dec-classes-passage
description: "⚠️ RÈGLE MÉTIER FONDATRICE : la plateforme envoie des listes de candidats à la DEC, qui renvoie des LISTES D'ADMIS sans notes → aucun classement d'examen possible ; le mérite = classes de passage, par trimestre"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-27T18:36:42.124Z
---

**Expliqué par le user (fonctionnaire DSIC/METP) les 2026-07-27 — sa parole prime, cf. [[user-fonctionnaire-dsic-metp]].** Commits `681cc40` puis `8ef9863`, app v3.0.9.

## Le partage des rôles — il commande toute la notion de mérite

| | Classes d'examen | Classes de passage |
|---|---|---|
| Niveaux (METP) | CM2→CEPE, 3e→BET, Tle→Bac | 6e, 5e, 4e, 2nde, 1ère, CP→CM1 |
| Élèves (réseau METP) | **81** | **216** |
| Rôle de la plateforme | **transmet la LISTE DES CANDIDATS à la DEC** | **calcule les moyennes** |
| Retour | **liste d'ADMIS, SANS NOTES** | produites ici, **par trimestre** |

**⚠️ Le sens du retour DEC (dit par le user le 2026-07-27, 2ᵉ précision)** : la DEC **publie des listes d'admis**, pas de relevés de notes. « Admis / ajourné » est **binaire** → **aucun classement d'examen n'est possible**, on ne départage pas 60 admis entre eux. Ne jamais reproposer un palmarès, un podium ou un « top » adossé aux examens d'État.

**⚠️ L'erreur que j'avais commise** : bâtir le palmarès sur `exam_candidates.average` — colonne **facultative** que la DEC n'alimente pas, remplie seulement si une école saisit un relevé qu'elle détient. À l'échelle réseau elle est vide : le classement serait sorti vide en séance. Les moyennes affichées venaient du seed de démo.

**Correctif de ma propre note précédente** : j'avais écrit qu'« aucun écran ne remplit `average`/`result` ». Faux — `exam_result_dialog.dart` + `setResult()` (`exam_registration_provider.dart`) enregistrent un résultat **reçu** de la DEC (source `saisie_manuelle`, deux horloges `decided_at` ≠ `result_received_at`, mig 0053). C'est `exam_dossier_actions.dart` qui n'écrit rien de tel. La saisie existe donc ; c'est la **moyenne** qui est facultative et absente en pratique.

## Conséquence de conception : UNE SEULE BASE DE MÉRITE
Écran « Meilleurs élèves » = **classes de passage uniquement**, sans onglets (l'onglet « Examens d'État » a existé et a été **retiré**, commit `8ef9863` — fichiers supprimés : `merit_exam_view`, `merit_table`, `admin_merit_provider`, `merit_pdf_service`, `merit_ranking_test`). Les mêler comparerait une moyenne d'établissement à une épreuve nationale.

**Ce que le ministère lit légitimement des examens** — taux de réussite, admis, transmissions, par filière et département — vit sur **« Examens nationaux »** (`admin_exams_provider` : `withResult`, `admitted`, `transmissions`), qui ne demande que l'admission. Pas de doublon à créer ailleurs.

`DossierDistinction` a été **reprise** pour le classement de passage : le bandeau du dossier porte rang + périmètre + **base du calcul** (« Contrôle continu, calculé par l'établissement ») + moyenne de la classe — sans quoi un dossier imprimé se lirait comme une distinction d'examen d'État.

## Le trimestre est l'UNITÉ, pas un filtre
Une moyenne n'existe pas hors d'une période. Sélecteur Période (T1/T2/T3/année) sur le classement **et** dans le dossier de l'élève (défaut : trimestre en cours ; sentinelle `_unset` car `null` = « année entière »). La période est écrite à l'écran **et** dans le document.

## `get_passage_merit` — migration 0061
Agrégation **côté serveur** (SECURITY INVOKER → RLS du demandeur) : rapatrier les notes de 1 000 écoles pour les moyenner sur le poste est intenable.
- **Classe de passage = `coalesce(exam_override_id, exam_id) is null OR exam_excluded`** — complément exact de la classe d'examen déjà dérivée par le trigger `trg_classes_derive_exam`. Le critère est LU, jamais réinventé.
- Règles **identiques** à `computeResults()` côté Dart, sinon un 1ᵉʳ du classement afficherait une autre moyenne dans son dossier : évaluations `status='published'` seulement, **absence exclue (jamais 0)**, note ramenée sur 20 via `max_score`, pondération coef. évaluation puis coef. matière.
- Renvoie la **moyenne de la classe** : 16/20 dans une classe à 15 ne désigne pas le même élève que 16/20 dans une classe à 9.

## ⚠️ Deux pièges techniques trouvés au passage
- **`.order()` de supabase-dart est DESCENDANT par défaut.** 35 listes étaient triées à l'envers (écoles Z→A, profils et modules en ordre inverse, plans par prix décroissant, trimestres 3→1). `ascending:` est désormais explicite partout dans `lib/`.
- **Polices PDF** : `PdfGoogleFonts` téléchargeait depuis fonts.gstatic.com ; sans réseau ni cache → repli sur **Helvetica, qui n'a pas d'Unicode** → tous les accents sautaient des documents officiels. Désormais embarquées dans `assets/fonts/` et mises en cache par session.

## Données de démo
`seed_trimestres.sql` duplique les évaluations du T3 vers T1/T2 avec progression : moyenne réseau **11,67 → 12,38 → 12,92**. Le niveau d'un élève dérive de sa moyenne d'examen quand elle existe.

Voir [[ministere-palmares-eleves-reseau]], [[examens-nationaux-socle]], [[bareme-mention-source-unique]].
