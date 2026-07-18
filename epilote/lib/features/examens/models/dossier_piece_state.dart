import 'exam_dossier_piece.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉTAT RÉEL D'UNE PIÈCE — et la règle qui décide si un élève compose.
//
//  Principe : une pièce est fournie parce qu'un FICHIER y est attaché, pas
//  parce qu'un agent a coché. C'est la règle déjà tenue pour `attestation_stage`
//  (satisfaite PAR le module Stages), étendue ici au dossier entier.
//
//  ── Pourquoi la déclaration survit quand même ──────────────────────────────
//  Deux raisons, aucune n'est de la complaisance :
//
//   1. RÉTROCOMPATIBILITÉ. Des milliers de dossiers ont été cochés avant que le
//      téléversement existe. Si « fournie » exigeait soudain un fichier, tous
//      redeviendraient incomplets la veille d'une clôture. On n'invalide pas le
//      travail déjà fait d'un pays pour la pureté d'un modèle.
//
//   2. IMPOSSIBILITÉ MATÉRIELLE. Une chemise cartonnée et une enveloppe kaki ne
//      seront JAMAIS un fichier ; les frais relèvent des Paiements. Pour ces
//      pièces la déclaration n'est pas un repli, c'est le seul mode possible.
//
//  Le scan est donc une preuve PLUS FORTE, pas une condition nouvelle. L'écran
//  distingue les deux et pousse à téléverser — il ne punit pas rétroactivement.
// ════════════════════════════════════════════════════════════════════════════

/// Code de la pièce « attestation de stage » — le point de jonction avec le
/// module Stages, seule source de vérité de cette pièce.
const kStagePieceCode = 'attestation_stage';

/// L'état d'une pièce, du plus faible au plus fort.
enum PieceFileState {
  /// Rien : ni fichier, ni déclaration. Seul état qui compte comme manquant.
  absente,

  /// Déclarée fournie par l'agent, sans scan. État terminal légitime pour une
  /// pièce physique ou financière ; état faible (à renforcer) pour un fichier.
  declaree,

  /// Un fichier réel est attaché.
  fournie,

  /// Un agent a ouvert le scan et confirmé qu'il est lisible, au bon nom, et
  /// légalisé si la pièce l'exige. Le pré-contrôle avant le comptoir DEC.
  verifiee,
}

/// Un fichier réellement attaché à une pièce du dossier.
/// Reflet d'une ligne `student_documents`.
class AttachedPiece {
  const AttachedPiece({
    required this.documentId,
    required this.code,
    required this.fileUrl,
    required this.fileName,
    required this.isVerified,
    this.verifiedAt,
    this.examCandidateId,
  });

  /// `student_documents.id`
  final String documentId;

  /// `student_documents.document_type` — égal au `code` de la pièce exigée.
  final String code;

  /// Chemin Storage (bucket privé) — jamais une URL publique.
  final String fileUrl;
  final String fileName;

  final bool isVerified;
  final DateTime? verifiedAt;

  /// `null` = pièce de l'ÉLÈVE, réutilisable à chaque candidature.
  /// Renseigné = pièce propre à CETTE candidature. Cf. migration 0056.
  final String? examCandidateId;

  bool get isStudentScoped => examCandidateId == null;

  PieceFileState get state =>
      isVerified ? PieceFileState.verifiee : PieceFileState.fournie;
}

/// L'état affichable d'une pièce, fichier et déclaration confondus.
PieceFileState pieceStateFor({
  required AttachedPiece? attached,
  required bool declared,
}) {
  if (attached != null) return attached.state;
  return declared ? PieceFileState.declaree : PieceFileState.absente;
}

/// Les pièces encore manquantes — celles qui feront renvoyer l'école au comptoir.
///
/// Une pièce est couverte si elle est ATTACHÉE (preuve forte) ou DÉCLARÉE
/// (preuve faible, mais seule possible pour le physique et le financier).
/// Les pièces conditionnelles n'entrent JAMAIS dans le compte : nous ne savons
/// pas qui est inapte à l'EPS, et la DEC tranche au comptoir. Les deviner
/// produirait un dossier faux.
List<ExamDossierPiece> deriveMissing({
  required List<ExamDossierPiece> required,
  required Set<String> attachedCodes,
  required Set<String> declaredCodes,
  required bool stageIssued,
}) {
  final missing = <ExamDossierPiece>[];
  for (final p in required) {
    if (p.isConditional) continue;

    // L'attestation de stage est satisfaite PAR le module Stages : le système
    // le sait, on ne redemande pas à l'agent de le déclarer.
    if (p.code == kStagePieceCode && stageIssued) continue;

    if (attachedCodes.contains(p.code) || declaredCodes.contains(p.code)) {
      continue;
    }
    missing.add(p);
  }
  return missing;
}
