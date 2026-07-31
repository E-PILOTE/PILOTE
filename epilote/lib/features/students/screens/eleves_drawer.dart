part of 'eleves_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  TIROIR DÉTAIL ÉLÈVE (slide droit) — dossier complet (identité, statuts,
//  inscription de l'année, tuteurs, pièces) + actions : Modifier · Inscrire
//  (si non inscrit) · Désactiver. Réutilise studentDossierProvider.
// ════════════════════════════════════════════════════════════════════════════
class _StudentDrawer extends ConsumerWidget {
  const _StudentDrawer({required this.row});
  final StudentRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossier = ref.watch(studentDossierProvider(row.id));
    final docs = ref.watch(studentDocumentsProvider(row.id)).valueOrNull ??
        const <StudentDocument>[];
    final readOnly = ref.watch(yearReadOnlyProvider);
    final w = MediaQuery.of(context).size.width;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: w < 520 ? w : 460,
        height: double.infinity,
        decoration: BoxDecoration(color: kCardBg),
        child: SafeArea(
          child: Column(children: [
            _DwHeader(row: row),
            Expanded(
              child: dossier.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur : $e',
                      style: TextStyle(color: kRed)),
                ),
                data: (d) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                  child: _DwBody(row: row, d: d, docs: docs),
                ),
              ),
            ),
            if (!readOnly) _DwActionBar(row: row),
          ]),
        ),
      ),
    );
  }
}

class _DwHeader extends StatelessWidget {
  const _DwHeader({required this.row});
  final StudentRow row;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: Icon(Icons.close_rounded, color: kTextMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Row(children: [
          _Avatar(name: row.fullName, photoUrl: row.photoUrl, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                AdminBadge('Inscrit', color: kGreen),
                if (row.className != null)
                  AdminBadge(row.className!, color: _cycColor(row.cycleCode)),
                if (row.matricule.isNotEmpty)
                  AdminBadge(row.matricule, color: kTextMuted),
              ]),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _DwBody extends StatelessWidget {
  const _DwBody({required this.row, required this.d, required this.docs});
  final StudentRow row;
  final StudentDossier d;
  final List<StudentDocument> docs;

  bool _b(Object? v) => v == 1 || v == true;

  @override
  Widget build(BuildContext context) {
    final dob = d.dob;
    final age = row.age;
    final naissance = dob == null
        ? '—'
        : '${dob.toIso8601String().substring(0, 10)}${age != null ? '  ($age ans)' : ''}';
    final adresse = [d.s('address'), d.s('city'), d.s('region')]
        .where((e) => e.isNotEmpty)
        .join(', ');
    final siblings = d.student['nombre_freres_soeurs'];
    final siblingsLabel = (siblings is int && siblings > 0) ? '$siblings' : '';
    final statuts = <(String, String)>[
      if (_b(d.student['is_boarder'])) ('Interne', '✓'),
      if (_b(d.student['is_affecte'])) ('Affecté MEPSA/METP', '✓'),
      if (_b(d.student['has_scholarship']))
        ('Boursier', d.s('scholarship_type').isEmpty ? '✓' : d.s('scholarship_type')),
      if (_b(d.student['has_social_aid']))
        ('Aide sociale', d.s('social_aid_type').isEmpty ? '✓' : d.s('social_aid_type')),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      ResumeCard(
        title: 'Inscription (année active)',
        icon: Icons.how_to_reg_outlined,
        rows: [
          ('Statut', 'Inscrit (validé)'),
          ('Classe', row.className ?? '—'),
          ('Cycle', _cycName(row.cycleCode)),
          if ((row.levelCode ?? '').isNotEmpty) ('Niveau', row.levelCode!),
          if (row.filiereLabel != null) ('Filière', row.filiereLabel!),
        ],
      ),
      ResumeCard(
        title: 'Identité',
        icon: Icons.person_outline,
        rows: [
          ('Matricule', row.matricule.isEmpty ? '—' : row.matricule),
          (
            'Sexe',
            row.gender == 'F'
                ? 'Féminin'
                : row.gender == 'M'
                    ? 'Masculin'
                    : '—'
          ),
          ('Naissance', naissance),
          ('Lieu de naissance', _od(d.s('place_of_birth'))),
          ('Nationalité', _od(d.s('nationality'))),
          ('Situation familiale', _od(d.s('situation_familiale'))),
          if (siblingsLabel.isNotEmpty) ('Frères et sœurs', siblingsLabel),
          ('Groupe sanguin', _od(d.s('blood_group'))),
          if (d.s('allergies').isNotEmpty) ('Antécédents', d.s('allergies')),
          ('Adresse', _od(adresse)),
        ],
      ),
      if (statuts.isNotEmpty)
        ResumeCard(
            title: 'Statuts particuliers',
            icon: Icons.verified_outlined,
            rows: statuts),
      ResumeCard(
        title: 'Tuteurs (${d.tutors.length})',
        icon: Icons.family_restroom_outlined,
        rows: d.tutors.isEmpty
            ? [('Aucun tuteur enregistré', '')]
            : [
                for (final t in d.tutors)
                  (
                    t.isPrimary ? 'Principal' : _rel(t.relationship),
                    [
                      t.fullName,
                      if ((t.phonePrimary ?? '').trim().isNotEmpty)
                        '· ${t.phonePrimary}',
                    ].join(' '),
                  ),
              ],
      ),
      ResumeCard(
        title: 'Dossier (${docs.length} pièce${docs.length > 1 ? 's' : ''})',
        icon: Icons.folder_open_rounded,
        rows: docs.isEmpty
            ? [('Aucune pièce téléversée', '')]
            : [
                for (final doc in docs)
                  (
                    docTypeLabel(doc.documentType),
                    doc.isVerified ? '✓ vérifiée' : 'à vérifier'
                  ),
              ],
      ),
    ]);
  }

  static String _od(String v) => v.isEmpty ? '—' : v;
  static String _rel(String c) => tutorRelationshipLabel(c);
}

class _DwActionBar extends ConsumerWidget {
  const _DwActionBar({required this.row});
  final StudentRow row;

  Future<void> _changeClass(BuildContext context, WidgetRef ref) async {
    final classId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClassChooserDialog(
          title: 'Changer de classe', subtitle: row.fullName),
    );
    if (classId == null || !context.mounted) return;
    final done = await runModuleWrite(
      context,
      () => changeEnrollmentClass(
          enrollmentId: row.enrollmentId!, newClassId: classId),
      success: 'Élève réaffecté',
    );
    if (done) ref.invalidate(studentsRegistryProvider);
  }

  Future<void> _revert(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(context, 'Annuler l\'inscription ?',
        '« ${row.fullName} » repartira dans la page Inscriptions (statut « en '
        'attente de validation »). Sa classe est conservée.',
        'Annuler l\'inscription', kAccent);
    if (ok != true || !context.mounted) return;
    final done = await runModuleWrite(
      context,
      () => revertEnrollmentToValidation(row.enrollmentId!),
      success: 'Inscription renvoyée au pipeline',
    );
    if (done) {
      ref.invalidate(studentsRegistryProvider);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _exit(BuildContext context, WidgetRef ref,
      {required String status}) async {
    final res = await showDialog<_ExitResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExitDialog(
          fullName: row.fullName,
          transfer: status == 'transferred'),
    );
    if (res == null || !context.mounted) return;
    final isTransfer = status == 'transferred';
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final done = await runModuleWrite(
      context,
      () async {
        await setEnrollmentExit(
            enrollmentId: row.enrollmentId!, status: status, reason: res.reason);
        // Réconciliation : un transfert depuis la fiche alimente le registre
        // des Transferts (statut « terminé », l'élève étant déjà sorti).
        if (isTransfer &&
            res.toSchoolName != null &&
            profile?.groupId != null &&
            profile?.schoolId != null) {
          await createTransfer(
            groupId: profile!.groupId!,
            fromSchoolId: profile.schoolId!,
            studentId: row.id,
            toSchoolName: res.toSchoolName!,
            toSchoolId: res.toSchoolId,
            transferDate: DateTime.now(),
            reason: res.reason,
            academicYearId: ref.read(activeYearIdProvider),
            initialStatus: 'completed',
            approvedBy: profile.id,
          );
        }
      },
      success: isTransfer ? 'Élève transféré' : 'Élève radié',
    );
    if (done) {
      ref.invalidate(studentsRegistryProvider);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(context, 'Désactiver cet élève ?',
        '« ${row.fullName} » sera retiré du registre actif. Son dossier et son '
        'historique sont conservés.',
        'Désactiver', kRed);
    if (ok != true || !context.mounted) return;
    final done = await runModuleWrite(context, () => deactivateStudent(row.id),
        success: 'Élève désactivé');
    if (done) {
      ref.invalidate(studentsRegistryProvider);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<bool?> _confirm(BuildContext context, String title, String body,
          String ok, Color c) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Retour')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ok),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUpdate = ref.watch(canProvider((slug: 'eleves', action: 'update')));
    final canDelete = ref.watch(canProvider((slug: 'eleves', action: 'delete')));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
      child: Row(children: [
        if (canUpdate)
          Expanded(
            child: AdminPrimaryButton(
              label: 'Modifier',
              icon: Icons.edit_outlined,
              color: kNavy,
              onTap: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    _StudentEditModal(studentId: row.id, fullName: row.fullName),
              ),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          tooltip: 'Cycle de vie',
          position: PopupMenuPosition.under,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          offset: const Offset(0, 6),
          onSelected: (v) {
            switch (v) {
              case 'class':
                _changeClass(context, ref);
              case 'revert':
                _revert(context, ref);
              case 'transfer':
                _exit(context, ref, status: 'transferred');
              case 'withdraw':
                _exit(context, ref, status: 'withdrawn');
              case 'deactivate':
                _deactivate(context, ref);
            }
          },
          itemBuilder: (_) => [
            if (canUpdate)
              const PopupMenuItem(
                  value: 'class',
                  child: _MenuRow(
                      icon: Icons.swap_horiz_rounded, label: 'Changer de classe')),
            if (canUpdate)
              const PopupMenuItem(
                  value: 'revert',
                  child: _MenuRow(
                      icon: Icons.undo_rounded,
                      label: 'Annuler l\'inscription')),
            if (canUpdate)
              const PopupMenuItem(
                  value: 'transfer',
                  child: _MenuRow(
                      icon: Icons.exit_to_app_rounded,
                      label: 'Transférer (autre école)')),
            if (canUpdate)
              const PopupMenuItem(
                  value: 'withdraw',
                  child: _MenuRow(
                      icon: Icons.logout_rounded, label: 'Radier / abandon')),
            if (canDelete) ...[
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'deactivate',
                  child: _MenuRow(
                      icon: Icons.person_off_outlined,
                      label: 'Désactiver',
                      color: kRed)),
            ],
          ],
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.more_horiz_rounded, color: kTextMuted, size: 20),
              const SizedBox(width: 6),
              Text('Actions',
                  style: TextStyle(
                      color: kTextMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color ?? kTextPrimary),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 13.5,
                color: color ?? kTextPrimary,
                fontWeight: FontWeight.w600)),
      ]);
}

// ─── Dialogue de sortie (transfert / radiation) avec motif ───────────────────
class _ExitDialog extends ConsumerStatefulWidget {
  const _ExitDialog({required this.fullName, required this.transfer});
  final String fullName;
  final bool transfer;
  @override
  ConsumerState<_ExitDialog> createState() => _ExitDialogState();
}

/// Résultat de la sortie : motif + (pour un transfert) école de destination
/// (cascade groupe → école). Alimente le registre des Transferts (réconciliation).
class _ExitResult {
  const _ExitResult({required this.reason, this.toSchoolId, this.toSchoolName});
  final String reason;
  final String? toSchoolId, toSchoolName;
}

class _ExitDialogState extends ConsumerState<_ExitDialog> {
  final _reason = TextEditingController();
  TransferDestination? _dest;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    return AdminFormDialog(
      icon: t ? Icons.exit_to_app_rounded : Icons.logout_rounded,
      title: t ? 'Transférer l\'élève' : 'Radier l\'élève',
      subtitle: widget.fullName,
      width: 460,
      submitLabel: t ? 'Transférer' : 'Radier',
      submitIcon: Icons.check_rounded,
      submitColor: kRed,
      onSubmit: () => Navigator.pop(
        context,
        _ExitResult(
          reason: _reason.text.trim().isEmpty
              ? (t ? 'Transfert' : 'Radiation')
              : _reason.text.trim(),
          toSchoolId: t ? _dest?.schoolId : null,
          toSchoolName: t && (_dest?.isValid ?? false) ? _dest!.schoolName : null,
        ),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            t
                ? 'L\'élève quitte l\'effectif (départ vers une autre école). '
                    'L\'historique est conservé et le transfert est inscrit au '
                    'registre.'
                : 'L\'élève quitte l\'effectif (abandon / exclusion). '
                    'L\'historique est conservé.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
        const SizedBox(height: 14),
        if (t) ...[
          TransferDestinationPicker(onChanged: (d) => _dest = d),
          const SizedBox(height: 14),
        ],
        Text('Motif',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _reason,
          maxLines: 3,
          style: const TextStyle(fontSize: 13.5),
          decoration: adminFilledInput(
              t ? 'Ex. : déménagement, motif…' : 'Ex. : abandon, exclusion…'),
        ),
      ]),
    );
  }
}
