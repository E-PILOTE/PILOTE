part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DIALOGUES — nouvelle année / correction, et passage d'année.
//
//  Le champ date vit maintenant dans `core/widgets/admin_date_field.dart` : il
//  existait ici en double avec celui du dialogue calendrier.
// ════════════════════════════════════════════════════════════════════════════

/// Bornes du sélecteur d'année : large, mais pas infini — une rentrée saisie en
/// 2043 par une frappe malheureuse coûte cher à rattraper.
DateTime get _borneMin => DateTime(DateTime.now().year - 5);
DateTime get _borneMax => DateTime(DateTime.now().year + 6);

// ─── Dialogue : nouvelle année OU édition ──────────────────────────────────────
// [existing] null → création (pré-remplie sur le calendrier type Congo).
// [existing] non null → correction du libellé/dates d'une année déjà créée.
class _YearDialog extends ConsumerStatefulWidget {
  const _YearDialog({this.existing});
  final AdminYear? existing;
  @override
  ConsumerState<_YearDialog> createState() => _YearDialogState();
}

class _YearDialogState extends ConsumerState<_YearDialog> {
  final _label = TextEditingController();
  DateTime? _start, _end;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _label.text = ex.label;
      _start = ex.startDate;
      _end = ex.endDate;
    } else {
      final y = defaultSchoolYearStart(DateTime.now());
      _label.text = schoolYearLabel(y);
      _start = schoolYearStartDate(y);
      _end = schoolYearEndDate(y);
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  String? _valider() {
    if (_label.text.trim().isEmpty) return 'Le libellé est requis.';
    if (_start == null || _end == null) {
      return 'Les dates de début et de fin sont requises.';
    }
    if (!_end!.isAfter(_start!)) {
      return 'La date de fin doit suivre la date de début.';
    }
    final jours = _end!.difference(_start!).inDays;
    if (jours < 90) {
      return 'Une année scolaire de $jours jours est probablement une erreur '
          'de saisie (minimum attendu : 90 jours).';
    }
    if (jours > 500) {
      return 'Une année scolaire de $jours jours dépasse ce qu\'un calendrier '
          'scolaire peut couvrir (maximum attendu : 500 jours).';
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _valider();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final svc = ref.read(adminCalendarServiceProvider);
      if (_isEdit) {
        await svc.updateYear(
            id: widget.existing!.id,
            label: _label.text,
            start: _start!,
            end: _end!);
      } else {
        await svc.createYear(label: _label.text, start: _start!, end: _end!);
      }
      ref.invalidate(adminAcademicYearsProvider);
      if (_isEdit) ref.invalidate(adminYearCalendarProvider(widget.existing!.id));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = messageErreur(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: _isEdit ? Icons.edit_calendar_rounded : Icons.event_rounded,
      title: _isEdit ? 'Modifier l\'année scolaire' : 'Nouvelle année scolaire',
      subtitle: _isEdit
          ? 'Corrigez le libellé ou les dates'
          : 'Pré-remplie sur le calendrier congolais — ajustez si besoin',
      width: 480,
      saving: _saving,
      submitLabel: _isEdit ? 'Enregistrer' : 'Créer',
      submitIcon: Icons.check_rounded,
      onSubmit: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdminFormSectionLabel("IDENTITÉ DE L'ANNÉE"),
          const SizedBox(height: 14),
          TextField(
              controller: _label,
              decoration: adminFilledInput('Libellé (ex. 2026-2027)',
                  icon: Icons.label_outline_rounded)),
          const AdminFormDivider(),
          const AdminFormSectionLabel('PÉRIODE'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: AdminDateField(
                    label: 'Début',
                    value: _start,
                    first: _borneMin,
                    last: _borneMax,
                    onPick: (d) => setState(() {
                          _start = d;
                          _error = null;
                        }))),
            const SizedBox(width: 12),
            Expanded(
                child: AdminDateField(
                    label: 'Fin',
                    value: _end,
                    first: _borneMin,
                    last: _borneMax,
                    onPick: (d) => setState(() {
                          _end = d;
                          _error = null;
                        }))),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: kNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isEdit
                      ? 'La correction se propage à toutes les écoles du groupe '
                          'à leur prochaine synchro. Le calendrier existant doit '
                          'rester dans les nouvelles bornes.'
                      : 'Créée NON courante. Toutes les écoles du groupe '
                          "l'hériteront à leur prochaine synchro. Deux années "
                          'ne peuvent pas se chevaucher.',
                  style: TextStyle(
                      fontSize: 11.5, color: kTextMuted, height: 1.4),
                ),
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AdminErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}

// ─── Dialogue : passage d'année ────────────────────────────────────────────────
class _RolloverDialog extends ConsumerStatefulWidget {
  const _RolloverDialog({required this.years});
  final List<AdminYear> years;
  @override
  ConsumerState<_RolloverDialog> createState() => _RolloverDialogState();
}

class _RolloverDialogState extends ConsumerState<_RolloverDialog> {
  String? _sourceId;
  final _label = TextEditingController();
  DateTime? _start, _end;
  bool _copyCalendar = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AdminYear? def;
    for (final y in widget.years) {
      if (y.isCurrent) {
        def = y;
        break;
      }
    }
    def ??= widget.years.isNotEmpty ? widget.years.first : null;
    _sourceId = def?.id;
    _applyPrefill(def);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  AdminYear? get _source {
    for (final y in widget.years) {
      if (y.id == _sourceId) return y;
    }
    return null;
  }

  void _applyPrefill(AdminYear? y) {
    if (y == null) return;
    _label.text = _nextLabel(y.label);
    _start = DateTime(y.startDate.year + 1, y.startDate.month, y.startDate.day);
    _end = DateTime(y.endDate.year + 1, y.endDate.month, y.endDate.day);
  }

  String _nextLabel(String label) {
    final m = RegExp(r'(\d{4})\s*[-/]\s*(\d{4})').firstMatch(label);
    if (m != null) return '${int.parse(m[1]!) + 1}-${int.parse(m[2]!) + 1}';
    final y = RegExp(r'(\d{4})').firstMatch(label);
    if (y != null) return '${int.parse(y[1]!) + 1}';
    return '';
  }

  String? _valider() {
    if (_source == null) return "L'année source est requise.";
    if (_label.text.trim().isEmpty) return 'Le libellé est requis.';
    if (_start == null || _end == null) {
      return 'Les dates de début et de fin sont requises.';
    }
    if (!_end!.isAfter(_start!)) {
      return 'La date de fin doit suivre la date de début.';
    }
    // Chevauchement avec une année existante : la base refuserait de toute
    // façon, autant le dire avant d'envoyer.
    for (final y in widget.years) {
      if (!y.startDate.isAfter(_end!) && !_start!.isAfter(y.endDate)) {
        return 'Ces dates chevauchent l\'année « ${y.label} » '
            '(${_fmtShort.format(y.startDate)} → '
            '${_fmtShort.format(y.endDate)}).';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _valider();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome =
          await ref.read(adminCalendarServiceProvider).rolloverYear(
                sourceYearId: _source!.id,
                label: _label.text,
                start: _start!,
                end: _end!,
                copyCalendar: _copyCalendar,
              );
      ref.invalidate(adminAcademicYearsProvider);
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
          SnackBar(backgroundColor: kGreen, content: Text(outcome.resume)));
    } catch (e) {
      setState(() => _error = messageErreur(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.move_up_rounded,
      title: "Passage d'année",
      subtitle: 'Créer la prochaine rentrée du groupe',
      width: 500,
      saving: _saving,
      submitLabel: 'Lancer le passage',
      submitIcon: Icons.move_up_rounded,
      submitColor: kGreen,
      onSubmit: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdminFormSectionLabel('ANNÉE SOURCE'),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _sourceId,
            isExpanded: true,
            decoration:
                adminFilledInput('Année source', icon: Icons.history_rounded),
            items: widget.years
                .map((y) => DropdownMenuItem(
                      value: y.id,
                      child: Text('${y.label}${y.isCurrent ? "  · en cours" : ""}',
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() {
              _sourceId = v;
              _applyPrefill(_source);
              _error = null;
            }),
          ),
          const AdminFormDivider(),
          const AdminFormSectionLabel('NOUVELLE ANNÉE'),
          const SizedBox(height: 14),
          TextField(
              controller: _label,
              decoration: adminFilledInput('Libellé de la nouvelle année',
                  icon: Icons.label_outline_rounded)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: AdminDateField(
                    label: 'Début',
                    value: _start,
                    first: _borneMin,
                    last: _borneMax,
                    onPick: (d) => setState(() {
                          _start = d;
                          _error = null;
                        }))),
            const SizedBox(width: 12),
            Expanded(
                child: AdminDateField(
                    label: 'Fin',
                    value: _end,
                    first: _borneMin,
                    last: _borneMax,
                    onPick: (d) => setState(() {
                          _end = d;
                          _error = null;
                        }))),
          ]),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => setState(() => _copyCalendar = !_copyCalendar),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _copyCalendar ? kGreen.withValues(alpha: 0.06) : kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _copyCalendar
                        ? kGreen.withValues(alpha: 0.4)
                        : kBorder),
              ),
              child: Row(children: [
                Icon(Icons.event_note_rounded,
                    size: 18, color: _copyCalendar ? kGreen : kTextMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Reporter le calendrier (trimestres, séquences et '
                        'vacances, décalés sur les nouvelles dates)',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: kNavy),
                      ),
                      const SizedBox(height: 2),
                      // Dire que les fériés ne sont PAS reportés évite la
                      // question — et surtout le doute de l'agent qui compte
                      // les lignes et n'en retrouve pas le même nombre.
                      Text(
                        'Les jours fériés légaux sont recalculés pour la '
                        'nouvelle année, pas recopiés : Pâques se déplace.',
                        style: TextStyle(fontSize: 11.5, color: kTextMuted),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: _copyCalendar,
                  activeColor: kGreen,
                  onChanged: (v) => setState(() => _copyCalendar = v ?? false),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: kNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Année, trimestres et séquences sont créés en une seule '
                  'transaction : en cas de coupure, rien n\'est créé à moitié. '
                  'L\'année est créée NON courante — définissez-la courante le '
                  'jour de la rentrée.',
                  style:
                      TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
                ),
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AdminErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}
