import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_fees_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SAISIR UN TARIF — le geste que l'école n'a plus.
//
//  ⚠️ Cette boîte POSSÈDE ses contrôleurs et les libère elle-même.
//  `await showDialog` rend la main au `Navigator.pop`, PAS à la fin de
//  l'animation de sortie : les libérer depuis l'appelant les détruit pendant
//  que les champs en dépendent encore, et l'écran vire au rouge sur
//  « _dependents.isEmpty is not true ». Piège déjà vécu deux fois.
// ════════════════════════════════════════════════════════════════════════════

const kAdminFeeTypes = <String, String>{
  'inscription': 'Inscription',
  'mensualite': 'Mensualité',
  'frais_examens': 'Frais d\'examens',
  'cotisation_ape': 'Cotisation APE',
  'autre': 'Autre',
};

String adminFeeTypeLabel(String? t) => kAdminFeeTypes[t] ?? 'Autre';

Future<bool> showAdminFeeForm(
  BuildContext context, {
  required String academicYearId,
  AdminFee? fee,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminFeeForm(academicYearId: academicYearId, fee: fee),
    ) ??
    false;

class _AdminFeeForm extends ConsumerStatefulWidget {
  const _AdminFeeForm({required this.academicYearId, this.fee});
  final String academicYearId;
  final AdminFee? fee;

  @override
  ConsumerState<_AdminFeeForm> createState() => _AdminFeeFormState();
}

class _AdminFeeFormState extends ConsumerState<_AdminFeeForm> {
  late final _nom = TextEditingController(text: widget.fee?.name ?? '');
  late final _montant =
      TextEditingController(text: widget.fee?.amount.toString() ?? '');
  late final _echeance =
      TextEditingController(text: widget.fee?.dueDay?.toString() ?? '');
  late final _source =
      TextEditingController(text: widget.fee?.sourceReference ?? '');

  late String? _schoolId = widget.fee?.schoolId;
  late String? _levelId = widget.fee?.levelId;
  // Pas de valeur par défaut à la création : rien ne doit devenir une
  // mensualité par omission, surtout dans le public où elle n'existe pas.
  late String? _feeType = widget.fee?.feeType;

  String? _erreur;
  bool _saving = false;

  @override
  void dispose() {
    _nom.dispose();
    _montant.dispose();
    _echeance.dispose();
    _source.dispose();
    super.dispose();
  }

  String? _probleme() {
    if (_feeType == null) return 'Choisissez le type de frais';
    if (_nom.text.trim().isEmpty) return 'Le nom du barème est obligatoire';
    final m = int.tryParse(_montant.text.trim().replaceAll(' ', ''));
    if (m == null || m <= 0) return 'Montant (> 0) requis';
    if (_source.text.trim().isEmpty) {
      return 'Indiquez le texte qui fonde ce tarif';
    }
    return null;
  }

  Future<void> _save() async {
    final probleme = _probleme();
    if (probleme != null) {
      setState(() => _erreur = probleme);
      return;
    }
    final groupId = ref.read(authNotifierProvider).valueOrNull?.groupId;
    if (groupId == null) {
      setState(() => _erreur = 'Groupe introuvable');
      return;
    }
    setState(() {
      _saving = true;
      _erreur = null;
    });
    try {
      await saveAdminFee(
        ref.read(supabaseClientProvider),
        id: widget.fee?.id,
        groupId: groupId,
        academicYearId: widget.academicYearId,
        name: _nom.text.trim(),
        feeType: _feeType!,
        amount: int.parse(_montant.text.trim().replaceAll(' ', '')),
        schoolId: _schoolId,
        // Un tarif réseau ne cible jamais un niveau : `applies_to_level_id`
        // désigne le niveau d'UNE école (cf. adminFeeLevelsProvider).
        levelId: _schoolId == null ? null : _levelId,
        dueDay: _feeType == 'mensualite'
            ? int.tryParse(_echeance.text.trim())
            : null,
        sourceReference: _source.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _erreur = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ecoles = ref.watch(adminFeeSchoolsProvider).valueOrNull ?? const [];
    final niveaux = _schoolId == null
        ? const <OptionRef>[]
        : (ref.watch(adminFeeLevelsProvider(_schoolId!)).valueOrNull ??
            const <OptionRef>[]);

    return AdminFormDialog(
      icon: Icons.request_quote_rounded,
      title: widget.fee == null ? 'Nouveau tarif' : 'Modifier le tarif',
      subtitle: 'Les écoles concernées l\'appliqueront sans pouvoir le changer',
      accent: kNavy,
      width: 520,
      saving: _saving,
      submitLabel: widget.fee == null ? 'Publier le tarif' : 'Enregistrer',
      submitIcon: Icons.check_rounded,
      onSubmit: _saving ? null : _save,
      body: Column(mainAxisSize: MainAxisSize.min, children: [
        // La portée d'abord : c'est la décision structurante, tout le reste
        // en découle (le ciblage par niveau n'existe qu'en portée école).
        DropdownButtonFormField<String?>(
          initialValue: _schoolId,
          isExpanded: true,
          decoration: adminFilledInput('Portée',
              icon: Icons.account_balance_rounded),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tout le réseau')),
            for (final e in ecoles)
              DropdownMenuItem(
                  value: e.id,
                  child: Text(e.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() {
            _schoolId = v;
            if (v == null) _levelId = null;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _feeType,
          isExpanded: true,
          decoration:
              adminFilledInput('Type de frais', icon: Icons.category_rounded),
          hint: const Text('À choisir'),
          items: [
            for (final e in kAdminFeeTypes.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _feeType = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nom,
          decoration: adminFilledInput('Nom du barème (ex. Inscription 2025-2026)',
              icon: Icons.label_outline_rounded),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _montant,
              keyboardType: TextInputType.number,
              decoration: adminFilledInput('Montant (FCFA)',
                  icon: Icons.payments_rounded),
            ),
          ),
          if (_feeType == 'mensualite') ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _echeance,
                keyboardType: TextInputType.number,
                decoration: adminFilledInput('Échéance (jour)',
                    icon: Icons.event_rounded),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        if (_schoolId != null)
          DropdownButtonFormField<String?>(
            initialValue: _levelId,
            isExpanded: true,
            decoration: adminFilledInput('Niveau concerné',
                icon: Icons.stairs_rounded),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Tous les niveaux')),
              for (final n in niveaux)
                DropdownMenuItem(value: n.id, child: Text(n.name)),
            ],
            onChanged: (v) => setState(() => _levelId = v),
          )
        else
          _note(
            'Un tarif réseau s\'applique à tous les niveaux. Pour tarifer un '
            'niveau en particulier, visez une école : les niveaux appartiennent '
            'à chaque établissement, pas au réseau.',
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _source,
          maxLines: 2,
          decoration: adminFilledInput(
              'Texte fondateur — arrêté, note de service, délibération…',
              icon: Icons.gavel_rounded),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Obligatoire : un montant sans texte qui le fonde n\'est pas un '
            'tarif, c\'est un chiffre.',
            style: TextStyle(fontSize: 11, color: kTextMuted),
          ),
        ),
        if (_erreur != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_erreur!,
                style: TextStyle(
                    fontSize: 12, color: kRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }

  Widget _note(String text) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kNavy.withValues(alpha: 0.18)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 15, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35)),
          ),
        ]),
      );
}
