// ════════════════════════════════════════════════════════════════════════════
//  ENREGISTRER UN AGENT — la direction CONSTATE une arrivée
//
//  Le titre n'est pas « Nouvel agent » par hasard. Un fonctionnaire n'est pas
//  choisi par son école : elle le reçoit, affecté par note de l'autorité de
//  tutelle. Un volontaire payé par l'APE, lui, est bel et bien engagé par la
//  direction. Le formulaire demande donc le STATUT en premier — c'est lui qui
//  décide de tout le reste : les motifs d'arrivée possibles, et si la référence
//  d'un acte sera exigée. C'est le SERVEUR qui tranche (migration 0092), jamais
//  cet écran ; il ne fait que refléter la règle pour éviter un aller-retour.
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
import '../providers/staff_dossier_provider.dart' show employmentStatusLabel;

part 'agent_creation_parts.dart';

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
  final _acte = TextEditingController();

  String _role = 'enseignant';
  String? _profilId;

  /// Statut d'emploi — la première question, celle qui commande les autres.
  /// Laissé nul : un défaut ferait passer un vacataire pour un fonctionnaire.
  String? _statut;

  /// Motif d'arrivée. Laissé nul tant qu'un statut n'est pas choisi : les
  /// motifs recevables en dépendent entièrement.
  String? _motif;
  DateTime? _acteDate;
  DateTime? _priseService;

  bool _saving = false;
  String? _erreur;

  /// Renseigné une fois le compte créé : l'écran bascule alors sur la remise
  /// des identifiants, et il n'y a plus rien à saisir.
  ({String email, String mdp})? _creees;

  @override
  void dispose() {
    for (final c in [_prenom, _nom, _email, _mdp, _tel, _matricule, _acte]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ce que le serveur exigera. On le vérifie ici pour ne pas laisser remplir
  /// douze champs avant de refuser — mais c'est la migration 0091 qui tranche.
  bool _completPour(ContexteCreationAgent c) =>
      _prenom.text.trim().isNotEmpty &&
      _nom.text.trim().isNotEmpty &&
      _email.text.trim().contains('@') &&
      _mdp.text.length >= 8 &&
      _profilId != null &&
      _statut != null &&
      _motif != null &&
      (!c.acteExige(_motif) ||
          (_acte.text.trim().isNotEmpty && _acteDate != null));

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
            statutEmploi: _statut!,
            motifArrivee: _motif!,
            acteReference: _acte.text,
            acteDate: _acteDate,
            priseDeService: _priseService,
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
      icon: Icon(_creees == null ? Icons.how_to_reg_rounded
                                 : Icons.check_circle_outline,
          color: _creees == null ? kNavy : kGreen, size: 30),
      title: Text(_creees == null ? 'Enregistrer un agent' : 'Compte créé'),
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
                onPressed: (_saving ||
                        ctx.valueOrNull == null ||
                        !_completPour(ctx.value!) ||
                        !ctx.value!.autorise ||
                        ctx.value!.quotaAtteint)
                    ? null
                    : _creer,
                icon: _saving
                    ? const SizedBox(
                        width: 15, height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.how_to_reg_rounded, size: 17),
                label: Text(_saving ? 'Enregistrement…' : 'Enregistrer l\'agent'),
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

    // Le serveur dit quels motifs vont avec le statut choisi ; on n'en invente
    // aucun. Un seul motif possible (le cas d'un volontaire) : le choix n'en
    // est pas un, on le pose.
    final motifs = c.motifsPour(_statut);
    if (_motif == null && motifs.length == 1) _motif = motifs.first;
    final acteExige = c.acteExige(_motif);

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
        // ── L'ACTE D'ABORD ──────────────────────────────────────────────────
        // Il vient avant l'identité parce qu'il en est la cause : c'est lui qui
        // explique pourquoi cet agent est ici, et c'est lui que la tutelle
        // lira dans la carrière.
        const AdminFormSectionLabel('CE QUI AMÈNE L\'AGENT'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _statut,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Statut d\'emploi *',
            helperText: _statut == null
                ? 'Un fonctionnaire arrive par acte ; un volontaire ou un '
                    'vacataire est engagé par votre établissement.'
                : kAideStatutEmploi[_statut],
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final s in c.statutsProposables)
              DropdownMenuItem(value: s, child: Text(employmentStatusLabel(s))),
          ],
          // Changer de statut change les motifs possibles : on ne garde pas un
          // motif que le nouveau statut ne permet plus.
          onChanged: (v) => setState(() {
            _statut = v;
            if (!c.motifsPour(v).contains(_motif)) _motif = null;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _motif,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Motif d\'arrivée *',
            helperText: _statut == null
                ? 'Choisissez d\'abord le statut de l\'agent.'
                : (_motif == null
                    ? 'Ce qui explique sa présence dans votre établissement.'
                    : kMotifsArrivee[_motif]?.aide),
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final m in motifs)
              DropdownMenuItem(value: m, child: Text(motifArriveeLabel(m))),
          ],
          onChanged:
              motifs.isEmpty ? null : (v) => setState(() => _motif = v),
        ),
        const SizedBox(height: 12),
        // La référence d'acte n'apparaît QUE si le motif la suppose. Demander
        // un numéro d'arrêté pour un bénévole de l'APE n'aurait pas de sens :
        // le champ resterait vide, et le formulaire paraîtrait bloqué.
        if (acteExige) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: _champ(_acte, 'Référence de l\'acte *',
                  aide: 'Sans elle, la carrière de l\'agent naîtrait sans acte.'),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _dateChamp(
                label: 'Date de l\'acte *',
                valeur: _acteDate,
                // Un acte est signé avant qu'on le constate : jamais de futur.
                dernier: DateTime.now(),
                onChoisi: (d) => setState(() => _acteDate = d),
              ),
            ),
          ]),
          const SizedBox(height: 12),
        ],
        _dateChamp(
          label: 'Prise de service',
          valeur: _priseService,
          aide: 'Vide = aujourd\'hui. Une arrivée peut s\'enregistrer à '
              'l\'avance, dans la limite de trois mois.',
          premier: DateTime.now().subtract(const Duration(days: 365 * 2)),
          dernier: DateTime.now().add(const Duration(days: 90)),
          onChoisi: (d) => setState(() => _priseService = d),
        ),
        const SizedBox(height: 16),
        const AdminFormSectionLabel('L\'AGENT'),
        const SizedBox(height: 8),
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

  /// Champ de date : on ouvre un calendrier plutôt que de laisser taper.
  /// « 03/04 » se lit avril au Congo et mars ailleurs — la saisie libre d'une
  /// date administrative est une source d'erreur qu'aucune relecture ne rattrape.
  Widget _dateChamp({
    required String label,
    required DateTime? valeur,
    required ValueChanged<DateTime> onChoisi,
    String? aide,
    DateTime? premier,
    DateTime? dernier,
  }) {
    final d = valeur;
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final choisi = await showDatePicker(
          context: context,
          initialDate: d ?? (dernier != null && dernier.isBefore(now) ? dernier : now),
          firstDate: premier ?? DateTime(now.year - 5),
          lastDate: dernier ?? now,
          locale: const Locale('fr'),
        );
        if (choisi != null) onChoisi(choisi);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: aide,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.event_rounded, size: 19),
        ),
        child: Text(
          d == null
              ? '—'
              : '${d.day.toString().padLeft(2, '0')}/'
                  '${d.month.toString().padLeft(2, '0')}/${d.year}',
          style: TextStyle(
              fontSize: 14,
              color: d == null ? kTextMuted : kTextPrimary,
              fontWeight: d == null ? FontWeight.w400 : FontWeight.w600),
        ),
      ),
    );
  }
}
