import 'exam_archives_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE CHIFFRE NATIONAL, POSÉ À CÔTÉ DU CHIFFRE DU RÉSEAU.
//
//  ── LE PROBLÈME QUE ÇA RÈGLE ───────────────────────────────────────────────
//  Le cockpit dit « 50,6 % de réussite ». La DEC a proclamé 51,61 % au
//  national. Les deux nombres sont justes et ne mesurent pas la même chose :
//  l'un porte sur les 91 candidats du réseau, l'autre sur les 15 843 du pays.
//  Seuls à l'écran, ils invitent la seule question qu'on ne veut pas entendre
//  en présentation — « alors, c'est lequel le vrai ? ».
//
//  Posés côte à côte, ils disent l'inverse : le réseau se situe AU NIVEAU du
//  national, et l'application le montre sans qu'on ait à ouvrir un rapport.
//  C'est aussi la démonstration du produit : le chiffre officiel relevé sur
//  « Résultats & archives » revient tout seul éclairer le pilotage.
//
//  ── DEUX RÈGLES DE RIGUEUR ─────────────────────────────────────────────────
//  1. La référence n'existe que pour UN examen. Il n'y a pas de taux national
//     « tous examens confondus » : le BET et le bac T&P ne se moyennent pas.
//  2. La session de la référence est TOUJOURS nommée. À défaut du chiffre de
//     la session courante, on montre la dernière session proclamée — mais
//     jamais sans dire laquelle, sinon on compare 2026 à 2025 en silence.
// ════════════════════════════════════════════════════════════════════════════

/// Le taux national proclamé par la DEC pour un examen, avec sa session.
class NationalReference {
  const NationalReference({
    required this.examCode,
    required this.yearLabel,
    required this.rate,
    required this.isCurrentSession,
    this.present,
    this.admitted,
    this.sourceLabel,
  });

  final String examCode;

  /// Année scolaire de la session proclamée (« 2024-2025 » = juin 2025).
  final String yearLabel;

  /// Taux de réussite en pourcentage, sur les PRÉSENTS.
  final double rate;

  /// `false` quand la DEC n'a encore rien proclamé pour la session en cours :
  /// la comparaison reste utile, à condition de la dater.
  final bool isCurrentSession;

  final int? present;
  final int? admitted;
  final String? sourceLabel;

  bool get hasCounts => present != null && admitted != null;
}

/// Retient, pour [examCode], le chiffre national opposable.
///
/// Priorité à la session en cours ([currentYearLabel]) ; à défaut, la session
/// proclamée la plus récente. `null` quand rien n'est relevé — et un `null`
/// s'affiche comme une absence, jamais comme un zéro.
NationalReference? nationalReferenceFor(
  List<OfficialFigure> figures, {
  required String? examCode,
  required String? currentYearLabel,
}) {
  // Règle 1 : pas de référence hors d'un examen précis.
  if (examCode == null) return null;

  final candidates = <OfficialFigure>[
    for (final f in figures)
      if (f.scope == PubScope.national &&
          f.examCode == examCode &&
          f.yearLabel != null &&
          f.passRate != null)
        f,
  ];
  if (candidates.isEmpty) return null;

  // Les libellés d'année scolaire (« 2024-2025 ») se comparent tels quels :
  // l'ordre lexicographique est l'ordre chronologique.
  candidates.sort((a, b) => b.yearLabel!.compareTo(a.yearLabel!));
  final best = candidates.firstWhere(
    (f) => f.yearLabel == currentYearLabel,
    orElse: () => candidates.first,
  );

  return NationalReference(
    examCode: examCode,
    yearLabel: best.yearLabel!,
    rate: best.passRate!,
    isCurrentSession: best.yearLabel == currentYearLabel,
    present: best.present,
    admitted: best.admitted,
    sourceLabel: best.sourceLabel,
  );
}
