part of 'emploi_du_temps_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ACTIONS EN LOT sur l'emploi du temps — dupliquer, vider, publier,
//  dépublier, exporter.
//
//  ⚠️ Seconde extension sur le MÊME état de page. Les méthodes restées dans
//  `emploi_du_temps_actions.dart` (dont `_snack` et `_shortTitle`) demeurent
//  appelables : les deux extensions vivent dans la même bibliothèque.
// ════════════════════════════════════════════════════════════════════════════
extension _EdtBulkActions on _EdtPageState {
  // Duplique l'emploi du temps de [from] vers une autre classe (sélection).
  //
  // ⚠️ DUPLIQUER, C'EST REMPLACER — PAS AJOUTER. La copie s'empilait sur les
  // créneaux existants de la classe cible : choisir une classe déjà pourvue
  // doublait toutes ses heures, deux cours au même moment, et la grille entière
  // passait en conflit. Rien ne le disait avant, rien ne l'annulait après —
  // « Vider l'emploi du temps » efface aussi ce qui était légitime.
  //
  // « L'EDT de 6e A vers 6e B » veut dire que B ressemble à A, jamais à A + B.
  // La liste annonce donc ce que chaque classe contient déjà, et un
  // remplacement se confirme en nommant ce qui sera perdu.
  Future<void> _duplicateTo(ClassModel from) async {
    final classes = ref.read(classesForModuleProvider(_kSlug)).valueOrNull ?? const <ClassModel>[];
    final all = ref.read(timetableSlotsProvider).valueOrNull ?? const <TimetableSlot>[];
    final compte = <String, int>{};
    for (final s in all) {
      compte[s.classId] = (compte[s.classId] ?? 0) + 1;
    }
    final others = classes.where((c) => c.id != from.id).toList()
      ..sort((a, b) {
        final o = (a.levelOrder ?? 999).compareTo(b.levelOrder ?? 999);
        return o != 0 ? o : a.name.compareTo(b.name);
      });
    if (others.isEmpty) {
      _snack('Aucune autre classe disponible.', kTextMuted);
      return;
    }
    final target = await showDialog<ClassModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Dupliquer l\'EDT de ${from.name} vers…'),
        children: [
          for (final c in others)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(Icons.groups_2_rounded, size: 18, color: kNavy),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.name)),
                  Text(
                    (compte[c.id] ?? 0) == 0
                        ? 'vide'
                        : '${compte[c.id]} créneaux — seront remplacés',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: (compte[c.id] ?? 0) == 0 ? kTextMuted : kAccent),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    final aRemplacer = compte[target.id] ?? 0;
    if (aRemplacer > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Remplacer l\'emploi du temps de ${target.name} ?'),
          content: Text(
              '${target.name} a déjà $aRemplacer créneau'
              '${aRemplacer > 1 ? 'x' : ''}. '
              'Ils seront supprimés, puis remplacés par une copie de '
              '${from.name}. Cette action est irréversible.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remplacer'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    final missing = missingWriteIds(
        groupId: profile?.groupId,
        schoolId: profile?.schoolId,
        actorId: profile?.id);
    if (missing.isNotEmpty) {
      _snack(writeIdentityMessage(missing), kRed);
      return;
    }
    if (!isUsableId(yearId)) {
      _snack('Aucune année scolaire active.', kRed);
      return;
    }
    final gid = profile!.groupId!, sid = profile.schoolId!, aid = yearId!;
    final actor = profile.id;
    await runModuleWrite(
      context,
      () async {
        final versionId = await ensureActiveVersionId(
          groupId: gid,
          schoolId: sid,
          academicYearId: aid,
          createdBy: actor,
        );
        if (aRemplacer > 0) {
          await clearClassTimetable(
            schoolId: sid,
            academicYearId: aid,
            classId: target.id,
          );
        }
        final n = await duplicateClassTimetable(
          groupId: gid,
          schoolId: sid,
          academicYearId: aid,
          fromClassId: from.id,
          toClassId: target.id,
          versionId: versionId,
        );
        if (n == 0) throw const ErreurMetier('Aucun créneau à copier');
      },
      success: 'Emploi du temps dupliqué vers ${target.name}',
    );
  }

  // Vide tout l'emploi du temps d'une classe (confirmation).
  Future<void> _clearClass(ClassModel klass) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Vider l\'emploi du temps de ${klass.name} ?'),
        content: const Text(
            'Tous les créneaux de cette classe seront supprimés. Cette action '
            'est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    final missing = missingWriteIds(
        groupId: profile?.groupId,
        schoolId: profile?.schoolId,
        actorId: profile?.id);
    if (missing.isNotEmpty) {
      _snack(writeIdentityMessage(missing), kRed);
      return;
    }
    if (!isUsableId(yearId)) {
      _snack('Aucune année scolaire active.', kRed);
      return;
    }
    final sid = profile!.schoolId!, aid = yearId!;
    await runModuleWrite(
      context,
      () => clearClassTimetable(
        schoolId: sid,
        academicYearId: aid,
        classId: klass.id,
      ),
      success: 'Emploi du temps vidé',
    );
  }

  // ── Publication de la version (visible enseignants/élèves/parents) ──────────
  Future<void> _publish(String versionId, int conflicts) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Publier l\'emploi du temps ?'),
        content: Text(conflicts > 0
            ? 'Attention : $conflicts conflit(s) subsiste(nt). L\'emploi du temps '
                'deviendra visible des enseignants, élèves et parents.'
            : 'L\'emploi du temps deviendra visible des enseignants, élèves et '
                'parents.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: conflicts > 0 ? kAccent : kGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final me = ref.read(authNotifierProvider).valueOrNull?.id;
    await runModuleWrite(
        context, () => publishTimetableVersion(versionId, validatedBy: me),
        success: 'Emploi du temps publié');
  }

  Future<void> _unpublish(String versionId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Repasser en brouillon ?'),
        content: const Text(
            'L\'emploi du temps ne sera plus publié. Vous pourrez le retravailler '
            'puis le publier à nouveau.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Brouillon'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runModuleWrite(context, () => unpublishTimetableVersion(versionId),
        success: 'Repassé en brouillon');
  }

  // Livret établissement : un PDF avec une page par classe (vue Établissement).
  void _exportBooklet(List<ClassModel> classes, List<TimetableSlot> all) {
    final sections = <({String title, List<TimetableSlot> slots})>[
      for (final c in classes)
        if (all.any((s) => s.classId == c.id))
          (title: c.name, slots: all.where((s) => s.classId == c.id).toList()),
    ];
    if (sections.isEmpty) {
      _snack('Aucun emploi du temps à exporter', kTextMuted);
      return;
    }
    final school = ref.read(currentSchoolProvider).valueOrNull;
    final year = ref.read(activeYearProvider)?.label;
    showPdfPreviewDialog(
      context,
      title: 'Emplois du temps — établissement',
      subtitle: '${sections.length} classe(s)'
          '${year != null ? ' · $year' : ''}',
      pdfFileName: 'EDT_Etablissement.pdf',
      build: (_) => EmploiDuTempsPdfService.buildBooklet(
        sections: sections,
        schoolName: school?['name'] as String?,
        yearLabel: year,
      ),
      onDownload: () => EmploiDuTempsPdfService.downloadBooklet(
        sections: sections,
        schoolName: school?['name'] as String?,
        yearLabel: year,
      ),
    );
  }

  // Export PDF de la sélection courante (vue classe / enseignant / salle).
  void _exportPdf(List<TimetableSlot> slots) {
    if (slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Aucun créneau à exporter'),
          backgroundColor: kTextMuted));
      return;
    }
    final title = _shortTitle(slots);
    final school = ref.read(currentSchoolProvider).valueOrNull;
    final year = ref.read(activeYearProvider)?.label;
    final view = switch (_view) {
      TtView.enseignant => TtPdfView.enseignant,
      TtView.salle => TtPdfView.salle,
      _ => TtPdfView.classe,
    };
    showPdfPreviewDialog(
      context,
      title: 'Emploi du temps — $title',
      subtitle: year != null ? 'Année $year' : null,
      pdfFileName: 'EDT_$title.pdf',
      build: (_) => EmploiDuTempsPdfService.buildPdf(
        slots: slots,
        entityTitle: title,
        view: view,
        schoolName: school?['name'] as String?,
        yearLabel: year,
      ),
      onDownload: () => EmploiDuTempsPdfService.downloadDoc(
        slots: slots,
        entityTitle: title,
        view: view,
        schoolName: school?['name'] as String?,
        yearLabel: year,
      ),
    );
  }
}
