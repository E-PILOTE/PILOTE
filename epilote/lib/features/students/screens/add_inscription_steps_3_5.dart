part of 'add_inscription_screen.dart';

// Convertit une classe en entrée de cascade (cycle/niveau résolus).
ClassPickerEntry _entryFor(ClassModel c) {
  final cyc = inscriptionCycleFromCode(c.cycleCode, c.name);
  return ClassPickerEntry(
    id: c.id,
    name: c.name,
    cycleCode: cyc.code,
    cycleLabel: cyc.label,
    cycleOrder: cyc.order,
    levelCode: c.levelCode ?? '',
    levelOrder: c.levelOrder ?? 999,
    capacity: c.capacity,
    count: c.studentCount,
  );
}

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
    final classesAsync = ref.watch(classesForModuleProvider(_kSlug));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle('Type d\'inscription'),
          FormDropdown<String>(
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
          const FormSectionTitle('Affectation'),
          // ── L'ANNÉE NE SE CHOISIT PAS ICI ────────────────────────────────
          // C'était une liste déroulante de toutes les années. Or la liste des
          // CLASSES, juste en dessous, est verrouillée sur l'année active
          // (`classesProvider`) : choisir « 2024-2025 » puis une classe —
          // forcément de l'année en cours — écrivait une inscription rattachée
          // à une année et à une classe d'une AUTRE année. Rien ne l'arrête :
          // aucune contrainte en base ne relie les deux. L'élève se retrouvait
          // compté dans une année et scolarisé dans une autre, sans erreur.
          //
          // Le guichet des admissions inscrit dans l'année en cours. On le dit,
          // et on ne propose plus un choix que le formulaire ne peut pas tenir.
          // (La réinscription vers l'année suivante se fait à sa place, depuis
          // l'écran Passage.)
          yearsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error:   (e, _) => Text(messageErreur(e), style: TextStyle(color: _kRed)),
            data:    (years) {
              final active = ref.watch(activeYearProvider);
              if (years.isEmpty || active == null) {
                return Text(
                  'Aucune année scolaire en cours — inscription impossible.',
                  style: TextStyle(color: _kRed),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FormFieldLabel('Année scolaire'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kNavy.withValues(alpha: 0.18)),
                    ),
                    child: Row(children: [
                      Icon(Icons.event_available_rounded,
                          size: 17, color: _kNavy),
                      const SizedBox(width: 9),
                      Text(active.label,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _kText)),
                      const SizedBox(width: 8),
                      Text('· année en cours',
                          style: TextStyle(fontSize: 12.5, color: _kMuted)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
          classesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error:   (e, _) => Text(messageErreur(e), style: TextStyle(color: _kRed)),
            data:    (classes) {
              if (classes.isEmpty) {
                return Text(
                  'Aucune classe disponible.',
                  style: TextStyle(color: _kMuted),
                );
              }
              // Cascade Cycle ▸ Niveau ▸ Classe (cycle/niveau résolus depuis la
              // classe — cohérent avec la fiche d'inscription et les KPI).
              final entries = [
                for (final c in classes)
                  _entryFor(c),
              ];
              final picked = s.classId == null
                  ? null
                  : classes.where((c) => c.id == s.classId).firstOrNull;
              final cap = picked?.capacity ?? 0;
              final head = picked?.studentCount ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CycleLevelClassPicker(
                    entries: entries,
                    classId: s.classId,
                    onChanged: (v) { s.classId = v; widget.onChanged(); },
                  ),
                  // La capacité était affichée « (45/45) » et rien de plus :
                  // on pouvait remplir indéfiniment une classe pleine sans que
                  // l'écran le dise. On avertit — sans bloquer : au Congo une
                  // classe dépasse couramment sa capacité théorique, et
                  // refuser une inscription pour cela serait pire.
                  if (picked != null && cap > 0 && head >= cap) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 10),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(9),
                        border:
                            Border.all(color: kAccent.withValues(alpha: 0.32)),
                      ),
                      child: Row(children: [
                        Icon(Icons.groups_2_rounded, size: 17, color: kAccent),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '${picked.name} est à $head élèves pour $cap '
                            'places. Cette inscription la portera à '
                            '${head + 1}.',
                            style: TextStyle(
                                fontSize: 12.5, color: _kText, height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
          FormCheckTile(
            label: 'Élève redoublant',
            value: s.isRepeating,
            onChanged: (v) { s.isRepeating = v; widget.onChanged(); },
          ),
          if (s.inscriptionType == 'transfer') ...[
            const SizedBox(height: 12),
            const FormSectionTitle('École d\'origine'),
            FormTextField(
              controller: _prevSchoolCtrl,
              label: 'Nom de l\'école précédente',
              onChanged: (v) { s.previousSchoolName = v.isEmpty ? null : v; widget.onChanged(); },
            ),
            FormTextField(
              controller: _prevClassCtrl,
              label: 'Classe précédente',
              onChanged: (v) { s.previousClassName = v.isEmpty ? null : v; widget.onChanged(); },
            ),
            FormTextField(
              controller: _transferReasonCtrl,
              label: 'Motif du transfert',
              maxLines: 2,
              onChanged: (v) { s.transferReason = v.isEmpty ? null : v; widget.onChanged(); },
            ),
          ],
          const SizedBox(height: 12),
          const FormSectionTitle('Notes internes'),
          FormTextField(
            controller: _notesCtrl,
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
      // ── LES PIÈCES SE JOIGNENT HORS LIGNE ─────────────────────────────────
      // L'étape envoyait le fichier à Storage sur-le-champ : une école sans
      // connexion inscrivait l'élève mais ne pouvait joindre AUCUNE pièce, et
      // le dossier restait incomplet jusqu'à un passage ultérieur avec du
      // réseau. Les octets vont désormais dans `upload_outbox` — sur le disque,
      // à un chemin calculé en local — et montent au retour du réseau.
      //
      // ⚠️ Seulement les OCTETS. La ligne `student_documents` s'écrit à
      // l'enregistrement, APRÈS la création de l'élève : l'écrire ici la
      // placerait dans la file PowerSync avant l'insertion de `students`, le
      // serveur refuserait sur la clé étrangère (`23503`), et le connecteur
      // tenant ce code pour fatal abandonnerait le LOT ENTIER — l'élève, ses
      // tuteurs et son inscription avec.
      final path = await queueStudentDocumentFile(
        schoolId: schoolId,
        // ⚠️ `effectiveStudentId`, PAS `studentId`. Le chemin de stockage est
        // `école/élève/pièce` et `studentId` est l'identifiant NEUF que
        // l'assistant se réserve à l'ouverture. En réinscription, cet
        // identifiant n'est jamais écrit nulle part : le fichier atterrissait
        // dans un dossier qui n'appartient à aucun élève, tandis que la ligne
        // en base, elle, pointait le vrai. Le dossier documentaire de l'enfant
        // se retrouvait éparpillé sur deux chemins, dont un orphelin.
        studentId: widget.state.effectiveStudentId,
        documentType: slug,
        fileName: f.name,
        bytes: bytes,
        client: ref.read(supabaseClientProvider),
      );
      widget.state.uploadedDocs[slug] =
          _DocEntry(typeSlug: slug, label: label, fileName: f.name, path: path);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _kRed,
          content: Text(messageErreur(e)),
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
        const FormSectionTitle('Dossier de l\'élève'),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'Joignez les pièces (PDF ou image). Sans connexion, elles sont '
            'gardées sur le poste et partent dès le retour du réseau. '
            'Le dossier suit l\'élève : en réinscription, les pièces déjà '
            'présentes sont conservées.',
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
        // Un FOND doit suivre le thème : `#F8FAFC` restait blanc sur carte
        // sombre. Le jeton de surface, lui, s'assombrit avec la palette.
        color: has ? _kGreen.withValues(alpha: 0.06) : kSurface,
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
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
            if (has)
              Text(entry!.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: _kMuted)),
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
              icon: Icon(Icons.close_rounded, size: 18, color: _kRed),
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
              side: BorderSide(color: _kNavy),
              minimumSize: const Size(0, 36),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ]),
    );
  }
}

/// Le tarif d'inscription applicable à la classe choisie.
///
/// ⚠️ Purement INFORMATIF : rien n'est encaissé ici. Le versement se fait après
/// l'enregistrement, depuis la fiche du dossier — parce qu'un paiement doit
/// être rattaché à une inscription qui existe (`student_payments.enrollment_id`
/// est NOT NULL, et une ligne orpheline ferait abandonner tout le lot PowerSync).
class _FraisAnnonce extends ConsumerWidget {
  const _FraisAnnonce({required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(fraisInscriptionClasseProvider(classId)).valueOrNull;
    if (f == null) return const SizedBox.shrink();

    // Pas de barème : on le DIT. Afficher « 0 F » se lirait « gratuit », et
    // trente écoles publiques du réseau n'ont aucun tarif posé.
    final sansBareme = !f.baremeDefini;
    final couleur = sansBareme ? kTextMuted : kNavy;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: couleur.withValues(alpha: 0.28)),
      ),
      child: Row(children: [
        Icon(Icons.payments_outlined, size: 18, color: couleur),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              sansBareme
                  ? 'Aucun tarif d\'inscription défini'
                  : '${f.du} F — ${f.libelle ?? 'frais d\'inscription'}',
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800, color: _kText),
            ),
            const SizedBox(height: 2),
            Text(
              sansBareme
                  ? 'Le groupe n\'a publié aucun barème pour ce niveau. '
                      'L\'inscription reste possible ; aucun encaissement ne '
                      'pourra être rattaché.'
                  : 'À encaisser depuis la fiche du dossier, une fois '
                      'l\'inscription enregistrée.',
              style: TextStyle(fontSize: 11.5, color: _kMuted, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Étape 5 — Résumé ─────────────────────────────────────────────────────────

class _Step5Resume extends ConsumerWidget {
  const _Step5Resume({required this.state});
  final _InscriptionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le récapitulatif ne montrait ni l'année, ni le niveau, ni LA CLASSE :
    // seulement le type d'inscription. Or l'affectation est ce qui engage —
    // c'est elle qu'on relit avant d'enregistrer, et c'est la seule chose que
    // l'écran ne disait pas.
    final classes = ref.watch(classesForModuleProvider(_kSlug)).valueOrNull ?? const [];
    final klass = state.classId == null
        ? null
        : classes.where((c) => c.id == state.classId).firstOrNull;
    final yearLabel = ref.watch(activeYearProvider)?.label;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FormSectionTitle('Résumé de l\'inscription'),
          if (state.reusesExistingStudent)
            ResumeCard(
              title: 'Élève (fiche existante)',
              icon: Icons.how_to_reg_rounded,
              rows: [
                ('Élève', state.existingStudentName ?? ''),
                ('Fiche', 'Conservée — aucun doublon créé'),
                ('Tuteurs', 'Déjà enregistrés'),
              ],
            )
          else
            ResumeCard(
              title: 'Élève',
              icon: Icons.person_outline,
              rows: [
              ('Prénom', state.firstName),
              ('Nom', state.lastName),
              ('Genre', state.gender == 'M' ? 'Masculin' : 'Féminin'),
              if (state.dateOfBirth != null) ('Date de naissance', state.dateOfBirth!),
              if (state.placeOfBirth != null) ('Lieu de naissance', state.placeOfBirth!),
              // Le code brut (« monoparentale_pere ») s'affichait ici, à
              // l'écran précis où l'on relit avant d'enregistrer — même défaut
              // que le lien de parenté, corrigé en son temps par
              // `tutorRelationshipLabel`.
              if (state.situationFamiliale != null)
                ('Situation familiale',
                    situationFamilialeLabel(state.situationFamiliale)),
            ],
          ),
          if (!state.reusesExistingStudent)
            ResumeCard(
            title: 'Parents / Tuteurs',
            icon: Icons.family_restroom,
            // `!isBlank` et non « prénom non vide » : une fiche saisie sans
            // prénom serait enregistrée mais absente du récapitulatif — on ne
            // relit alors pas ce qu'on s'apprête à écrire.
            rows: tutorsToPersist(state.tutors)
                .map((t) => (
                  (t.isPrimary ? 'Principal' : 'Contact'),
                  '${t.firstName} ${t.lastName} · ${tutorRelationshipLabel(t.relationship)}',
                ))
                .toList(),
          ),
          ResumeCard(
            title: 'Scolarité',
            icon: Icons.school_outlined,
            rows: [
              ('Type', switch (state.inscriptionType) {
                'new'           => 'Nouvelle inscription',
                'reinscription' => 'Réinscription',
                'transfer'      => 'Transfert',
                _               => state.inscriptionType,
              }),
              if (yearLabel != null) ('Année scolaire', yearLabel),
              if (klass != null) ('Classe', klass.name),
              if (klass?.levelCode != null) ('Niveau', klass!.levelCode!),
              if (klass?.filiereLabel?.trim().isNotEmpty ?? false)
                ('Filière', klass!.filiereLabel!.trim()),
              if (state.isRepeating) ('Statut', 'Redoublant'),
              if (state.previousSchoolName != null)
                ('École précédente', state.previousSchoolName!),
            ],
          ),
          ResumeCard(
            title: 'Dossier (pièces téléversées)',
            icon: Icons.folder_open_rounded,
            rows: state.uploadedDocs.isEmpty
                ? [('Pièces', 'Aucune pour le moment')]
                : state.uploadedDocs.values.map((d) => (d.label, '✓')).toList(),
          ),
          // ── CE QUE ÇA VA COÛTER, AVANT D'ENREGISTRER ────────────────────
          // Le secrétariat annonce le montant à la famille au moment où il
          // ouvre le dossier. Le lui faire découvrir après enregistrement,
          // dans un autre module, c'est le faire rappeler la famille.
          if (state.classId != null) _FraisAnnonce(classId: state.classId!),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _kGreen, size: 18),
                const SizedBox(width: 8),
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
