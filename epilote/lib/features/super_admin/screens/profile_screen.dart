import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes, SignOutScope;

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kCard => kCardBg;
Color get _kText => kTextPrimary;
Color get _kSub => kTextMuted;
Color get _kBg => kSurface;

final _fmtDate = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

// ─── Profile provider (fetch from profiles table) ─────────────────────────────
final _profileDetailProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user   = ref.watch(currentUserProvider);
  if (user == null) return null;

  final row = await client
      .from('profiles')
      .select('id, first_name, last_name, role, phone, avatar_url, employee_number, is_active, last_login, created_at, updated_at')
      .eq('id', user.id)
      .maybeSingle();

  return row;
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl     = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();

  bool _saving       = false;
  bool _saved        = false;
  bool _pwdSaving    = false;
  bool _showCurrentPwd = false;
  bool _showNewPwd     = false;
  bool _showConfirmPwd = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_profileDetailProvider);
    final user  = ref.watch(currentUserProvider);

    return AppShell(
      title: 'Mon Profil',
      child: async.when(
        skipLoadingOnReload: true, skipLoadingOnRefresh: true,
        loading: () => Center(child: CircularProgressIndicator(color: _kNavy)),
        error:   (e, _) => Center(child: Text('Erreur : $e', style: TextStyle(color: _kSub))),
        data:    (profile) {
          // Populate controllers once
          if (_firstNameCtrl.text.isEmpty && profile != null) {
            _firstNameCtrl.text = profile['first_name'] as String? ?? '';
            _lastNameCtrl.text  = profile['last_name']  as String? ?? '';
            _phoneCtrl.text     = profile['phone']      as String? ?? '';
          }
          return _ProfileBody(
            profile: profile,
            user: user,
            firstNameCtrl: _firstNameCtrl,
            lastNameCtrl:  _lastNameCtrl,
            phoneCtrl:     _phoneCtrl,
            currentPwdCtrl: _currentPwdCtrl,
            newPwdCtrl:     _newPwdCtrl,
            confirmPwdCtrl: _confirmPwdCtrl,
            saving:          _saving,
            saved:           _saved,
            pwdSaving:       _pwdSaving,
            showCurrentPwd:  _showCurrentPwd,
            showNewPwd:      _showNewPwd,
            showConfirmPwd:  _showConfirmPwd,
            onToggleCurrentPwd: () => setState(() => _showCurrentPwd = !_showCurrentPwd),
            onToggleNewPwd:     () => setState(() => _showNewPwd     = !_showNewPwd),
            onToggleConfirmPwd: () => setState(() => _showConfirmPwd = !_showConfirmPwd),
            onSaveProfile: _saveProfile,
            onChangePassword: _changePassword,
            onSignOutAll: _signOutAllSessions,
          );
        },
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() { _saving = true; _saved = false; });
    try {
      final client = ref.read(supabaseClientProvider);
      final user   = ref.read(currentUserProvider);
      if (user == null) return;

      await client.from('profiles').update({
        'first_name': _firstNameCtrl.text.trim(),
        'last_name':  _lastNameCtrl.text.trim(),
        'phone':      _phoneCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      ref.invalidate(_profileDetailProvider);
      setState(() { _saving = false; _saved = true; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _saved = false);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _changePassword() async {
    if (_newPwdCtrl.text != _confirmPwdCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas'), backgroundColor: Colors.red));
      return;
    }
    if (_newPwdCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum 8 caractères'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _pwdSaving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.updateUser(UserAttributes(password: _newPwdCtrl.text));
      _currentPwdCtrl.clear(); _newPwdCtrl.clear(); _confirmPwdCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Mot de passe modifié avec succès !'), backgroundColor: _kGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _pwdSaving = false);
    }
  }

  Future<void> _signOutAllSessions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnecter toutes les sessions ?'),
        content: const Text(
            'Vous serez déconnecté de tous les appareils, y compris celui-ci. '
            'Vous devrez vous reconnecter.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(supabaseClientProvider).auth.signOut(scope: SignOutScope.global);
      // La redirection vers /login est gérée par l'écouteur d'état d'authentification.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// ─── Profile body ─────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.user,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.phoneCtrl,
    required this.currentPwdCtrl,
    required this.newPwdCtrl,
    required this.confirmPwdCtrl,
    required this.saving,
    required this.saved,
    required this.pwdSaving,
    required this.showCurrentPwd,
    required this.showNewPwd,
    required this.showConfirmPwd,
    required this.onToggleCurrentPwd,
    required this.onToggleNewPwd,
    required this.onToggleConfirmPwd,
    required this.onSaveProfile,
    required this.onChangePassword,
    required this.onSignOutAll,
  });

  final Map<String, dynamic>? profile;
  final dynamic user;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController currentPwdCtrl;
  final TextEditingController newPwdCtrl;
  final TextEditingController confirmPwdCtrl;
  final bool saving;
  final bool saved;
  final bool pwdSaving;
  final bool showCurrentPwd;
  final bool showNewPwd;
  final bool showConfirmPwd;
  final VoidCallback onToggleCurrentPwd;
  final VoidCallback onToggleNewPwd;
  final VoidCallback onToggleConfirmPwd;
  final VoidCallback onSaveProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onSignOutAll;

  @override
  Widget build(BuildContext context) {
    final firstName = profile?['first_name'] as String? ?? '';
    final lastName  = profile?['last_name']  as String? ?? '';
    final role      = profile?['role']       as String? ?? 'super_admin';
    final email     = user?.email ?? '—';
    final lastLogin = profile?['last_login'] as String?;
    final createdAt = profile?['created_at'] as String?;
    final empNumber = profile?['employee_number'] as String?;

    final initials = _initials(firstName, lastName, email);
    final roleLabel = _roleLabel(role);

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Profile hero ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kNavy, const Color(0xFF2A4F7A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  child: Text(initials,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName.isNotEmpty || lastName.isNotEmpty
                            ? '$firstName $lastName'.trim()
                            : email,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kGreen.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _kGreen.withValues(alpha: 0.5)),
                        ),
                        child: Text(roleLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                if (empNumber != null && empNumber.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('N° employé', style: TextStyle(color: Colors.white60, fontSize: 10)),
                      Text(empNumber, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Meta row ──────────────────────────────────────────────────
          Container(
            color: _kCard,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Row(
              children: [
                _MetaItem(icon: Icons.calendar_today_rounded, label: 'Inscrit le',
                    value: createdAt != null ? _fmt(createdAt) : '—'),
                const SizedBox(width: 24),
                _MetaItem(icon: Icons.login_rounded, label: 'Dernière connexion',
                    value: lastLogin != null ? _fmt(lastLogin) : 'Jamais'),
                const Spacer(),
                Container(
                  width: 10, height: 10,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                ),
                Text('Compte actif', style: TextStyle(fontSize: 12, color: _kGreen, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Divider(height: 1, color: kBorder),

          // ── Two column layout ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left: edit form ────────────────────────────────────
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _Card(
                        title: 'Informations personnelles',
                        icon: Icons.person_rounded,
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(child: _Field(ctrl: firstNameCtrl, label: 'Prénom')),
                              const SizedBox(width: 12),
                              Expanded(child: _Field(ctrl: lastNameCtrl, label: 'Nom de famille')),
                            ]),
                            const SizedBox(height: 12),
                            _Field(ctrl: phoneCtrl, label: 'Téléphone', hint: '+242 00 000 0000',
                                keyboardType: TextInputType.phone),
                            const SizedBox(height: 12),
                            _ReadonlyField(label: 'Adresse e-mail', value: email,
                                icon: Icons.lock_outline_rounded),
                            const SizedBox(height: 12),
                            _ReadonlyField(label: 'Rôle', value: roleLabel,
                                icon: Icons.shield_outlined),
                            const SizedBox(height: 20),
                            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              FilledButton.icon(
                                onPressed: saving ? null : onSaveProfile,
                                icon: saved
                                    ? const Icon(Icons.check_rounded, size: 16)
                                    : saving
                                        ? const SizedBox(width: 14, height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.save_rounded, size: 16),
                                label: Text(saved ? 'Sauvegardé !' : 'Enregistrer les modifications'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: saved ? _kGreen : _kNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      _Card(
                        title: 'Changer le mot de passe',
                        icon: Icons.lock_rounded,
                        child: Column(
                          children: [
                            _PasswordField(
                              ctrl: currentPwdCtrl,
                              label: 'Mot de passe actuel',
                              show: showCurrentPwd,
                              onToggle: onToggleCurrentPwd,
                            ),
                            const SizedBox(height: 12),
                            _PasswordField(
                              ctrl: newPwdCtrl,
                              label: 'Nouveau mot de passe',
                              show: showNewPwd,
                              onToggle: onToggleNewPwd,
                            ),
                            const SizedBox(height: 12),
                            _PasswordField(
                              ctrl: confirmPwdCtrl,
                              label: 'Confirmer le mot de passe',
                              show: showConfirmPwd,
                              onToggle: onToggleConfirmPwd,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Minimum 8 caractères, avec lettres et chiffres',
                                  style: TextStyle(fontSize: 11, color: _kSub)),
                            ),
                            const SizedBox(height: 20),
                            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              FilledButton.icon(
                                onPressed: pwdSaving ? null : onChangePassword,
                                icon: pwdSaving
                                    ? const SizedBox(width: 14, height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.lock_reset_rounded, size: 16),
                                label: const Text('Modifier le mot de passe'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // ── Right: sessions & info ─────────────────────────────
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _Card(
                        title: 'Activité du compte',
                        icon: Icons.history_rounded,
                        child: Column(children: [
                          _ActivityRow(
                            icon: Icons.login_rounded,
                            label: 'Dernière connexion',
                            value: lastLogin != null ? _fmt(lastLogin) : 'Jamais',
                            color: _kGreen,
                          ),
                          Divider(height: 20, color: kBorder),
                          _ActivityRow(
                            icon: Icons.verified_user_rounded,
                            label: 'Compte créé le',
                            value: createdAt != null ? _fmt(createdAt) : '—',
                            color: _kNavy,
                          ),
                          Divider(height: 20, color: kBorder),
                          _ActivityRow(
                            icon: Icons.admin_panel_settings_rounded,
                            label: 'Niveau d\'accès',
                            value: roleLabel,
                            color: const Color(0xFF7C3AED),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 16),

                      const _Card(
                        title: 'Sécurité',
                        icon: Icons.security_rounded,
                        child: Column(children: [
                          _SecurityRow(label: 'Authentification à deux facteurs', enabled: false),
                          SizedBox(height: 10),
                          _SecurityRow(label: 'Alertes de connexion par email',   enabled: true),
                          SizedBox(height: 10),
                          _SecurityRow(label: 'Session sécurisée (HTTPS)',        enabled: true),
                        ]),
                      ),

                      const SizedBox(height: 16),

                      // Danger zone
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('Zone sensible',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                            ]),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: onSignOutAll,
                              icon: const Icon(Icons.logout_rounded, size: 14),
                              label: const Text('Déconnecter toutes les sessions', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return _fmtDate.format(dt.toLocal());
  }

  String _initials(String first, String last, String email) {
    if (first.isNotEmpty && last.isNotEmpty) return '${first[0]}${last[0]}'.toUpperCase();
    if (first.isNotEmpty) return first[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'super_admin':   return 'Super Administrateur';
      case 'admin_groupe':  return 'Administrateur Groupe';
      case 'directeur':     return 'Directeur';
      default:              return role;
    }
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});
  final String title; final IconData icon; final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: _kNavy),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
        ]),
        const SizedBox(height: 16),
        Divider(height: 1, color: kBorder),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.ctrl, required this.label, this.hint, this.keyboardType});
  final TextEditingController ctrl; final String label; final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kSub)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: _kSub),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kNavy)),
          filled: true, fillColor: _kBg,
        ),
      ),
    ],
  );
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.label, required this.value, required this.icon});
  final String label; final String value; final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kSub)),
      const SizedBox(height: 4),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: _kSub),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 13, color: _kSub)),
        ]),
      ),
    ],
  );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.ctrl, required this.label, required this.show, required this.onToggle});
  final TextEditingController ctrl; final String label; final bool show; final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kSub)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        obscureText: !show,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kNavy)),
          filled: true, fillColor: _kBg,
          suffixIcon: IconButton(
            icon: Icon(show ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: _kSub),
            onPressed: onToggle,
          ),
        ),
      ),
    ],
  );
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label, required this.value});
  final IconData icon; final String label; final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: _kSub),
    const SizedBox(width: 6),
    Text('$label : ', style: TextStyle(fontSize: 11, color: _kSub)),
    Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kText)),
  ]);
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon; final String label; final String value; final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 15, color: color),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: _kSub)),
        Text(value,  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
      ],
    )),
  ]);
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({required this.label, required this.enabled});
  final String label; final bool enabled;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(enabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
        size: 16, color: enabled ? _kGreen : _kSub),
    const SizedBox(width: 10),
    Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: enabled ? _kText : _kSub))),
  ]);
}
