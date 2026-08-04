# Frais de scolarité — public contre privé

**Date** : 2026-08-04 · **Branche** : `feat/livraison-windows` · **Échéance** : déploiement national du 2 octobre 2026

---

## 1. Le problème posé

La plateforme accueille deux catégories d'écoles, héritées du secteur de leur groupe
(`school_groups.group_type` → `schools.school_type`, public XOR privé, migration 0060).
Dans le privé, l'élève paie une scolarité mensuelle. Dans le public, non.

L'application ne fait aucune différence entre les deux.

## 2. Le cadre réel (état au 4 août 2026)

**La loi.** Loi scolaire n° 25-95 du 17 novembre 1995, article 1 : « l'enseignement
public est gratuit ». Une mensualité en école publique n'est pas une pratique
discutable — elle est illégale.

**La pratique**, corrigée par le ministère (DSIC/METP) :

- Les **inscriptions sont payantes en école publique depuis ~2022**. Le web ouvert ne
  le documente pas ; la parole du ministère fait foi. Les montants seront saisis par
  le ministère lui-même : nous n'avons pas à les connaître.
- La **cotisation APE** finance le fonctionnement de l'établissement.
- Les **enseignants non fonctionnaires sont payés directement par l'État** depuis
  l'accord du 16 octobre 2023 (bourse mensuelle, contrats de 5 ans renouvelables,
  signé par le METP **et** le MEPSA). Le METP verse ; le MEPSA accuse 10 mois
  d'arriérés (déclaration RNEC du 29 juillet 2026), et l'APE y comble encore le trou
  en pratique.
- Les **frais d'examen** sont fixés par l'État, identiques dans les deux secteurs, et
  publiés par note de service (ex. N°0015/METP-CAB/DECTP-SD du 09/12/2024).
  Officiel congolais : BAC 5 000 · BEPC 4 000 · CEPE 2 000 · concours 3 000.
  Candidat libre : 15 000 · 10 000 · 3 000.
- La **surfacturation est massive et dénoncée publiquement par l'APEEC** : 25 000 à
  35 000 F réclamés pour le BAC contre 5 000 officiels, plus de 40 000 par endroits.

**Répartition sur la plateforme** : public/MEPSA 18 écoles (3 groupes) ·
public/METP 12 (1 groupe) · privé/MEPSA 7 (3 groupes). 8 130 élèves dans le public,
974 dans le privé. Cycles : `primaire`, `college`, `lycee`, `formation_pro`.

## 3. Ce que fait l'application aujourd'hui — audit

**Le secteur n'est lu nulle part dans l'espace école.** `school_type` / `group_type`
n'apparaissent que dans les écrans `admin_groupe`, pour une pastille et un filtre.
Zéro occurrence dans `features/finance/`, le tableau de bord ou la barre latérale.
La donnée descend pourtant bien sur le poste (`SELECT *` du bucket `by_group`,
déclarée `powersync_schema.dart:157`).

Conséquences, sur 30 écoles publiques :

- Le formulaire de barème propose « **Mensualité** » — valeur **par défaut** de l'enum
  `fee_type` en base. L'application invite à un acte illégal.
- La page Paiements affiche « Recouvrement », « Élèves à jour : 0/430 », « 0 % ont
  payé ». Elle accuse d'un échec de collecte une école qui n'a rien à collecter.
- `exam_fees_provider.dart:141` — `setExamFeeAmount`, commenté « révision
  ministérielle » — laisse **l'école fixer elle-même le montant de son frais
  d'examen**, hors ligne. Le mécanisme de surfacturation dénoncé par l'APEEC est
  implémenté comme une fonctionnalité.

**État des données** : `fee_structures` 0 ligne · `student_payments` 0 · `expenses` 0 ·
`budget_lines` 0. Le module n'a jamais servi : rien à migrer, la correction est gratuite.

## 4. Décisions actées

| # | Décision | Auteur |
|---|---|---|
| D1 | La cotisation APE est tracée **nominativement** (barème, encaissement par élève, reçu, qui a versé / qui n'a pas). | Ministère |
| D2 | **Tout montant est défini par `admin_groupe`.** L'école reçoit et applique — elle n'écrit aucun barème. Un ministère est un groupe scolaire comme un autre. | Ministère |
| D3 | Les tarifs peuvent **changer à tout moment** sur décision du groupe. | Ministère |
| D4 | Un encaissement au-dessus du tarif officiel **passe**, mais il est **tracé et remonté** au groupe. On ne bloque pas. | Ministère |
| D5 | Le groupe définit les **motifs d'exonération** ; l'école **constate** qu'un élève y a droit. Même grammaire que l'arrivée d'un agent (migration 0091). | Ministère |
| D6 | Les montants réels sont saisis par le ministère. Nous livrons la table vide. | Ministère |
| D7 | Un paiement est un **versement sur une obligation**, pas une transaction autonome. Le montant se **choisit** dans les barèmes du groupe ; l'élève peut **avancer une partie** de la somme. | Ministère |
| D8 | **Pas de barème, pas d'encaissement.** Le module Paiements reste fermé tant que le groupe n'a rien défini. La saisie des tarifs devient un **prérequis bloquant du déploiement**. | Ministère |

## 5. Le modèle

### 5.1 La ligne de fracture

Ce n'est pas public/privé, c'est **imposé contre décidé** — et D2 tranche : tout est
imposé par le groupe. Le secteur ne décide plus que du **vocabulaire** offert au
groupe quand il crée ses barèmes.

### 5.2 `fee_structures` — remontée au groupe

- `school_id` devient **NULLABLE**. `NULL` = barème du groupe, applicable à toutes ses
  écoles. Renseigné = barème d'un établissement précis (cas d'un groupe privé qui
  module par école).
- `fee_type` gagne la valeur `cotisation_ape`, et **perd son défaut** `'mensualite'` :
  rien ne doit devenir une mensualité par omission, surtout dans le public.
- Nouvelle colonne `source_reference text NULL` — le texte fondateur (note de service,
  délibération d'assemblée APE). Un tarif sans texte qui le fonde n'est pas un tarif.
- Écriture réservée à `admin_groupe`. Les mutations côté école
  (`saveFeeStructure`, `deleteFeeStructure`, `ensureExamFeeStructure`,
  `setExamFeeAmount`) sont **retirées**.
- Toute modification de montant est journalisée dans `audit_logs`
  (action `TARIF_MODIFIE`, 13 caractères — la colonne est `varchar(20)`).

**Pas de versionnage de barème.** L'historique n'est pas porté par le tarif mais par
l'encaissement (§5.3) : c'est ce qui permet à D3 d'exister sans réécrire le passé.

### 5.3 `student_payments` — l'encaissement fige son contexte

| Colonne | Rôle |
|---|---|
| `academic_year_id uuid NOT NULL` | Aucune requête ne borne l'année aujourd'hui : en 2027 les versements de 2026 compteraient comme payés. |
| `reference_amount_xaf integer NULL` | **Tarif figé au moment de l'encaissement.** Sans lui, un tarif relevé en mars transforme rétroactivement des milliers d'élèves à jour en débiteurs, et un tarif baissé efface la preuve d'une surfacturation. |
| `overcharge_reason text NULL` | Motif, **obligatoire** si le **cumul versé** dépasse le dû (D4 — voir §5.7, l'erreur corrigée). |
| `cancelled_at`, `cancelled_by`, `cancellation_reason` | L'annulation remplace la suppression. |
| `refunded_amount_xaf`, `refunded_at`, `refunded_by`, `refund_reason` | Le statut `refunded` existe déjà mais ne porte rien. |

`receipt_number` : l'unicité passe de **globale** à `(school_id, receipt_number)`.

### 5.4 Exonérations (D5)

- `fee_exemption_reasons` — nouvelle table, portée **groupe** : `group_id`, `code`,
  `label`, `is_active`. Le groupe définit.
- `student_fee_exemptions` — portée **école** : `student_id`, `academic_year_id`,
  `reason_id`, `fee_type NULL` (= tous), `granted_by`, `granted_at`, `note`.
  L'école constate.

`students.has_scholarship` / `scholarship_type` existent déjà et sont saisis dès
l'inscription : ils sont affichés comme indicateur, mais **une bourse n'est pas une
exonération** (un boursier peut devoir la cotisation APE). Les deux concepts restent
distincts.

### 5.5 Le secteur décide le vocabulaire

Le secteur agit à **deux endroits distincts** :

- côté `admin_groupe`, il **restreint les types de barème** proposés à la création
  (un groupe public ne peut pas créer de mensualité) ;
- côté école, il **renomme** ce que le poste affiche en lecture seule.

`secteurEcoleProvider`, lu depuis le SQLite local (`schools.school_type`).

| | Privé | Public |
|---|---|---|
| Inscription | oui | oui (depuis ~2022) |
| Mensualité | oui | **retirée du formulaire** |
| Cotisation APE | possible | oui |
| Frais d'examen | tarif du groupe | tarif du groupe |

L'écran « Frais de scolarité » devient « **Contributions et cotisations** » en public.
Un directeur de lycée d'État ne doit plus jamais voir l'État lui proposer le mot
« mensualité ».

### 5.6 ⚠️ Les trois endroits — piège déjà vécu

Toute colonne lue hors ligne doit exister en **base**, dans **`powersync_schema.dart`**
et dans les **sync-rules**. Le bucket `directory` avait oublié le troisième la semaine
dernière : `employment_status` arrivait NULL sur chaque poste.

Ici le piège est identique et pire :

```yaml
sync-rules.yaml:230   SELECT * FROM fee_structures WHERE school_id = bucket.sid
RLS fee_structures    ... (is_admin_groupe() OR school_id = auth_school_id())
```

Un barème de groupe a `school_id IS NULL`. `NULL = bucket.sid` est faux ;
`NULL = auth_school_id()` est faux. **Le ministère définirait des tarifs qu'aucune
école ne verrait — ni hors ligne, ni en ligne.**

Corrections, dans le même geste que la migration :

- **sync-rules**, bucket `by_group` (ne pas toucher la ligne `by_school` existante) :
  ```yaml
  - SELECT * FROM fee_structures
      WHERE group_id = bucket.gid AND school_id IS NULL AND is_active = true
  - SELECT * FROM fee_exemption_reasons WHERE group_id = bucket.gid AND is_active = true
  ```
- **RLS** : scinder la policy `ALL` en une policy de **lecture**
  (`... OR school_id IS NULL`) et une policy d'**écriture** réservée à
  `is_admin_groupe()`. L'école doit lire le barème du groupe sans jamais l'écrire.

### 5.7 Le versement, l'avance, et l'erreur que ça corrige (D7, D8)

Un élève avance rarement la totalité. Le formulaire ne demande donc plus
« combien », il demande **« combien sur quoi »** :

```
Frais concerné   Inscription 2025-2026 — 5 000 F   ▾   (barèmes du groupe)
Déjà versé       2 000 F
Reste dû         3 000 F
Montant versé  [ 3 000 ]  ← pré-rempli au reste, librement baissable
```

L'avance est le cas **normal** : le champ se baisse sans justification. C'est
vers le haut qu'il faut s'expliquer.

`fee_structure_id` devient **obligatoire** (D8) : l'option « Autre / libre »
disparaît, et l'écran affiche un état vide bloquant nommant le groupe tant
qu'aucun barème n'existe. **Pas d'imputation automatique** : si un élève doit
l'inscription et l'APE et verse une somme sans préciser, c'est l'école qui
désigne le frais. Un versement que personne n'a imputé est un versement qu'on
ne saura pas justifier six mois plus tard.

#### ⚠️ L'erreur corrigée dans §5.3

La première version faisait porter l'alerte de dépassement sur **un versement**
comparé au tarif. Avec des avances, cette règle est aveugle : trois versements
de 2 000 sur un tarif de 5 000 dépassent de 1 000 **sans qu'aucun ne dépasse
individuellement**. Le contrôle porte donc sur le **cumul versé confirmé contre
le dû**, recalculé à chaque versement.

Bénéfice collatéral : « Élèves à jour » (§6.5) devient enfin vrai. 2 000 versés
sur 5 000 dus, ce n'est pas à jour — aujourd'hui l'application compte cet élève
comme réglé.

#### ⚠️ Piège de lecture, une couche au-dessus des sync-rules

`feeStructuresProvider` (`frais_provider.dart:54`) filtre `WHERE f.school_id = ?`.
Un barème du groupe (`school_id IS NULL`) ne remontera donc **jamais** dans le
sélecteur, même une fois les sync-rules et la RLS corrigées (§5.6). Les **trois**
couches sont à traiter ensemble : projection, RLS, requête applicative.

Constaté à l'écran le 2026-08-04 : le sélecteur n'offrait que « Autre / libre »,
la base ne contenant aucun barème.

## 6. Défauts trouvés à l'audit

### 6.1 🔴 Le numéro de reçu détruit des paiements

```dart
paiements_provider.dart:236
final receipt = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
```

`millisecondsSinceEpoch` fait 13 chiffres, `substring(7)` en garde **6** : le numéro
recommence **toutes les 16 min 40 s**. En base, `student_payments_receipt_number_key`
impose l'unicité **sur tout le pays**.

Chaîne complète : collision → `23505` → le motif `^23...$` de `_fatalResponseCodes`
(`powersync_connector.dart:11`) → **transaction abandonnée, paiement définitivement
perdu**. Loi des anniversaires sur 10⁶ valeurs : ~2 000 encaissements suffisent pour
que la collision soit probable à 86 %. À la rentrée, avec 1 000 écoles, c'est acquis.
Le journal `sync_failures` lèvera la bannière — la perte sera visible, mais le parent
sera reparti avec un papier sans contrepartie en base.

**Correctif** : le numéro porte l'identité du poste —
`REC-{code_école}-{yy}-{poste}-{séquence}`, où `{poste}` est un identifiant d'appareil
stable, tiré une fois et conservé aux côtés de `epilote.identite_poste`
(`SessionKeeper`). Unicité garantie **sans coordination réseau** : c'est la seule
propriété qui tienne hors ligne. Lisible par un parent, traçable jusqu'au poste par un
contrôleur. Séquence tenue dans une table locale-only (même patron que
`sync_failures`).

### 6.2 🔴 Il n'existe aucun reçu papier

Une trentaine de services PDF dans l'application — bulletins, convocations,
attestations, bordereaux de paie, fiches de transfert. **Aucun pour un encaissement.**
Au Congo le reçu *est* la preuve. Le reçu imprime le tarif officiel **à côté** du
montant encaissé : c'est ce qui rend la surfacturation opposable.
Chrome partagé : `OfficialPdfKit` + `showPdfPreviewDialog`. ⚠️ `pw.Page`, jamais
`MultiPage` (voir `attestations-emises`).

### 6.3 🟠 L'exonération est saisie et jamais lue

Traité par §5.4.

### 6.4 🟠 Le transfert coupe le dossier financier en deux

`student_payments.school_id` fige l'école d'encaissement. Un élève transféré en janvier
arrive avec un dû complet et zéro versement visible, pendant que ses versements restent
comptés dans l'ancienne école. Le module Transferts est livré : le trou s'ouvre à la
première mutation. **Résolu** par le calcul du dû à l'échelle de l'élève et de l'année
(§5.3), pas de l'école.

⚠️ **Limite assumée** : un transfert vers un **autre groupe** reste non résolu — la
nouvelle école ne voit pas les versements de l'ancienne, faute de bucket commun, et
son barème n'est pas le même. Cas rare (public → privé) et non traité ici : à porter
au module Transferts, pas à la Finance.

### 6.5 🟠 « Élèves à jour » ment

`paiements_provider.dart:85` compte à jour tout élève ayant **au moins un** paiement
confirmé, quel qu'en soit le montant. Il n'existe aucune notion de montant dû.

Le dû devient calculable : somme des barèmes applicables au niveau de l'élève pour
l'année, moins ses exonérations. **Les 8 130 élèves du public n'ont que des frais
uniques** — inscription, APE, examen — donc le dû y est immédiat. L'échéancier mensuel
ne concerne que les 974 élèves du privé, où le dû se dérive du nombre de mois écoulés
depuis la rentrée. Aucune table d'échéances.

### 6.6 🟡 Aucun arrêté de caisse

Rien ne répond à « combien y a-t-il en caisse ce soir, et qui l'a compté ». Sur des
fonds publics manipulés en espèces, c'est la première question d'un contrôleur.
**Hors périmètre** : c'est un module, pas un correctif. Consigné pour la suite.

## 7. Le livrable politique — écran « Écarts au tarif officiel »

Côté `admin_groupe` (en ligne, `supabase.from` — règle d'architecture) : par
établissement, montant moyen encaissé contre tarif de référence, nombre d'élèves
concernés, motifs invoqués, trié par écart décroissant.

C'est la carte de la surfacturation, école par école, tirée des encaissements réels.
L'APEEC réclame ce chiffre publiquement et personne ne l'a.

## 8. Découpage

| Lot | Contenu | Dépend de |
|---|---|---|
| **0** | Numéro de reçu (6.1) · reçu PDF (6.2) · annulation au lieu de suppression | rien — perte d'argent en cours |
| **1** | `academic_year_id` · dû réel (6.5) · exonérations (5.4) · remboursement | rien |
| **2** | Barèmes remontés au groupe (5.2) · **sync-rules + RLS + provider** (5.6, 5.7) · écrans `admin_groupe` · école en lecture seule · secteur au vocabulaire (5.5) · versement sur obligation, avance, barème obligatoire (5.7) | rien |
| **3** | Tarif figé (5.3) · alerte de dépassement **sur le cumul** · écran « Écarts au tarif officiel » (§7) | **lot 2** (le tarif de référence est le barème du groupe) |

Seul le lot 3 dépend techniquement d'un autre. L'ordre 0 → 1 → 2 est un ordre de
livraison : le lot 0 passe devant parce qu'il arrête une perte d'argent.

Migrations à partir de **0094** (dernière appliquée : 0093).

## 9. Hors périmètre

- API Mobile Money (phase 2 du cahier des charges ; `payment_configs` reste en l'état).
- Comptabilité générale, `facturation-ecole`.
- Arrêté de caisse (6.6).
- Échéancier mensuel paramétrable — le dérivé du §6.5 suffit.
- Le régime de la bourse d'État des enseignants volontaires (arriérés trimestriels) :
  question **RH**, pas Finance. Consignée, non traitée ici.

## 10. Tests attendus

- Collision de numéro de reçu : deux postes, même milliseconde de cycle → deux numéros
  distincts (garde-fou de non-régression sur 6.1).
- Un barème de groupe (`school_id IS NULL`) descend jusqu'au poste et se lit hors ligne.
- Une école ne peut pas écrire un barème de groupe (RLS en écriture).
- Un tarif modifié après un encaissement ne modifie pas le dû de cet encaissement.
- En public, `mensualite` est absent du vocabulaire proposé.
- Un élève exonéré n'apparaît jamais débiteur.
- Un élève transféré conserve son dû et ses versements.
- Trois versements de 2 000 sur un tarif de 5 000 déclenchent l'alerte au
  troisième — aucun ne dépasse seul (garde-fou de l'erreur du §5.7).
- Un élève ayant versé 2 000 sur 5 000 n'est **pas** compté à jour.
- Sans aucun barème, l'encaissement est impossible et l'écran désigne le groupe.

## 11. Prérequis de déploiement (D8)

Une conséquence directe de « pas de barème, pas d'encaissement » : **le groupe
doit avoir saisi ses tarifs avant que ses écoles n'ouvrent le module Paiements**.
À porter au parcours de démarrage ([[premiere-heure-etablissement]]) et à la
check-list du 2 octobre — sinon trente écoles encaisseront hors système le temps
que Brazzaville renseigne sa grille.
