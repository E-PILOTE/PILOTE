part of 'add_inscription_screen.dart';

// ─── Étape 3 — Scolarité ─────────────────────────────────────────────────────

class _Step3Scolarite extends ConsumerStatefulWidget {
  const _Step3Scolarite({
    required this.state,
    required this.onChanged,
  });
  final _InscriptionState state;
  final VoidCallback onChanged;

  @override
  ConsumerState<_Step3Scolarite> createState() => _Step3ScolariteState();
}

class _Step3ScolariteState extends ConsumerState<_Step3Scolarite> {
  late final _prevSchoolCtrl = TextEditingController(
    text: widget.state.previousSchoolName ?? '',
  );
  late final _prevClassCtrl = TextEditingController(
    text: widget.state.previousClassName ?? '',
  );
  late final _transferReasonCtrl = TextEditingController(
    text: widget.state.transferReason ?? '',
  );
  late final _notesCtrl = TextEditingController(
    text: widget.state.notes ?? '',
  );

  @override
  void dispose() {
    _prevSchoolCtrl.dispose();
    _prevClassCtrl.dispose();
    _transferReasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s            = widget.state;
    final yearsAsync   = ref.watch(academicYearsProvider);
    final classesAsync = ref.watch(classesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Type d\'inscription'),
          _DropdownField<String>(
            label: 'Type',
            value: s.inscriptionType,
            items: const {
              'new':           'Nouvelle inscription',
              'reinscription': 'Réinscription',
              'transfer':      'Transfert',
            },
            onChanged: (v) { s.inscriptionType = v!; widget.onChanged(); },
          ),
          const SizedBox(height: 12),
          const _SectionTitle('Affectation'),
          yearsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error:   (e, _) => Text('Erreur : $e', style: const TextStyle(color: _kRed)),
            data:    (years) {
              if (years.isEmpty) {
                return const Text(
                  'Aucune année scolaire active.',
                  style: TextStyle(color: _kMuted),
                );
              }
              return _DropdownField<String>(
                label: 'Année scolaire *',
                value: s.academicYearId,
                items: {for (final y in years) y.id: y.label},
                onChanged: (v) { s.academicYearId = v; widget.onChanged(); },
              );
            },
          ),
          classesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error:   (e, _) => Text('Erreur : $e', style: const TextStyle(color: _kRed)),
            data:    (classes) {
              if (classes.isEmpty) {
                return const Text(
                  'Aucune classe disponible.',
                  style: TextStyle(color: _kMuted),
                );
              }
              return _DropdownField<String>(
                label: 'Classe *',
                value: s.classId,
                items: {for (final c in classes) c.id: c.name},
                onChanged: (v) { s.classId = v; widget.onChanged(); },
              );
            },
          ),
          _CheckTile(
            label: 'Élève redoublant',
            value: s.isRepeating,
            onChanged: (v) { s.isRepeating = v!; widget.onChanged(); },
          ),
          if (s.inscriptionType == 'transfer') ...[
            const SizedBox(height: 12),
            const _SectionTitle('École d\'origine'),
            _Field(
              ctrl: _prevSchoolCtrl,
              label: 'Nom de l\'école précédente',
              onChanged: (v) { s.previousSchoolName = v.isEmpty ? null : v; widget.onChanged(); },
            ),
            _Field(
              ctrl: _prevClassCtrl,
              label: 'Classe précédente',
              onChanged: (v) { s.previousClassName = v.isEmpty ? null : v; widget.onChanged(); },
            ),
            _Field(
              ctrl: _transferReasonCtrl,
              label: 'Motif du transfert',
              maxLines: 2,
              onChanged: (v) { s.transferReason = v.isEmpty ? null : v; widget.onChanged(); },
            ),
          ],
          const SizedBox(height: 12),
          const _SectionTitle('Notes internes'),
          _Field(
            ctrl: _notesCtrl,
            label: 'Observations (optionnel)',
            maxLines: 3,
            onChanged: (v) { s.notes = v.isEmpty ? null : v; widget.onChanged(); },
          ),
        ],
      ),
    );
  }
}

// ─── Étape 4 — Documents ─────────────────────────────────────────────────────

class _Step4Documents extends ConsumerStatefulWidget {
  const _Step4Documents({required this.state, required this.onChanged});
  final _InscriptionState state;
  final VoidCallback onChanged;

  @override
  ConsumerState<_Step4Documents> createState() => _Step4DocumentsState();
}

class _Step4DocumentsState extends ConsumerState<_Step4Documents> {
  final _uploading = <String>{};

  Future<void> _pick(String slug, String label) async {
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final schoolId = profile?.schoolId ?? '';
    if (schoolId.isEmpty) return;
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    setState(() => _uploading.add(slug));
    try {
      final client = ref.read(supabaseClientProvider);
      final path = await uploadStudentDocumentFile(
        client: client,
        schoolId: schoolId,
        studentId: widget.state.studentId,
        typeSlug: slug,
        fileName: f.name,
        bytes: bytes,
      );
      widget.state.uploadedDocs[slug] =
          _DocEntry(typeSlug: slug, label: label, fileName: f.name, path: path);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _kRed,
          content: Text('Téléversement impossible (connexion requise) : $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(slug));
    }
  }

  void _remove(String slug) {
    setState(() => widget.state.uploadedDocs.remove(slug));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('Dossier de l\'élève'),
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text(
            'Téléversez les pièces (PDF ou image). Le dossier suit l\'élève : '
            'en réinscription, les pièces déjà présentes sont conservées.',
            style: TextStyle(fontSize: 12, color: _kMuted, height: 1.4),
          ),
        ),
        for (final e in studentDocTypes.entries)
          _DocRow(
            label: e.value,
            entry: widget.state.uploadedDocs[e.key],
            uploading: _uploading.contains(e.key),
            onPick: () => _pick(e.key, e.value),
            onRemove: () => _remove(e.key),
          ),
      ]),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.label,
    required this.entry,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });
  final String label;
  final _DocEntry? entry;
  final bool uploading;
  final VoidCallback onPick, onRemove;

  @override
  Widget build(BuildContext context) {
    final has = entry != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: has ? _kGreen.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: has ? _kGreen.withValues(alpha: 0.4) : _kBorder),
      ),
      child: Row(children: [
        Icon(has ? Icons.check_circle_rounded : Icons.description_outlined,
            size: 20, color: has ? _kGreen : _kMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
            if (has)
              Text(entry!.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _kMuted)),
          ]),
        ),
        const SizedBox(width: 8),
        if (uploading)
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
        else if (has)
          Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(
                onPressed: onPick,
                style: TextButton.styleFrom(
                    foregroundColor: _kNavy, minimumSize: const Size(0, 32)),
                child: const Text('Remplacer', style: TextStyle(fontSize: 12))),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: _kRed),
              tooltip: 'Retirer',
              onPressed: onRemove,
            ),
          ])
        else
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file_rounded, size: 16),
            label: const Text('Téléverser'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kNavy,
              side: const BorderSide(color: _kNavy),
              minimumSize: const Size(0, 36),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ]),
    );
  }
}

// ─── Étape 5 — Résumé ─────────────────────────────────────────────────────────

class _Step5Resume extends StatelessWidget {
  const _Step5Resume({required this.state});
  final _InscriptionState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Résumé de l\'inscription'),
          _ResumeCard(
            title: 'Élève',
            icon: Icons.person_outline,
            rows: [
              ('Prénom', state.firstName),
              ('Nom', state.lastName),
              ('Genre', state.gender == 'M' ? 'Masculin' : 'Féminin'),
              if (state.dateOfBirth != null) ('Date de naissance', state.dateOfBirth!),
              if (state.placeOfBirth != null) ('Lieu de naissance', state.placeOfBirth!),
              if (state.situationFamiliale != null)
                ('Situation familiale', state.situationFamiliale!),
            ],
          ),
          _ResumeCard(
            title: 'Parents / Tuteurs',
            icon: Icons.family_restroom,
            rows: state.tutors
                .where((t) => t.firstName.isNotEmpty)
                .map((t) => (
                  (t.isPrimary ? 'Principal' : 'Contact'),
                  '${t.firstName} ${t.lastName} (${t.relationship})',
                ))
                .toList(),
          ),
          _ResumeCard(
            title: 'Scolarité',
            icon: Icons.school_outlined,
            rows: [
              ('Type', switch (state.inscriptionType) {
                'new'           => 'Nouvelle inscription',
                'reinscription' => 'Réinscription',
                'transfer'      => 'Transfert',
                _               => state.inscriptionType,
              }),
              if (state.isRepeating) ('Statut', 'Redoublant'),
              if (state.previousSchoolName != null)
                ('École précédente', state.previousSchoolName!),
            ],
          ),
          _ResumeCard(
            title: 'Dossier (pièces téléversées)',
            icon: Icons.folder_open_rounded,
            rows: state.uploadedDocs.isEmpty
                ? [('Aucune pièce téléversée', '')]
                : state.uploadedDocs.values.map((d) => (d.label, '✓')).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: _kGreen, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'L\'inscription sera créée avec le statut "En attente de validation". '
                    'Le directeur devra la valider pour qu\'elle devienne active.',
                    style: TextStyle(color: _kGreen, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.title,
    required this.icon,
    required this.rows,
  });
  final String             title;
  final IconData           icon;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: _kNavy),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _kNavy,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      r.$1,
                      style: const TextStyle(color: _kMuted, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
