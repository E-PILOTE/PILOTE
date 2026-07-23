import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/active_agent_provider.dart';
import 'auth_colors.dart';

const _kAccent = kAuthAccent;
const _kPinLen = 4;

/// Pavé PIN de l'écran-verrou (feuille bleu nuit). PIN à 4 chiffres :
/// auto-validation, clavier physique (poste desktop), secousse à l'erreur,
/// bouton « Afficher », et pause anti-force-brute progressive et persistante.
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
  String _pin = '';
  String? _firstEntry; // mode création : 1ʳᵉ saisie mémorisée
  String? _error;
  bool _busy = false;
  bool _reveal = false;

  DateTime? _lockedUntil; // pause anti-force-brute active
  Timer? _ticker;
  late final AnimationController _shake;
  final FocusNode _focus = FocusNode();

  bool get _confirming => widget.isCreate && _firstEntry != null;
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
    final until = await ref.read(agentPinServiceProvider).lockedUntil(widget.agent.id);
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
    _focus.dispose();
    super.dispose();
  }

  String get _title {
    if (!widget.isCreate) return 'Saisissez votre code à 4 chiffres';
    return _confirming ? 'Confirmez votre code' : 'Choisissez un code à 4 chiffres';
  }

  void _fail(String message) {
    _shake.forward(from: 0);
    setState(() {
      _error = message;
      _pin = '';
    });
  }

  void _onDigit(String d) {
    if (_busy || _locked || _pin.length >= _kPinLen) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == _kPinLen) {
      // Laisse le 4ᵉ point s'afficher avant l'auto-validation.
      Future.delayed(const Duration(milliseconds: 140), _validate);
    }
  }

  void _onBackspace() {
    if (_busy || _locked || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _validate() async {
    if (_pin.length != _kPinLen || _busy) return;
    final svc = ref.read(agentPinServiceProvider);

    if (widget.isCreate) {
      if (!_confirming) {
        setState(() {
          _firstEntry = _pin;
          _pin = '';
        });
        return;
      }
      if (_pin != _firstEntry) {
        setState(() => _firstEntry = null);
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
    _fail(until != null
        ? 'Trop de tentatives.'
        : 'Code incorrect. Réessayez.');
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && ch.length == 1 && '0123456789'.contains(ch)) {
      _onDigit(ch);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      widget.onBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(agent: widget.agent, onBack: _busy ? null : widget.onBack),
          const SizedBox(height: 6),
          Text(_title,
              style: TextStyle(
                  fontSize: 12.5, color: Colors.white.withValues(alpha: 0.65))),
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: _shake,
            builder: (_, child) {
              final t = _shake.value;
              final dx = math.sin(t * math.pi * 4) * 10 * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: _Dots(pin: _pin, max: _kPinLen, reveal: _reveal, error: _error != null),
          ),
          const SizedBox(height: 10),
          if (_locked)
            _CooldownNote(until: _lockedUntil!)
          else if (_error != null)
            Text(_error!,
                style: const TextStyle(color: kAuthDanger, fontSize: 12.5))
          else
            _RevealToggle(
                on: _reveal, onTap: () => setState(() => _reveal = !_reveal)),
          const SizedBox(height: 18),
          // Poste desktop (Windows/Mac) : la saisie se fait au clavier — pas de
          // pavé à l'écran. Indice discret pour la découvrabilité.
          if (!_locked)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.keyboard_rounded,
                    size: 15, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text('Tapez votre code sur le clavier',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            widget.isCreate
                ? '🔒 Ce code protège vos saisies sur ce poste partagé.'
                : 'Code oublié ? La direction peut le réinitialiser.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.agent, required this.onBack});
  final AgentOption agent;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: Colors.white.withValues(alpha: 0.8),
            tooltip: 'Retour',
            onPressed: onBack,
          ),
          Expanded(
            child: Text(agent.fullName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(width: 40),
        ],
      );
}

class _Dots extends StatelessWidget {
  const _Dots(
      {required this.pin,
      required this.max,
      required this.reveal,
      required this.error});
  final String pin;
  final int max;
  final bool reveal;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? kAuthDanger : _kAccent;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < max; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 9),
            width: reveal ? 24 : 15,
            height: reveal ? 30 : 15,
            alignment: Alignment.center,
            // On garde une forme rectangulaire et on n'anime QUE le rayon :
            // à 15×15 un rayon ≥ 7,5 rend un cercle. Animer `shape` entre cercle
            // et rectangle est interdit (BoxDecoration.lerp → cercle + rayon →
            // assertion) — c'était le crash du bouton « Afficher ».
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(reveal ? 6 : 8),
              color: i < pin.length && !reveal ? color : Colors.transparent,
              border: Border.all(
                  color: i < pin.length
                      ? color
                      : Colors.white.withValues(alpha: 0.35),
                  width: 1.6),
            ),
            child: reveal && i < pin.length
                ? Text(pin[i],
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16))
                : null,
          ),
      ],
    );
  }
}

class _RevealToggle extends StatelessWidget {
  const _RevealToggle({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onTap,
        icon: Icon(on ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 15, color: Colors.white.withValues(alpha: 0.6)),
        label: Text(on ? 'Masquer' : 'Afficher',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
      );
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
