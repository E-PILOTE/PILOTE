import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/admin_groupe/providers/wayback_provider.dart';

const _sample = '''
{
  "32246": {
    "itemTitle": "World Imagery (Wayback 2026-06-30)",
    "itemURL": "https://wayback.maptiles.arcgis.com/arcgis/rest/services/World_Imagery/WMTS/1.0.0/default028mm/MapServer/tile/32246/{level}/{row}/{col}"
  },
  "10842": {
    "itemTitle": "World Imagery (Wayback 2018-03-15)",
    "itemURL": "https://wayback.maptiles.arcgis.com/arcgis/rest/services/World_Imagery/WMTS/1.0.0/default028mm/MapServer/tile/10842/{level}/{row}/{col}"
  }
}
''';

void main() {
  test('parseWaybackConfig extrait, date et trie décroissant', () {
    final r = parseWaybackConfig(_sample);
    expect(r.length, 2);
    expect(r.first.date.year, 2026); // plus récent d'abord
    expect(r.first.releaseNum, 32246);
    expect(r.last.date.year, 2018);
  });

  test('tileUrlTemplate est converti au format flutter_map {z}/{y}/{x}', () {
    final r = parseWaybackConfig(_sample);
    expect(r.first.tileUrlTemplate, contains('{z}/{y}/{x}'));
    expect(r.first.tileUrlTemplate, isNot(contains('{level}')));
    expect(r.first.tileUrlTemplate, isNot(contains('{row}')));
    expect(r.first.tileUrlTemplate, isNot(contains('{col}')));
  });

  test('parse tolère un JSON vide/mauvais → liste vide', () {
    expect(parseWaybackConfig('{}'), isEmpty);
    expect(parseWaybackConfig('null'), isEmpty);
    expect(parseWaybackConfig('[]'), isEmpty);
  });

  test('ignore les entrées sans date ou sans URL', () {
    const bad = '{"1":{"itemTitle":"World Imagery (sans date)","itemURL":"x/{level}/{row}/{col}"},'
        '"2":{"itemTitle":"World Imagery (Wayback 2020-01-01)"}}';
    expect(parseWaybackConfig(bad), isEmpty);
  });
}
