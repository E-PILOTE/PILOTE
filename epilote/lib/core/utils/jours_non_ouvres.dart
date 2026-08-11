// ════════════════════════════════════════════════════════════════════════════
//  JOURS NON OUVRÉS — natures de fermeture et comptage des jours de classe.
//
//  Ce fichier ne contient PLUS la liste des fériés congolais ni le comput
//  pascal. Ils vivaient ici en double avec `national_holidays_congo()` et
//  `fn_easter_sunday()` en base, bordés par un test qui comparait le Dart à une
//  liste figée — garde-fou en trompe-l'œil : il ne voyait pas le SQL dériver.
//
//  La base est désormais l'UNIQUE autorité. Deux raisons, dans cet ordre :
//
//   1. le parc. Plus de 1000 écoles mises à jour de façon échelonnée : une
//      règle embarquée dans le binaire donne des calendriers différents selon
//      la version installée. Une règle en base donne les mêmes lignes à tous.
//   2. le décret. Le jour où un férié est ajouté ou déplacé — probable sur la
//      durée de vie de ce logiciel — il n'y a qu'un endroit à corriger, pas
//      deux dont un s'oubliera.
//
//  Le groupe sème le calendrier national une fois par année scolaire (RPC
//  `seed_national_holidays`, transactionnelle, auditée, idempotente) ; les
//  écoles en héritent par le bucket `by_group` des sync-rules et ne le
//  ressaisissent jamais.
//
//  Fonctions PURES : aucune dépendance Flutter, directement testables.
// ════════════════════════════════════════════════════════════════════════════

/// Natures de jour non ouvré (colonne `school_holidays.kind`).
///
/// Ici plutôt que dans le provider école : l'espace groupe saisit le calendrier
/// national et a besoin des mêmes valeurs, sans pour autant tirer PowerSync
/// dans ses dépendances.
const kHolidayKinds = <(String, String)>[
  ('ferie', 'Jour férié'),
  ('vacances', 'Vacances scolaires'),
];

String holidayKindLabel(String? k) => kHolidayKinds
    .firstWhere((e) => e.$1 == k, orElse: () => ('ferie', 'Jour férié'))
    .$2;

/// Ajoute [n] jours à [d] sans passer par `Duration`.
///
/// `add(Duration(days: 1))` décale d'une heure au passage d'un changement
/// d'heure : le Congo n'en connaît pas, mais les tests tournent sur le fuseau
/// du poste de développement, qui lui en connaît. Le constructeur normalise
/// les débordements de mois et ignore la question.
DateTime _plus(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

/// Une période pendant laquelle l'école ne fonctionne pas.
typedef PeriodeFermee = ({DateTime start, DateTime end});

/// Jours de classe réellement travaillés entre [from] et [to] : les jours de
/// semaine (lundi → vendredi) desquels on retranche [closed] (vacances, fériés).
///
/// C'est le seul chiffre qu'un responsable regarde vraiment sur un calendrier :
/// « combien de jours de classe pour boucler le programme ». Volontairement
/// détaché de tout modèle : l'espace groupe et l'espace école ont chacun le
/// leur, la règle de comptage est la même.
int countWorkingDays(
    DateTime from, DateTime to, List<PeriodeFermee> closed) {
  var jour = _jour(from);
  final fin = _jour(to);
  var n = 0;
  while (!jour.isAfter(fin)) {
    if (jour.weekday != DateTime.saturday &&
        jour.weekday != DateTime.sunday &&
        !closed.any((p) =>
            !_jour(p.start).isAfter(jour) && !_jour(p.end).isBefore(jour))) {
      n++;
    }
    jour = _plus(jour, 1);
  }
  return n;
}
