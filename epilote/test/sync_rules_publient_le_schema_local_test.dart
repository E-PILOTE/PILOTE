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
}
