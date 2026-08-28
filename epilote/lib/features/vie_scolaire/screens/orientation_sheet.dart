part of 'orientation_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FICHE D'ORIENTATION — un élève : niveau cible, filière cible, recommandation
//  du conseiller, consultation des parents. Écriture offline.
// ════════════════════════════════════════════════════════════════════════════
class _OrientationSheet extends ConsumerStatefulWidget {
  const _OrientationSheet({
    required this.row,
    required this.trimesterId,
    required this.canEdit,
    required this.onSaved,
  });
  final OrientationRow row;
  final String? trimesterId;
  final bool canEdit;
  final VoidCallback onSaved;
  @override
  ConsumerState<_OrientationSheet> createState() => _OrientationSheetState();
}

class _OrientationSheetState extends ConsumerState<_OrientationSheet> {
  // Des CODES du référentiel, plus du texte libre : voir l'en-tête de
  // `orientation_provider.dart`. Une orientation qui ne s'agrège pas ne sert
  // à personne au niveau national.
  late String? _levelCode = widget.row.targetLevel;
  late String? _filiereCode = widget.row.targetFiliere;
  late final _reco =
      TextEditingController(text: widget.row.recommendation ?? '');
  late bool _consulted = widget.row.parentConsulted;
  bool _busy = false;

  @override
  void dispose() {
    _reco.dispose();
    super.dispose();
  }

  /// Liste déroulante d'un référentiel, tolérante à une valeur qui n'y est
  /// plus : une filière retirée du référentiel ne doit pas faire disparaître —
  /// ni planter — la fiche d'un élève déjà orienté.
  Widget _cibleField({
    required String label,
    required IconData icon,
    required List<CibleOrientation> cibles,
    required String? valeur,
    required ValueChanged<String?> onChanged,
  }) {
    final codes = {for (final c in cibles) c.code};
    final inconnu = valeur != null && valeur.isNotEmpty && !codes.contains(valeur);
    return DropdownButtonFormField<String?>(
      initialValue: valeur == null || valeur.isEmpty ? null : valeur,
      isExpanded: true,
      decoration: adminFilledInput(label, icon: icon),
      onChanged: widget.canEdit ? onChanged : null,
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('—')),
        if (inconnu)
          DropdownMenuItem<String?>(
            value: valeur,
            child: Text('$valeur (hors référentiel)',
                overflow: TextOverflow.ellipsis),
          ),
        for (final c in cibles)
          DropdownMenuItem<String?>(
            value: c.code,
            child: Text(c.cycle == null ? c.nom : '${c.nom} · ${c.cycle}',
                overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }

  Future<void> _save() async {
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) return;
    final missing = missingWriteIds(
        groupId: p?.groupId, schoolId: p?.schoolId, actorId: p?.id);
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(writeIdentityMessage(missing)), backgroundColor: kRed));
      return;
    }
    setState(() => _busy = true);
    final ok = await runModuleWrite(
      context,
      () => saveOrientation(
        id: widget.row.recordId,
        groupId: p!.groupId!,
        schoolId: p.schoolId!,
        academicYearId: yearId,
        studentId: widget.row.studentId,
        trimesterId: widget.trimesterId,
        recommendation: _reco.text.trim().isEmpty ? null : _reco.text.trim(),
        targetLevel: _levelCode,
        targetFiliere: _filiereCode,
        parentConsulted: _consulted,
        counselorId: p.id,
      ),
      success: 'Orientation enregistrée',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onSaved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
            child: Row(children: [
              Icon(Icons.explore_rounded, size: 18, color: kNavy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.row.studentName,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ),
              if (!widget.canEdit)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.lock_outline_rounded,
                      size: 16, color: kTextMuted),
                ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _cibleField(
                  label: 'Niveau cible',
                  icon: Icons.stairs_rounded,
                  cibles:
                      ref.watch(niveauxCiblesProvider).valueOrNull ?? const [],
                  valeur: _levelCode,
                  onChanged: (v) => setState(() => _levelCode = v),
                ),
                const SizedBox(height: 14),
                _cibleField(
                  label: 'Filière cible',
                  icon: Icons.alt_route_rounded,
                  cibles:
                      ref.watch(filieresCiblesProvider).valueOrNull ?? const [],
                  valeur: _filiereCode,
                  onChanged: (v) => setState(() => _filiereCode = v),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _reco,
                  enabled: widget.canEdit,
                  maxLines: 5,
                  decoration: adminFilledInput(
                      'Recommandation du conseiller',
                      icon: Icons.recommend_rounded),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _consulted,
                  activeThumbColor: kGreen,
                  onChanged: widget.canEdit
                      ? (v) => setState(() => _consulted = v)
                      : null,
                  title: const Text('Parents consultés',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 16),
                if (widget.canEdit)
                  SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(backgroundColor: kNavy),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Enregistrer l\'orientation'),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
