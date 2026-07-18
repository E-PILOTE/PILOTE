/// Regroupement générique de lignes par CLASSE, pour un rendu virtualisé et
/// pliable (examens, stages). Pur : aucune dépendance Flutter, testable seul.
///
/// Pourquoi ici et générique : les deux modules (candidats d'examen, stages)
/// affichent des listes potentiellement longues (500+ à l'échelle nationale)
/// qu'on ne veut ni à plat ni non virtualisées. Ce module produit le modèle
/// APLATI (en-têtes + lignes) que consomme un `SliverList.builder`.
class ClassGroup<T> {
  ClassGroup({
    required this.classId,
    required this.className,
    required this.filiereLabel,
    required this.levelOrder,
    required this.items,
  });

  final String? classId;
  final String className;
  final String? filiereLabel;
  final int levelOrder;
  final List<T> items;
}

/// Regroupe `rows` par `classId`, chaque groupe trié par `levelOrder` puis nom.
/// L'ordre des items à l'intérieur d'un groupe suit l'ordre d'entrée (déjà trié
/// par la requête SQL : last_name, first_name).
List<ClassGroup<T>> groupByClass<T>(
  List<T> rows, {
  required String? Function(T) classId,
  required String Function(T) className,
  required String? Function(T) filiere,
  required int Function(T) levelOrder,
}) {
  final map = <String?, ClassGroup<T>>{};
  for (final r in rows) {
    final id = classId(r);
    final g = map.putIfAbsent(
      id,
      () => ClassGroup<T>(
        classId: id,
        className: className(r),
        filiereLabel: filiere(r),
        levelOrder: levelOrder(r),
        items: <T>[],
      ),
    );
    g.items.add(r);
  }
  final list = map.values.toList()
    ..sort((a, b) {
      final d = a.levelOrder.compareTo(b.levelOrder);
      return d != 0 ? d : a.className.compareTo(b.className);
    });
  return list;
}

/// Une entrée de la liste APLATIE consommée par le SliverList : soit un en-tête
/// de groupe, soit une ligne d'item (présente seulement si le groupe est déplié).
sealed class GroupedRow<T> {
  const GroupedRow();
}

class GroupHeaderRow<T> extends GroupedRow<T> {
  const GroupHeaderRow(this.group);
  final ClassGroup<T> group;
}

class GroupItemRow<T> extends GroupedRow<T> {
  const GroupItemRow(this.item, this.classId);
  final T item;
  final String? classId;
}

/// Aplati les groupes en une séquence header/items. Un groupe dont le `classId`
/// est dans `collapsed` n'émet que son en-tête. C'est ce que parcourt le
/// `SliverList.builder` -> virtualisation réelle.
List<GroupedRow<T>> flattenGroups<T>(
  List<ClassGroup<T>> groups,
  Set<String?> collapsed,
) {
  final out = <GroupedRow<T>>[];
  for (final g in groups) {
    out.add(GroupHeaderRow<T>(g));
    if (!collapsed.contains(g.classId)) {
      for (final it in g.items) {
        out.add(GroupItemRow<T>(it, g.classId));
      }
    }
  }
  return out;
}
