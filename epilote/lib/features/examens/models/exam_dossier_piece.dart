import 'dart:convert';

// ════════════════════════════════════════════════════════════════════════════
//  UNE PIÈCE DU DOSSIER D'EXAMEN
//
//  Source de vérité : `exam_sessions.required_documents` (migration 0052, note
//  officielle METP). Une pièce n'est pas un libellé — elle porte trois
//  distinctions sans lesquelles le dossier ment :
//
//   • NATURE. Une chemise cartonnée et une enveloppe kaki ne seront JAMAIS un
//     fichier. Sans cette distinction, « manquant = exigé − fichiers présents »
//     déclarerait éternellement incomplet tout dossier du pays.
//
//   • CONDITION. Le certificat médical d'inaptitude n'est dû que si le candidat
//     est déclaré inapte à l'EPS ; la note ENEF, que pour le BTF. Les exiger de
//     tous rendrait tout dossier incomplet à jamais.
//
//   • LÉGALISATION. Le diplôme n'est pas « fourni » : il est fourni LÉGALISÉ.
//     C'est le motif de rejet au comptoir le plus banal.
//
//  Rétrocompatibilité : les sessions MEPSA (CEPE, BEPC, BAC_G) n'ont pas été
//  retouchées faute de source — leurs pièces n'ont ni `nature` ni `source`.
//  D'où les valeurs par défaut : fichier / élève / inconditionnelle.
// ════════════════════════════════════════════════════════════════════════════

enum PieceNature {
  /// Dématérialisable : acte de naissance, diplôme, attestation, certificat.
  fichier,

  /// Objet physique : chemise cartonnée, enveloppe kaki. Jamais un fichier,
  /// donc jamais dérivable — se coche à la main.
  physique,

  /// Frais d'inscription : relève du module Paiements, pas d'un dépôt de pièce.
  financiere;

  static PieceNature parse(String? raw) => switch (raw) {
        'physique' => PieceNature.physique,
        'financiere' => PieceNature.financiere,
        _ => PieceNature.fichier,
      };
}

enum PieceSource {
  /// Permanente : vit dans `student-documents`, ressert à chaque session.
  /// Cf. migration 0008 : « le dossier suit l'ÉLÈVE, réinscription = rien à
  /// re-téléverser ».
  eleve,

  /// Propre à CETTE session : attestation de stage de l'année, certificat
  /// médical, reçu de frais. Réutiliser la précédente serait une faute.
  candidature;

  static PieceSource parse(String? raw) =>
      raw == 'candidature' ? PieceSource.candidature : PieceSource.eleve;
}

class ExamDossierPiece {
  const ExamDossierPiece({
    required this.code,
    required this.label,
    required this.copies,
    required this.nature,
    required this.source,
    required this.legalise,
    required this.condition,
  });

  final String code;
  final String label;
  final int copies;
  final PieceNature nature;
  final PieceSource source;
  final bool legalise;

  /// `si_inapte_eps`, … ou `null` si la pièce est due par tout le monde.
  final String? condition;

  /// Une pièce conditionnelle ne bloque JAMAIS la complétude : nous ne pouvons
  /// pas savoir qui est inapte à l'EPS, et la DEC vérifie au comptoir. La
  /// deviner produirait un dossier faux ; l'ignorer laisse l'école décider.
  bool get isConditional => condition != null;

  String get conditionLabel => switch (condition) {
        'si_inapte_eps' => 'seulement si le candidat est déclaré inapte à l\'EPS',
        _ => 'seulement si applicable',
      };

  static ExamDossierPiece fromMap(Map<String, dynamic> m) => ExamDossierPiece(
        code: m['code'] as String? ?? '',
        label: m['label'] as String? ?? '',
        copies: (m['copies'] as num?)?.toInt() ?? 1,
        nature: PieceNature.parse(m['nature'] as String?),
        source: PieceSource.parse(m['source'] as String?),
        legalise: m['legalise'] == true,
        condition: m['condition'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'label': label,
        'copies': copies,
        'nature': nature.name,
        'source': source.name,
        if (legalise) 'legalise': true,
        if (condition != null) 'condition': condition,
      };

  /// Tolère une colonne `jsonb` rendue en texte par PowerSync, une liste déjà
  /// décodée, ou `null`. Un dossier ne doit jamais planter sur une donnée molle.
  static List<ExamDossierPiece> parseList(Object? raw) {
    if (raw == null) return const [];
    final Object? decoded = raw is String
        ? (raw.trim().isEmpty ? null : jsonDecode(raw))
        : raw;
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => ExamDossierPiece.fromMap(e.cast<String, dynamic>()))
        .where((p) => p.code.isNotEmpty)
        .toList();
  }

  static String encodeList(Iterable<ExamDossierPiece> pieces) =>
      jsonEncode(pieces.map((p) => p.toMap()).toList());
}
