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
///
/// ── POURQUOI TOUJOURS LA JOINTURE, MAINTENANT QUE `school_id` EXISTE ───────
/// La migration 0110 a posé `student_tutors.school_id`, et les sync-rules
/// filtrent désormais dessus : sur un poste à jour, cette table ne contient
/// plus que l'école. Filtrer directement sur la colonne serait donc suffisant
/// — et c'est précisément pour cela qu'on ne le fait pas.
///
/// Les sync-rules se déploient À LA MAIN, par le dashboard PowerSync Cloud.
/// Entre la mise à jour de l'application et ce déploiement, les tuteurs des
/// écoles sœurs sont encore sur le disque. La jointure les écarte quoi qu'il
/// arrive ; la colonne seule s'en remettrait à une opération humaine.
///
/// Elle écarte aussi les tuteurs d'un élève désactivé, que `students` ne
/// descend plus (`is_active = true`) mais qui pourraient traîner localement.
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

/// ── ⚠️ LES QUATRE CARTES COMPTENT LE MÊME ENSEMBLE ─────────────────────────
/// « Familles » et « Avec contact » se dérivaient de [familiesProvider], donc
/// du registre — restreint aux classes du membre quand son profil dit
/// `own_classes`. « Tuteurs » et « Urgence », eux, se comptaient sur
/// [schoolTutorsProvider], c'est-à-dire sur l'école entière : la même rangée
/// affichait « 12 familles » et « 847 tuteurs ». Les quatre se lisent
/// désormais sur les familles effectivement affichées.
final annuaireStatsProvider = Provider.autoDispose<AnnuaireStats>((ref) {
  final fams = ref.watch(familiesProvider).valueOrNull ?? const [];
  var tutors = 0, emergency = 0;
  for (final f in fams) {
    tutors += f.tutors.length;
    emergency += f.tutors.where((t) => t.isEmergencyContact).length;
  }
  return AnnuaireStats(
    students: fams.length,
    withContact: fams.where((f) => f.hasContact).length,
    tutors: tutors,
    emergency: emergency,
  );
});
