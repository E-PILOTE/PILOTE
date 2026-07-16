import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_colors.dart';
import 'vitrine_clock.dart';

const _kAccent = kAuthAccent;

/// Vitrine de sécurité au repos (plein écran, JAMAIS de scroll). Co-branding
/// institutionnel, horloge sobre, message de service (données Phase 3), bouton
/// unique « Ouvrir une session », encart partenaire (opt-in, Phase 3), pied
/// E-PILOTE. C'est la surface éditoriale du parc national.
class VitrineShell extends StatefulWidget {
  const VitrineShell({
    super.key,
    required this.schoolName,
    required this.schoolLogoUrl,
    required this.onOpen,
    this.groupName,
    this.serviceMessages = const [],
    this.showPartner = false,
    this.partners = const [],
  });

  final String schoolName;
  final String? schoolLogoUrl;

  /// Nom du groupe scolaire (réseau) — co-branding en haut à gauche, à côté du
  /// drapeau. Repli sur « MEPSA · METP » si absent (offline non encore synchro).
  final String? groupName;
  final VoidCallback onOpen;
  final List<String> serviceMessages;
  final bool showPartner;

  /// (nom, logoUrl?) des partenaires à afficher quand [showPartner] est vrai.
  final List<({String name, String? logoUrl})> partners;

  @override
  State<VitrineShell> createState() => _VitrineShellState();
}

class _VitrineShellState extends State<VitrineShell> {
  /// Délai d'inactivité avant « repos profond » : les animations se figent pour
  /// ne pas solliciter le GPU d'un poste allumé toute la journée. Tout geste
  /// (souris/clavier) réveille la vitrine.
  static const _restAfter = Duration(minutes: 1);
  Timer? _idle;
  bool _awake = true;

  bool get _reduce => WidgetsBinding
      .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  /// Les composants animent seulement si la vitrine est éveillée ET que
  /// l'utilisateur n'a pas demandé de réduire les animations (accessibilité).
  bool get _animate => _awake && !_reduce;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _scheduleRest();
  }

  @override
  void dispose() {
    _idle?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _scheduleRest() {
    _idle?.cancel();
    _idle = Timer(_restAfter, () {
      if (mounted && _awake) setState(() => _awake = false);
    });
  }

  /// Réveille (relance les animations) et repousse le repos.
  void _wake() {
    if (!_awake && mounted) setState(() => _awake = true);
    _scheduleRest();
  }

  bool _onKey(KeyEvent _) {
    _wake();
    return false; // ne consomme pas l'évènement
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (_) => _wake(),
      onPointerDown: (_) => _wake(),
      onPointerMove: (_) => _wake(),
      onPointerSignal: (_) => _wake(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            children: [
              _Crest(
                schoolName: widget.schoolName,
                logoUrl: widget.schoolLogoUrl,
                groupName: widget.groupName,
                animate: _animate,
              ),
              const Spacer(),
              _SecureBadge(animate: _animate),
              const SizedBox(height: 14),
              const VitrineClock(),
              const SizedBox(height: 26),
              if (widget.serviceMessages.isNotEmpty) ...[
                _ServiceBanner(messages: widget.serviceMessages),
                const SizedBox(height: 22),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: _OpenButton(onTap: widget.onOpen, animate: _animate),
              ),
              const Spacer(),
              if (widget.showPartner && widget.partners.isNotEmpty) ...[
                _PartnerStrip(partners: widget.partners),
                const SizedBox(height: 12),
              ],
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

const _kCrestText = Color(0xFFCDD9EA);

class _Crest extends StatelessWidget {
  const _Crest({
    required this.schoolName,
    required this.logoUrl,
    required this.groupName,
    required this.animate,
  });
  final String schoolName;
  final String? logoUrl;
  final String? groupName;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    // GAUCHE : drapeau + nom du GROUPE scolaire (réseau). Repli institutionnel
    // « MEPSA · METP » tant que la ligne du groupe n'est pas encore synchronisée.
    final group = (groupName != null && groupName!.trim().isNotEmpty)
        ? groupName!.trim()
        : 'MEPSA · METP';
    return Row(
      // spaceBetween : groupe collé à GAUCHE, école collée à DROITE (symétrie).
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇨🇬', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _kCrestText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // DROITE : nom de l'ÉCOLE animé (sheen discret) + logo établissement.
        Flexible(
          child: _SchoolChip(
              name: schoolName, logoUrl: logoUrl, animate: animate),
        ),
      ],
    );
  }
}

/// Nom de l'école (droite du crest) parcouru par un léger reflet lumineux
/// (« sheen ») qui balaie le texte toutes les ~5 s — pattern premium sobre qui
/// signale l'identité vivante de l'établissement. Gelé au repos profond, sous
/// reduced-motion et en test (captures déterministes).
class _SchoolChip extends StatefulWidget {
  const _SchoolChip(
      {required this.name, required this.logoUrl, required this.animate});
  final String name;
  final String? logoUrl;
  final bool animate;
  @override
  State<_SchoolChip> createState() => _SchoolChipState();
}

class _SchoolChipState extends State<_SchoolChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen;

  bool get _live => widget.animate && !vitrineClockFrozen;

  @override
  void initState() {
    super.initState();
    _sheen = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3400));
    _sync();
  }

  void _sync() {
    if (_live) {
      if (!_sheen.isAnimating) _sheen.repeat();
    } else {
      _sheen.stop();
    }
  }

  @override
  void didUpdateWidget(covariant _SchoolChip old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) _sync();
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(widget.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: _kCrestText, fontSize: 12.5, fontWeight: FontWeight.w700));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _live
              ? AnimatedBuilder(
                  animation: _sheen,
                  builder: (context, child) => ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) {
                      // Centre de la bande lumineuse, de -0.3 à 1.3 (entre/sort).
                      final c = -0.3 + 1.6 * _sheen.value;
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: const [_kCrestText, Colors.white, _kCrestText],
                        stops: [
                          (c - 0.22).clamp(0.0, 1.0),
                          c.clamp(0.0, 1.0),
                          (c + 0.22).clamp(0.0, 1.0),
                        ],
                      ).createShader(bounds);
                    },
                    child: child,
                  ),
                  child: text,
                )
              : text,
        ),
        const SizedBox(width: 7),
        _SchoolLogo(url: widget.logoUrl),
      ],
    );
  }
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
  const _SecureBadge({required this.animate});
  final bool animate;
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
    _sync();
  }

  /// Boucle tant que la vitrine est éveillée (et hors test figé) ; se fige au
  /// repos profond pour épargner le GPU. Reprend là où elle s'était arrêtée.
  void _sync() {
    if (widget.animate && !vitrineClockFrozen) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void didUpdateWidget(covariant _SecureBadge old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) _sync();
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
  const _OpenButton({required this.onTap, required this.animate});
  final VoidCallback onTap;
  final bool animate;
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
    _sync();
  }

  /// Pulse tant que la vitrine est éveillée (hors test) ; au repos, se fige sur
  /// la lueur minimale (t=0) pour ne pas solliciter le GPU inutilement.
  void _sync() {
    if (widget.animate && !vitrineClockFrozen) {
      if (!_glow.isAnimating) _glow.repeat(reverse: true);
    } else {
      _glow.stop();
      _glow.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant _OpenButton old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) _sync();
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
        // Curseur MAIN sur toute l'emprise du bouton (règle : tout élément
        // cliquable affiche le curseur main pour signaler l'interaction).
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
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
                  mouseCursor: SystemMouseCursors.click,
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
