# Lot 2 — Les barèmes remontent au ministère

> **Pour les agents :** SOUS-COMPÉTENCE REQUISE — `superpowers:executing-plans`.
> Les étapes sont des cases à cocher (`- [ ]`).

**Objectif :** l'école ne crée plus aucun montant. Le groupe (= le ministère)
définit les barèmes, ils descendent hors ligne sur les postes, l'école les
consulte et les applique.

**Architecture :** `fee_structures.school_id` devient nullable et change de sens
— il dit **« s'applique à »**, plus jamais « créé par ». L'auteur est imposé par
la RLS (écriture `admin_groupe`, lecture ouverte au périmètre). Le barème du
groupe descend par le bucket `by_group`, sur le patron déjà éprouvé de
`school_programs WHERE group_id = bucket.gid AND school_id IS NULL`.

**Spec :** `docs/superpowers/specs/2026-08-04-frais-scolarite-public-prive-design.md`
(D2, D3, D6, D9 · §5.1, §5.2, §5.5, §5.6).

**Pile :** Flutter 3 · Riverpod · PowerSync (école, hors ligne) · Supabase
(ministère, en ligne) · PostgreSQL 17.

## Contraintes globales

- **Deux chemins de données, non négociable.** Espace ministère (`admin_groupe`)
  → `supabase.from(...)`. Espace école (tout rôle passant `_isStaffRole`) →
  `db.watch()` / `db.execute()`, **jamais** `supabase.from()`.
- **Une colonne n'est visible hors ligne que si elle existe en TROIS endroits** :
  Postgres, `powersync_schema.dart`, et la projection du bucket. Pour une ligne
  de **portée groupe**, il y a un **quatrième** endroit : la requête applicative,
  qui filtre encore `WHERE school_id = ?`.
- `COALESCE(is_active, 1) <> 0` — **jamais** `is_active = 1` (la vue PowerSync ne
  garantit pas l'entier ; cf. `[[powersync-is-active-egalite-stricte]]`).
- `audit_logs.action` est un `varchar(20)`.
- Dart : **≤ 500 lignes par fichier**, alerte à 400.
- `flutter analyze` doit rester à **0 issue**.
- `inFilter()` (pas `in_()`), `CardThemeData`, `.withValues(alpha:)`.
- Migrations à partir de **0096** (dernière appliquée : 0095).
- Les sync-rules se déploient par `npx powersync deploy sync-config` — jamais à
  l'aveugle.

## Fichiers touchés

| Fichier | Rôle |
|---|---|
| `database/migrations/0096_le_bareme_appartient_au_groupe.sql` | créer — portée, RLS, index, journal |
| `powersync/config/sync-rules.yaml` | modifier — `by_group` projette les barèmes de groupe |
| `epilote/lib/services/powersync/powersync_schema.dart` | modifier — `source_reference` |
| `epilote/lib/features/finance/services/bareme_applicable.dart` | créer — résolution pure, testée |
| `epilote/lib/features/finance/providers/frais_provider.dart` | modifier — lit les deux portées, perd sa plume |
| `epilote/lib/features/finance/screens/frais_screen.dart` | modifier — consultation |
| `epilote/lib/features/finance/screens/frais_form.dart` | **supprimer** |
| `epilote/lib/features/examens/providers/exam_fees_provider.dart` | modifier — perd `ensureExamFeeStructure` / `setExamFeeAmount` |
| `epilote/lib/features/examens/widgets/exam_fees_panel.dart` | modifier — perd la saisie du montant |
| `epilote/lib/features/admin_groupe/providers/admin_fees_provider.dart` | créer |
| `epilote/lib/features/admin_groupe/screens/admin_fees_screen.dart` | créer |
| `epilote/lib/features/admin_groupe/screens/admin_fee_form_dialog.dart` | créer |
| `epilote/lib/core/constants/routes.dart` · `core/router/app_router.dart` · `core/widgets/app_shell/nav_config.dart` | modifier — route + entrée de menu |
| `epilote/test/bareme_applicable_test.dart` | créer |

---

## Tâche 1 — Le barème appartient au groupe (base)

**Fichiers :**
- Créer : `database/migrations/0096_le_bareme_appartient_au_groupe.sql`
- Modifier : `epilote/lib/services/powersync/powersync_schema.dart`

**Interfaces :**
- Produit : `fee_structures.school_id` nullable · `fee_type` gagne
  `cotisation_ape` et perd son défaut · colonne `source_reference text NULL` ·
  policies `fee_structures_read` / `_insert` / `_update` / `_delete` ·
  index `uniq_fee_structure_exam_session_group` et `…_school`.

- [ ] **Étape 1 : vérifier l'état de départ**

```bash
export PGPASSWORD='069698620libe'
psql -h aws-1-eu-central-2.pooler.supabase.com -p 5432 \
  -U postgres.wqpdamlnrwgozfvzjjpo -d postgres \
  -c "select count(*) from fee_structures;" \
  -c "select policyname, cmd from pg_policies where tablename='fee_structures';"
```

Attendu : `0` ligne, une seule policy `fee_structures_tenant` en `ALL`.
Si le compte n'est pas nul, **s'arrêter** : la migration passe `school_id` en
nullable sans convertir de données, ce qui est sans risque, mais le changement
de RLS retirerait la plume à des écoles qui ont des barèmes en cours d'usage —
cela se décide, ça ne se subit pas.

- [ ] **Étape 2 : écrire la migration**

```sql
-- 0096_le_bareme_appartient_au_groupe.sql
--
-- Un barème n'est pas une donnée de l'école, c'est un ACTE DU GROUPE. Dans le
-- public le montant vient d'un arrêté, dans le privé du siège : l'école est un
-- exécutant. Tant qu'elle peut écrire le montant, il n'existe aucun tarif de
-- référence — donc la surfacturation est indétectable, et le ministère ne peut
-- pas répondre à « combien coûte l'inscription en 6e ».
--
-- ⚠️ `school_id` CHANGE DE SENS. Il dit désormais « s'applique à », plus jamais
-- « créé par ». La variance est réelle (un groupe privé n'a pas le même tarif
-- partout), mais elle n'autorise personne à écrire : l'auteur est imposé par la
-- RLS, pas par le périmètre de la ligne.

BEGIN;

-- ── 1. Portée ──────────────────────────────────────────────────────────────
ALTER TABLE fee_structures ALTER COLUMN school_id DROP NOT NULL;

COMMENT ON COLUMN fee_structures.school_id IS
  'S''APPLIQUE À (jamais « créé par »). NULL = barème du groupe, valable pour '
  'toutes ses écoles. Renseigné = barème posé par le groupe POUR cette école.';

-- ── 2. Vocabulaire ─────────────────────────────────────────────────────────
-- La cotisation APE est tracée nominativement (D1) : il lui faut son type.
ALTER TYPE fee_type ADD VALUE IF NOT EXISTS 'cotisation_ape';

-- Rien ne doit devenir une mensualité par omission — surtout dans le public,
-- où la mensualité n'existe pas.
ALTER TABLE fee_structures ALTER COLUMN fee_type DROP DEFAULT;

-- ── 3. Le texte qui fonde le tarif ─────────────────────────────────────────
-- Un montant sans texte fondateur n'est pas un tarif, c'est un chiffre.
ALTER TABLE fee_structures
  ADD COLUMN IF NOT EXISTS source_reference text;

COMMENT ON COLUMN fee_structures.source_reference IS
  'Texte fondateur : arrêté, note de service, délibération d''assemblée APE.';

-- ── 4. Unicité du barème d'examen ──────────────────────────────────────────
-- L'ancien index portait sur (school_id, exam_session_id). Avec school_id NULL,
-- deux barèmes de groupe pour la même session passeraient tous les deux : en
-- btree les NULL sont distincts. Deux barèmes concurrents feraient diverger
-- l'attendu et le recouvrement.
DROP INDEX IF EXISTS uniq_fee_structure_exam_session;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_fee_structure_exam_session_group
  ON fee_structures (group_id, exam_session_id)
  WHERE exam_session_id IS NOT NULL AND school_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_fee_structure_exam_session_school
  ON fee_structures (school_id, exam_session_id)
  WHERE exam_session_id IS NOT NULL AND school_id IS NOT NULL;

-- ── 5. RLS : lecture large, écriture au seul groupe ────────────────────────
-- L'ancienne policy était un ALL unique : lire et écrire au même endroit. C'est
-- exactement ce qu'il faut casser.
DROP POLICY IF EXISTS fee_structures_tenant ON fee_structures;

-- Lecture : l'école voit le barème du groupe ET le sien.
CREATE POLICY fee_structures_read ON fee_structures
  FOR SELECT USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (
          is_admin_groupe()
          OR school_id IS NULL
          OR school_id = auth_school_id()))
  );

-- Écriture : le groupe, et lui seul.
CREATE POLICY fee_structures_insert ON fee_structures
  FOR INSERT WITH CHECK (
    is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
  );

CREATE POLICY fee_structures_update ON fee_structures
  FOR UPDATE USING (
    is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
  ) WITH CHECK (
    is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
  );

CREATE POLICY fee_structures_delete ON fee_structures
  FOR DELETE USING (
    is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
  );

-- ── 6. Un tarif qui change laisse une trace ────────────────────────────────
-- D3 autorise le ministère à changer un tarif à tout moment. Ce qui n'est pas
-- négociable, c'est de savoir qui l'a changé, quand, et depuis quel montant.
CREATE OR REPLACE FUNCTION log_fee_structure_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.amount_xaf IS DISTINCT FROM OLD.amount_xaf THEN
    INSERT INTO audit_logs (
      id, group_id, school_id, user_id, action, table_name, record_id,
      old_values, new_values, created_at
    ) VALUES (
      gen_random_uuid(), NEW.group_id, NEW.school_id,
      COALESCE(auth.uid(), NEW.group_id),
      'TARIF_MODIFIE',                       -- 13 caractères ; la colonne est varchar(20)
      'fee_structures', NEW.id,
      jsonb_build_object('amount_xaf', OLD.amount_xaf,
                         'source_reference', OLD.source_reference),
      jsonb_build_object('amount_xaf', NEW.amount_xaf,
                         'source_reference', NEW.source_reference),
      now()
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_fee_structure_change ON fee_structures;
CREATE TRIGGER trg_log_fee_structure_change
  AFTER UPDATE ON fee_structures
  FOR EACH ROW EXECUTE FUNCTION log_fee_structure_change();

COMMIT;
```

⚠️ `ALTER TYPE … ADD VALUE` ne peut pas cohabiter avec l'usage de la nouvelle
valeur dans la même transaction. Ici on ne fait que la déclarer — aucun `INSERT`
ne l'utilise dans ce fichier — donc le `BEGIN … COMMIT` tient. Si Postgres
refuse malgré tout, sortir la ligne `ALTER TYPE` **avant** le `BEGIN`.

- [ ] **Étape 3 : appliquer et vérifier**

```bash
export PGPASSWORD='069698620libe'
psql -h aws-1-eu-central-2.pooler.supabase.com -p 5432 \
  -U postgres.wqpdamlnrwgozfvzjjpo -d postgres \
  -f database/migrations/0096_le_bareme_appartient_au_groupe.sql
```

Puis :

```bash
psql … -c "select is_nullable from information_schema.columns
           where table_name='fee_structures' and column_name='school_id';" \
       -c "select policyname, cmd from pg_policies where tablename='fee_structures' order by 1;" \
       -c "select unnest(enum_range(null::fee_type))::text;"
```

Attendu : `YES` ; quatre policies (`read`/`insert`/`update`/`delete`) ;
`cotisation_ape` dans l'énumération.

⚠️ Ne **jamais** tenter la migration avec `psql -c "BEGIN; … ROLLBACK;"` en une
seule chaîne : le rollback n'est pas fiable dans cette forme.

- [ ] **Étape 4 : déclarer la colonne au schéma local**

Dans `powersync_schema.dart`, table `fee_structures`, ajouter au bloc de
colonnes :

```dart
    Column.text('source_reference'),
```

- [ ] **Étape 5 : commit**

```bash
git add database/migrations/0096_le_bareme_appartient_au_groupe.sql \
        epilote/lib/services/powersync/powersync_schema.dart
git commit -m "feat(finance) : le barème appartient au groupe, plus à l'école"
```

---

## Tâche 2 — Le barème du groupe descend sur les postes

**Fichiers :**
- Modifier : `powersync/config/sync-rules.yaml`

**Interfaces :**
- Consomme : `fee_structures.school_id` nullable (tâche 1).
- Produit : les lignes `school_id IS NULL` du groupe présentes dans la base
  locale de chaque poste.

- [ ] **Étape 1 : projeter le barème de groupe**

Dans le bucket `by_group`, juste après la ligne `school_programs` (qui porte
déjà le même patron « portée groupe = `school_id IS NULL` ») :

```yaml
      # Barèmes de frais du GROUPE (school_id NULL = tarif valable pour toutes
      # ses écoles). Le bucket by_school ne projette que school_id = bucket.sid :
      # sans cette ligne, un tarif ministériel serait écrit en base, visible du
      # ministère, et INVISIBLE sur les postes — panne muette.
      - SELECT * FROM fee_structures
        WHERE group_id = bucket.gid AND school_id IS NULL AND is_active = true
```

Le bucket `by_school` garde sa ligne existante inchangée : elle couvre les
barèmes posés par le groupe **pour** une école précise.

- [ ] **Étape 2 : déployer**

```bash
cd /home/melack/E-PILOTE/powersync
npx powersync deploy sync-config
```

- [ ] **Étape 3 : vérifier le déploiement**

Attendu dans la sortie : le déploiement réussit et le compte de requêtes de
`by_group` a augmenté de 1. Si l'outil signale une erreur de validation,
**s'arrêter** — une règle cassée coupe la synchro de tout le réseau.

- [ ] **Étape 4 : commit**

```bash
git add powersync/config/sync-rules.yaml
git commit -m "feat(sync) : le barème du ministère descend sur les postes"
```

---

## Tâche 3 — Résoudre le barème applicable (logique pure, testée)

**Fichiers :**
- Créer : `epilote/lib/features/finance/services/bareme_applicable.dart`
- Créer : `epilote/test/bareme_applicable_test.dart`

**Interfaces :**
- Produit :
  ```dart
  typedef LigneBareme = ({
    String id, String feeType, int montant, String? schoolId, String? levelId,
  });
  List<LigneBareme> baremesApplicables(List<LigneBareme> visibles, {String? levelId});
  ```

**Le problème que ça résout.** Une fois les deux portées lisibles, un élève de
6ᵉ voit potentiellement quatre lignes pour le **même** frais : le tarif du
groupe pour tout le réseau, celui du groupe pour son école, celui du groupe pour
son niveau, et le croisement des deux. Additionnées, elles feraient un dû de
quatre fois le tarif. Il faut **une seule ligne par type de frais**, la plus
spécifique.

Ordre de spécificité, du plus fort au plus faible :
1. école **et** niveau renseignés,
2. école renseignée, tous niveaux,
3. groupe, niveau renseigné,
4. groupe, tous niveaux.

- [ ] **Étape 1 : écrire le test qui échoue**

```dart
// epilote/test/bareme_applicable_test.dart
import 'package:epilote/features/finance/services/bareme_applicable.dart';
import 'package:flutter_test/flutter_test.dart';

LigneBareme l(String id, String type, int m, {String? school, String? level}) =>
    (id: id, feeType: type, montant: m, schoolId: school, levelId: level);

void main() {
  group('un seul barème par type de frais', () {
    test('sans rien de spécifique, le tarif du groupe s\'applique', () {
      final r = baremesApplicables([l('g', 'inscription', 5000)], levelId: '6e');
      expect(r.map((e) => e.id), ['g']);
      expect(r.single.montant, 5000);
    });

    test('le tarif posé pour l\'école prime sur celui du réseau', () {
      // ⚠️ Le cas qui compte : additionner les deux ferait un dû de 12 500.
      final r = baremesApplicables([
        l('g', 'inscription', 5000),
        l('e', 'inscription', 7500, school: 'ec1'),
      ], levelId: '6e');
      expect(r.single.id, 'e');
    });

    test('le tarif du niveau prime sur celui de toute l\'école', () {
      final r = baremesApplicables([
        l('tous', 'inscription', 5000),
        l('6e', 'inscription', 3000, level: '6e'),
      ], levelId: '6e');
      expect(r.single.id, '6e');
    });

    test('école + niveau bat école seule et niveau seul', () {
      final r = baremesApplicables([
        l('groupe', 'inscription', 5000),
        l('niveau', 'inscription', 4000, level: '6e'),
        l('ecole', 'inscription', 7000, school: 'ec1'),
        l('les2', 'inscription', 6000, school: 'ec1', level: '6e'),
      ], levelId: '6e');
      expect(r.single.id, 'les2');
    });

    test('un barème d\'un AUTRE niveau ne s\'applique pas', () {
      final r = baremesApplicables([
        l('term', 'inscription', 9000, level: 'terminale'),
      ], levelId: '6e');
      expect(r, isEmpty);
    });

    test('des types différents coexistent, ils ne se remplacent pas', () {
      final r = baremesApplicables([
        l('i', 'inscription', 5000),
        l('m', 'mensualite', 12000),
        l('a', 'cotisation_ape', 2000),
      ], levelId: '6e');
      expect(r.length, 3);
    });

    test('un élève sans niveau connu ne prend que les tarifs tous niveaux', () {
      final r = baremesApplicables([
        l('tous', 'inscription', 5000),
        l('6e', 'inscription', 3000, level: '6e'),
      ], levelId: null);
      expect(r.single.id, 'tous');
    });
  });
}
```

- [ ] **Étape 2 : lancer le test, vérifier l'échec**

```bash
cd epilote && flutter test test/bareme_applicable_test.dart
```

Attendu : ÉCHEC — `bareme_applicable.dart` n'existe pas.

- [ ] **Étape 3 : implémenter**

```dart
// epilote/lib/features/finance/services/bareme_applicable.dart
//
// ════════════════════════════════════════════════════════════════════════════
//  QUEL BARÈME S'APPLIQUE À CET ÉLÈVE ?
//
//  Depuis que le barème appartient au groupe (migration 0096), un poste voit
//  DEUX portées : le tarif du réseau (`school_id IS NULL`) et celui posé pour
//  son école. S'y ajoute le ciblage par niveau. Les additionner ferait payer
//  un élève deux à quatre fois — d'où cette résolution : UNE seule ligne par
//  type de frais, la plus spécifique.
// ════════════════════════════════════════════════════════════════════════════

typedef LigneBareme = ({
  String id,
  String feeType,
  int montant,
  String? schoolId,
  String? levelId,
});

/// Score de spécificité : école (2) l'emporte sur niveau (1), les deux se
/// cumulent. Plus haut = plus proche de l'élève.
int _specificite(LigneBareme b) =>
    (b.schoolId != null ? 2 : 0) + (b.levelId != null ? 1 : 0);

/// Parmi les barèmes visibles sur le poste, ceux qui s'appliquent réellement à
/// un élève du niveau [levelId] — au plus un par type de frais.
List<LigneBareme> baremesApplicables(
  List<LigneBareme> visibles, {
  required String? levelId,
}) {
  final retenu = <String, LigneBareme>{};
  for (final b in visibles) {
    // Un barème ciblant un autre niveau ne concerne pas cet élève. Un élève
    // sans niveau connu ne prend que les barèmes « toute l'école ».
    if (b.levelId != null && b.levelId != levelId) continue;

    final actuel = retenu[b.feeType];
    if (actuel == null || _specificite(b) > _specificite(actuel)) {
      retenu[b.feeType] = b;
    }
  }
  return retenu.values.toList();
}
```

- [ ] **Étape 4 : lancer le test, vérifier le succès**

```bash
cd epilote && flutter test test/bareme_applicable_test.dart
```

Attendu : 7 tests passent.

- [ ] **Étape 5 : commit**

```bash
git add epilote/lib/features/finance/services/bareme_applicable.dart \
        epilote/test/bareme_applicable_test.dart
git commit -m "feat(finance) : un seul barème par frais, le plus spécifique"
```

---

## Tâche 4 — L'école consulte, elle n'écrit plus

**Fichiers :**
- Modifier : `epilote/lib/features/finance/providers/frais_provider.dart`
- Modifier : `epilote/lib/features/finance/providers/obligation_provider.dart`
- Modifier : `epilote/lib/features/finance/screens/frais_screen.dart`
- Supprimer : `epilote/lib/features/finance/screens/frais_form.dart`
- Modifier : `epilote/lib/features/examens/providers/exam_fees_provider.dart`
- Modifier : `epilote/lib/features/examens/widgets/exam_fees_panel.dart`

**Interfaces :**
- Consomme : `baremesApplicables` (tâche 3), les deux portées descendues (tâche 2).
- Produit : `FeeStructure` gagne `scope` (`BaremeScope.reseau` / `.etablissement`)
  et `sourceReference`. `saveFeeStructure`, `deleteFeeStructure`,
  `ensureExamFeeStructure`, `setExamFeeAmount` **n'existent plus**.

- [ ] **Étape 1 : le provider lit les deux portées**

Dans `frais_provider.dart`, remplacer le `WHERE` de `feeStructuresProvider` :

```dart
    WHERE f.group_id = ? AND (f.school_id = ? OR f.school_id IS NULL)
      AND f.academic_year_id = ?
      AND COALESCE(f.is_active, 1) <> 0
    ORDER BY f.fee_type, f.school_id IS NULL, f.amount_xaf DESC
```

paramètres `[groupId, schoolId, yearId ?? '']`. Le `group_id` explicite évite
qu'un barème d'un autre groupe resté en base après une mutation d'appareil ne
remonte (cf. `[[licence-coffre-appareil-cross-groupe]]`).

Enrichir le modèle :

```dart
enum BaremeScope { reseau, etablissement }

class FeeStructure {
  const FeeStructure({
    required this.id,
    required this.name,
    required this.feeType,
    required this.amount,
    required this.dueDay,
    required this.levelId,
    required this.levelName,
    required this.scope,
    required this.sourceReference,
  });
  final String id, name, feeType;
  final int amount;
  final int? dueDay;
  final String? levelId, levelName, sourceReference;
  final BaremeScope scope;
}
```

et au mapping :

```dart
            scope: (r['school_id'] as String?) == null
                ? BaremeScope.reseau
                : BaremeScope.etablissement,
            sourceReference: r['source_reference'] as String?,
```

- [ ] **Étape 2 : retirer la plume à l'école**

Supprimer de `frais_provider.dart` les fonctions `saveFeeStructure` et
`deleteFeeStructure` — entièrement, avec leur en-tête. Remplacer par :

```dart
// ─── Aucune mutation ici, et c'est volontaire ────────────────────────────────
//
// Un barème est un ACTE DU GROUPE (migration 0096, décision D2). L'école le
// reçoit et l'applique. `saveFeeStructure` / `deleteFeeStructure` ont été
// retirées le 5 août 2026 : tant qu'elles existaient, il n'y avait aucun tarif
// de référence, donc aucun moyen de constater une surfacturation. La RLS
// refuserait de toute façon l'écriture — mais un refus serveur abandonne le
// LOT PowerSync entier, ce qui emporterait le travail des autres modules.
// L'absence de bouton est la vraie protection ; la RLS est le filet.
```

Dans `obligation_provider.dart`, `baremesApplicablesProvider` lit déjà
`(school_id = ? OR school_id IS NULL)` — ajouter le `group_id = ?` et faire
passer les lignes par `baremesApplicables()` avant de calculer le dû.

- [ ] **Étape 3 : l'écran devient une consultation**

Dans `frais_screen.dart` :
- supprimer le bouton d'en-tête `+ Barème`, le bouton `Nouveau barème` de l'état
  vide, et le menu `⋮` (Modifier / Supprimer) de chaque ligne ;
- supprimer l'import de `frais_form.dart`, puis `git rm` le fichier ;
- sous-titre de l'en-tête → `'Tarifs définis par le ministère · consultation'` ;
- sur chaque ligne, une puce de portée :

```dart
  Widget _puceScope(BaremeScope s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: (s == BaremeScope.reseau ? kNavy : kAccent)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          s == BaremeScope.reseau ? 'Réseau' : 'Établissement',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: s == BaremeScope.reseau ? kNavy : kAccent,
          ),
        ),
      );
```

- état vide réécrit — il doit **désigner qui agit**, pas laisser l'école devant
  un mur :

```dart
              const AdminEmptyState(
                icon: Icons.request_quote_outlined,
                title: 'Aucun tarif pour cette année',
                message:
                    'Les frais de scolarité sont fixés par le ministère. Tant '
                    'qu\'aucun tarif n\'est publié, aucun encaissement n\'est '
                    'possible. Rapprochez-vous de votre administration de '
                    'tutelle.',
              ),
```

- [ ] **Étape 4 : les frais d'examen cessent d'être fixés par l'école**

C'est le défaut le plus net de l'audit : `setExamFeeAmount` laissait
l'établissement décider de frais que la DEC fixe nationalement.
`exam_sessions.fee_amount` porte **déjà** le montant national.

Dans `exam_fees_provider.dart` : supprimer `ensureExamFeeStructure` et
`setExamFeeAmount`. La lecture du barème devient explicitement celle du groupe :

```dart
  // Le barème d'examen est posé par le MINISTÈRE pour la session (school_id
  // NULL). L'école ne le crée pas : `ensureExamFeeStructure` a été retirée le
  // 5 août 2026, elle fabriquait une surcouche établissement par-dessus le
  // tarif national — c'est-à-dire la surfacturation, livrée comme une
  // fonctionnalité.
  final fee = await db.getOptional(
    'SELECT id, amount_xaf FROM fee_structures '
    'WHERE exam_session_id = ? AND COALESCE(is_active, 1) <> 0 LIMIT 1',
    [sessionId],
  );
```

Renommer le champ `isSchoolScale` en `baremePublie` (`fee != null`) : ce qui
importe désormais n'est plus « l'école a-t-elle son propre tarif » mais « le
ministère a-t-il ouvert les frais de cette session ».

Dans `exam_fees_panel.dart` : supprimer le champ de saisie du montant et son
appel (lignes ~234 et ~242). À la place, quand `!d.baremePublie` :

```dart
            Text(
              'Le ministère n\'a pas encore publié les frais de cette session. '
              'Le montant affiché est celui porté par la session nationale ; '
              'aucun encaissement n\'est rattachable tant que le barème n\'est '
              'pas publié.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted),
            ),
```

- [ ] **Étape 5 : vérifier**

```bash
cd epilote
flutter analyze
flutter test
```

Attendu : 0 issue ; la suite passe (926 tests : 919 + les 7 de la tâche 3).
Le compilateur doit signaler tout appelant oublié de `saveFeeStructure`,
`deleteFeeStructure`, `ensureExamFeeStructure`, `setExamFeeAmount` — les traiter
tous avant de continuer.

- [ ] **Étape 6 : commit**

```bash
git add -A epilote/lib/features/finance epilote/lib/features/examens
git commit -m "feat(finance) : l'école consulte les tarifs, elle ne les écrit plus"
```

---

## Tâche 5 — L'écran du ministère : Frais & tarifs

**Fichiers :**
- Créer : `epilote/lib/features/admin_groupe/providers/admin_fees_provider.dart`
- Créer : `epilote/lib/features/admin_groupe/screens/admin_fees_screen.dart`
- Créer : `epilote/lib/features/admin_groupe/screens/admin_fee_form_dialog.dart`
- Modifier : `epilote/lib/core/constants/routes.dart`
- Modifier : `epilote/lib/core/router/app_router.dart`
- Modifier : `epilote/lib/core/widgets/app_shell/nav_config.dart`

**Interfaces :**
- Consomme : les policies d'écriture de la tâche 1.
- Produit : route `Routes.adminFrais` = `/admin/frais` ; provider
  `adminFeesProvider` (`AsyncValue<List<AdminFee>>`) ; `saveAdminFee` /
  `deactivateAdminFee`.

⚠️ **`admin_groupe` est en ligne, sur Supabase direct** — `supabase.from(...)`,
jamais `db.watch()`. C'est la règle centrale du projet.

- [ ] **Étape 1 : le provider**

```dart
// epilote/lib/features/admin_groupe/providers/admin_fees_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  FRAIS & TARIFS DU GROUPE — le seul endroit où un montant se crée.
//  admin_groupe travaille EN LIGNE sur Supabase (règle centrale du projet).
// ════════════════════════════════════════════════════════════════════════════

class AdminFee {
  const AdminFee({
    required this.id,
    required this.name,
    required this.feeType,
    required this.amount,
    required this.schoolId,
    required this.schoolName,
    required this.levelId,
    required this.dueDay,
    required this.sourceReference,
  });
  final String id, name, feeType;
  final int amount;
  final String? schoolId, schoolName, levelId, sourceReference;
  final int? dueDay;

  bool get estReseau => schoolId == null;
}

final adminFeesProvider =
    FutureProvider.autoDispose.family<List<AdminFee>, String>((ref, yearId) async {
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null || yearId.isEmpty) return const [];
  final rows = await supabase
      .from('fee_structures')
      .select('id, name, fee_type, amount_xaf, school_id, applies_to_level_id, '
          'due_day_of_month, source_reference, schools(name)')
      .eq('group_id', groupId)
      .eq('academic_year_id', yearId)
      .eq('is_active', true)
      .order('fee_type');
  return [
    for (final r in rows as List)
      AdminFee(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '—',
        feeType: (r['fee_type'] as String?) ?? 'autre',
        amount: (r['amount_xaf'] as num?)?.round() ?? 0,
        schoolId: r['school_id'] as String?,
        schoolName: (r['schools'] as Map?)?['name'] as String?,
        levelId: r['applies_to_level_id'] as String?,
        dueDay: (r['due_day_of_month'] as num?)?.round(),
        sourceReference: r['source_reference'] as String?,
      ),
  ];
});

Future<void> saveAdminFee({
  String? id,
  required String groupId,
  required String academicYearId,
  required String name,
  required String feeType,
  required int amount,
  String? schoolId,
  String? levelId,
  int? dueDay,
  required String sourceReference,
}) async {
  final payload = {
    'group_id': groupId,
    'school_id': schoolId,
    'academic_year_id': academicYearId,
    'name': name,
    'fee_type': feeType,
    'amount_xaf': amount,
    'applies_to_level_id': levelId,
    'due_day_of_month': dueDay,
    'source_reference': sourceReference,
    'is_active': true,
    'updated_at': DateTime.now().toIso8601String(),
  };
  if (id != null) {
    await supabase.from('fee_structures').update(payload).eq('id', id);
  } else {
    await supabase.from('fee_structures').insert({
      ...payload,
      'id': _uuid.v4(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

/// Retrait logique : un tarif qui a servi à des encaissements ne disparaît pas
/// de l'historique, il cesse simplement de s'appliquer.
Future<void> deactivateAdminFee(String id) =>
    supabase.from('fee_structures').update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
```

- [ ] **Étape 2 : la boîte de saisie**

`admin_fee_form_dialog.dart` — un `StatefulWidget` qui **possède ses
contrôleurs et les libère lui-même**.

⚠️ `await showDialog` rend la main au `Navigator.pop`, **pas** à la fin de
l'animation de sortie : libérer un contrôleur depuis l'appelant juste après
l'attente le détruit pendant que le champ en dépend encore, et l'écran vire au
rouge sur « `_dependents.isEmpty` is not true ». Piège déjà vécu deux fois.

Champs, dans cet ordre :
1. **Portée** — `DropdownButtonFormField<String?>` : `null` = « Tout le réseau »,
   sinon la liste des écoles du groupe. C'est le premier champ parce que c'est
   la décision structurante.
2. **Type de frais** — `inscription`, `mensualite`, `frais_examens`,
   `cotisation_ape`, `autre`. **Pas de valeur pré-sélectionnée** : rien ne doit
   devenir une mensualité par omission.
3. **Nom** (ex. « Inscription 2025-2026 »).
4. **Montant (FCFA)** — entier > 0.
5. **Niveau concerné** — optionnel, `null` = tous.
6. **Échéance (jour du mois)** — optionnel, visible seulement si
   `feeType == 'mensualite'`.
7. **Texte fondateur** — `source_reference`, **obligatoire**, avec l'aide
   « Arrêté, note de service ou délibération qui fonde ce tarif ».

Validation avant enregistrement, chaque cas avec son message :

```dart
  String? _probleme() {
    if (_feeType == null) return 'Choisissez le type de frais';
    if (_nom.text.trim().isEmpty) return 'Le nom du barème est obligatoire';
    final m = int.tryParse(_montant.text.trim().replaceAll(' ', ''));
    if (m == null || m <= 0) return 'Montant (> 0) requis';
    if (_source.text.trim().isEmpty) {
      return 'Indiquez le texte qui fonde ce tarif';
    }
    return null;
  }
```

- [ ] **Étape 3 : l'écran**

`admin_fees_screen.dart` — même chrome que les autres écrans du groupe
(`admin_ui.dart`) :
- en-tête « Frais & tarifs », sous-titre « Les montants que vos écoles
  appliquent », bouton `+ Tarif` ;
- quatre KPI en `GridView.builder` avec `mainAxisExtent` (**jamais**
  `childAspectRatio`) : Tarifs actifs · Écoles couvertes · Inscription (réseau) ·
  Mensualité (réseau) ;
- la liste groupée par type de frais, chaque ligne portant sa puce de portée
  (« Réseau » ou le nom de l'école), son montant, et son texte fondateur en
  gris sous le nom ;
- `⋮` → Modifier / Retirer, la suppression passant par `showAdminConfirm`.

Si le fichier dépasse 400 lignes, sortir la liste dans
`admin_fees_list.dart` — jamais couper au milieu d'un widget.

- [ ] **Étape 4 : câbler la route et le menu**

`routes.dart`, section Admin Groupe, après `adminAnnees` :

```dart
  // Le seul endroit de la plateforme où un montant se crée. L'école reçoit et
  // applique — elle n'a aucun écran d'écriture (migration 0096, décision D2).
  static const String adminFrais        = '/admin/frais';
```

`app_router.dart` : importer l'écran et déclarer la route dans le bloc
`admin_groupe`, sur le même patron que `Routes.adminAnnees`.

`nav_config.dart`, dans `_adminGroupeSections`, section **GESTION**, juste après
« Années scolaires » (le tarif suit l'année à laquelle il s'attache) :

```dart
      NavEntry.item(
        icon: Icons.request_quote_rounded,
        label: 'Frais & tarifs',
        route: Routes.adminFrais,
      ),
```

- [ ] **Étape 5 : vérifier**

```bash
cd epilote && flutter analyze && flutter test
```

Attendu : 0 issue, suite verte.

- [ ] **Étape 6 : commit**

```bash
git add -A epilote/lib
git commit -m "feat(admin) : le ministère définit les frais de ses écoles"
```

---

## Recette à l'écran (elle vaut aussi pour le lot 1)

À faire d'un bout à l'autre, dans cet ordre, **avec deux sessions** : le
ministère (`metp@epilote.cg`) puis l'école (Lycée Technique du 1er Mai).

- [ ] Ministère ▸ **Frais & tarifs** : créer « Inscription 2025-2026 », portée
      *Tout le réseau*, 5 000 F, texte fondateur renseigné. Sans texte fondateur,
      l'enregistrement est refusé.
- [ ] École ▸ Finance ▸ **Frais de scolarité** : le tarif apparaît, marqué
      **Réseau**, et **aucun bouton de création ni de suppression n'existe**.
- [ ] École ▸ Finance ▸ **Paiements** : le bandeau « Barème non défini » a
      disparu ; les élèves sont **Impayé**, reste dû 5 000 F.
- [ ] Enregistrer **2 000 F** sur un élève → **Avance partielle**, reste 3 000 F.
- [ ] Enregistrer **3 000 F** de plus → **À jour**.
- [ ] Rembourser : 6 000 F refusé, 2 000 F accepté, la ligne porte le
      remboursement.
- [ ] Imprimer le reçu : numéro, élève, classe, objet, encaisseur.
- [ ] Annuler un paiement avec motif : la ligne reste, marquée annulée en rouge,
      et le reçu réimprimé porte l'annulation.
- [ ] Ministère : porter le tarif à 7 500 F → `audit_logs` contient une ligne
      `TARIF_MODIFIE` avec l'ancien et le nouveau montant.
- [ ] **Purger les données de test de la production** :
      `delete from student_payments …` puis `delete from fee_structures …`,
      et vérifier que les deux tables sont revenues à 0.

## Hors de ce lot

Reportés au **lot 2b**, pour tenir le « pas à pas » :
- l'écran de préparation « niveaux et types de frais sans tarif » (§11) ;
- le versement sur obligation : barème obligatoire à l'encaissement, reste dû
  affiché, avance explicite (D7, D8) ;
- les exonérations (D5) ;
- le circuit « demander un tarif au ministère » (contre-feu de D9).

Et au **lot 3** : tarif figé sur l'encaissement, alerte de dépassement sur le
cumul, écran « Écarts au tarif officiel ».

Le **budget de fonctionnement** reste hors périmètre (D10), bien qu'il porte le
même défaut : `budget_lines` est écrit, modifié et supprimé depuis l'école.
