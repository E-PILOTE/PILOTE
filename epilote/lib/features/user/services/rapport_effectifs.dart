// ════════════════════════════════════════════════════════════════════════════
//  L'ÉTAT DES EFFECTIFS — le comptage, séparé de son affichage
//
//  ── POURQUOI CE FICHIER EXISTE SEUL ────────────────────────────────────────
//  Ce que ces fonctions produisent part sur du papier à en-tête, signé par un
//  chef d'établissement et transmis à une direction départementale. Un total
//  faux n'y est pas un défaut d'affichage : c'est une déclaration inexacte.
//
//  Enfermé dans un `build()` ou dans un service PDF, ce comptage n'aurait été
//  vérifiable qu'en imprimant. Ici, il l'est ligne à ligne
//  (`rapport_effectifs_test.dart`).
//
//  ── LA RÈGLE QUI TIENT TOUT LE RESTE ───────────────────────────────────────
//  ⚠️ **Aucun élève actif ne peut disparaître d'un état.** Un élève dont la
//  classe n'a pas de cycle, ou dont la classe est introuvable, ne doit PAS être
//  écarté silencieusement : il rejoint une ligne qui le dit. Écarter, c'est
//  sous-déclarer un effectif — et l'effectif déclaré décide des dotations.
// ════════════════════════════════════════════════════════════════════════════

/// Un élève tel qu'il compte dans un état officiel.
///
/// [statut] est celui de son INSCRIPTION : seul `active` entre dans un
/// effectif. [sexe] vaut `'M'`, `'F'` ou `null` — les listes importées d'un
/// tableur en contiennent, et le fichier d'import lui-même rend `null` quand
/// la colonne ne se lit pas.
typedef EleveCompte = ({
  String? classId,
  String? className,
  String? cycleCode,
  int levelOrder,
  String? statut,
  String? sexe,
  bool interne,
  bool boursier,
});

/// Une ligne d'état : une classe, ou un cumul (cycle, total général).
typedef LigneEffectif = ({
  String classId,
  String className,
  String? cycleCode,
  int levelOrder,
  int total,
  int filles,
  int garcons,
  int sexeInconnu,
  int internes,
  int boursiers,
});

/// Le seul statut d'inscription qui compte dans un effectif.
const String kStatutInscrit = 'active';

/// Libellé de la classe de repli, quand une inscription active n'en désigne
/// aucune. ⚠️ Elle ne doit jamais rester vide en production : sa présence sur
/// un état signale une donnée à corriger, pas une catégorie d'élèves.
const String kSansClasse = 'Sans classe';

/// Libellé du regroupement des classes qu'aucun cycle ne rattache.
const String kCycleNonRattache = 'Non rattaché';

/// L'effectif par classe, dans l'ordre où un chef d'établissement le lit :
/// du plus petit niveau au plus grand, puis par nom de classe.
///
/// ⚠️ Les inscriptions non actives sont écartées ICI et nulle part ailleurs.
/// Compter un élève retiré en mars gonflerait l'effectif déclaré ; le compter
/// dans le total mais pas dans sa classe le rendrait introuvable.
List<LigneEffectif> effectifsParClasse(Iterable<EleveCompte> eleves) {
  final parClasse = <String, LigneEffectif>{};

  for (final e in eleves) {
    if (e.statut != kStatutInscrit) continue;

    final id = (e.classId ?? '').trim();
    final cle = id.isEmpty ? kSansClasse : id;
    final courant = parClasse[cle];

    final nom = (e.className ?? '').trim();
    parClasse[cle] = (
      classId: cle,
      className: courant?.className ??
          (id.isEmpty ? kSansClasse : (nom.isEmpty ? kSansClasse : nom)),
      cycleCode: courant?.cycleCode ?? e.cycleCode,
      // Une classe sans niveau se range en fin d'état plutôt qu'en tête : la
      // première ligne d'un document officiel doit être la plus petite classe.
      levelOrder: courant?.levelOrder ?? (id.isEmpty ? 9999 : e.levelOrder),
      total: (courant?.total ?? 0) + 1,
      filles: (courant?.filles ?? 0) + (e.sexe == 'F' ? 1 : 0),
      garcons: (courant?.garcons ?? 0) + (e.sexe == 'M' ? 1 : 0),
      // ⚠️ Un sexe non renseigné n'est PAS un garçon. Le ranger d'office chez
      // les garçons produirait un état où filles + garçons = total, donc
      // impossible à contester — et faux.
      sexeInconnu:
          (courant?.sexeInconnu ?? 0) + (e.sexe != 'F' && e.sexe != 'M' ? 1 : 0),
      internes: (courant?.internes ?? 0) + (e.interne ? 1 : 0),
      boursiers: (courant?.boursiers ?? 0) + (e.boursier ? 1 : 0),
    );
  }

  final lignes = parClasse.values.toList()
    ..sort((a, b) {
      final o = a.levelOrder.compareTo(b.levelOrder);
      return o != 0 ? o : a.className.compareTo(b.className);
    });
  return lignes;
}

/// Additionne des lignes en une seule, sous le libellé donné.
///
/// Sert aux sous-totaux de cycle comme au total général : un seul chemin
/// d'addition, donc une seule occasion de se tromper.
LigneEffectif cumul(String libelle, Iterable<LigneEffectif> lignes) {
  var total = 0, filles = 0, garcons = 0, inconnu = 0, internes = 0, bours = 0;
  for (final l in lignes) {
    total += l.total;
    filles += l.filles;
    garcons += l.garcons;
    inconnu += l.sexeInconnu;
    internes += l.internes;
    bours += l.boursiers;
  }
  return (
    classId: '',
    className: libelle,
    cycleCode: null,
    levelOrder: 0,
    total: total,
    filles: filles,
    garcons: garcons,
    sexeInconnu: inconnu,
    internes: internes,
    boursiers: bours,
  );
}

/// Un cycle et ses classes, prêt à imprimer.
typedef BlocCycle = ({String cycle, List<LigneEffectif> classes, LigneEffectif total});

/// Regroupe les classes par cycle, chaque cycle apparaissant dans l'ordre de
/// sa plus petite classe — c'est-à-dire l'ordre de la scolarité.
///
/// ⚠️ Les classes sans cycle forment leur propre bloc au lieu d'être écartées.
/// Un bloc visible se corrige ; un élève absent d'un état ne se voit pas.
List<BlocCycle> blocsParCycle(List<LigneEffectif> lignes) {
  final ordre = <String>[];
  final parCycle = <String, List<LigneEffectif>>{};
  for (final l in lignes) {
    final brut = (l.cycleCode ?? '').trim();
    final cle = brut.isEmpty ? kCycleNonRattache : brut;
    final bloc = parCycle[cle];
    if (bloc == null) {
      ordre.add(cle);
      parCycle[cle] = [l];
    } else {
      bloc.add(l);
    }
  }
  return [
    for (final c in ordre)
      (cycle: c, classes: parCycle[c]!, total: cumul('Total $c', parCycle[c]!)),
  ];
}

/// Part de filles dans un effectif, en %. `null` quand l'effectif est nul —
/// « 0 % de filles » sur une école vide se lirait comme un fait.
double? partFilles(LigneEffectif l) =>
    l.total == 0 ? null : l.filles * 100 / l.total;
