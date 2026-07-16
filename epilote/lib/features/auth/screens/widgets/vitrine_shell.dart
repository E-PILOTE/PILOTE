import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'auth_colors.dart';
import 'vitrine_clock.dart';

const _kAccent = kAuthAccent;

/// Vitrine de sécurité au repos (plein écran, JAMAIS de scroll). Co-branding
/// institutionnel, horloge sobre, message de service (données Phase 3), bouton
/// unique « Ouvrir une session », encart partenaire (opt-in, Phase 3), pied
/// E-PILOTE. C'est la surface éditoriale du parc national.
class VitrineShell extends StatelessWidget {
  const VitrineShell({
    super.key,
    required this.schoolName,
    required this.schoolLogoUrl,
    required this.onOpen,
    this.serviceMessages = const [],
    this.showPartner = false,
    this.partners = const [],
  });

  final String schoolName;
  final String? schoolLogoUrl;
  final VoidCallback onOpen;
  final List<String> serviceMessages;
  final bool showPartner;

  /// (nom, logoUrl?) des partenaires à afficher quand [showPartner] est vrai.
  final List<({String name, String? logoUrl})> partners;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(
          children: [
            _Crest(schoolName: schoolName, logoUrl: schoolLogoUrl),
            const Spacer(),
            const _SecureBadge(),
            const SizedBox(height: 14),
            const VitrineClock(),
            const SizedBox(height: 26),
            if (serviceMessages.isNotEmpty) ...[
              _ServiceBanner(messages: serviceMessages),
              const SizedBox(height: 22),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: _OpenButton(onTap: onOpen),
            ),
            const Spacer(),
            if (showPartner && partners.isNotEmpty) ...[
              _PartnerStrip(partners: partners),
              const SizedBox(height: 12),
            ],
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Crest extends StatelessWidget {
  const _Crest({required this.schoolName, required this.logoUrl});
  final String schoolName;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) => Row(
        // spaceBetween : drapeau collé à GAUCHE, école collée à DROITE (symétrie
        // exacte). L'ancien Spacer + Flexible laissait un vide à droite de l'école.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: _chip(const Text('🇨🇬', style: TextStyle(fontSize: 14)),
                'MEPSA · METP'),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: _chip(
              _SchoolLogo(url: logoUrl),
              schoolName,
              trailing: true,
            ),
          ),
        ],
      );

  Widget _chip(Widget leading, String label, {bool trailing = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!trailing) ...[leading, const SizedBox(width: 7)],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFCDD9EA),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
          if (trailing) ...[const SizedBox(width: 7), leading],
        ],
      );
}

class _SchoolLogo extends StatelessWidget {
  const _SchoolLogo({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final has = url != null && url!.isNotEmpty;
    return Container(
      width: 26,
      height: 26,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: has
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const _LogoFallback(),
            )
          : const _LogoFallback(),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();
  @override
  Widget build(BuildContext context) => const Center(
      child: Icon(Icons.school_rounded, color: Colors.white, size: 15));
}

/// Badge de sécurité : un cercle « verre » avec un ANNEAU LUMINEUX qui tourne
/// en boucle continue autour (dégradé bleu accent → vert national du Congo).
/// Sobriété institutionnelle : rotation lente, un seul arc net. Respecte le
/// reduced-motion et l'horloge de test figée (anneau immobile → golden stable).
class _SecureBadge extends StatefulWidget {
  const _SecureBadge();
  @override
  State<_SecureBadge> createState() => _SecureBadgeState();
}

class _SecureBadgeState extends State<_SecureBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
        vsync: this, duration: const Duration(seconds: 6));
    // Boucle continue en production (rotation ambiante, sobre) ; figée seulement
    // sous horloge de test pour des captures déterministes.
    if (!vitrineClockFrozen) _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dim = 74.0;
    return SizedBox(
      width: dim,
      height: dim,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anneau rotatif — la « boucle circulaire ».
          AnimatedBuilder(
            animation: _spin,
            builder: (context, _) => CustomPaint(
              size: const Size(dim, dim),
              painter: _RingPainter(_spin.value * 2 * math.pi),
            ),
          ),
          // Cercle central en verre + bouclier.
          Container(
            width: dim - 16,
            height: dim - 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: const Icon(Icons.shield_moon_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

/// Anneau fin balayé par un arc lumineux (bleu → vert), tourné de [angle].
class _RingPainter extends CustomPainter {
  const _RingPainter(this.angle);
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2 - 1.5;
    // Piste sombre discrète (l'anneau « éteint »).
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.10),
    );
    // Arc lumineux rotatif (sweep gradient transparent → accent → vert → transparent).
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        transform: GradientRotation(angle),
        colors: const [
          Colors.transparent,
          _kAccent,
          kAuthCongoGreen,
          Colors.transparent,
        ],
        stops: const [0.0, 0.28, 0.42, 0.6],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5);
    canvas.drawCircle(center, radius, glow);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.angle != angle;
}

class _ServiceBanner extends StatefulWidget {
  const _ServiceBanner({required this.messages});
  final List<String> messages;
  @override
  State<_ServiceBanner> createState() => _ServiceBannerState();
}

class _ServiceBannerState extends State<_ServiceBanner> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  @override
  void didUpdateWidget(_ServiceBanner old) {
    super.didUpdateWidget(old);
    if (old.messages.length != widget.messages.length) _maybeStart();
  }

  void _maybeStart() {
    _timer?.cancel();
    // Carrousel lent uniquement s'il y a plusieurs messages ET que l'appareil
    // n'a pas demandé de réduire les animations (accessibilité).
    final reduce =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (widget.messages.length > 1 && !reduce) {
      _timer = Timer.periodic(const Duration(seconds: 7), (_) {
        if (mounted) setState(() => _i++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msgs = widget.messages.take(3).toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(kAuthRadius),
              border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.campaign_rounded, size: 16, color: _kAccent),
                const SizedBox(width: 8),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(msgs[_i % msgs.length],
                        key: ValueKey(_i),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFDBE7FF), fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ),
          if (msgs.length > 1) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var k = 0; k < msgs.length; k++)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() => _i = k),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_i % msgs.length) == k
                              ? _kAccent
                              : Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Bouton unique « Ouvrir une session » — même forme qu'avant, augmenté d'un
/// HALO FLUORESCENT qui respire autour (bleu accent + vert national). Le glow
/// pulse doucement pour inviter au clic sans agiter l'écran. Respecte le
/// reduced-motion et l'horloge de test figée (glow au repos → golden stable).
class _OpenButton extends StatefulWidget {
  const _OpenButton({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_OpenButton> createState() => _OpenButtonState();
}

class _OpenButtonState extends State<_OpenButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1900));
    // Lueur pulsée en boucle continue en production ; figée sous horloge de test.
    if (!vitrineClockFrozen) _glow.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _glow,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_glow.value); // 0 → 1 → 0
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kAuthRadius),
              // Double halo fluorescent (bleu + vert), diffusé et pulsé.
              boxShadow: [
                BoxShadow(
                    color: _kAccent.withValues(alpha: 0.30 + 0.40 * t),
                    blurRadius: 16 + 22 * t,
                    spreadRadius: 1 + 2 * t),
                BoxShadow(
                    color: kAuthCongoGreen.withValues(alpha: 0.10 + 0.22 * t),
                    blurRadius: 22 + 20 * t,
                    spreadRadius: -3),
              ],
            ),
            child: child,
          );
        },
        child: SizedBox(
          width: double.infinity,
          child: Material(
            borderRadius: BorderRadius.circular(kAuthRadius),
            elevation: 8,
            shadowColor: _kAccent.withValues(alpha: 0.5),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kAuthRadius),
                gradient: const LinearGradient(colors: [kAuthNavy, _kAccent]),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(kAuthRadius),
                onTap: widget.onTap,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('Ouvrir une session',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _PartnerStrip extends StatelessWidget {
  const _PartnerStrip({required this.partners});
  final List<({String name, String? logoUrl})> partners;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('EN PARTENARIAT AVEC · PARTENAIRE',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 8,
                  letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 6,
            children: [for (final p in partners) _PartnerLogo(partner: p)],
          ),
        ],
      );
}

class _PartnerLogo extends StatelessWidget {
  const _PartnerLogo({required this.partner});
  final ({String name, String? logoUrl}) partner;

  @override
  Widget build(BuildContext context) {
    final has = partner.logoUrl != null && partner.logoUrl!.isNotEmpty;
    // Repli sur le NOM en texte tant que le logo n'est pas en cache (offline).
    final fallback = Text(partner.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w700));
    if (!has) return fallback;
    return CachedNetworkImage(
      imageUrl: partner.logoUrl!,
      height: 22,
      fit: BoxFit.contain,
      errorWidget: (_, _, _) => fallback,
      placeholder: (_, _) => fallback,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => Text(
        'Propulsé par E-PILOTE · République du Congo',
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w500),
      );
}
