// ════════════════════════════════════════════════════════════════════════════
//  MUTER, RADIER, RÉINTÉGRER — les trois gestes qui remplacent un booléen
//
//  L'écran des utilisateurs proposait « Activer / Désactiver ». Ce bouton
//  confondait un retraité, un démissionnaire, un révoqué, un mort et un MUTÉ —
//  qu'il désactivait alors qu'on l'attendait dans une autre école.
//
//  Ici, trois gestes distincts, chacun avec sa date d'effet et la référence de
//  l'acte qui le fonde. Aucun n'écrit `profiles` directement : tout passe par
//  les fonctions serveur de la migration 0083, qui tiennent `profiles` et
//  `staff_affectations` cohérents dans une même transaction.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/mouvement_agent.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_carriere_provider.dart';
import '../providers/admin_users_provider.dart';

String _jourFr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Pied de modale avec un bouton principal RÉELLEMENT désactivable — le chrome
/// partagé n'en propose pas : `AdminPrimaryButton.onTap` est non nullable, et
/// `AdminFormDialog` supprime tout le pied (bouton Annuler compris) quand
/// `onSubmit` est null. Or ici l'action doit rester visible mais inerte tant
/// que la date d'effet et le motif ne sont pas saisis.
class _PiedMouvement extends StatelessWidget {
  const _PiedMouvement({
    required this.label,
    required this.icon,
    required this.couleur,
    required this.saving,
    required this.onSubmit,
  });

  final String label;
  final IconData icon;
  final Color couleur;
  final bool saving;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) => Row(children: [
        TextButton.icon(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Annuler'),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: saving ? null : onSubmit,
          icon: saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: couleur,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ]);
}

/// Champ date compact — un mouvement administratif a toujours une date d'effet.
class _ChampDate extends StatelessWidget {
  const _ChampDate({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final DateTime? value;
  final String? helper;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(DateTime.now().year + 5),
          locale: const Locale('fr', 'FR'),
        );
        if (d != null) onChanged(d);
      },
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          prefixIcon: const Icon(Icons.event_outlined, size: 20),
          border: const OutlineInputBorder(),
        ),
        child: Text(value == null ? 'Choisir une date' : _jourFr(value!)),
      ),
    );
  }
}

/// Les champs communs à tout mouvement : l'acte qui le fonde, et l'observation.
class _ChampsActe extends StatelessWidget {
  const _ChampsActe({
    required this.reference,
    required this.notes,
    required this.acteDate,
    required this.onActeDate,
  });

  final TextEditingController reference, notes;
  final DateTime? acteDate;
  final ValueChanged<DateTime> onActeDate;

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: reference,
              decoration: const InputDecoration(
                labelText: 'Référence de l\'acte',
                hintText: 'Arrêté n° 1234/METP/CAB/2026',
                helperText: 'Facultatif, mais c\'est lui qui rend le registre '
                    'opposable.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _ChampDate(
                label: 'Date de l\'acte',
                value: acteDate,
                onChanged: onActeDate),
          ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Observations',
            border: OutlineInputBorder(),
          ),
        ),
      ]);
}

// ─── MUTATION ───────────────────────────────────────────────────────────────

Future<ChargeLiberee?> showMutationDialog(
  BuildContext context, {
  required AdminUser user,
  required List<SchoolOption> schools,
}) =>
    showDialog<ChargeLiberee>(
      context: context,
      builder: (_) => _MutationDialog(user: user, schools: schools),
    );

class _MutationDialog extends ConsumerStatefulWidget {
  const _MutationDialog({required this.user, required this.schools});
  final AdminUser user;
  final List<SchoolOption> schools;

  @override
  ConsumerState<_MutationDialog> createState() => _MutationDialogState();
}

class _MutationDialogState extends ConsumerState<_MutationDialog> {
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String? _schoolId;
  String? _role;
  DateTime? _effet;
  DateTime? _acteDate;
  bool _saving = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
  }

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_schoolId == null || _effet == null) return;
    setState(() { _saving = true; _erreur = null; });
    try {
      final charge = await ref.read(agentCarriereServiceProvider).muter(
            profileId:     widget.user.id,
            schoolId:      _schoolId!,
            effectiveDate: _effet!,
            role:          _role,
            acteReference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
            acteDate:      _acteDate,
            notes:         _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context, charge);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _erreur = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final autres = widget.schools.where((s) => s.id != widget.user.schoolId).toList();
    return AdminFormDialog(
      icon: Icons.swap_horiz_rounded,
      title: 'Muter ${widget.user.fullName}',
      subtitle: 'Poste actuel : ${widget.user.schoolName ?? '—'} '
          '· ${widget.user.roleLbl}',
      accent: kNavy,
      footer: _PiedMouvement(
        label: 'Enregistrer la mutation',
        icon: Icons.swap_horiz_rounded,
        couleur: kNavy,
        saving: _saving,
        onSubmit: (_schoolId == null || _effet == null) ? null : _submit,
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _NoteExplicative(
          icon: Icons.info_outline,
          texte: 'L\'agent reste ACTIF : il change d\'établissement, il ne '
              'quitte pas le service. Son poste précédent se ferme la veille '
              'de la prise de fonction, et son ancienneté est conservée.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _schoolId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Établissement d\'accueil *',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final s in autres)
              DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _schoolId = v),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _role,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Fonction au nouveau poste',
            helperText: 'Un enseignant muté peut arriver directeur : la '
                'fonction appartient au poste.',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final r in kStaffRoles)
              DropdownMenuItem(value: r.value, child: Text(r.label)),
          ],
          onChanged: (v) => setState(() => _role = v),
        ),
        const SizedBox(height: 14),
        _ChampDate(
          label: 'Prise de fonction *',
          value: _effet,
          helper: 'Le poste quitté se ferme la veille.',
          onChanged: (d) => setState(() => _effet = d),
        ),
        const SizedBox(height: 14),
        _ChampsActe(
          reference: _reference,
          notes: _notes,
          acteDate: _acteDate,
          onActeDate: (d) => setState(() => _acteDate = d),
        ),
        if (_erreur != null) ...[
          const SizedBox(height: 14),
          AdminErrorBanner(message: _erreur!),
        ],
      ]),
    );
  }
}

// ─── DÉPART DU SERVICE ──────────────────────────────────────────────────────

Future<ChargeLiberee?> showRadiationDialog(BuildContext context,
        {required AdminUser user}) =>
    showDialog<ChargeLiberee>(
      context: context,
      builder: (_) => _RadiationDialog(user: user),
    );

class _RadiationDialog extends ConsumerStatefulWidget {
  const _RadiationDialog({required this.user});
  final AdminUser user;

  @override
  ConsumerState<_RadiationDialog> createState() => _RadiationDialogState();
}

class _RadiationDialogState extends ConsumerState<_RadiationDialog> {
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String? _motif;
  DateTime? _effet;
  DateTime? _acteDate;
  bool _saving = false;
  String? _erreur;

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_motif == null || _effet == null) return;
    setState(() { _saving = true; _erreur = null; });
    try {
      final charge = await ref.read(agentCarriereServiceProvider).radier(
            profileId:     widget.user.id,
            motif:         _motif!,
            effectiveDate: _effet!,
            acteReference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
            acteDate:      _acteDate,
            notes:         _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context, charge);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _erreur = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    MouvementMotif? choisi;
    for (final m in kMotifsDepart) {
      if (m.code == _motif) choisi = m;
    }
    return AdminFormDialog(
      icon: Icons.logout_rounded,
      title: 'Fin de service — ${widget.user.fullName}',
      subtitle: '${widget.user.schoolName ?? '—'} · ${widget.user.roleLbl}',
      accent: kRed,
      footer: _PiedMouvement(
        label: 'Enregistrer le départ',
        icon: Icons.logout_rounded,
        couleur: kRed,
        saving: _saving,
        onSubmit: (_motif == null || _effet == null) ? null : _submit,
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _NoteExplicative(
          icon: Icons.shield_outlined,
          texte: 'Rien n\'est supprimé. Le dossier reste consultable — pension, '
              'attestations — et les écritures faites par l\'agent restent '
              'attribuables. Pour une MUTATION, utiliser « Muter » : un muté '
              'n\'a pas quitté le service.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _motif,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Motif du départ *',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final m in kMotifsDepart)
              DropdownMenuItem(value: m.code, child: Text(m.label)),
          ],
          onChanged: (v) => setState(() => _motif = v),
        ),
        if (choisi != null) ...[
          const SizedBox(height: 8),
          Text(choisi.hint,
              style: TextStyle(
                  fontSize: 12.5,
                  color: choisi.reversible ? Colors.black54 : kRed,
                  fontWeight: choisi.reversible ? FontWeight.w400 : FontWeight.w600)),
        ],
        const SizedBox(height: 14),
        _ChampDate(
          label: 'Date d\'effet *',
          value: _effet,
          onChanged: (d) => setState(() => _effet = d),
        ),
        const SizedBox(height: 14),
        _ChampsActe(
          reference: _reference,
          notes: _notes,
          acteDate: _acteDate,
          onActeDate: (d) => setState(() => _acteDate = d),
        ),
        if (_erreur != null) ...[
          const SizedBox(height: 14),
          AdminErrorBanner(message: _erreur!),
        ],
      ]),
    );
  }
}

// ─── RÉINTÉGRATION ──────────────────────────────────────────────────────────

Future<ChargeLiberee?> showReintegrationDialog(
  BuildContext context, {
  required AdminUser user,
  required List<SchoolOption> schools,
}) =>
    showDialog<ChargeLiberee>(
      context: context,
      builder: (_) => _ReintegrationDialog(user: user, schools: schools),
    );

class _ReintegrationDialog extends ConsumerStatefulWidget {
  const _ReintegrationDialog({required this.user, required this.schools});
  final AdminUser user;
  final List<SchoolOption> schools;

  @override
  ConsumerState<_ReintegrationDialog> createState() => _ReintegrationDialogState();
}

class _ReintegrationDialogState extends ConsumerState<_ReintegrationDialog> {
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String? _schoolId;
  String? _role;
  DateTime? _effet;
  DateTime? _acteDate;
  bool _saving = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
    _schoolId = widget.user.schoolId;
  }

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_schoolId == null || _effet == null) return;
    setState(() { _saving = true; _erreur = null; });
    try {
      final charge = await ref.read(agentCarriereServiceProvider).reintegrer(
            profileId:     widget.user.id,
            schoolId:      _schoolId!,
            effectiveDate: _effet!,
            role:          _role,
            acteReference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
            acteDate:      _acteDate,
            notes:         _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context, charge);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _erreur = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloque = !departReversible(widget.user.departureMotif);
    return AdminFormDialog(
      icon: Icons.person_add_alt_1_rounded,
      title: 'Réintégrer ${widget.user.fullName}',
      subtitle: 'Parti le '
          '${widget.user.departureDate == null ? '—' : _jourFr(widget.user.departureDate!)}'
          ' · ${mouvementLabel(widget.user.departureMotif)}',
      accent: kGreen,
      footer: _PiedMouvement(
        label: 'Réintégrer',
        icon: Icons.person_add_alt_1_rounded,
        couleur: kGreen,
        saving: _saving,
        onSubmit: (bloque || _schoolId == null || _effet == null) ? null : _submit,
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (bloque)
          _NoteExplicative(
            icon: Icons.block,
            couleur: kRed,
            texte: 'Un départ pour '
                '« ${mouvementLabel(widget.user.departureMotif)} » ne se défait '
                'pas d\'un clic. Le dossier doit d\'abord être corrigé — la '
                'base refuse également cette réintégration.',
          )
        else
          const _NoteExplicative(
            icon: Icons.history_rounded,
            texte: 'Une nouvelle affectation s\'ouvre ; les précédentes restent '
                'au dossier. L\'ancienneté déjà acquise n\'est pas perdue.',
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _schoolId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Établissement d\'accueil *',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final s in widget.schools)
              DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: bloque ? null : (v) => setState(() => _schoolId = v),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _role,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Fonction',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final r in kStaffRoles)
              DropdownMenuItem(value: r.value, child: Text(r.label)),
          ],
          onChanged: bloque ? null : (v) => setState(() => _role = v),
        ),
        const SizedBox(height: 14),
        _ChampDate(
          label: 'Reprise de fonction *',
          value: _effet,
          onChanged: (d) => setState(() => _effet = d),
        ),
        const SizedBox(height: 14),
        _ChampsActe(
          reference: _reference,
          notes: _notes,
          acteDate: _acteDate,
          onActeDate: (d) => setState(() => _acteDate = d),
        ),
        if (_erreur != null) ...[
          const SizedBox(height: 14),
          AdminErrorBanner(message: _erreur!),
        ],
      ]),
    );
  }
}

// ─── Bandeau explicatif ─────────────────────────────────────────────────────

class _NoteExplicative extends StatelessWidget {
  const _NoteExplicative({required this.icon, required this.texte, this.couleur});
  final IconData icon;
  final String texte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final c = couleur ?? kNavy;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.22)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texte,
              style: const TextStyle(fontSize: 12.5, height: 1.45)),
        ),
      ]),
    );
  }
}
