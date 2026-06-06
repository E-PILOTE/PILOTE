import 'package:flutter/material.dart';

import 'auth_colors.dart';

// ─── LoginFormCard ─────────────────────────────────────────────────────────────
//
// Card autonome : gère ses propres contrôleurs et états de formulaire.
// L'écran parent lui fournit isLoading, errorMsg et les callbacks d'auth.
//
// Règle 500 lignes : ce fichier est intentionnellement isolé de login_screen.dart.


class LoginFormCard extends StatefulWidget {
  const LoginFormCard({
    super.key,
    required this.isLoading,
    this.errorMsg,
    required this.onLogin,
    required this.onForgotPassword,
  });

  final bool isLoading;
  final String? errorMsg;
  final Future<void> Function(String email, String password) onLogin;
  final VoidCallback onForgotPassword;

  @override
  State<LoginFormCard> createState() => _LoginFormCardState();
}

class _LoginFormCardState extends State<LoginFormCard>
    with SingleTickerProviderStateMixin {

  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure    = true;
  bool _rememberMe = false;

  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.onLogin(_emailCtrl.text.trim(), _passwordCtrl.text);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 60,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: kAuthNavy.withValues(alpha: 0.15),
            blurRadius: 30,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cardHeader(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Adresse email'),
                    const SizedBox(height: 6),
                    _emailField(),
                    const SizedBox(height: 16),

                    _fieldLabel('Mot de passe'),
                    const SizedBox(height: 6),
                    _passwordField(),

                    // Erreur sous le champ mot de passe
                    if (widget.errorMsg != null) ...[
                      const SizedBox(height: 10),
                      _errorBanner(widget.errorMsg!),
                    ],

                    const SizedBox(height: 14),

                    // Se souvenir de moi · Mot de passe oublié ?
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _rememberMeRow(),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: widget.onForgotPassword,
                            child: const Text(
                              'Contacter E-PILOTE',
                              style: TextStyle(
                                fontSize: 12,
                                color: kAuthNavy,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: kAuthNavy,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    _loginBtn(),
                    const SizedBox(height: 20),
                    _footer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Card header ────────────────────────────────────────────────────────────
  // Note : pas de logo ici — il est déjà dans la topbar de LoginScreen.
  Widget _cardHeader() {
    return Column(
      children: [
        // Icône décorative (sans logo SVG)
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: kAuthNavyDark,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kAuthNavy.withValues(alpha: 0.35),
                blurRadius: 14, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: 14),

        // Titre
        const Text('ESPACE DE SESSION',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kAuthNavyDark, fontSize: 20,
              fontWeight: FontWeight.w800, letterSpacing: 2.0,
            )),
        const SizedBox(height: 3),

        // Sous-titre
        const Text('Plateforme Nationale de Gestion Scolaire',
            textAlign: TextAlign.center,
            style: TextStyle(color: kAuthSlate, fontSize: 11)),
        const SizedBox(height: 14),

        // Stripes drapeau Congo
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [kAuthCongoGreen, kAuthCongoYellow, kAuthCongoRed]
              .map((c) => Container(
                    width: 36, height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                        color: c, borderRadius: BorderRadius.circular(2)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),

        // Badge "Connexion sécurisée"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 11, color: Color(0xFF166534)),
              SizedBox(width: 6),
              Text('Connexion sécurisée',
                  style: TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers champs ─────────────────────────────────────────────────────────
  Widget _fieldLabel(String label) => Text(label,
      style: const TextStyle(
          color: Color(0xFF374151),
          fontSize: 13, fontWeight: FontWeight.w600));

  InputDecoration _inputDeco(
          {required String hint,
          required IconData prefixIcon,
          Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
        prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF9CA3AF)),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kAuthNavy, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kAuthDanger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kAuthDanger, width: 2)),
      );

  Widget _emailField() => TextFormField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 14, color: kAuthTextPrimary),
        decoration:
            _inputDeco(hint: 'nom@ecole.cg', prefixIcon: Icons.email_outlined),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Saisissez votre e-mail';
          if (!v.contains('@')) return 'E-mail invalide';
          return null;
        },
      );

  Widget _passwordField() => TextFormField(
        controller: _passwordCtrl,
        obscureText: _obscure,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        style: const TextStyle(fontSize: 14, color: kAuthTextPrimary),
        decoration: _inputDeco(
          hint: '••••••••',
          prefixIcon: Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18, color: const Color(0xFF9CA3AF),
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Saisissez votre mot de passe';
          if (v.length < 6) return 'Minimum 6 caractères';
          return null;
        },
      );

  Widget _errorBanner(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 15, color: kAuthDanger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(color: kAuthDanger, fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _rememberMeRow() => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: _rememberMe ? kAuthNavy : Colors.white,
                  border: Border.all(
                    color: _rememberMe ? kAuthNavy : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _rememberMe
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              const Text('Se souvenir de moi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      );

  // ── Bouton principal avec glow fluorescent animé ──────────────────────────
  Widget _loginBtn() {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, child) {
        final g = _glowCtrl.value; // 0.0 → 1.0 → 0.0 (reverse)
        return Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: widget.isLoading ? null : [
              // Halo principal — bleu navy pulsant
              BoxShadow(
                color: kAuthNavy.withValues(alpha: 0.25 + g * 0.40),
                blurRadius: 6 + g * 20,
                spreadRadius: g * 4,
              ),
              // Lueur verte Congo en périphérie
              BoxShadow(
                color: kAuthCongoGreen.withValues(alpha: g * 0.22),
                blurRadius: g * 28,
                spreadRadius: g * 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: widget.isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: kAuthNavy,
            foregroundColor: Colors.white,
            disabledBackgroundColor: kAuthNavy.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            elevation: 2,
            shadowColor: kAuthNavy.withValues(alpha: 0.4),
          ).copyWith(
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Ouvrir une session',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _footer() => const Column(
        children: [
          Divider(height: 1),
          SizedBox(height: 10),
          Text('Support 24h/24  ·  © 2026 E-PILOTE CONGO',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 11)),
          SizedBox(height: 6),
        ],
      );
}
