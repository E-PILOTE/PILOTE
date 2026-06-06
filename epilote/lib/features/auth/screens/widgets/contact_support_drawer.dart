import 'package:flutter/material.dart';

import 'auth_colors.dart';

// ─── Tokens ───────────────────────────────────────────────────────────────────
const _kPanelWidth  = 380.0;
const _kPanelRadius = 20.0;
const _kNavy        = kAuthNavy;
const _kNavyDeep    = kAuthNavyDeep;
const _kGreen       = kAuthCongoGreen;
const _kSlate       = kAuthSlate;

// ─── Point d'entrée public ───────────────────────────────────────────────────
void showContactSupportDrawer(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim, _) => const _ContactPanel(),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

// ─── Panneau principal ────────────────────────────────────────────────────────
class _ContactPanel extends StatefulWidget {
  const _ContactPanel();

  @override
  State<_ContactPanel> createState() => _ContactPanelState();
}

class _ContactPanelState extends State<_ContactPanel> {
  final _formKey    = GlobalKey<FormState>();
  final _nomCtrl    = TextEditingController();
  final _etablCtrl  = TextEditingController();
  final _msgCtrl    = TextEditingController();

  String  _role      = 'Directeur';
  String  _typeDemd  = 'Accès compte';
  bool    _sending   = false;
  bool    _sent      = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _etablCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() { _sending = false; _sent = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 24, bottom: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: _kPanelWidth,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_kPanelRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 40,
                  offset: const Offset(-4, -4),
                ),
                BoxShadow(
                  color: _kNavy.withValues(alpha: 0.10),
                  blurRadius: 20,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kPanelRadius),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Header(onClose: () => Navigator.of(context).pop()),
                  Flexible(
                    child: _sent ? _SuccessBody(onClose: () => Navigator.of(context).pop()) : _FormBody(
                      formKey: _formKey,
                      nomCtrl: _nomCtrl,
                      etablCtrl: _etablCtrl,
                      msgCtrl: _msgCtrl,
                      role: _role,
                      typeDemd: _typeDemd,
                      sending: _sending,
                      onRoleChanged: (v) => setState(() => _role = v),
                      onTypeChanged: (v) => setState(() => _typeDemd = v),
                      onSend: _send,
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
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kNavyDeep, _kNavy],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          // Indicateur vert "en ligne"
          Container(
            width: 10, height: 10,
            decoration: const BoxDecoration(
              color: _kGreen, shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support E-PILOTE CONGO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'Réponse sous 24h ouvrées',
                  style: TextStyle(
                    color: Color(0xFF7FA8C8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Ligne tricolore verticale
          Container(
            width: 3, height: 32,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kAuthCongoGreen, kAuthCongoYellow, kAuthCongoRed],
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ─── Formulaire ───────────────────────────────────────────────────────────────
class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.formKey,
    required this.nomCtrl,
    required this.etablCtrl,
    required this.msgCtrl,
    required this.role,
    required this.typeDemd,
    required this.sending,
    required this.onRoleChanged,
    required this.onTypeChanged,
    required this.onSend,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nomCtrl;
  final TextEditingController etablCtrl;
  final TextEditingController msgCtrl;
  final String role;
  final String typeDemd;
  final bool sending;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onSend;

  static const _roles = [
    'Super Admin', 'Admin Groupe', 'Directeur', 'Proviseur',
    'Enseignant', 'Comptable', 'Secrétaire', 'Autre',
  ];

  static const _types = [
    'Accès compte', 'Problème technique', 'Information', 'Autre',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bandeau sécurité ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD54F)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 15, color: Color(0xFF795548)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Identification requise pour la sécurité de votre compte.',
                      style: TextStyle(
                        color: Color(0xFF5D4037),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Nom complet ─────────────────────────────────────────────────
            _label('Nom complet *'),
            const SizedBox(height: 5),
            _textField(
              ctrl: nomCtrl,
              hint: 'Jean-Marie Nkounkou',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Nom requis (min. 3 caractères)' : null,
            ),
            const SizedBox(height: 14),

            // ── Établissement ───────────────────────────────────────────────
            _label('Établissement / Organisation *'),
            const SizedBox(height: 5),
            _textField(
              ctrl: etablCtrl,
              hint: 'Lycée Technique de Brazzaville',
              icon: Icons.school_outlined,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Établissement requis' : null,
            ),
            const SizedBox(height: 14),

            // ── Rôle ────────────────────────────────────────────────────────
            _label('Votre rôle *'),
            const SizedBox(height: 5),
            _dropdown(
              value: role,
              items: _roles,
              icon: Icons.badge_outlined,
              onChanged: onRoleChanged,
            ),
            const SizedBox(height: 18),

            // ── Type de demande ─────────────────────────────────────────────
            _label('Type de demande'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _types.map((t) => _TypeChip(
                label: t,
                selected: t == typeDemd,
                onTap: () => onTypeChanged(t),
              )).toList(),
            ),
            const SizedBox(height: 18),

            // ── Message ─────────────────────────────────────────────────────
            _label('Votre message *'),
            const SizedBox(height: 5),
            TextFormField(
              controller: msgCtrl,
              maxLines: 4,
              minLines: 3,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              decoration: _deco(
                hint: 'Décrivez votre demande en détail…',
                icon: Icons.chat_bubble_outline,
              ),
              validator: (v) => (v == null || v.trim().length < 15)
                  ? 'Message trop court (min. 15 caractères)' : null,
            ),
            const SizedBox(height: 20),

            // ── Bouton envoyer ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: sending ? null : onSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kNavy.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                child: sending
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Envoyer la demande',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Contact direct ──────────────────────────────────────────────
            const _DirectContact(),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151)));

  InputDecoration _deco({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        prefixIcon: Icon(icon, size: 17, color: _kSlate),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            borderSide: const BorderSide(color: _kNavy, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kAuthDanger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kAuthDanger, width: 2)),
      );

  Widget _textField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        decoration: _deco(hint: hint, icon: icon),
        validator: validator,
      );

  Widget _dropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        // ignore: deprecated_member_use
        value: value,
        decoration: _deco(hint: '', icon: icon),
        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.expand_more, size: 18, color: _kSlate),
        items: items
            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
            .toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      );
}

// ─── Chip type de demande ─────────────────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kNavy : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kNavy : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

// ─── Contact direct ───────────────────────────────────────────────────────────
class _DirectContact extends StatelessWidget {
  const _DirectContact();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFD7F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contact direct',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kNavy,
                  letterSpacing: 0.3)),
          SizedBox(height: 6),
          _ContactLine(
              icon: Icons.email_outlined,
              text: 'support@epilote.cg'),
          SizedBox(height: 4),
          _ContactLine(
              icon: Icons.phone_outlined,
              text: '+242 06 000 0000'),
          SizedBox(height: 4),
          _ContactLine(
              icon: Icons.access_time_rounded,
              text: 'Lun–Ven  ·  08h00–17h00'),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: _kNavy),
        const SizedBox(width: 7),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Écran succès ─────────────────────────────────────────────────────────────
class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: _kGreen, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Demande envoyée !',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'équipe E-PILOTE vous répondra\ndans les 24 heures ouvrées.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kSlate, fontSize: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kNavy,
                side: const BorderSide(color: _kNavy),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Fermer',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
