part of '../admin_regional_view.dart';

// ─── Dialogue : corriger la position GPS d'une école ─────────────────────────
class _SchoolGpsDialog extends ConsumerStatefulWidget {
  const _SchoolGpsDialog({required this.school, required this.onSaved});
  final AdminSchoolPin school;
  final VoidCallback onSaved;

  @override
  ConsumerState<_SchoolGpsDialog> createState() => _SchoolGpsDialogState();
}

class _SchoolGpsDialogState extends ConsumerState<_SchoolGpsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  bool _saving = false;

  // Bornes de la République du Congo (avec marge). Un point hors de ces bornes
  // est presque sûrement une erreur de saisie (lat/lng inversées, signe oublié).
  static const _latMin = -5.2, _latMax = 3.8, _lngMin = 11.0, _lngMax = 18.8;

  @override
  void initState() {
    super.initState();
    _latCtrl = TextEditingController(
        text: widget.school.latitude?.toStringAsFixed(6) ?? '');
    _lngCtrl = TextEditingController(
        text: widget.school.longitude?.toStringAsFixed(6) ?? '');
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  double? _parse(String? v) =>
      double.tryParse((v ?? '').trim().replaceAll(',', '.'));

  String? _validateLat(String? v) {
    final d = _parse(v);
    if (d == null) return 'Latitude invalide';
    if (d < _latMin || d > _latMax) return 'Hors Congo ($_latMin à $_latMax)';
    return null;
  }

  String? _validateLng(String? v) {
    final d = _parse(v);
    if (d == null) return 'Longitude invalide';
    if (d < _lngMin || d > _lngMax) return 'Hors Congo ($_lngMin à $_lngMax)';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminProjectServiceProvider).patchSchoolGps(
            schoolId: widget.school.id,
            latitude: _parse(_latCtrl.text)!,
            longitude: _parse(_lngCtrl.text)!,
            source: 'manual',
          );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Position mise à jour'), backgroundColor: kGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: kRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32, offset: const Offset(0, 8)),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [kNavy, _kBlue],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.edit_location_alt_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('Corriger la position GPS',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w800))),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.school.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      decoration: adminInputDecoration('Latitude *'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,\-]')),
                      ],
                      validator: _validateLat,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngCtrl,
                      decoration: adminInputDecoration('Longitude *'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,\-]')),
                      ],
                      validator: _validateLng,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: kTextMuted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        'La position sera marquée « saisie manuelle ». '
                        'Bornes Congo : lat $_latMin…$_latMax, '
                        'lng $_lngMin…$_lngMax.',
                        style: TextStyle(
                            fontSize: 10, color: kTextMuted, height: 1.3)),
                  ),
                ]),
              ]),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              child: Row(children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    side: const BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Annuler',
                      style: TextStyle(color: kTextMuted)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

