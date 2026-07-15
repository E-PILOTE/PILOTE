import 'dart:async';

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
            // Portail de session : cercle unique respirant = horloge + action.
            _SessionPortal(onTap: onOpen),
            if (serviceMessages.isNotEmpty) ...[
              const SizedBox(height: 28),
              _ServiceBanner(messages: serviceMessages),
            ],
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
        children: [
          _chip(const Text('🇨🇬', style: TextStyle(fontSize: 14)),
              'MEPSA · METP'),
          const Spacer(),
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

/// Portail de session : le point focal de la vitrine. Un cercle « verre »
/// unique qui EST le bouton — il porte l'horloge vivante (icône + heure) et
/// l'action « Ouvrir une session ». Un halo respire lentement derrière lui
/// (invite au clic sans distraire). Respecte le reduced-motion et l'injection
/// d'horloge de test (`debugVitrineClock`) → captures déterministes.
class _SessionPortal extends StatefulWidget {
  const _SessionPortal({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_SessionPortal> createState() => _SessionPortalState();
}

class _SessionPortalState extends State<_SessionPortal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  Timer? _timer;
  late DateTime _now = vitrineNow();
  bool _hover = false;

  static const _days = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
  ];
  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
    'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];

  bool get _reduce => WidgetsBinding
      .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3600));
    // Respiration figée en test / si reduced-motion : pas de boucle.
    if (!_reduce && !vitrineClockFrozen) _breath.repeat(reverse: true);
    // Horloge figée (test) → pas de timer, rendu stable.
    if (!vitrineClockFrozen) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = vitrineNow());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  String get _time =>
      '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
  String get _date =>
      '${_days[_now.weekday - 1]} ${_now.day} ${_months[_now.month - 1]} ${_now.year}';

  @override
  Widget build(BuildContext context) {
    const dim = 250.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: dim + 70,
          height: dim + 70,
          child: AnimatedBuilder(
            animation: _breath,
            builder: (context, child) {
              final t =
                  _reduce ? 0.0 : Curves.easeInOut.transform(_breath.value);
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Halo respirant (sonar doux) — derrière le médaillon.
                  Transform.scale(
                    scale: 1.0 + 0.16 * t,
                    child: Opacity(
                      opacity: 0.5 * (1 - t),
                      child: Container(
                        width: dim,
                        height: dim,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _kAccent.withValues(alpha: 0.0),
                              _kAccent.withValues(alpha: 0.55),
                            ],
                            stops: const [0.68, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Médaillon : respiration d'échelle très douce.
                  Transform.scale(scale: 1.0 + 0.02 * t, child: child),
                ],
              );
            },
            child: _medallion(dim),
          ),
        ),
        const SizedBox(height: 18),
        // Légende : date + « poste sécurisé » (sous le cercle).
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded,
                size: 12, color: Colors.white.withValues(alpha: 0.55)),
            const SizedBox(width: 6),
            Text('$_date · poste sécurisé',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12.5)),
          ],
        ),
      ],
    );
  }

  Widget _medallion(double dim) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Semantics(
          button: true,
          label: 'Ouvrir une session — il est $_time',
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: dim,
              height: dim,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: _hover ? 0.20 : 0.13),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                    color:
                        Colors.white.withValues(alpha: _hover ? 0.5 : 0.32),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: _kAccent.withValues(alpha: _hover ? 0.5 : 0.3),
                      blurRadius: 42,
                      spreadRadius: -6),
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 10)),
                ],
              ),
              // Padding horizontal + FittedBox : le texte garde sa taille
              // naturelle dans l'app réelle, mais se réduit sans jamais déborder
              // du cercle (utile aussi pour la police « en blocs » des goldens).
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule_rounded,
                        color: Colors.white.withValues(alpha: 0.8), size: 24),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_time,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(height: 14),
                    Container(
                        width: 54,
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(height: 14),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_open_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Ouvrir une session',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
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
