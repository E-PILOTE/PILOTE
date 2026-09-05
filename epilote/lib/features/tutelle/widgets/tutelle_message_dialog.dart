import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../communication/providers/messages_provider.dart';
import '../providers/tutelle_destinataires_provider.dart';
import '../providers/tutelle_reseau_provider.dart';

part 'tutelle_message_destinataires.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉCRIRE À UN GROUPE SUPERVISÉ — par la messagerie, pas par un canal de plus
//
//  ── CE QUE CET ÉCRAN REMPLACE ─────────────────────────────────────────────
//  La « circulaire de tutelle » : quatre écrans, un formulaire à sept champs,
//  un vocabulaire propre et deux entrées de menu, pour un objet dont la base
//  ne comptait AUCUNE ligne. La plateforme portait déjà trois canaux —
//  annonces, messagerie, tickets. Un ministère n'a pas à apprendre un
//  quatrième geste pour écrire à quelqu'un.
//
//  ── ON CHOISIT QUI, ET C'EST TOUT L'INTÉRÊT ──────────────────────────────
//  Le ministère coche l'administrateur du groupe, ou les chefs des
//  établissements qu'il vise, ou les deux. C'est la portée d'une circulaire —
//  atteindre les établissements — sans en réinventer l'objet.
//
//  ── ⚠️ RIEN DE NOUVEAU CÔTÉ SÉCURITÉ, ET C'EST VOULU ─────────────────────
//  Le message part comme n'importe quel autre : `group_id` = le groupe de
//  l'EXPÉDITEUR, `sender_id` = lui. `msg_insert` l'accepte tel quel. Et
//  `msg_select` le rend au destinataire par `recipient_id = auth.uid()`, SANS
//  condition de groupe — chacun le lit donc dans sa propre messagerie, bien
//  qu'il appartienne à un autre groupe. Aucune politique n'a été élargie.
//
//  L'envoi passe par `sendMessageToMany` : une LIGNE par destinataire, parce
//  que `recipient_id` est NOT NULL. Ce n'est pas un envoi groupé masqué —
//  chacun reçoit son message, et peut y répondre seul.
// ════════════════════════════════════════════════════════════════════════════

/// Ouvre la rédaction d'un message adressé au groupe [g].
Future<void> ouvrirMessageGroupe(BuildContext context, TutelleGroupe g) =>
    showDialog<void>(
      context: context,
      builder: (_) => TutelleMessageDialog(groupe: g),
    );

class TutelleMessageDialog extends ConsumerStatefulWidget {
  const TutelleMessageDialog({super.key, required this.groupe});
  final TutelleGroupe groupe;

  @override
  ConsumerState<TutelleMessageDialog> createState() =>
      _TutelleMessageDialogState();
}

class _TutelleMessageDialogState extends ConsumerState<TutelleMessageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _objet = TextEditingController();
  final _corps = TextEditingController();

  /// Les destinataires cochés, par identifiant d'utilisateur.
  final _coches = <String>{};

  /// ⚠️ La pré-sélection ne se fait qu'UNE fois. La refaire à chaque `build`
  /// aurait recoché l'administrateur juste après qu'on l'ait décoché.
  bool _preselectionFaite = false;
  bool _envoi = false;

  @override
  void dispose() {
    _objet.dispose();
    _corps.dispose();
    super.dispose();
  }

  /// ⚠️ Le GROUPE est coché d'office, les écoles ne le sont pas.
  ///
  /// Écrire à la personne morale est le geste ordinaire ; toucher chaque chef
  /// d'établissement est une décision, et une décision se prend en cochant,
  /// pas en oubliant de décocher.
  void _preselectionner(List<DestinataireTutelle> tous) {
    if (_preselectionFaite || tous.isEmpty) return;
    _preselectionFaite = true;
    for (final d in tous) {
      if (d.estLeGroupe) _coches.add(d.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.groupe;
    final couleur = g.estPublic ? kNavy : kAccent;
    final async = ref.watch(destinatairesTutelleProvider(g.id));
    async.whenData(_preselectionner);

    return AdminFormDialog(
      icon: Icons.forum_rounded,
      title: 'Écrire à ${g.nom}',
      subtitle: 'Le message arrive dans la messagerie de chaque destinataire.',
      accent: couleur,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Destinataires(
              async: async,
              couleur: couleur,
              coches: _coches,
              onBascule: (id) => setState(() =>
                  _coches.contains(id) ? _coches.remove(id) : _coches.add(id)),
              onTousLesChefs: (ids, cocher) => setState(() =>
                  cocher ? _coches.addAll(ids) : _coches.removeAll(ids)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _objet,
              decoration: const InputDecoration(
                labelText: 'Objet *',
                hintText: 'Ex. Rentrée scolaire 2026-2027',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _corps,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Message *',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            // ⚠️ Un message n'est pas une circulaire : il n'emporte ni accusé
            // de lecture ni échéance. Le dire évite qu'on le prenne pour une
            // notification administrative opposable.
            const _Note(
              'Message ordinaire : il se lit et se répond dans la messagerie. '
              'Il ne porte pas d’accusé de réception. Chaque destinataire '
              'reçoit sa propre copie.',
            ),
          ],
        ),
      ),
      // ⚠️ Compact : « Envoyer aux 4 destinataires » faisait déborder le pied
      // de la modale de 58 px à côté du bouton « Annuler ». Le compte reste
      // dit — c'est ce qui compte — mais il tient.
      submitLabel: _coches.length <= 1
          ? 'Envoyer'
          : 'Envoyer (${_coches.length})',
      submitIcon: Icons.send_rounded,
      submitColor: couleur,
      saving: _envoi,
      // ⚠️ Pas de bouton tant que personne n'est coché : `recipient_id` est
      // NOT NULL, un envoi à vide échouerait en base et l'agent croirait à une
      // panne de réseau.
      onSubmit: _coches.isEmpty ? null : _envoyer,
    );
  }

  Future<void> _envoyer() async {
    if (!_formKey.currentState!.validate() || _envoi || _coches.isEmpty) return;
    final profil = ref.read(authNotifierProvider).valueOrNull;
    final monGroupe = profil?.groupId;
    final moi = profil?.id;
    if (monGroupe == null || moi == null) return;

    setState(() => _envoi = true);
    final messenger = ScaffoldMessenger.of(context);
    final combien = _coches.length;
    try {
      await sendMessageToMany(
        client: ref.read(supabaseClientProvider),
        senderId: moi,
        recipientIds: _coches.toList(),
        // ⚠️ MON groupe, pas celui des destinataires : c'est ce que
        // `msg_insert` exige. Ils le liront quand même — `msg_select` le rend
        // par `recipient_id`, sans condition de groupe.
        groupId: monGroupe,
        subject: _objet.text.trim(),
        body: _corps.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text(combien == 1
            ? 'Message envoyé.'
            : 'Message envoyé à $combien destinataires.'),
        backgroundColor: kGreen,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      messenger.showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Envoi')),
        backgroundColor: kRed,
      ));
    }
  }
}

class _Note extends StatelessWidget {
  const _Note(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 15, color: kTextMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(texte,
                style:
                    TextStyle(fontSize: 11, color: kTextMuted, height: 1.45)),
          ),
        ]),
      );
}
