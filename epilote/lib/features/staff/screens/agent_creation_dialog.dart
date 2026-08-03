// ════════════════════════════════════════════════════════════════════════════
//  NOUVEL AGENT — le formulaire que la direction remplit à la rentrée
//
//  Il dit trois choses AVANT de laisser saisir : combien de places restent sur
//  l'abonnement, si le réseau est là, et qu'aucun compte ne s'ouvre sans profil
//  d'accès. Remplir douze champs pour se voir refuser à l'enregistrement est la
//  meilleure façon de faire abandonner un établissement.
//
//  Le mot de passe est REMIS EN CLAIR à la fin, une fois, avec l'adresse : sur
//  un poste d'école, il n'existe aucun autre canal pour le transmettre à
//  l'agent. Ne pas l'afficher obligerait à le réinitialiser dans la minute.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/agent_creation_provider.dart';
import '../providers/staff_directory_provider.dart';

Future<bool> showAgentCreationDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AgentCreationDialog(),
    ) ??
    false;

class _AgentCreationDialog extends ConsumerStatefulWidget {
  const _AgentCreationDialog();
  @override
  ConsumerState<_AgentCreationDialog> createState() => _State();
}

class _State extends ConsumerState<_AgentCreationDialog> {
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  final _tel = TextEditingController();
  final _matricule = TextEditingController();

  String _role = 'enseignant';
  String? _profilId;
  bool _saving = false;
  String? _erreur;

  /// Renseigné une fois le compte créé : l'écran bascule alors sur la remise
  /// des identifiants, et il n'y a plus rien à saisir.
  ({String email, String mdp})? _creees;

  @override
  void dispose() {
    for (final c in [_prenom, _nom, _email, _mdp, _tel, _matricule]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _complet =>
      _prenom.text.trim().isNotEmpty &&
      _nom.text.trim().isNotEmpty &&
      _email.text.trim().contains('@') &&
      _mdp.text.length >= 8 &&
      _profilId != null;

  Future<void> _creer() async {
    setState(() { _saving = true; _erreur = null; });
    try {
      await ref.read(agentCreationServiceProvider).creer(
            email: _email.text,
            motDePasse: _mdp.text,
            prenom: _prenom.text,
            nom: _nom.text,
            role: _role,
            profilAccesId: _profilId!,
            telephone: _tel.text,
            matricule: _matricule.text,
          );
      ref.invalidate(staffDirectoryProvider);
      if (mounted) {
        setState(() {
          _creees = (email: _email.text.trim().toLowerCase(), mdp: _mdp.text);
          _saving = false;
        });
      }
    } on EchecCreationAgent catch (e) {
      if (mounted) setState(() { _erreur = e.message; _saving = false; });
    } catch (e) {
      if (mounted) setState(() { _erreur = '$e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contexteCreationAgentProvider);

    return AlertDialog(
      icon: Icon(_creees == null ? Icons.person_add_alt_1_rounded
                                 : Icons.check_circle_outline,
          color: _creees == null ? kNavy : kGreen, size: 30),
      title: Text(_creees == null ? 'Nouvel agent' : 'Compte créé'),
      content: SizedBox(
        width: 520,
        child: _creees != null
            ? _Identifiants(email: _creees!.email, mdp: _creees!.mdp)
            : ctx.when(
                loading: () => const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => _Empechement(
                    message: 'Impossible de préparer le formulaire : $e'),
                data: _formulaire,
              ),
      ),
      actions: _creees != null
          ? [
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Terminé'),
              ),
            ]
          : [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton.icon(
                onPressed: (_saving || !_complet ||
                        !(ctx.valueOrNull?.autorise ?? false) ||
                        (ctx.valueOrNull?.quotaAtteint ?? false))
                    ? null
                    : _creer,
                icon: _saving
                    ? const SizedBox(
                        width: 15, height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.person_add_alt_1_rounded, size: 17),
                label: Text(_saving ? 'Création…' : 'Créer le compte'),
              ),
            ],
    );
  }

  Widget _formulaire(ContexteCreationAgent c) {
    if (c.horsLigne) {
      return const _Empechement(
        message: 'Aucune connexion. Créer un compte exige le réseau : un '
            'identifiant de connexion vit sur le serveur, il ne peut pas être '
            'fabriqué hors ligne.\n\nTout le reste de l\'application continue '
            'de fonctionner normalement.',
        icone: Icons.cloud_off_rounded,
      );
    }
    if (!c.autorise) {
      return const _Empechement(
        message: 'Seule la direction de l\'établissement peut ouvrir un compte.',
        icone: Icons.lock_outline_rounded,
      );
    }
    if (c.aucunProfilDisponible) {
      return const _Empechement(
        message: 'Aucun profil d\'accès n\'existe dans votre réseau. Un compte '
            'créé sans profil ouvrirait une application sans aucun module — '
            'l\'agent ne pourrait rien faire.\n\nDemandez à l\'administration '
            'du réseau de créer au moins un profil d\'accès.',
        icone: Icons.shield_outlined,
      );
    }
    if (c.quotaAtteint) {
      return _Empechement(
        message: 'Le nombre d\'agents autorisé par l\'abonnement est atteint '
            '(${c.agentsActuels} / ${c.maxStaff}).\n\nRapprochez-vous de '
            'l\'administration du réseau pour l\'augmenter.',
        icone: Icons.block_rounded,
      );
    }

    final restantes = c.placesRestantes;
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (restantes != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$restantes place${restantes > 1 ? 's' : ''} restante'
              '${restantes > 1 ? 's' : ''} sur votre abonnement.',
              style: TextStyle(
                  fontSize: 12,
                  color: restantes <= 2 ? kAccent : kTextMuted,
                  fontWeight:
                      restantes <= 2 ? FontWeight.w700 : FontWeight.w400),
            ),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _champ(_prenom, 'Prénom *')),
          const SizedBox(width: 10),
          Expanded(child: _champ(_nom, 'Nom *')),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _role,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Fonction *',
            helperText: 'Nommer un directeur ou un proviseur reste un acte de '
                'l\'administration du réseau.',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final r in kRolesProvisionnablesParEcole)
              DropdownMenuItem(value: r.value, child: Text(r.label)),
          ],
          onChanged: (v) => setState(() => _role = v ?? _role),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _profilId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Profil d\'accès *',
            helperText: 'C\'est lui qui décide de ce que l\'agent verra. '
                'Obligatoire : sans profil, l\'application s\'ouvre vide.',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final p in c.profils)
              DropdownMenuItem(
                  value: p.id,
                  child: Text(p.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _profilId = v),
        ),
        const SizedBox(height: 16),
        const AdminFormSectionLabel('IDENTIFIANTS DE CONNEXION'),
        const SizedBox(height: 8),
        _champ(_email, 'Adresse électronique *',
            clavier: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _champ(_mdp, 'Mot de passe provisoire *',
            aide: 'Huit caractères au minimum. Il sera affiché une fois, à la '
                'fin : c\'est ainsi que vous le remettrez à l\'agent.'),
        const SizedBox(height: 16),
        const AdminFormSectionLabel('FACULTATIF'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _champ(_tel, 'Téléphone')),
          const SizedBox(width: 10),
          Expanded(child: _champ(_matricule, 'Matricule')),
        ]),
        if (_erreur != null) ...[
          const SizedBox(height: 14),
          AdminErrorBanner(message: _erreur!),
        ],
      ]),
    );
  }

  Widget _champ(TextEditingController c, String label,
          {String? aide, TextInputType? clavier}) =>
      TextField(
        controller: c,
        keyboardType: clavier,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          helperText: aide,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      );
}

/// La remise des identifiants — le seul moment où le mot de passe est lisible.
class _Identifiants extends StatelessWidget {
  const _Identifiants({required this.email, required this.mdp});
  final String email, mdp;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Remettez ces identifiants à l\'agent. Le mot de passe ne sera '
            'plus affiché : il n\'est conservé nulle part en clair.',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          _Ligne(label: 'Adresse', valeur: email),
          const SizedBox(height: 8),
          _Ligne(label: 'Mot de passe', valeur: mdp),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.info_outline, size: 16, color: kTextMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Invitez-le à le changer à sa première connexion.',
                style: TextStyle(fontSize: 11.5, color: kTextMuted),
              ),
            ),
          ]),
        ],
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.label, required this.valeur});
  final String label, valeur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          SizedBox(
            width: 108,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ),
          Expanded(
            child: SelectableText(valeur,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace')),
          ),
          IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy_rounded, size: 17),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: valeur));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copié')));
            },
          ),
        ]),
      );
}

/// Ce qui empêche, dit avant la saisie plutôt qu'après.
class _Empechement extends StatelessWidget {
  const _Empechement({required this.message, this.icone});
  final String message;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone ?? Icons.info_outline, color: kAccent, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
        ]),
      );
}
