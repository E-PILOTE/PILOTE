// ════════════════════════════════════════════════════════════════════════════
//  CALENDRIER SCOLAIRE TYPE — République du Congo (Brazzaville).
//
//  La rentrée se situe ~début octobre, la fin d'année ~mi-juillet. Ces valeurs
//  ne sont que des DÉFAUTS PRÉ-REMPLIS et ÉDITABLES : l'admin_groupe ajuste
//  toujours avant de valider. Le but est d'éliminer les fautes de saisie
//  (libellé « 20.26-2027 », dates de quelques jours) sans retirer le contrôle.
//
//  Fonctions PURES (aucune dépendance Flutter/Riverpod) → testables directement.
// ════════════════════════════════════════════════════════════════════════════

/// Année de rentrée à proposer par défaut selon la date du jour.
///
/// À partir de juin, on prépare la rentrée de l'année civile courante
/// (ex. juillet 2026 → 2026-2027). Avant juin, l'année scolaire en cours a
/// démarré l'automne précédent (ex. février 2026 → 2025-2026).
int defaultSchoolYearStart(DateTime now) =>
    now.month >= 6 ? now.year : now.year - 1;

/// Libellé canonique « AAAA-AAAA » (ex. 2026 → « 2026-2027 »).
String schoolYearLabel(int startYear) => '$startYear-${startYear + 1}';

/// Date de rentrée : 1er lundi d'octobre de [startYear].
DateTime schoolYearStartDate(int startYear) {
  var d = DateTime(startYear, 10, 1);
  while (d.weekday != DateTime.monday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// Date de fin : 2ᵉ vendredi de juillet de l'année suivante (~mi-juillet).
DateTime schoolYearEndDate(int startYear) {
  var d = DateTime(startYear + 1, 7, 1);
  var fridays = 0;
  while (true) {
    if (d.weekday == DateTime.friday) {
      fridays++;
      if (fridays == 2) break;
    }
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// Libellé de l'année SUIVANTE (« 2026-2027 » → « 2027-2028 »). Robuste aux
/// formats libres ; renvoie '' si aucun millésime n'est reconnaissable.
String nextSchoolYearLabel(String label) {
  final m = RegExp(r'(\d{4})\s*[-/]\s*(\d{4})').firstMatch(label);
  if (m != null) return '${int.parse(m[1]!) + 1}-${int.parse(m[2]!) + 1}';
  final y = RegExp(r'(\d{4})').firstMatch(label);
  if (y != null) return '${int.parse(y[1]!) + 1}';
  return '';
}
