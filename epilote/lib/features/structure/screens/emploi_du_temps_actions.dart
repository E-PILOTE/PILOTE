part of 'emploi_du_temps_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ACTIONS sur un créneau (extension de la page) — pour garder l'orchestrateur
//  sous 500 lignes : MODAL de création/édition, suppression confirmée, TIROIR
//  de détail latéral, export PDF de la sélection courante.
// ════════════════════════════════════════════════════════════════════════════
extension _EdtActions on _EdtPageState {
  // ── Slots + titre selon la vue courante ────────────────────────────────────
  (List<TimetableSlot>, String?) _resolve(
      List<TimetableSlot> all, Map<String, ClassModel> classById) {
    switch (_view) {
      case TtView.ensemble:
        var s = all;
        if (_scope.cycle != null) {
          s = s.where((x) => x.cycleCode == _scope.cycle).toList();
        }
        if (_scope.level != null) {
          s = s
              .where((x) => classById[x.classId]?.levelCode == _scope.level)
              .toList();
        }
        return (s.where(_match).toList(), 'Établissement');
      case TtView.classe:
        final id = _scope.classId;
        if (id == null) return (const [], null);
        final name = classById[id]?.name ?? 'Classe';
        return (
          all.where((x) => x.classId == id).where(_match).toList(),
          'Emploi du temps · $name'
        );
      case TtView.enseignant:
        final id = _teacherId;
        if (id == null) return (const [], null);
        final name = all
                .firstWhere((s) => s.staffId == id, orElse: _empty)
                .teacherName ??
            'Enseignant';
        return (
          all.where((x) => x.staffId == id).where(_match).toList(),
          'Emploi du temps · $name'
        );
      case TtView.salle:
        final r = _room;
        if (r == null) return (const [], null);
        return (
          all.where((x) => (x.room ?? '').trim() == r).where(_match).toList(),
          'Salle · $r'
        );
    }
  }

  TimetableSlot _empty() => const TimetableSlot(
      id: '', classId: '', className: null, cycleCode: null, subjectId: '',
      subjectName: null, staffId: '', teacherName: null, dayOfWeek: 1,
      startTime: '00:00', endTime: '00:00', room: null);

  String _shortTitle(List<TimetableSlot> slots) => switch (_view) {
        TtView.enseignant =>
          slots.isNotEmpty ? (slots.first.teacherName ?? 'Enseignant') : 'Enseignant',
        TtView.salle => _room ?? 'Salle',
        TtView.ensemble => 'Établissement',
        TtView.classe =>
          slots.isNotEmpty ? (slots.first.className ?? 'Classe') : 'Classe',
      };

  // Modal de création / édition d'un créneau (classe sélectionnée requise).
  void _openSlotForm({TimetableSlot? slot, int? day, String? start, String? end}) {
    final classId = _scope.classId;
    if (classId == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SlotForm(
        classId: classId,
        slot: slot,
        presetDay: day,
        presetStart: start,
        presetEnd: end,
      ),
    );
  }

  Future<void> _deleteSlot(TimetableSlot s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer ce créneau ?'),
        content: Text('${s.subjectName ?? 'Cours'} · ${frDays[s.dayOfWeek]} '
            '${s.timeLabel} sera retiré de l\'emploi du temps.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runModuleWrite(context, () => deleteTimetableSlot(s.id),
        success: 'Créneau supprimé');
  }

  // Tiroir latéral de détail d'un créneau (slide depuis la droite).
  void _openSlotDrawer(
      TimetableSlot s, bool canEdit, bool canDelete, List<TimetableSlot> all) {
    final conflict = conflictingSlotIds(detectConflicts(all)).contains(s.id);
    showGeneralDialog(
      context: context,
      barrierLabel: 'Détail du créneau',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, _) => Align(
        alignment: Alignment.centerRight,
        child: _SlotDrawer(
          slot: s,
          conflict: conflict,
          onEdit: canEdit
              ? () {
                  Navigator.pop(ctx);
                  _openSlotForm(slot: s);
                }
              : null,
          onDelete: canDelete
              ? () {
                  Navigator.pop(ctx);
                  _deleteSlot(s);
                }
              : null,
          onViewClass: (_view != TtView.classe && s.classId.isNotEmpty)
              ? () {
                  Navigator.pop(ctx);
                  _jumpToClass(s);
                }
              : null,
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  // Glisser-déposer : repositionne un créneau sur (jour, plage). Bloque si le
  // déplacement crée un conflit DUR (prof/classe) ou tombe sur une indispo.
  Future<void> _moveSlot(
      TimetableSlot s, int day, String start, String end, List<TimetableSlot> all) async {
    if (s.dayOfWeek == day && s.hhmmStart == start && s.hhmmEnd == end) return;
    final conflicts = conflictsForCandidate(
      all: all,
      classId: s.classId,
      day: day,
      start: start,
      end: end,
      staffId: s.staffId,
      room: s.room,
      roomId: s.roomId,
      excludeId: s.id,
    );
    final hard =
        conflicts.where((c) => c.kind != ConflictKind.room).toList();
    if (hard.isNotEmpty) {
      _snack('Déplacement impossible : ${hard.first.label()}', kRed);
      return;
    }
    final avail = ref.read(teacherAvailabilityProvider).valueOrNull ?? const [];
    if (availabilityViolation(
            avail: avail,
            staffId: s.staffId,
            day: day,
            start: start,
            end: end) ==
        'unavailable') {
      _snack('Déplacement impossible : enseignant indisponible ce créneau', kRed);
      return;
    }
    await runModuleWrite(
      context,
      () => updateTimetableSlot(
        id: s.id,
        subjectId: s.subjectId,
        staffId: s.staffId,
        dayOfWeek: day,
        startTime: start,
        endTime: end,
        room: s.room,
        roomId: s.roomId,
      ),
      success: 'Créneau déplacé',
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}
