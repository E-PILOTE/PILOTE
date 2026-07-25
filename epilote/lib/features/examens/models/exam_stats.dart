// ════════════════════════════════════════════════════════════════════════════
//  STATISTIQUES DE RÉUSSITE — ce que le ministère lira.
//
//  ── La règle qui fait tout ──────────────────────────────────────────────────
//  Le taux se calcule sur les RÉSULTATS CONNUS, jamais sur l'effectif. Une
//  session non encore proclamée afficherait sinon 0 % de réussite, et une école
//  irréprochable passerait pour sinistrée la veille d'une présentation.
//
//  Corollaire assumé : quand aucun résultat n'est connu, `rate` vaut `null` —
//  PAS zéro. L'écran doit alors écrire « en attente de proclamation », pas un
//  chiffre. Un taux nul et un taux inconnu ne sont pas la même chose.
//
//  L'assiette accompagne toujours le taux à l'affichage (« 42 résultats connus
//  sur 60 candidats ») : un pourcentage sans son dénominateur est un mensonge
//  commode.
// ════════════════════════════════════════════════════════════════════════════

/// Résultats qui comptent comme CONNUS. Un absent ou un fraudeur a bien un
/// résultat — il n'est simplement pas admis.
const _kKnownResults = {'admis', 'ajourne', 'absent', 'fraude'};

class ExamStatInput {
  const ExamStatInput({
    required this.result,
    this.className,
    this.filiereLabel,
    this.gender,
    this.mention,
    this.department,
  });

  final String result;
  final String? className;
  final String? filiereLabel;
  final String? gender;
  final String? mention;

  /// Département de l'établissement — dimension du pilotage MINISTÉRIEL
  /// (inutilisée côté école : une école = un département). Voir
  /// [groupExamLines] pour la ventilation nationale.
  final String? department;

  bool get isKnown => _kKnownResults.contains(result);
  bool get isAdmitted => result == 'admis';
}

/// `true` si le résultat compte comme CONNU (proclamé). Exposé pour que le
/// cockpit ministériel partage la MÊME règle que l'école — ne jamais recopier
/// la liste `_kKnownResults` ailleurs (source unique, cf. barème mentions).
bool isKnownExamResult(String result) => _kKnownResults.contains(result);

/// Ventile une population de candidats selon une clé arbitraire (filière,
/// département…) en lignes de réussite [ExamStatLine], en appliquant la règle
/// « taux sur résultats connus » (`rate` = `null` tant que rien n'est proclamé).
/// Réutilisé par le cockpit ministériel pour les axes que [computeExamStats]
/// ne porte pas (ex. département). Trié par effectif décroissant.
List<ExamStatLine> groupExamLines(
  Iterable<ExamStatInput> rows,
  String? Function(ExamStatInput) keyOf, {
  String unsetLabel = _kUnset,
}) {
  final m = <String, _Acc>{};
  for (final r in rows) {
    final k = keyOf(r);
    final key = k?.trim().isNotEmpty == true ? k!.trim() : unsetLabel;
    final a = m.putIfAbsent(key, _Acc.new);
    a.total++;
    if (r.isKnown) {
      a.known++;
      if (r.isAdmitted) a.admitted++;
    }
  }
  return _lines(m);
}

class ExamStatLine {
  const ExamStatLine({
    required this.label,
    required this.total,
    required this.known,
    required this.admitted,
  });

  final String label;

  /// Candidats inscrits sur cette ligne.
  final int total;

  /// Ceux dont le résultat est proclamé — le dénominateur du taux.
  final int known;

  final int admitted;

  /// `null` tant qu'aucun résultat n'est connu : afficher 0 % serait faux.
  double? get rate => known == 0 ? null : admitted / known;

  /// Ce qui reste à proclamer.
  int get pending => total - known;
}

class ExamStats {
  const ExamStats({
    required this.overall,
    required this.byClass,
    required this.byFiliere,
    required this.byGender,
    required this.mentions,
  });

  final ExamStatLine overall;
  final List<ExamStatLine> byClass;
  final List<ExamStatLine> byFiliere;
  final List<ExamStatLine> byGender;

  /// Répartition des mentions — sur les ADMIS seulement : la mention d'un
  /// ajourné n'a pas de sens.
  final Map<String, int> mentions;

  bool get hasResults => overall.known > 0;
}

const _kUnset = 'Non renseigné';

class _Acc {
  int total = 0, known = 0, admitted = 0;
}

List<ExamStatLine> _lines(Map<String, _Acc> src) {
  final out = [
    for (final e in src.entries)
      ExamStatLine(
        label: e.key,
        total: e.value.total,
        known: e.value.known,
        admitted: e.value.admitted,
      ),
  ];
  // Trié par effectif décroissant : les grosses cohortes portent le résultat
  // de l'établissement, elles doivent se lire en premier.
  out.sort((a, b) => b.total.compareTo(a.total));
  return out;
}

String _genderLabel(String? g) => switch (g) {
      'M' => 'Garçons',
      'F' => 'Filles',
      _ => _kUnset,
    };

ExamStats computeExamStats(List<ExamStatInput> rows) {
  final overall = _Acc();
  final byClass = <String, _Acc>{};
  final byFiliere = <String, _Acc>{};
  final byGender = <String, _Acc>{};
  final mentions = <String, int>{};

  void bump(Map<String, _Acc> m, String key, ExamStatInput r) {
    final a = m.putIfAbsent(key, _Acc.new);
    a.total++;
    if (r.isKnown) {
      a.known++;
      if (r.isAdmitted) a.admitted++;
    }
  }

  for (final r in rows) {
    overall.total++;
    if (r.isKnown) {
      overall.known++;
      if (r.isAdmitted) overall.admitted++;
    }

    bump(byClass, r.className?.trim().isNotEmpty == true ? r.className! : _kUnset, r);
    bump(byFiliere,
        r.filiereLabel?.trim().isNotEmpty == true ? r.filiereLabel! : _kUnset, r);
    bump(byGender, _genderLabel(r.gender), r);

    final m = r.mention?.trim();
    if (r.isAdmitted && m != null && m.isNotEmpty) {
      mentions[m] = (mentions[m] ?? 0) + 1;
    }
  }

  return ExamStats(
    overall: ExamStatLine(
      label: 'Ensemble',
      total: overall.total,
      known: overall.known,
      admitted: overall.admitted,
    ),
    byClass: _lines(byClass),
    byFiliere: _lines(byFiliere),
    byGender: _lines(byGender),
    mentions: mentions,
  );
}
