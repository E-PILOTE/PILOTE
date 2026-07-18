/// Détail COMPLET d'un stage — tout ce qu'exigent les documents officiels
/// (attestation de fin de stage, convention). `InternshipRow` reste léger pour
/// la liste virtualisée ; ce modèle n'est chargé qu'à la génération d'un document.
class StageDetail {
  const StageDetail({
    required this.id,
    required this.studentName,
    required this.matricule,
    required this.dateOfBirth,
    required this.gender,
    required this.className,
    required this.filiereLabel,
    required this.companyName,
    required this.companySector,
    required this.companyAddress,
    required this.companyCity,
    required this.companyContact,
    required this.companyTutorName,
    required this.companyTutorPhone,
    required this.schoolTutorName,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.conventionSignedAt,
    required this.attestationIssuedAt,
    required this.evaluationGrade,
    required this.evaluationComment,
  });

  final String id;
  final String studentName;
  final String? matricule;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? className;
  final String? filiereLabel;

  final String? companyName;
  final String? companySector;
  final String? companyAddress;
  final String? companyCity;
  final String? companyContact;
  final String? companyTutorName;
  final String? companyTutorPhone;

  final String? schoolTutorName;

  final String? title;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;

  final DateTime? conventionSignedAt;
  final DateTime? attestationIssuedAt;
  final double? evaluationGrade;
  final String? evaluationComment;

  bool get hasAttestation => attestationIssuedAt != null;

  /// Adresse compacte « adresse, ville » (sans virgule pendante si l'une manque).
  String? get companyPlace {
    final parts = [companyAddress, companyCity]
        .where((e) => e != null && e.trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}
