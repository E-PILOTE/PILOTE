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

  @override
  void dispose() {
    _prevSchoolCtrl.dispose();
    _prevClassCtrl.dispose();
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
          ],
        ],
      ),
    );
  }
}

// ─── Étape 4 — Documents ─────────────────────────────────────────────────────

class _Step4Documents extends StatefulWidget {
  const _Step4Documents({required this.state, required this.onChanged});
  final _InscriptionState state;
  final VoidCallback onChanged;

  @override
  State<_Step4Documents> createState() => _Step4DocumentsState();
}

class _Step4DocumentsState extends State<_Step4Documents> {
  static const _docs = [
    'Extrait d\'acte de naissance',
    'Certificat de nationalité',
    'Certificat de résidence',
    'Bulletin de notes (année précédente)',
    'Certificat médical de bonne santé',
    'Photos d\'identité (2)',
    'Attestation de transfert (si transfert)',
    'Livret scolaire',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _docs.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Pièces justificatives'),
                Text(
                  'Cochez les documents fournis par la famille.',
                  style: TextStyle(color: _kMuted, fontSize: 13),
                ),
              ],
            ),
          );
        }
        final doc = _docs[i - 1];
        return CheckboxListTile(
          title: Text(doc, style: const TextStyle(fontSize: 14)),
          value: widget.state.checkedDocs.contains(doc),
          activeColor: _kGreen,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                widget.state.checkedDocs.add(doc);
              } else {
                widget.state.checkedDocs.remove(doc);
              }
            });
            widget.onChanged();
          },
        );
      },
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
            title: 'Documents',
            icon: Icons.description_outlined,
            rows: state.checkedDocs.isEmpty
                ? [('Aucun document coché', '')]
                : state.checkedDocs.map((d) => (d, '✓')).toList(),
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
