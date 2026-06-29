part of 'timetable_provider.dart';

// ─── Détection de conflits ───────────────────────────────────────────────────
//  Trois familles, du standard SaaS scolaire :
//   • teacher  : un enseignant placé dans 2 classes au même moment (DUR) ;
//   • room     : une salle occupée 2 fois au même moment (DUR) ;
//   • classOverlap : 2 cours qui se chevauchent dans la MÊME classe (DUR).
enum ConflictKind { teacher, room, classOverlap }

class SlotConflict {
  const SlotConflict(this.kind, this.a, this.b);
  final ConflictKind kind;
  final TimetableSlot a, b;

  String label() => switch (kind) {
        ConflictKind.teacher =>
          '${a.teacherName ?? 'Enseignant'} : ${a.className ?? ''} et '
              '${b.className ?? ''} se chevauchent',
        ConflictKind.room =>
          'Salle ${a.room ?? ''} occupée par ${a.className ?? ''} et '
              '${b.className ?? ''}',
        ConflictKind.classOverlap =>
          '${a.className ?? 'Classe'} : ${a.subjectName ?? ''} et '
              '${b.subjectName ?? ''} se chevauchent',
      };
}

bool _slotsOverlap(TimetableSlot a, TimetableSlot b) =>
    a.dayOfWeek == b.dayOfWeek &&
    rangesOverlap(a.hhmmStart, a.hhmmEnd, b.hhmmStart, b.hhmmEnd);

/// Deux créneaux occupent-ils la MÊME salle ? Priorité à l'id de salle (registre,
/// fiable) ; repli sur l'égalité du texte (créneaux legacy non encore migrés).
bool _sameRoom(String? aId, String? aText, String? bId, String? bText) {
  final ai = (aId ?? '').trim(), bi = (bId ?? '').trim();
  if (ai.isNotEmpty && bi.isNotEmpty) return ai == bi;
  final at = (aText ?? '').trim().toLowerCase();
  final bt = (bText ?? '').trim().toLowerCase();
  return at.isNotEmpty && at == bt;
}

/// Tous les conflits (paires) présents dans [slots]. Comparaison O(n²) — l'EDT
/// d'une école reste de l'ordre de la centaine de créneaux.
List<SlotConflict> detectConflicts(List<TimetableSlot> slots) {
  final out = <SlotConflict>[];
  for (var i = 0; i < slots.length; i++) {
    for (var j = i + 1; j < slots.length; j++) {
      final a = slots[i], b = slots[j];
      if (!_slotsOverlap(a, b)) continue;
      if (a.staffId.isNotEmpty && a.staffId == b.staffId) {
        out.add(SlotConflict(ConflictKind.teacher, a, b));
      }
      if (_sameRoom(a.roomId, a.room, b.roomId, b.room)) {
        out.add(SlotConflict(ConflictKind.room, a, b));
      }
      if (a.classId.isNotEmpty && a.classId == b.classId) {
        out.add(SlotConflict(ConflictKind.classOverlap, a, b));
      }
    }
  }
  return out;
}

/// Ids des créneaux impliqués dans au moins un conflit (pour le surlignage).
Set<String> conflictingSlotIds(List<SlotConflict> conflicts) {
  final s = <String>{};
  for (final c in conflicts) {
    s..add(c.a.id)..add(c.b.id);
  }
  return s;
}

/// Conflits qu'un créneau candidat (en cours de saisie) provoquerait, sans
/// l'enregistrer. [excludeId] = le créneau en cours de modification.
List<SlotConflict> conflictsForCandidate({
  required List<TimetableSlot> all,
  required String classId,
  required int day,
  required String start,
  required String end,
  required String staffId,
  String? room,
  String? roomId,
  String? excludeId,
}) {
  final cand = TimetableSlot(
    id: excludeId ?? '__candidate__',
    classId: classId,
    className: null,
    cycleCode: null,
    subjectId: '',
    subjectName: null,
    staffId: staffId,
    teacherName: null,
    dayOfWeek: day,
    startTime: start,
    endTime: end,
    room: room,
    roomId: roomId,
  );
  final out = <SlotConflict>[];
  for (final s in all) {
    if (s.id == excludeId) continue;
    if (!_slotsOverlap(cand, s)) continue;
    if (staffId.isNotEmpty && staffId == s.staffId) {
      out.add(SlotConflict(ConflictKind.teacher, cand, s));
    }
    if (_sameRoom(roomId, room, s.roomId, s.room)) {
      out.add(SlotConflict(ConflictKind.room, cand, s));
    }
    if (classId.isNotEmpty && classId == s.classId) {
      out.add(SlotConflict(ConflictKind.classOverlap, cand, s));
    }
  }
  return out;
}
