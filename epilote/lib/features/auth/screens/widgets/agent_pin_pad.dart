import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin_groupe/providers/admin_users_provider.dart'
    show roleLabel;
import '../../providers/active_agent_provider.dart';
import 'auth_colors.dart';

const _kAccent = kAuthAccent;
const _kPinLen = 4;

/// Saisie du PIN de l'écran-verrou (feuille bleu nuit). Carte d'identité de
/// l'agent (photo + nom + rôle) puis une **zone de saisie unique** (vrai
/// `TextField`, hauteur normale, œil de visibilité à droite) : capte le clavier
/// physique nativement, auto-validation à 4 chiffres, secousse à l'erreur,
/// pause anti-force-brute progressive.
class AgentPinPad extends ConsumerStatefulWidget {
  const AgentPinPad({
    super.key,
    required this.agent,
    required this.isCreate,
    required this.onBack,
    required this.onSuccess,
  });
  final AgentOption agent;
  final bool isCreate;
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  @override
  ConsumerState<AgentPinPad> createState() => _AgentPinPadState();
}

class _AgentPinPadState extends ConsumerState<AgentPinPad>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _firstEntry = ''; // mode création : 1ʳᵉ saisie mémorisée
  bool _hasFirst = false;
  String? _error;
  bool _busy = false;
  bool _reveal = false;

  DateTime? _lockedUntil; // pause anti-force-brute active
  Timer? _ticker;
  late final AnimationController _shake;

  String get _pin => _ctrl.text;
  bool get _confirming => widget.isCreate && _hasFirst;
  bool get _locked =>
      _lockedUntil != null && _lockedUntil!.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    if (!widget.isCreate) _loadLock();
  }

  Future<void> _loadLock() async {
    final until =
        await ref.read(agentPinServiceProvider).lockedUntil(widget.agent.id);
    if (!mounted || until == null) return;
    setState(() => _lockedUntil = until);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_locked) {
        _ticker?.cancel();
        setState(() => _lockedUntil = null);
      } else {
        setState(() {}); // rafraîchit le compte à rebours
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _title {
    if (!widget.isCreate) return 'Saisissez votre code à 4 chiffres';
    return _confirming
        ? 'Confirmez votre code'
        : 'Choisissez un code à 4 chiffres';
  }

  void _clearField() {
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _fail(String message) {
    _shake.forward(from: 0);
    _clearField();
    setState(() => _error = message);
  }

  void _onChanged(String v) {
    if (_error != null) setState(() => _error = null);
    if (v.length == _kPinLen) {
      // Laisse le 4ᵉ caractère s'afficher avant l'auto-validation.
      Future.delayed(const Duration(milliseconds: 130), () {
        if (mounted && _ctrl.text.length == _kPinLen) _validate();
      });
    }
  }

  Future<void> _validate() async {
    if (_pin.length != _kPinLen || _busy) return;
    final svc = ref.read(agentPinServiceProvider);

    if (widget.isCreate) {
      if (!_confirming) {
        setState(() {
          _firstEntry = _pin;
          _hasFirst = true;
        });
        _clearField();
        return;
      }
      if (_pin != _firstEntry) {
        setState(() => _hasFirst = false);
        _fail('Les deux codes ne correspondent pas.');
        return;
      }
      setState(() => _busy = true);
      await svc.setPin(widget.agent.id, _pin);
      if (mounted) widget.onSuccess();
      return;
    }

    setState(() => _busy = true);
    final ok = await svc.verifyPin(widget.agent.id, _pin);
    if (!mounted) return;
    if (ok) {
      await svc.clearFails(widget.agent.id);
      widget.onSuccess();
      return;
    }
    await svc.recordFail(widget.agent.id);
    final until = await svc.lockedUntil(widget.agent.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lockedUntil = until;
    });
    if (until != null) _startTicker();
    _fail(until != null ? 'Trop de tentatives.' : 'Code incorrect. Réessayez.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Retour à la grille des profils.
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: Colors.white.withValues(alpha: 0.8),
            tooltip: 'Retour',
            onPressed: _busy ? null : widget.onBack,
          ),
        ),
        // Carte d'identité : photo de profil, nom, rôle.
        _Identity(agent: widget.agent),
        const SizedBox(height: 16),
        Text(_title,
            style: TextStyle(
                fontSize: 12.5, color: Colors.white.withValues(alpha: 0.65))),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _shake,
          builder: (_, child) {
            final t = _shake.value;
            final dx = math.sin(t * math.pi * 4) * 10 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: _PinField(
            controller: _ctrl,
            focusNode: _focus,
            obscure: !_reveal,
            enabled: !_locked && !_busy,
            error: _error != null,
            onChanged: _onChanged,
            onSubmitted: (_) => _validate(),
            onToggleReveal: () => setState(() => _reveal = !_reveal),
          ),
        ),
        const SizedBox(height: 10),
        // Ligne d'état (hauteur réservée pour un rythme vertical stable).
        SizedBox(
          height: 18,
          child: _locked
              ? _CooldownNote(until: _lockedUntil!)
              : (_error != null
                  ? Text(_error!,
                      style: const TextStyle(
                          color: kAuthDanger, fontSize: 12.5))
                  : null),
        ),
        const SizedBox(height: 12),
        Text(
          widget.isCreate
              ? '🔒 Ce code protège vos saisies sur ce poste partagé.'
              : 'Code oublié ? La direction peut le réinitialiser.',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

/// Carte d'identité de l'agent : photo de profil (ou initiales), nom, rôle.
class _Identity extends StatelessWidget {
  const _Identity({required this.agent});
  final AgentOption agent;

  @override
  Widget build(BuildContext context) {
    final role = roleLabel(agent.role);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(agent: agent, size: 60),
        const SizedBox(height: 10),
        Text(agent.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        if (role.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.agent, required this.size});
  final AgentOption agent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final has = agent.avatarUrl != null && agent.avatarUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D74B8), Color(0xFF23568C)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
      ),
      child: has
          ? CachedNetworkImage(
              imageUrl: agent.avatarUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() => Center(
        child: Text(agent.initials,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36)),
      );
}

/// Zone de saisie du PIN : champ unique de hauteur normale, chiffres masqués
/// par des ●, avec l'œil de visibilité à droite (pattern mot de passe).
class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.focusNode,
    required this.obscure,
    required this.enabled,
    required this.error,
    required this.onChanged,
    required this.onSubmitted,
    required this.onToggleReveal,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscure;
  final bool enabled;
  final bool error;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onToggleReveal;

  @override
  Widget build(BuildContext context) {
    final accent = error ? kAuthDanger : _kAccent;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return SizedBox(
      width: 240,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        enabled: enabled,
        obscureText: obscure,
        obscuringCharacter: '●',
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: _kPinLen,
        cursorColor: _kAccent,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(_kPinLen),
        ],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 6,
        ),
        decoration: InputDecoration(
          counterText: '',
          isDense: true,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          suffixIcon: IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
                obscure
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 19,
                color: Colors.white.withValues(alpha: 0.6)),
            tooltip: obscure ? 'Afficher' : 'Masquer',
            onPressed: onToggleReveal,
          ),
          enabledBorder: border(Colors.white.withValues(alpha: 0.18), 1.2),
          focusedBorder: border(accent, 1.8),
          disabledBorder: border(Colors.white.withValues(alpha: 0.10), 1.2),
        ),
      ),
    );
  }
}

class _CooldownNote extends StatelessWidget {
  const _CooldownNote({required this.until});
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final secs = until.difference(DateTime.now()).inSeconds.clamp(0, 3599);
    final m = (secs ~/ 60).toString();
    final s = (secs % 60).toString().padLeft(2, '0');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_clock_rounded, size: 15, color: kAuthDanger),
        const SizedBox(width: 6),
        Text('Réessayez dans $m:$s',
            style: const TextStyle(
                color: kAuthDanger, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
