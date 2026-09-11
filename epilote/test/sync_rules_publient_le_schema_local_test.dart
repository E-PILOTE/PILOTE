import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE TABLE DÉCLARÉE EN LOCAL MAIS PUBLIÉE PAR AUCUN BUCKET
//
//  ── LA PANNE QUI N'EN A PAS L'AIR ──────────────────────────────────────────
//  Déclarer une table dans `powersync_schema.dart` crée sa copie SQLite sur le
//  poste. L'application y écrit, le connecteur remonte la ligne vers Postgres,
//  la RLS l'accepte : de bout en bout, tout réussit.
//
//  Puis PowerSync arrive au checkpoint suivant. Il ne connaît qu'une chose :
//  les buckets. Une table qu'AUCUN bucket ne publie n'a rien à faire sur
//  l'appareil — il supprime la copie locale. La ligne existe en base, et
//  l'écran est vide.
//
//  C'est la pire des formes : pas d'exception, pas de conflit, pas de perte de
//  données. Juste un écran qui ment, et un utilisateur qui ressaisit.
//
//  ── CE QUI A AMENÉ CE GARDE (2026-08-29) ───────────────────────────────────
//  `issued_documents` (le registre des documents délivrés) est né avec sa
//  table serveur, sa RLS, son schéma local et son écran — et sans sa ligne
//  dans `by_school`. Le défaut a été vu avant la livraison. Rien ne garantit
//  que le suivant le soit : la ligne manquante se trouve dans un AUTRE fichier
//  que celui qu'on édite en ajoutant une table.
//
//  Ce garde ferme les deux sens à la fois :
//
//   • déclarée en local, publiée nulle part → la copie locale disparaît ;
//   • publiée par un bucket, non déclarée en local → la donnée descend sur le
//     réseau de l'école puis est jetée par le client. Pas de panne visible,
//     mais de la bande passante payée pour rien sur des liaisons qui n'en ont
//     pas à revendre — et souvent le signe d'une table renommée d'un seul côté.
//
//  ⚠️ CE QU'IL NE PEUT PAS VOIR : il lit le FICHIER du dépôt, pas les règles
//  DÉPLOYÉES. Les sync-rules ne prennent effet qu'après un déploiement sur
//  l'instance PowerSync Cloud de production. Un fichier juste et non déployé
//  produit exactement la panne décrite plus haut. Voir `docs/DEPLOIEMENT_ORDRE.md`.
// ════════════════════════════════════════════════════════════════════════════

const _kSchema = 'lib/services/powersync/powersync_schema.dart';
const _kRules = '../powersync/config/sync-rules.yaml';

/// Les tables déclarées dans le schéma SQLite local.
List<String> _tablesLocales() {
  final f = File(_kSchema);
  if (!f.existsSync()) {
    fail('$_kSchema introuvable — lancer les tests depuis `epilote/`.');
  }
  final motif = RegExp(r"Table\(\s*'([a-z_0-9]+)'");
  return [
    for (final m in motif.allMatches(f.readAsStringSync())) m.group(1)!,
  ]..sort();
}

/// Les tables publiées, et par quel(s) bucket(s). On lit `data:` uniquement :
/// les `parameters:` interrogent des tables (`profiles`) sans les synchroniser.
Map<String, Set<String>> _tablesPubliees() {
  final f = File(_kRules);
  if (!f.existsSync()) fail('$_kRules introuvable.');
  final doc = loadYaml(f.readAsStringSync()) as YamlMap;
  final buckets = doc['bucket_definitions'] as YamlMap?;
  if (buckets == null || buckets.isEmpty) {
    fail('`bucket_definitions` absent ou vide : les sync-rules ne publient '
        'plus rien du tout.');
  }
  final motif = RegExp(r'\bFROM\s+([a-z_0-9]+)', caseSensitive: false);
  final par = <String, Set<String>>{};
  for (final entree in buckets.entries) {
    final nom = entree.key as String;
    final data = (entree.value as YamlMap)['data'] as YamlList?;
    for (final requete in data ?? const []) {
      final m = motif.firstMatch(requete as String);
      if (m == null) {
        fail('Requête sans FROM dans le bucket `$nom` : '
            '«${requete.trim()}». Une entrée `data:` illisible est une table '
            'qu’on croit publiée.');
      }
      par.putIfAbsent(m.group(1)!, () => <String>{}).add(nom);
    }
  }
  return par;
}

void main() {
  group('Le schéma local et les sync-rules décrivent le même monde', () {
    test('toute table déclarée en local est publiée par au moins un bucket',
        () {
      final publiees = _tablesPubliees();
      final orphelines =
          _tablesLocales().where((t) => !publiees.containsKey(t)).toList();

      expect(
        orphelines,
        isEmpty,
        reason: 'Ces tables sont déclarées dans $_kSchema mais aucun bucket ne '
            'les publie : ${orphelines.join(', ')}.\n'
            'L’application écrira dedans, la ligne partira vers Postgres, et '
            'PowerSync supprimera la copie locale au checkpoint suivant. '
            'L’écran s’affichera VIDE alors que la donnée existe.\n'
            'Correctif : ajouter `- SELECT * FROM <table> WHERE …` sous le '
            '`data:` du bucket qui correspond à sa portée (by_school pour une '
            'donnée d’établissement), PUIS DÉPLOYER les sync-rules.',
      );
    });

    test('toute table publiée est déclarée dans le schéma local', () {
      final locales = _tablesLocales().toSet();
      final inutiles =
          _tablesPubliees().keys.where((t) => !locales.contains(t)).toList()
            ..sort();

      expect(
        inutiles,
        isEmpty,
        reason: 'Ces tables sont publiées par un bucket mais absentes de '
            '$_kSchema : ${inutiles.join(', ')}.\n'
            'Leurs lignes traversent le réseau de l’école puis sont jetées par '
            'le client. Aucune panne visible, de la bande passante payée pour '
            'rien — et souvent le signe d’une table renommée d’un seul côté.',
      );
    });

    test('aucune requête n’est écrite deux fois dans le même bucket', () {
      // ⚠️ Publier la MÊME TABLE plusieurs fois dans un bucket est légitime et
      // voulu : PowerSync n’accepte pas `IN (liste)` en data-query, donc
      // `audit_logs` filtré sur trois `table_name` s’écrit en trois requêtes.
      // Ce qui n’a aucun sens, en revanche, c’est deux requêtes IDENTIQUES —
      // la marque d’une fusion de branches ratée.
      final doc = loadYaml(File(_kRules).readAsStringSync()) as YamlMap;
      final buckets = doc['bucket_definitions'] as YamlMap;
      for (final entree in buckets.entries) {
        final vues = <String>{};
        final data = (entree.value as YamlMap)['data'] as YamlList?;
        for (final requete in data ?? const []) {
          final normalisee =
              (requete as String).replaceAll(RegExp(r'\s+'), ' ').trim();
          expect(vues.add(normalisee), isTrue,
              reason: 'Le bucket `${entree.key}` contient deux fois la même '
                  'requête : «$normalisee».');
        }
      }
    });
  });

  group('Les tables nées ces derniers jours descendent bien', () {
    // Elles ont chacune leur garde dans leur propre fichier de test ; ici on
    // vérifie seulement qu’elles n’ont pas quitté les buckets par mégarde.
    test('`issued_documents` est publiée par by_school', () {
      expect(_tablesPubliees()['issued_documents'], contains('by_school'));
    });

    test('`students` est publiée par by_school', () {
      expect(_tablesPubliees()['students'], contains('by_school'));
    });
  });
  group('La sonde des refus muets couvre ce qui descend vraiment', () {
    // ── CE QUE CE TEST GARDE ────────────────────────────────────────────────
    // `database/checks/0166` annonçait sonder « les 86 tables synchronisées ».
    // Son tableau en listait 67, et 87 descendent réellement. VINGT tables
    // n'avaient jamais été sondées — dont `audit_logs`, `schools`,
    // `school_groups`, `staff_members`, `payment_configs`.
    //
    // ⚠️ Une sonde qui annonce une couverture qu'elle n'a pas est PIRE qu'une
    // sonde absente : elle transforme « je n'ai pas regardé » en « j'ai
    // regardé et il n'y a rien ». Personne ne rouvre le second.
    //
    // La liste de la sonde se tient donc ici, contre les sync-rules — c'est-à-
    // dire contre ce qui descend, pas contre ce dont on se souvient.
    Set<String> tablesSondees() {
      final f = File('../database/checks/0169_refus_muets_update_et_delete.sql');
      expect(f.existsSync(), isTrue,
          reason: 'Sonde aveugle : le contrôle des refus muets a disparu.');
      final sql = f.readAsStringSync().replaceAll('\r\n', '\n');
      final debut = sql.indexOf('tables text[] := ARRAY[');
      expect(debut, greaterThan(-1),
          reason: 'Sonde aveugle : tableau des tables introuvable.');
      final bloc = sql.substring(debut, sql.indexOf('];', debut));
      return RegExp("'([a-z_][a-z0-9_]*)'")
          .allMatches(bloc)
          .map((m) => m.group(1)!)
          .toSet();
    }

    test('toute table publiée par un bucket est sondée', () {
      final oubliees = _tablesPubliees().keys.toSet().difference(tablesSondees());
      expect(oubliees, isEmpty,
          reason: 'Ces tables descendent sur les postes mais échappent à la '
              'chasse aux refus muets — ajouter chacune au tableau de '
              '`0169_refus_muets_update_et_delete.sql` :\n  '
              '${oubliees.join(', ')}');
    });

    test('le seul chemin d\'écriture vers une table muette reste gardé', () {
      // ── CE QUE CE TEST GARDE ──────────────────────────────────────────────
      // Relevé du 2026-09-01 sur les 87 tables synchronisées : `school_holidays`
      // est MUETTE en UPDATE comme en DELETE pour un directeur — la politique
      // `school_holidays_tenant` exige `school_id = auth_school_id()`, donc un
      // férié légal (`school_id IS NULL`) est écarté sans que rien ne lève.
      //
      // C'est la SEULE table muette vers laquelle le dépôt ouvre un chemin
      // d'écriture hors ligne. Sans garde côté Dart, la copie locale change, la
      // remontée ne touche aucune ligne, et la valeur d'origine revient à la
      // synchro suivante — « je l'ai modifié et c'est revenu ».
      //
      // ⚠️ `updateHoliday` n'avait AUCUN appelant quand le garde a été posé, et
      // c'est précisément pourquoi il fallait le poser : une fonction qui perd
      // des écritures en silence n'attend qu'un bouton. Le cadenas de l'IHM
      // (`edt_calendar_tab.dart`) ne compte pas — un verrou d'écran n'est pas
      // un verrou.
      final f = File(
          'lib/features/structure/providers/school_holidays_provider.dart');
      expect(f.existsSync(), isTrue, reason: 'Sonde aveugle : provider absent.');
      final src = f.readAsStringSync().replaceAll('\r\n', '\n');

      for (final nom in ['updateHoliday', 'deleteHoliday']) {
        final debut = src.indexOf('Future<void> $nom(');
        expect(debut, greaterThan(-1), reason: '`$nom` a disparu du provider.');
        // ⚠️ Ne PAS couper sur le premier `\n}` : la parenthèse des
        // paramètres nommés se referme par `}) async {` en colonne 0, donc la
        // coupure tomberait AVANT le corps. On borne sur la déclaration
        // suivante — son commentaire de documentation ou sa signature.
        final bornes = [
          src.indexOf('\n///', debut + 1),
          src.indexOf('\nFuture<', debut + 1),
        ].where((i) => i > debut);
        final fin = bornes.isEmpty ? src.length : bornes.reduce((a, b) => a < b ? a : b);
        expect(src.substring(debut, fin).contains('_estFerieNational'), isTrue,
            reason: '`$nom` écrit sur `school_holidays` sans vérifier que la '
                'ligne appartient à l\'école. Le serveur, lui, refusera SANS '
                'LEVER : la modification paraîtra enregistrée puis reviendra.');
      }
    });

    test('la sonde ne liste rien qui ne descende plus', () {
      // Symétrique : une table retirée des sync-rules et laissée dans la sonde
      // fait grossir le compte « sans ligne visible » et donne l'illusion
      // d'une couverture large.
      final fantomes = tablesSondees().difference(_tablesPubliees().keys.toSet());
      expect(fantomes, isEmpty,
          reason: 'Ces tables sont sondées mais ne descendent plus sur aucun '
              'poste :\n  ${fantomes.join(', ')}');
    });
  });
}
