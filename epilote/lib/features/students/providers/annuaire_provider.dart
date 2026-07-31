import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/student_tutor_model.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'students_registry_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ANNUAIRE — répertoire des FAMILLES : chaque élève actif et ses tuteurs
//  (parents / contacts) avec téléphones. Outil de contact rapide (terrain :
//  appeler une famille). 100% offline. Pilote la COUVERTURE contact (élèves sans
//  tuteur = trou à combler). Réutilise le registre élèves + `student_tutors`.
// ════════════════════════════════════════════════════════════════════════════

/// Tuteurs de toute l'école (joints aux élèves pour le scope school_id).
final schoolTutorsProvider =
    StreamProvider.autoDispose<List<StudentTutorModel>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db
      .watch(
        '''
        SELECT t.* FROM student_tutors t
        JOIN   students s ON s.id = t.student_id
        WHERE  s.school_id = ?
        ORDER  BY t.is_primary_contact DESC, t.created_at ASC
        ''',
        parameters: [schoolId],
      )
      .map((rows) => rows.map(StudentTutorModel.fromMap).toList());
});

/// Une famille = un élève actif + ses tuteurs.
class FamilyRow {
  FamilyRow({required this.student, required this.tutors});
  final StudentRow student;
  final List<StudentTutorModel> tutors;

  bool get hasContact => tutors.isNotEmpty;
  int get tutorCount => tutors.length;
  StudentTutorModel? get primary {
    if (tutors.isEmpty) return null;
    return tutors.firstWhere((t) => t.isPrimaryContact,
        orElse: () => tutors.first);
  }

  // Tous les numéros distincts de la famille (principal + secondaires).
  List<String> get phones {
    final set = <String>{};
    for (final t in tutors) {
      if (t.phonePrimary.trim().isNotEmpty) set.add(t.phonePrimary.trim());
      final s = t.phoneSecondary?.trim();
      if (s != null && s.isNotEmpty) set.add(s);
    }
    return set.toList();
  }
}

/// Répertoire complet (élèves actifs + tuteurs regroupés par élève).
final familiesProvider =
    Provider.autoDispose<AsyncValue<List<FamilyRow>>>((ref) {
  final roster = ref.watch(studentsRegistryProvider('annuaire'));
  final tutors = ref.watch(schoolTutorsProvider);
  return roster.whenData((students) {
    final byStudent = <String, List<StudentTutorModel>>{};
    for (final t in tutors.valueOrNull ?? const <StudentTutorModel>[]) {
      byStudent.putIfAbsent(t.studentId, () => []).add(t);
    }
    return [
      for (final s in students)
        FamilyRow(student: s, tutors: byStudent[s.id] ?? const []),
    ];
  });
});

// ─── Statistiques de couverture contact (KPIs) ───────────────────────────────
class AnnuaireStats {
  const AnnuaireStats({
    required this.students,
    required this.withContact,
    required this.tutors,
    required this.emergency,
  });
  final int students, withContact, tutors, emergency;
  int get withoutContact => students - withContact;
}

final annuaireStatsProvider = Provider.autoDispose<AnnuaireStats>((ref) {
  final fams = ref.watch(familiesProvider).valueOrNull ?? const [];
  final tutors = ref.watch(schoolTutorsProvider).valueOrNull ?? const [];
  return AnnuaireStats(
    students: fams.length,
    withContact: fams.where((f) => f.hasContact).length,
    tutors: tutors.length,
    emergency: tutors.where((t) => t.isEmergencyContact).length,
  );
});
