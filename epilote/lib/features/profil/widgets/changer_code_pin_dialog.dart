import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/active_agent_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHANGER SON CODE PIN — depuis « Mon profil »
//
//  Jusqu'ici, le seul endroit où un code se posait était l'écran-verrou, et
//  seulement à l'enrôlement : une fois le code créé, plus rien dans le produit
//  ne permettait d'en changer. Un agent qui avait laissé un collègue voir son
//  code n'avait aucun recours — sauf demander un reset à l'administrateur du
//  groupe, c'est-à-dire attendre le réseau et déranger quelqu'un pour une
//  affaire strictement locale.
//
//  ── L'ANCIEN CODE EST EXIGÉ, POUR LA MÊME RAISON QUE LE MOT DE PASSE ──────
//  Un poste partagé reste souvent ouvert entre deux services. Sans cette
//  vérification, il suffirait de passer derrière un collègue parti aux
//  photocopies pour lui poser un code qu'il ne connaît pas : on ne lui volerait
//  rien, on le mettrait dehors de sa propre machine — et c'est pire, car il
//  n'aurait plus le moyen d'y rentrer avant le retour du réseau.
//
//  ── LA PAUSE ANTI-FORCE-BRUTE EST CELLE DE L'ÉCRAN-VERROU ─────────────────
//  Même service, même compteur d'échecs, même barème ([pinCooldown]) : sinon
//  cette boîte de dialogue deviendrait le chemin doux pour essayer les dix
//  mille combinaisons que l'écran-verrou refuse de laisser essayer.
// ════════════════════════════════════════════════════════════════════════════

class ChangerCodePinDialog extends ConsumerStatefulWidget {
  const ChangerCodePinDialog({
    super.key,
    required this.profilId,
    required this.aPoser,
  });

  /// La personne dont on change le code — l'agent au clavier, pas le compte
  /// qui a authentifié l'appareil.
  final String profilId;

  /// Aucun code sur ce poste (ou invalidé par un reset) : on le POSE, et l'on
  /// ne peut donc pas réclamer l'ancien.
  final bool aPoser;

  @override
  ConsumerState<ChangerCodePinDialog> createState() =>
      _ChangerCodePinDialogState();
}

class _ChangerCodePinDialogState extends ConsumerState<ChangerCodePinDialog> {
  final _actuel = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirme = TextEditingController();

  String? _erreur;
  bool _envoi = false;
  DateTime? _pauseJusqua;
  Timer? _minuteur;

  bool get _enPause =>
      _pauseJusqua != null && _pauseJusqua!.isAfter(DateTime.now());

  int get _secondesRestantes => _pauseJusqua == null
      ? 0
      : _pauseJusqua!.difference(DateTime.now()).inSeconds + 1;

  @override
  void initState() {
    super.initState();
    if (!widget.aPoser) _relirePause();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _actuel.dispose();
    _nouveau.dispose();
    _confirme.dispose();
    super.dispose();
  }

  /// La pause en cours vient de l'écran-verrou autant que d'ici : le compteur
  /// est partagé, on le relit à l'ouverture au lieu de repartir de zéro.
  Future<void> _relirePause() async {
    final until =
        await ref.read(agentPinServiceProvider).lockedUntil(widget.profilId);
    if (!mounted || until == null) return;
    setState(() => _pauseJusqua = until);
    _demarrerMinuteur();
  }

  void _demarrerMinuteur() {
    _minuteur?.cancel();
    _minuteur = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_enPause) {
        _minuteur?.cancel();
        setState(() => _pauseJusqua = null);
      } else {
        setState(() {}); // rafraîchit le compte à rebours
      }
    });
  }

  Future<void> _valider() async {
    if (_envoi || _enPause) return;
    final svc = ref.read(agentPinServiceProvider);
    final nouveau = _nouveau.text;

    if (nouveau.length != kAgentPinLength) {
      setState(() => _erreur = 'Le code compte $kAgentPinLength chiffres.');
      return;
    }
    if (_confirme.text != nouveau) {
      setState(() => _erreur = 'Les deux codes ne correspondent pas.');
      return;
    }

    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      if (!widget.aPoser) {
        if (_actuel.text.length != kAgentPinLength) {
          setState(() => _erreur = 'Saisissez votre code actuel.');
          return;
        }
        if (!await svc.verifyPin(widget.profilId, _actuel.text)) {
          await svc.recordFail(widget.profilId);
          final until = await svc.lockedUntil(widget.profilId);
          if (!mounted) return;
          setState(() {
            _actuel.clear();
            _pauseJusqua = until;
            _erreur = 'Code actuel incorrect.';
          });
          if (until != null) _demarrerMinuteur();
          return;
        }
        // Un « nouveau » code identique à l'ancien donne le sentiment d'avoir
        // agi sans que rien ne change — le cas exact où l'on croit s'être
        // protégé après s'être fait voir en train de composer son code.
        if (nouveau == _actuel.text) {
          setState(() => _erreur = 'Choisissez un code différent de l\'actuel.');
          return;
        }
      }

      await svc.setPin(widget.profilId, nouveau);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poser = widget.aPoser;
    return AlertDialog(
      backgroundColor: kCardBg,
      title: Text(poser ? 'Poser mon code' : 'Changer mon code'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              poser
                  ? 'Ce code vous identifie au clavier sur CE poste, sans '
                      'internet. Il n\'est enregistré que sur cette machine.'
                  : 'Le nouveau code ne vaut que sur CE poste : sur les autres '
                      'ordinateurs de l\'école, l\'ancien continue de servir.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          if (!poser) ...[
            _ChampPin(
              controleur: _actuel,
              etiquette: 'Code actuel',
              autofocus: true,
              actif: !_enPause && !_envoi,
              onChange: () => setState(() => _erreur = null),
            ),
            const SizedBox(height: 12),
          ],
          _ChampPin(
            controleur: _nouveau,
            etiquette: 'Nouveau code',
            autofocus: poser,
            actif: !_enPause && !_envoi,
            onChange: () => setState(() => _erreur = null),
          ),
          const SizedBox(height: 12),
          _ChampPin(
            controleur: _confirme,
            etiquette: 'Confirmer le nouveau code',
            actif: !_enPause && !_envoi,
            onChange: () => setState(() => _erreur = null),
            onSubmit: _valider,
          ),
          if (_enPause) ...[
            const SizedBox(height: 12),
            _Alerte(
              texte: 'Trop d\'essais. Réessayez dans $_secondesRestantes s.',
              couleur: kAccent,
            ),
          ] else if (_erreur != null) ...[
            const SizedBox(height: 12),
            _Alerte(texte: _erreur!, couleur: kRed),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: (_envoi || _enPause) ? null : _valider,
          style: FilledButton.styleFrom(backgroundColor: kNavy),
          child: Text(poser ? 'Poser le code' : 'Changer le code'),
        ),
      ],
    );
  }
}

/// Champ de code : chiffres uniquement, masqué, longueur bornée.
class _ChampPin extends StatelessWidget {
  const _ChampPin({
    required this.controleur,
    required this.etiquette,
    required this.actif,
    required this.onChange,
    this.autofocus = false,
    this.onSubmit,
  });

  final TextEditingController controleur;
  final String etiquette;
  final bool actif;
  final VoidCallback onChange;
  final bool autofocus;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controleur,
        enabled: actif,
        autofocus: autofocus,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: kAgentPinLength,
        onChanged: (_) => onChange(),
        onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(letterSpacing: 6, fontSize: 18),
        decoration: InputDecoration(
          labelText: etiquette,
          counterText: '',
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      );
}

class _Alerte extends StatelessWidget {
  const _Alerte({required this.texte, required this.couleur});
  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: couleur.withValues(alpha: 0.35)),
        ),
        child: Text(texte,
            style: TextStyle(
                fontSize: 12.5, color: couleur, fontWeight: FontWeight.w600)),
      );
}
