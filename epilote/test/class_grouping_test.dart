import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/core/utils/class_grouping.dart';

class _Row {
  const _Row(this.cid, this.cls, this.fil, this.ord, this.name);
  final String? cid;
  final String cls;
  final String? fil;
  final int ord;
  final String name;
}

List<ClassGroup<_Row>> _group(List<_Row> rows) => groupByClass<_Row>(
      rows,
      classId: (r) => r.cid,
      className: (r) => r.cls,
      filiere: (r) => r.fil,
      levelOrder: (r) => r.ord,
    );

void main() {
  group('groupByClass', () {
    test('regroupe par classe, trie par levelOrder puis nom de classe', () {
      final rows = [
        const _Row('b', 'Tle A', 'BAC_T', 2, 'Zoé'),
        const _Row('a', '3e B', null, 1, 'Ana'),
        const _Row('b', 'Tle A', 'BAC_T', 2, 'Bob'),
      ];
      final g = _group(rows);
      expect(g.map((e) => e.classId).toList(), ['a', 'b']);
      expect(g[1].items.length, 2);
      expect(g[1].filiereLabel, 'BAC_T');
      expect(g[0].levelOrder, 1);
    });

    test('liste vide -> aucun groupe', () {
      expect(_group(const []), isEmpty);
    });
  });

  group('flattenGroups', () {
    test('groupe déplié = header + items ; replié = header seul', () {
      final rows = [
        const _Row('a', '3e B', null, 1, 'Ana'),
        const _Row('b', 'Tle A', 'BAC_T', 2, 'Bob'),
      ];
      final g = _group(rows);
      final flat = flattenGroups<_Row>(g, {'b'}); // 'b' replié
      // a: header + 1 item ; b: header seul
      expect(flat.length, 3);
      expect(flat[0], isA<GroupHeaderRow<_Row>>());
      expect(flat[1], isA<GroupItemRow<_Row>>());
      expect(flat[2], isA<GroupHeaderRow<_Row>>());
    });
  });
}
