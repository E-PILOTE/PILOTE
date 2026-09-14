# PASSE TRANSVERSALE — DOUBLONS ENTRE CATÉGORIES

**Objet** : ce qui est calculé, écrit ou affiché **deux fois** dans la
plateforme, en traversant les frontières de catégorie.
**Date** : 2026-09-09 · conduite après les douze rapports, pour pouvoir
trianguler.

> **Le doublon qui compte n'est pas le code recopié.** C'est **la règle
> recopiée** : deux endroits qui répondent à la même question et finissent par
> ne plus répondre pareil. Le précédent connu de ce produit est le revenu
> mensuel affiché 120 000 F sur un écran et 184 000 F sur un autre.
>
> Cette passe cherche donc les **règles en double**, pas les lignes en double.

---

## A. Méthode

Trois filtres, appliqués dans cet ordre :

1. **Deux endroits répondent-ils à la même question métier ?** (pas : « le code
   se ressemble-t-il ».)
2. **Peuvent-ils diverger ?** Si l'un lit une colonne que l'autre ignore, oui.
3. **Divergent-ils déjà ?** Vérifié en base de production. Un doublon
   *dormant* reste un doublon : il attend une saisie.

Un doublon **légitime** est écarté explicitement : `profil/`, `audit/` et
`communication/` sont des modules **scope-aware** — un seul code, périmètre
déduit du rôle. Les routes `/super/profil`, `/admin/profil` et `/user/profil`
mènent au même écran ; c'est la doctrine, pas un défaut.

---

## B. Les doublons confirmés

### B.1 ✅ CORRIGÉ (client) · ⏳ migration écrite — TROIS moteurs de moyenne, deux lisaient le mauvais coefficient

> `03-cat-evaluation.md` §E.1 avait posé la question — « décider aussi du
> coefficient : `class_subjects.coefficient` (bulletin) ou
> `subjects.coefficient` (les deux autres) ». Cette passe la tranche en
> comptant les moteurs et en interrogeant la base.

| | Moteur ÉCOLE | Moteur RÉSEAU | Moteur PALMARÈS |
|---|---|---|---|
| Où | `features/evaluation/providers/bulletins_provider.dart` | `features/admin_groupe/providers/student_results_provider.dart` | `get_passage_merit()` — **en base** |
| Mode | offline (PowerSync) | online (Supabase) | SQL, appelé par `passage_merit_provider` |
| Sortie | `bulletins.overall_average`, `bulletin_subject_lines` — **ce que reçoit la famille** | le dossier de l'élève consulté par le réseau et le ministère | le palmarès du réseau |
| Coefficient de matière | `COALESCE(cs.coefficient, subj.coefficient)` — l.153 ✅ | `subject?['coefficient']` — l.182 ⚠️ | `sub.coefficient::numeric AS coef_matiere` ⚠️ |

**Deux des trois lisent le coefficient PAR DÉFAUT.** Vérifié dans la
définition de la fonction en base le 2026-09-09.

Les trois calculent **la même chose** : la moyenne générale d'un élève, à
partir des mêmes `evaluations` et des mêmes `grades`. Les trois appliquent les
mêmes règles fines — absence ignorée (« la compter 0 inventerait un échec »),
normalisation `score / max_score * 20`, pondération par le coefficient de
l'évaluation puis par celui de la matière.

**Ils divergent sur un point, et c'est le point qui décide du résultat.**

`class_subjects.coefficient` existe précisément pour qu'une classe puisse
surcharger le coefficient d'une matière ; `data/models/subject_model.dart:7` le
dit noir sur blanc : « `coefficient` n'est qu'un coefficient **PAR DÉFAUT**,
proposé ». L'écran d'édition existe et écrit vraiment
(`class_subjects_provider.dart:188` — `UPDATE class_subjects SET coefficient = ?`).

Le moteur école lit le coefficient **effectif**. Le moteur réseau et la
fonction `get_passage_merit` lisent le coefficient **par défaut**, et ne
joignent jamais `class_subjects`.

**Vérifié en base le 2026-09-09** :

```sql
select count(*) filter (where cs.coefficient is distinct from s.coefficient) …
→ divergents = 0  sur  total = 4 564
```

**Le défaut est donc DORMANT** : aujourd'hui aucune classe n'a surchargé un
coefficient, et les trois moteurs tombent d'accord par accident. Le jour où un
proviseur pondère les mathématiques à 5 dans sa Terminale C, **le bulletin de
l'école, le dossier consulté par le ministère et le palmarès du réseau
afficheront des moyennes différentes pour le même élève, le même trimestre** —
et personne ne saura laquelle est bonne.

> C'est exactement la forme du précédent « 120 000 F / 184 000 F » : deux
> écrans, deux lectures, et un fondateur qui arbitre entre ses propres écrans.

**Foyer proposé** : le moteur école. C'est lui qui produit le document
officiel — le bulletin que reçoit la famille — et lui qui connaît le
coefficient effectif. Deux issues honnêtes :

- **(a)** faire lire `class_subjects.coefficient` aux **deux** autres : la
  requête du moteur réseau a déjà la classe (`k.classId`), il ne manque qu'une
  jointure ; `get_passage_merit` a `ev.class_id` sous la main. ⚠️ La fonction
  SQL se corrige par **migration**, donc elle se déploie séparément du client :
  les deux moitiés doivent partir dans le bon ordre ;
- **(b)** faire lire au réseau les `bulletin_subject_lines` **déjà calculées**
  par l'école plutôt que de recalculer — plus juste encore, puisque le réseau
  verrait alors exactement ce que la famille a reçu, mais indisponible tant
  qu'aucun bulletin n'est publié.

**Ce qui a été fait (2026-09-10)** — l'issue (a), dans ses deux moitiés :

| Moitié | État |
|---|---|
| **Client** — `student_results_provider.dart` lit `class_subjects` pour la classe consultée et passe le coefficient effectif à `computeResults` | ✅ **appliqué** |
| **Base** — `database/migrations/0205_le_palmares_lisait_le_coefficient_par_defaut.sql` : `LEFT JOIN class_subjects` + `COALESCE` dans `get_passage_merit` | ⏳ **écrite, NON appliquée** |

⚠️ **La migration n'a pas été exécutée sur la base de production.** C'est un
geste de déploiement, il appartient au fondateur. Prise isolément, chacune des
deux moitiés est aujourd'hui un **no-op exact** (0 divergence sur 4 564
lignes) : elles peuvent donc partir dans n'importe quel ordre, sans fenêtre de
risque.

⚠️ La jointure ajoutée est un **LEFT JOIN**, et c'est essentiel : en INNER, les
notes d'une matière que la classe n'a pas explicitement pondérée
**disparaîtraient** de la moyenne. Ce serait changer le résultat au lieu de le
corriger.

**Gardé par** `test/coefficient_effectif_test.dart` : le comportement du moteur
réseau (le coefficient de la classe prime, la matière non pondérée garde son
défaut, la moyenne de classe suit la même règle) **et** la présence de la règle
dans les trois sources — le fichier du bulletin, celui du dossier réseau, et le
fichier de migration.

*Reste ouvert : l'issue (b), faire lire au réseau les `bulletin_subject_lines`
déjà calculées plutôt que de recalculer. Effort : M.*

---

### B.2 ✅ CORRIGÉ — Deux façons de préparer la rentrée, deux classes différentes

| | Chemin « Calendrier scolaire » | Chemin « Passage » |
|---|---|---|
| Entrée | `structure/screens/calendar_rollover.dart:58` | `/user/passage` → `structure/providers/class_rollover.dart:93` |
| Fonction | `copySchoolClassesToYear` (`academic_year_provider.dart:211`) | `class_rollover` |
| Colonnes écrites | `name, capacity, room, level_id, main_teacher_id` | **+ `cycle_code`, `level_code`, `level_order`, `filiere_code`, `filiere_label`** |

Deux écrans font le même geste — recopier les classes d'une année vers la
suivante — et produisent deux objets différents.

Les cinq colonnes manquantes sont **dénormalisées expressément** :
`createStructuredClass` dit d'elles qu'elles sont « les champs dénormalisés
dont dépendent les KPI Inscriptions → cohérence garantie ». Elles sont lues
telles quelles par `etat_rentree_provider.dart:183`, `inscriptions_data_provider.dart:347`
(`ORDER BY level_order`), `documents_provider.dart:109` et
`students_registry_provider.dart:148`.

**Et les perdre ne vide rien** — c'est ce qui rend le défaut méchant. Les
lectures retombent sur `?? 99` / `?? 999`. Une classe de 6ᵉ préparée depuis le
Calendrier scolaire se serait donc rangée **derrière la Terminale** sur l'État
de rentrée, le document dont dépendent les dotations. Pas une erreur : un faux
ordre.

**Vérifié en base** : 554 classes, **0** sans `cycle_code` — le défaut n'a
jamais été déclenché en production. *Corrigé le 2026-09-09* :
`copySchoolClassesToYear` recopie désormais les cinq colonnes.

---

### B.3 ✅ CORRIGÉ — `createClass`, la porte amputée à côté de la porte complète

`features/classes/providers/class_provider.dart` portait **deux** créateurs de
classe voisins :

- `createClass` — sans les colonnes dénormalisées, **aucun appelant** ;
- `createStructuredClass` — complet, utilisé par les **deux** écrans qui créent
  une classe (`classes_parts.dart:746`, `academic_structure_class_form.dart:101`).

`grep -rn "\bcreateClass\b" lib/ test/` → une seule occurrence : sa propre
définition.

Ce n'est pas du code mort inoffensif : c'est un piège. La fonction amputée
porte le nom le plus court et le plus évident ; le prochain écran qui crée une
classe a une chance sur deux de la choisir. *Supprimée le 2026-09-09*, avec la
raison écrite à sa place.

---

## C. Les candidats écartés — et pourquoi

Un rapport de doublons qui ne dit pas ce qu'il a **innocenté** n'est pas
vérifiable.

| Candidat | Verdict | Preuve |
|---|---|---|
| **Le barème de mentions** | ✅ source unique | `mentionFor` dans `core/utils/mention.dart`, 8 appelants, **aucune recopie** du barème. Cherché : `grep -rn "Très Bien\|Assez Bien"` hors du fichier → 0 |
| **Le dû de scolarité** | ✅ source unique | `duScolarite` (`finance/providers/obligation_provider.dart:123`). `decompte_du_provider` dit lui-même : « Ce fichier ne DÉCIDE de rien. Il décompose ce que `duScolarite` calcule ». `paiements_provider` l'invoque aussi |
| **Le tarif d'un groupe** | ✅ source unique | `core/utils/tarif_ecoles.dart`, importé par 8 écrans (économie, plans, abonnements, tableaux de bord, rapports, IA). `tarif_ecoles_test` le compare aux valeurs de la base |
| **Les deux « états des effectifs »** (`/user/etat-rentree` et `/user/rapports`) | ✅ deux documents distincts, populations identiques | Les deux filtrent `status = 'active'` ET `COALESCE(s.is_active,1) <> 0` (`etat_rentree_provider.dart:194`, `rapports_provider.dart:58`). L'un est l'état de rentrée par niveau, l'autre l'état des effectifs par cycle et par sexe : deux documents, deux destinataires |
| **`profil/`, `audit/`, `communication/` dans trois espaces** | ✅ doublon *voulu* | Modules scope-aware. `auditScopeProvider` est « le SEUL point de divergence entre les deux espaces » (`audit_scope.dart:11`) |
| **Les entrées natives de la barre** | ✅ déjà déduplíqué | `socle_natif.dart` est la déclaration unique, née précisément d'un triple écrit (deux fois dans `nav_config`, une en base) dont les copies avaient divergé — « Messages » d'un côté, « Messagerie » de l'autre. `socle_natif_test` garde l'alignement avec le déclencheur 0177 |
| **`tutelle_pdf_service` / `tutelle_fiche_pdf_service`** | ✅ factorisé | `tutelle_pdf_commun.dart` porte ce qu'ils partagent. C'est l'inverse d'un doublon |

---

## D. Redondances d'affichage — le sujet du fondateur

Distinct des doublons de règle : ici rien n'est faux, mais la même mesure
occupe deux écrans, et le lecteur ne sait plus lequel fait foi.

| # | Mesure | Écran A | Écran B | Doctrine | Reste à trancher |
|---|---|---|---|---|---|
| 1 | Effectif de l'école | Tableau de bord `/user/dashboard` | État de rentrée, Rapports | Usage/volumes = Dashboard ; document officiel = Rapports | ✅ conforme — le tableau de bord ne signe rien |
| 2 | Effectif du réseau | Tableau de bord groupe | Rapports du réseau | idem | ✅ conforme |
| 3 | Recouvrement | Tableau de bord groupe (courbe) | Rapports du réseau (état signable) | idem | ✅ conforme |
| 4 | Nombre d'écoles d'un groupe | 6 lectures distinctes dans `super_admin` | — | **Une seule source** attendue : le PRIX en dépend | ⚠️ **six lectures indépendantes de `schools`, toutes désormais paginées, mais aucune n'est la « source »**. Voir E.2 |

---

## E. Les trois choses à faire

1. **Trancher le coefficient effectif (B.1).** C'est le seul doublon qui peut
   produire deux chiffres officiels contradictoires sur le même élève. Il est
   dormant : c'est le bon moment.
   *Effort : S · Entrée : `admin_groupe/providers/student_results_provider.dart:182`.*

2. **Donner UN foyer au nombre d'écoles d'un groupe.** Six endroits comptent
   `schools` par `group_id` (`school_groups_provider`, `subscriptions_provider`,
   `reports_provider`, `super_dashboard_provider`, `national_map_provider`,
   `ai_screen`). Ils sont tous corrects aujourd'hui — et le prix d'un groupe
   dépend de ce nombre (mig. 0159). Six lectures indépendantes d'un chiffre
   facturable, c'est six occasions de diverger.
   *Effort : S — un provider `nombreEcolesParGroupeProvider`, que les six
   lisent.*

3. **Poser un test qui confronte les TROIS moteurs de moyenne.** Même jeu de
   notes en entrée, même résultat attendu en sortie — `bulletinComputationProvider`,
   `computeResults` et `get_passage_merit`. C'est le seul garde-fou qui
   survivra aux deux prochaines évolutions du bulletin, et le seul qui verra la
   dérive quand elle viendra de la base plutôt que du client.
   *Effort : M.*
