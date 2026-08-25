import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/session_morte.dart';
import '../providers/auth_provider.dart';
import 'widgets/auth_colors.dart';
import 'widgets/contact_support_drawer.dart';
import 'widgets/login_anim_widgets.dart';
import 'widgets/login_form_card.dart';
import 'widgets/login_hero_panel.dart';

// ─── Breakpoints ──────────────────────────────────────────────────────────────
const _kDesktopBreak = 960.0; // Desktop : héros gauche + card droite

// ─── LoginScreen ──────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {

  bool    _isLoading = false;
  String? _errorMsg;

  late final AnimationController _anim;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<void> _handleLogin(String email, String password) async {
    // L'agent reprend la main : le message d'expiration a fait son office.
    ref.read(sessionMorteMessageProvider.notifier).state = null;
    setState(() { _errorMsg = null; _isLoading = true; });
    try {
      await ref.read(authNotifierProvider.notifier).signIn(email, password);
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMsg = _translateErr(e.message));
    } catch (_) {
      if (mounted) setState(() => _errorMsg = 'Erreur de connexion. Réessayez.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _translateErr(String m) {
    if (m.contains('Invalid login'))       return 'E-mail ou mot de passe incorrect';
    if (m.contains('Email not confirmed')) return 'Confirmez votre adresse e-mail';
    if (m.contains('Too many'))            return 'Trop de tentatives. Réessayez.';
    return m;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Ecoute les erreurs Riverpod (ex : session expirée côté provider)
    ref.listen<AsyncValue>(authNotifierProvider, (_, next) {
      if (next.hasError && mounted) {
        final e = next.error;
        setState(() => _errorMsg = e is AuthException
            ? _translateErr(e.message)
            : 'Erreur de connexion');
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          Column(
            children: [
              _topBar(),
              Expanded(child: _body()),
              _bottomBar(),
            ],
          ),
        ],
      ),
    );
  }

  // ── Corps responsive ────────────────────────────────────────────────────────
  Widget _body() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _kDesktopBreak;

        if (isDesktop) {
          // ── Desktop : héros gauche + card droite ──
          return Row(
            children: [
              // Panneau héros (55 %)
              const Expanded(
                flex: 55,
                child: LoginHeroPanel(),
              ),
              // Card de login (45 %) — centrée verticalement
              Expanded(
                flex: 45,
                child: Center(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: _formCard(),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // ── Tablette / Mobile : card seule, centrée ──
        return Center(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: _formCard(),
            ),
          ),
        );
      },
    );
  }

  Widget _formCard() => LoginFormCard(
        isLoading: _isLoading,
        // À défaut d'erreur de saisie, on explique pourquoi l'agent se
        // retrouve ici : une session tombée toute seule n'est pas une faute
        // de sa part, et le dire évite l'appel au support.
        errorMsg:  _errorMsg ?? ref.watch(sessionMorteMessageProvider),
        onLogin:   _handleLogin,
        onForgotPassword: () => showContactSupportDrawer(context),
      );

  // ── Fond ────────────────────────────────────────────────────────────────────
  Widget _buildBackground() {
    return Stack(children: [
      // Gradient diagonal
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kAuthNavyDeep, kAuthNavyDark, kAuthNavy],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      ),
      // Image salle de classe — plus visible à droite (0.42) qu'à gauche (0.22)
      // pour que la photo respire côté card et reste discrète côté héros.
      Positioned.fill(
        child: Image.asset(
          'assets/images/login_bg.webp',
          fit: BoxFit.cover,
          opacity: const AlwaysStoppedAnimation(0.42),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
      // Ligne tricolore gauche
      Positioned(
        left: 0, top: 0, bottom: 0,
        child: Container(
          width: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                kAuthCongoGreen.withValues(alpha: 0.7),
                kAuthCongoYellow.withValues(alpha: 0.6),
                kAuthCongoRed.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      // Grille de points décorative
      Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
    ]);
  }

  // ── Top bar ─────────────────────────────────────────────────────────────────
  Widget _topBar() {
    return Container(
      height: 66,
      color: kAuthNavyDeep.withValues(alpha: 0.92),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          SvgPicture.asset('assets/icons/logo.svg', width: 46, height: 46),
          const SizedBox(width: 14),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('E-PILOTE CONGO',
                  style: TextStyle(
                    color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w800, letterSpacing: 1.2,
                  )),
              Text('Plateforme Nationale de Gestion Scolaire',
                  style: TextStyle(color: Color(0xFF6B8BA4), fontSize: 11)),
            ],
          ),
          const Spacer(),
          // ── République du Congo + devise (remplace le drapeau) ──────────────
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('RÉPUBLIQUE DU CONGO',
                  style: TextStyle(
                    color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700, letterSpacing: 0.6,
                  )),
              Text('Unité · Travail · Progrès',
                  style: TextStyle(color: Color(0xFF6B8BA4), fontSize: 9.5)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom bar : ligne tricolore pleine largeur + crédits + étoiles ─────────
  Widget _bottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ligne tricolore animée — s'étend sur toute la largeur (héros + card)
        const AnimatedTricolorLine(height: 3),
        Container(
          height: 32,
          color: kAuthNavyDeep.withValues(alpha: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              const Text('République du Congo · MEPSA · METP',
                  style: TextStyle(color: Color(0xFF3D5A73), fontSize: 10)),
              const Spacer(),
              // ── 5 étoiles ──────────────────────────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) => Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(Icons.star_rounded, size: 10,
                      color: kAuthCongoYellow.withValues(alpha: 0.65)),
                )),
              ),
              const SizedBox(width: 14),
              const Text('v3.0',
                  style: TextStyle(color: Color(0xFF3D5A73), fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Grille de points décorative ───────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;
    const spacing = 36.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter _) => false;
}
