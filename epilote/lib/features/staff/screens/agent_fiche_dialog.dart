// ════════════════════════════════════════════════════════════════════════════
//  CORRIGER LA FICHE D'UN AGENT — et rien de plus
//
//  Ce que cet écran permet : réparer une faute de frappe, mettre à jour un
//  téléphone, ajouter un matricule, poser une photo. Des soins apportés à un
//  dossier, pas des actes de carrière.
//
//  ⚠️ CE QUE CET ÉCRAN NE PERMETTRA JAMAIS, ET POURQUOI IL LE DIT
//  Ni la fonction, ni l'activation, ni l'établissement. Dans le public, un
//  agent arrive et repart par acte de l'autorité de tutelle : muter, radier ou
//  réintégrer sont des décisions du ministère, pas de l'école qui les subit.
//  Le serveur (migration 0091) n'expose aucun paramètre pour ces colonnes —
//  la liste blanche se lit dans la SIGNATURE de la fonction, elle ne peut donc
//  pas être contournée depuis ici. L'encart en bas de page l'explique à la
//  direction plutôt que de la laisser chercher un bouton qui n'existe pas.
//
//  Tout est EN LIGNE : la RLS `profiles_update` refuse une écriture PowerSync
//  sur la fiche d'autrui, et un refus serveur emporterait le lot entier.
// ════════════════════════════════════════════════════════════════════════════

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../communication/widgets/user_avatar.dart';
import '../../user/widgets/staff_account_widgets.dart' show staffRoleLabel;
import '../providers/agent_creation_provider.dart';
import '../providers/staff_directory_provider.dart';
import '../providers/staff_photo_provider.dart';
import '../providers/staff_dossier_provider.dart'
    show kEmploymentStatuses, employmentStatusLabel;
import '../services/agent_photo_service.dart';

/// Ouvre la correction de fiche. Renvoie `true` si quelque chose a changé.
Future<bool> showAgentFicheDialog(BuildContext context, StaffMember agent) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AgentFicheDialog(agent: agent),
    ) ??
    false;

class _AgentFicheDialog extends ConsumerStatefulWidget {
  const _AgentFicheDialog({required this.agent});
  final StaffMember agent;
  @override
  ConsumerState<_AgentFicheDialog> createState() => _State();
}

class _State extends ConsumerState<_AgentFicheDialog> {
  late final _prenom = TextEditingController(text: widget.agent.firstName);
  late final _nom = TextEditingController(text: widget.agent.lastName);
  late final _tel = TextEditingController(text: widget.agent.phone ?? '');
  late final _matricule =
      TextEditingController(text: widget.agent.employeeNumber ?? '');

  /// Statut d'emploi choisi, quand la fiche n'en portait aucun.
  String? _statut;

  bool get _statutDejaPose =>
      (widget.agent.employmentStatus ?? '').isNotEmpty;

  /// Photo choisie mais pas encore envoyée — l'aperçu se fait sur ces octets.
  String? _photoUrl;
  bool _effacerPhoto = false;
  bool _envoiPhoto = false;

  bool _saving = false;
  String? _erreur;
  bool _modifie = false;

  @override
  void dispose() {
    for (final c in [_prenom, _nom, _tel, _matricule]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ce que la pastille doit montrer, dans l'ordre de fraîcheur : le choix en
  /// cours (pas encore enregistré), puis une demande déposée mais pas encore
  /// appliquée par le serveur, puis la fiche.
  ///
  /// Sans le deuxième terme, un chef qui rouvre la fiche hors ligne verrait
  /// encore l'ancienne photo — et la reprendrait, croyant son geste perdu.
  String? _photoAffichee(WidgetRef ref) {
    if (_effacerPhoto) return null;
    if (_photoUrl != null) return _photoUrl;
    return photoAffichee(ref, widget.agent.id, widget.agent.avatarUrl);
  }

  Future<void> _choisirPhoto() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kAvatarExtensions,
      withData: true,
    );
    final f = res?.files.firstOrNull;
    final bytes = f?.bytes;
    if (f == null || bytes == null) return;

    final schoolId = ref.read(authNotifierProvider).valueOrNull?.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      setState(() => _erreur = 'Établissement inconnu sur ce poste.');
      return;
    }

    setState(() { _envoiPhoto = true; _erreur = null; });
    try {
      // Les octets partent AVANT toute écriture dans la fiche : on ne promet
      // jamais dans le dossier une photo qui ne serait pas arrivée.
      final url = await preparerPhotoAgent(
        client: ref.read(supabaseClientProvider),
        schoolId: schoolId,
        profileId: widget.agent.id,
        fileName: f.name,
        bytes: bytes,
      );
      if (mounted) {
        setState(() {
          _photoUrl = url;
          _effacerPhoto = false;
          _envoiPhoto = false;
        });
      }
    } on EchecPhotoAgent catch (e) {
      if (mounted) setState(() { _erreur = e.message; _envoiPhoto = false; });
    } catch (e) {
      if (mounted) setState(() { _erreur = '$e'; _envoiPhoto = false; });
    }
  }

  Future<void> _enregistrer() async {
    setState(() { _saving = true; _erreur = null; });
    try {
      // ── LA PHOTO PART D'ABORD, ET PAR SA PROPRE PORTE ───────────────────
      // Elle est le SEUL champ de cette fiche qui sache attendre le réseau :
      // la demande s'écrit en local, PowerSync la remonte, le serveur
      // l'applique. Le reste — nom, téléphone, matricule — passe par une RPC
      // et ne peut pas.
      //
      // On la dépose donc AVANT : si la RPC échoue faute de connexion, au
      // moins la photo est acquise, et on le dit. L'ordre inverse aurait fait
      // perdre les deux.
      final profil = ref.read(authNotifierProvider).valueOrNull;
      final aPhoto = _effacerPhoto || _photoUrl != null;
      if (aPhoto && profil?.groupId != null && profil?.schoolId != null) {
        await deposerDemandePhotoAgent(
          groupId: profil!.groupId!,
          schoolId: profil.schoolId!,
          profileId: widget.agent.id,
          avatarUrl: _photoUrl,
          requestedBy: profil.id,
          effacer: _effacerPhoto,
        );
      }

      // ⚠️ Plus de `photoUrl` ici : la photo a UNE seule porte, sans quoi elle
      // s'appliquerait deux fois — une par la demande, une par la RPC — et le
      // journal d'audit porterait deux corrections pour un seul geste.
      await ref.read(agentCreationServiceProvider).corriger(
            profileId: widget.agent.id,
            prenom: _prenom.text,
            nom: _nom.text,
            telephone: _tel.text,
            matricule: _matricule.text,
          );
      // Après la fiche, et seulement s'il en manquait un : deux appels parce
      // que ce sont deux gestes de nature différente — soigner un dossier
      // d'un côté, constater une situation administrative de l'autre. Ils ne
      // portent pas la même trace d'audit.
      if (!_statutDejaPose && _statut != null) {
        await ref.read(agentCreationServiceProvider).renseignerStatut(
              profileId: widget.agent.id,
              statutEmploi: _statut!,
            );
      }
      ref.invalidate(staffDirectoryProvider);
      if (mounted) Navigator.pop(context, true);
    } on EchecCreationAgent catch (e) {
      if (mounted) setState(() { _erreur = e.message; _saving = false; });
    } catch (e) {
      if (mounted) setState(() { _erreur = '$e'; _saving = false; });
    }
  }

  /// Annuler un enregistrement qui n'a rien produit.
  ///
  /// Le serveur décide seul : s'il refuse, il NOMME ce qui bloque. On affiche
  /// sa réponse telle quelle — un refus qu'on ne comprend pas se contourne au
  /// hasard.
  Future<void> _annuler() async {
    final ok = await showAdminConfirm(
      context,
      title: 'Annuler cet enregistrement ?',
      message: '${widget.agent.lastFirst} sera retiré de l\'établissement et '
          'son compte supprimé.\n\nCe geste n\'est possible que si l\'agent ne '
          's\'est jamais connecté et ne porte aucun travail. Il ne remplace '
          'jamais une radiation : un agent qui a servi se retire par acte de '
          'l\'autorité de tutelle.',
      confirmLabel: 'Annuler l\'enregistrement',
      danger: true,
    );
    if (ok != true || !mounted) return;

    setState(() { _saving = true; _erreur = null; });
    try {
      final bloquants = await ref
          .read(agentCreationServiceProvider)
          .annulerEnregistrement(widget.agent.id);
      if (!mounted) return;
      if (bloquants.isEmpty) {
        ref.invalidate(staffDirectoryProvider);
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _saving = false;
        _erreur = 'Annulation impossible : cet agent porte déjà '
            '${bloquants.join(', ')}. Retirez-lui ces charges, ou passez par '
            'l\'administration du réseau.';
      });
    } on EchecCreationAgent catch (e) {
      if (mounted) setState(() { _erreur = e.message; _saving = false; });
    } catch (e) {
      if (mounted) setState(() { _erreur = '$e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.agent;
    return AlertDialog(
      icon: Icon(Icons.edit_note_rounded, color: kNavy, size: 30),
      title: const Text('Corriger la fiche'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Photo ──────────────────────────────────────────────────────
            Row(children: [
              Stack(alignment: Alignment.bottomRight, children: [
                UserAvatarCircle(
                    name: a.fullName,
                    role: a.role,
                    avatarUrl: _photoAffichee(ref),
                    radius: 38),
                if (_envoiPhoto)
                  const Positioned.fill(
                    child: Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4)),
                    ),
                  ),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.lastFirst,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(staffRoleLabel(a.role),
                          style: TextStyle(fontSize: 12, color: kTextMuted)),
                      const SizedBox(height: 8),
                      Builder(builder: (_) {
                        final photo = _photoAffichee(ref);
                        return Row(children: [
                        OutlinedButton.icon(
                          onPressed: _envoiPhoto || _saving ? null : _choisirPhoto,
                          icon: const Icon(Icons.photo_camera_outlined, size: 16),
                          label: Text(photo == null
                              ? 'Ajouter une photo'
                              : 'Remplacer'),
                        ),
                        if (photo != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _envoiPhoto || _saving
                                ? null
                                : () => setState(() {
                                      _effacerPhoto = true;
                                      _photoUrl = null;
                                    }),
                            child: Text('Retirer',
                                style: TextStyle(color: kRed, fontSize: 12.5)),
                          ),
                        ],
                        ]);
                      }),
                    ]),
              ),
            ]),
            const SizedBox(height: 18),
            const AdminFormSectionLabel('IDENTITÉ'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _champ(_prenom, 'Prénom')),
              const SizedBox(width: 10),
              Expanded(child: _champ(_nom, 'Nom')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _champ(_tel, 'Téléphone')),
              const SizedBox(width: 10),
              Expanded(child: _champ(_matricule, 'Matricule')),
            ]),
            const SizedBox(height: 18),
            const AdminFormSectionLabel('STATUT D\'EMPLOI'),
            const SizedBox(height: 8),
            // Un statut ABSENT se renseigne — l'école a l'agent devant elle et
            // sait s'il est fonctionnaire ou payé par l'APE. Un statut POSÉ ne
            // se change plus : requalifier, c'est titulariser, et cela relève
            // de la tutelle. Le serveur refuse (migration 0093) ; ici on se
            // contente de ne pas proposer un geste qui serait rejeté.
            if (_statutDejaPose)
              _StatutPose(libelle: employmentStatusLabel(widget.agent.employmentStatus))
            else
              DropdownButtonFormField<String>(
                initialValue: _statut,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Statut à renseigner',
                  helperText: 'Il ne pourra plus être modifié ici ensuite : '
                      'requalifier un agent est un acte de la tutelle.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final (code, libelle) in kEmploymentStatuses)
                    DropdownMenuItem(value: code, child: Text(libelle)),
                ],
                onChanged: (v) => setState(() {
                  _statut = v;
                  _modifie = true;
                }),
              ),
            const SizedBox(height: 18),
            // ── Ce que l'école ne peut pas faire, dit plutôt que caché ──────
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.gavel_rounded, size: 18, color: kTextMuted),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'La fonction, la mutation et la fin de service ne se '
                        'modifient pas ici : l\'agent est affecté à votre '
                        'établissement par acte de l\'autorité de tutelle, et '
                        'c\'est elle qui les décide.',
                        style: TextStyle(
                            fontSize: 11.5, color: kTextMuted, height: 1.45),
                      ),
                    ),
                  ]),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 14),
              AdminErrorBanner(message: _erreur!),
            ],
            // ── LE REFUS DU SERVEUR NE DOIT PAS RESTER MUET ──────────────────
            // Le trigger qui applique une demande de photo ne lève JAMAIS : une
            // exception ferait abandonner à PowerSync le lot entier. Il inscrit
            // donc son motif dans la demande, qui redescend sur le poste — et
            // c'est ici, la seule fois où l'agent peut l'apprendre. Sans cet
            // affichage, la photo ne changerait simplement jamais, sans un mot.
            Builder(builder: (_) {
              final refus =
                  ref.watch(demandePhotoAgentProvider(widget.agent.id)).refus;
              if (refus == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: AdminErrorBanner(message: 'Photo refusée — $refus'),
              );
            }),
          ]),
        ),
      ),
      // Une seule Row : `actions` est posé dans un OverflowBar, où un `Spacer`
      // n'a aucun Flex parent pour s'étendre. L'annulation reste à gauche,
      // loin du bouton qu'on presse par réflexe.
      actions: [
        Row(children: [
          TextButton.icon(
            onPressed: _saving ? null : _annuler,
            icon: Icon(Icons.person_remove_outlined, size: 16, color: kRed),
            label: Text('Annuler l\'enregistrement',
                style: TextStyle(color: kRed, fontSize: 12.5)),
          ),
          const Spacer(),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, _modifie),
            child: const Text('Fermer'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _saving || _envoiPhoto ? null : _enregistrer,
            icon: _saving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 17),
            label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
          ),
        ]),
      ],
    );
  }

  Widget _champ(TextEditingController c, String label) => TextField(
        controller: c,
        onChanged: (_) => setState(() => _modifie = true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );
}

/// Statut déjà posé : on le montre, on ne le propose pas à la modification.
/// Le dire explicitement vaut mieux qu'un champ grisé sans explication — un
/// champ grisé se lit comme une panne, une phrase se lit comme une règle.
class _StatutPose extends StatelessWidget {
  const _StatutPose({required this.libelle});
  final String libelle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(Icons.badge_rounded, size: 18, color: kTextMuted),
          const SizedBox(width: 11),
          Text(libelle,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const Spacer(),
          Flexible(
            child: Text(
              'Requalifier un agent relève du réseau.',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: kTextMuted),
            ),
          ),
        ]),
      );
}
