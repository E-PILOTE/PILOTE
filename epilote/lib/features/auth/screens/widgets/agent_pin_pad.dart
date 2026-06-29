import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/admin_ui.dart'
    show kNavy, kRed, kTextMuted, kTextPrimary, kBorder;
import '../../providers/active_agent_provider.dart';

/// Pavé PIN de l'écran-verrou. Création (saisie + confirmation) ou vérification.
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

class _AgentPinPadState extends ConsumerState<AgentPinPad> {
  static const _maxLen = 6;
  String _pin = '';
  String? _firstEntry; // mode création : 1ʳᵉ saisie mémorisée
  String? _error;
  bool _busy = false;

  bool get _confirming => widget.isCreate && _firstEntry != null;

  String get _title {
    if (!widget.isCreate) return 'Saisissez votre code PIN';
    return _confirming
        ? 'Confirmez votre code'
        : 'Choisissez un code (4 à 6 chiffres)';
  }

  Future<void> _onDigit(String d) async {
    if (_busy || _pin.length >= _maxLen) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _onBackspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _validate() async {
    if (_pin.length < 4) {
      setState(() => _error = 'Le code doit comporter au moins 4 chiffres.');
      return;
    }
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
        setState(() {
          _error = 'Les deux codes ne correspondent pas.';
          _firstEntry = null;
          _pin = '';
        });
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
      widget.onSuccess();
    } else {
      setState(() {
        _busy = false;
        _error = 'Code PIN incorrect.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              color: kTextMuted,
              onPressed: _busy ? null : widget.onBack,
            ),
            Expanded(
              child: Text(widget.agent.fullName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 6),
        Text(_title, style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
        const SizedBox(height: 18),
        _Dots(filled: _pin.length, max: _maxLen),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: kRed, fontSize: 12.5)),
        ],
        const SizedBox(height: 18),
        _Keypad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          onValidate: _validate,
          canValidate: !_busy && _pin.length >= 4,
        ),
        const SizedBox(height: 10),
        Text(
          widget.isCreate
              ? 'Ce code protège vos saisies sur ce poste partagé.'
              : 'Code oublié ? La direction peut le réinitialiser.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: kTextMuted),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.max});
  final int filled;
  final int max;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < max; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? kNavy : Colors.transparent,
                border: Border.all(
                    color: i < filled ? kNavy : kBorder, width: 1.5),
              ),
            ),
        ],
      );
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onValidate,
    required this.canValidate,
  });
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onValidate;
  final bool canValidate;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => SizedBox(
          width: 72,
          height: 56,
          child: Material(
            color: const Color(0xFFF6F8FB),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Center(
                child: child ??
                    Text(label,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary)),
              ),
            ),
          ),
        );

    Widget row(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final c in children)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: c),
            ],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([for (final d in ['1', '2', '3']) key(d, onTap: () => onDigit(d))]),
        row([for (final d in ['4', '5', '6']) key(d, onTap: () => onDigit(d))]),
        row([for (final d in ['7', '8', '9']) key(d, onTap: () => onDigit(d))]),
        row([
          key('',
              onTap: onBackspace,
              child: const Icon(Icons.backspace_outlined,
                  size: 20, color: kTextMuted)),
          key('0', onTap: () => onDigit('0')),
          SizedBox(
            width: 72,
            height: 56,
            child: Material(
              color: canValidate ? kNavy : kBorder,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: canValidate ? onValidate : null,
                child: const Center(
                    child: Icon(Icons.check_rounded,
                        size: 22, color: Colors.white)),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}
