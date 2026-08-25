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
import 'agent_mouvement_kit.dart';

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
      footer: PiedMouvement(
        label: 'Enregistrer la mutation',
        icon: Icons.swap_horiz_rounded,
        couleur: kNavy,
        saving: _saving,
        onSubmit: (_schoolId == null || _effet == null) ? null : _submit,
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const NoteExplicative(
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
        ChampDate(
          label: 'Prise de fonction *',
          value: _effet,
          helper: 'Le poste quitté se ferme la veille.',
          onChanged: (d) => setState(() => _effet = d),
        ),
        const SizedBox(height: 14),
        ChampsActe(
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
      footer: PiedMouvement(
        label: 'Enregistrer le départ',
        icon: Icons.logout_rounded,
        couleur: kRed,
        saving: _saving,
        onSubmit: (_motif == null || _effet == null) ? null : _submit,
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const NoteExplicative(
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
        ChampDate(
          label: 'Date d\'effet *',
          value: _effet,
          onChanged: (d) => setState(() => _effet = d),
        ),
        const SizedBox(height: 14),
        ChampsActe(
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
          '${widget.user.departureDate == null ? '—' : jourFr(widget.user.departureDate!)}'
          ' · ${mouvementLabel(widget.user.departureMotif)}',
      accent: kGreen,
      footer: PiedMouvement(
        label: 'Réintégrer',
        icon: Icons.person_add_alt_1_rounded,
        couleur: kGreen,
        saving: _saving,
        onSubmit: (bloque || _schoolId == null || _effet == null) ? null : _submit,
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (bloque)
          NoteExplicative(
            icon: Icons.block,
            couleur: kRed,
            texte: 'Un départ pour '
                '« ${mouvementLabel(widget.user.departureMotif)} » ne se défait '
                'pas d\'un clic. Le dossier doit d\'abord être corrigé — la '
                'base refuse également cette réintégration.',
          )
        else
          const NoteExplicative(
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
        ChampDate(
          label: 'Reprise de fonction *',
          value: _effet,
          onChanged: (d) => setState(() => _effet = d),
        ),
        const SizedBox(height: 14),
        ChampsActe(
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
