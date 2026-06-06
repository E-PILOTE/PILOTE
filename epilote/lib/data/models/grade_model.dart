/// Modèle correspondant à la table `grades`
class GradeModel {

  const GradeModel({
    required this.id,
    required this.enrollmentId,
    required this.studentId,
    required this.subjectId,
    required this.sequenceId,
    required this.trimesterId,
    required this.academicYearId,
    required this.schoolId,
    required this.groupId,
    required this.value,
    this.coefficient,
    this.comment,
    this.gradeType,
    this.gradedAt,
    required this.createdAt,
    required this.updatedAt,
    this.studentName,
    this.subjectName,
  });

  factory GradeModel.fromMap(Map<String, dynamic> map) {
    final student = map['students'] as Map<String, dynamic>?;
    final subject = map['subjects'] as Map<String, dynamic>?;

    return GradeModel(
      id: map['id'] as String,
      enrollmentId: map['enrollment_id'] as String,
      studentId: map['student_id'] as String,
      subjectId: map['subject_id'] as String,
      sequenceId: map['sequence_id'] as String,
      trimesterId: map['trimester_id'] as String,
      academicYearId: map['academic_year_id'] as String,
      schoolId: map['school_id'] as String,
      groupId: map['group_id'] as String,
      value: (map['value'] as num).toDouble(),
      coefficient: (map['coefficient'] as num?)?.toDouble(),
      comment: map['comment'] as String?,
      gradeType: map['grade_type'] as String?,
      gradedAt: map['graded_at'] != null
          ? DateTime.parse(map['graded_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      studentName: student != null
          ? '${student['first_name']} ${student['last_name']}'
          : null,
      subjectName: subject?['name'] as String?,
    );
  }
  final String id;
  final String enrollmentId;
  final String studentId;
  final String subjectId;
  final String sequenceId;
  final String trimesterId;
  final String academicYearId;
  final String schoolId;
  final String groupId;
  final double value;       // Note sur 20
  final double? coefficient;
  final String? comment;
  final String? gradeType;  // controle, devoir, examen, tp
  final DateTime? gradedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Jointures optionnelles
  final String? studentName;
  final String? subjectName;

  /// Mention selon barème congolais
  String get mention {
    if (value >= 18) return 'Excellent';
    if (value >= 16) return 'Très Bien';
    if (value >= 14) return 'Bien';
    if (value >= 12) return 'Assez Bien';
    if (value >= 10) return 'Passable';
    return 'Insuffisant';
  }

  bool get isPassing => value >= 10;

  String get displayValue => value % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  @override
  String toString() => 'GradeModel($value/20, $subjectName)';
}
