part of 'eleves_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE CYCLE DE VIE D'UN ÉLÈVE, depuis son tiroir : modifier son dossier,
//  changer sa classe, annuler son inscription, le transférer, le radier, le
//  désactiver — et délivrer les papiers qui accompagnent ces gestes.
//
//  Chaque sortie exige un MOTIF normalisé : une ligne de plus dans un total
//  qu'on ne sait pas ventiler ne dit rien de la déperdition scolaire, qui ne se
//  lit nulle part ailleurs.
// ════════════════════════════════════════════════════════════════════════════
class _DwActionBar extends ConsumerWidget {
  const _DwActionBar({required this.row, required this.readOnly});
  final StudentRow row;

  /// Année clôturée ou passée : plus rien ne s'écrit, mais tout se lit — et
  /// s'imprime.
  final bool readOnly;

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

    // ⚠️ LA PROMESSE DU DIALOGUE SE VÉRIFIE AVANT, PAS APRÈS. Il annonce que
    // « le transfert est inscrit au registre » ; l'écriture était pourtant
    // conditionnée à un `group_id` et un `school_id` que l'appareil n'a pas
    // toujours. Sans eux, la ligne du registre était sautée EN SILENCE : l'élève
    // quittait l'effectif, le registre des transferts restait muet, et l'école
    // d'accueil n'avait aucune trace à opposer. On refuse la sortie entière
    // plutôt que d'en réussir la moitié.
    if (isTransfer && !isUsableId(profile?.groupId)) {
      _refuser(context, writeIdentityMessage(const ['groupe']));
      return;
    }
    if (isTransfer && !isUsableId(profile?.schoolId)) {
      _refuser(context, writeIdentityMessage(const ['école']));
      return;
    }

    final done = await runModuleWrite(
      context,
      () async {
        await setEnrollmentExit(
            enrollmentId: row.enrollmentId!,
            status: status,
            motif: res.motif,
            reason: res.reason);
        // Réconciliation : un transfert depuis la fiche alimente le registre
        // des Transferts (statut « terminé », l'élève étant déjà sorti).
        // Les identifiants ont été vérifiés avant d'ouvrir l'écriture : ce
        // qui reste ici, c'est le cas légitime d'une RADIATION, qui n'alimente
        // pas le registre des transferts.
        if (isTransfer && res.toSchoolName != null) {
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
    if (!done) return;
    ref.invalidate(studentsRegistryProvider);

    // Le papier au moment où la famille est encore au guichet. La chercher
    // plus tard dans un registre où elle ne figure plus est bien plus coûteux.
    if (context.mounted) {
      await delivrerCertificatRadiation(
        context,
        ref,
        eleve: AttestationEleve(
          firstName: row.firstName,
          lastName: row.lastName,
          className: row.className ?? '—',
          ine: row.ine,
          matricule: row.matricule,
          gender: row.gender,
          dateOfBirth: row.dateOfBirth,
        ),
        enrollmentStatus: status,
        motif: res.motif,
        dateSortie: DateTime.now(),
        observations: res.reason,
      );
    }
    if (context.mounted) Navigator.of(context).pop();
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

  /// Le papier que le secrétariat délivre tous les jours — bourse, transport,
  /// allocation, visa. Il se tapait à la machine, donc il se recopiait faux.
  Future<void> _certificatScolarite(BuildContext context, WidgetRef ref) async {
    final d = await ref.read(studentDossierProvider(row.id).future);
    if (!context.mounted) return;
    final lieu = d.s('place_of_birth');
    await delivrerCertificatScolarite(
      context,
      ref,
      eleve: AttestationEleve(
        firstName: row.firstName,
        lastName: row.lastName,
        className: row.className ?? '—',
        ine: row.ine,
        matricule: row.matricule,
        gender: row.gender,
        dateOfBirth: row.dateOfBirth,
        placeOfBirth: lieu.isEmpty ? null : lieu,
      ),
      enrollmentStatus: row.enrollmentStatus,
    );
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
    final canUpdate =
        !readOnly && ref.watch(canProvider((slug: 'eleves', action: 'update')));
    final canDelete =
        !readOnly && ref.watch(canProvider((slug: 'eleves', action: 'delete')));
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
              case 'certificat':
                _certificatScolarite(context, ref);
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
            const PopupMenuItem(
                value: 'certificat',
                child: _MenuRow(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Certificat de scolarité')),
            // Le séparateur ne se dessine que s'il sépare quelque chose : sur
            // une année clôturée, le certificat est seul et le trait pendait.
            if (canUpdate || canDelete) const PopupMenuDivider(),
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

/// Dit non, et pourquoi. Un refus muet se lit comme un bouton cassé.
void _refuser(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: kRed));

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
  const _ExitResult({
    required this.motif,
    required this.reason,
    this.toSchoolId,
    this.toSchoolName,
  });

  /// Catégorie normalisée — c'est elle qui se compte.
  final String motif;

  /// Le commentaire de l'agent, pour ce que la catégorie ne dit pas.
  final String reason;
  final String? toSchoolId, toSchoolName;
}

class _ExitDialogState extends ConsumerState<_ExitDialog> {
  final _reason = TextEditingController();
  String? _motif;

  /// ⚠️ Affectée SANS `setState` à l'origine : le bouton n'apprenait jamais
  /// qu'une destination avait été choisie. Sans cela, exiger la destination
  /// aurait laissé le bouton grisé pour toujours.
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
      // Sans motif, pas de sortie. Ce n'est pas une rigidité : une sortie sans
      // catégorie est une ligne de plus dans un total qu'on ne sait pas
      // ventiler, et la déperdition scolaire ne se lit nulle part ailleurs.
      //
      // ⚠️ ET SANS DESTINATION, PAS DE TRANSFERT. Le texte juste en dessous
      // promet que « le transfert est inscrit au registre » ; la destination
      // était pourtant facultative, et sans elle aucune ligne n'était écrite —
      // l'élève quittait l'effectif, le registre des transferts restait muet, et
      // rien ne le disait. La promesse est tenue, ou le bouton reste gris.
      onSubmit: _motif == null || (t && !(_dest?.isValid ?? false))
          ? null
          : () => Navigator.pop(
        context,
        _ExitResult(
          motif: _motif!,
          reason: _reason.text.trim(),
          toSchoolId: t ? _dest?.schoolId : null,
          toSchoolName: t ? _dest!.schoolName : null,
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
          Text('École de destination *',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 6),
          TransferDestinationPicker(onChanged: (d) => setState(() => _dest = d)),
          const SizedBox(height: 14),
        ],
        Text('Motif *',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _motif,
          isExpanded: true,
          decoration: adminFilledInput('Choisir un motif'),
          style: const TextStyle(fontSize: 13.5),
          items: [
            for (final m in motifsPour(transfert: t))
              DropdownMenuItem(value: m.code, child: Text(m.label)),
          ],
          onChanged: (v) => setState(() => _motif = v),
        ),
        if (_motif != null) ...[
          const SizedBox(height: 5),
          Text(
            motifsPour(transfert: t).firstWhere((m) => m.code == _motif).hint,
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.3),
          ),
        ],
        const SizedBox(height: 12),
        Text('Précision (facultatif)',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _reason,
          maxLines: 2,
          style: const TextStyle(fontSize: 13.5),
          decoration:
              adminFilledInput('Ce que la catégorie ne dit pas'),
        ),
      ]),
    );
  }
}
