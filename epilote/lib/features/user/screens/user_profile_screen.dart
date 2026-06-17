import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/password_change_dialog.dart';
import '../../../core/widgets/staff_ui.dart';
import '../../../data/models/profile_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/structure/providers/academic_year_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/staff_account_widgets.dart';

/// Page « Mon profil » du personnel scolaire — identité, informations
/// personnelles éditables, détails du compte et sécurité.
/// Données 100 % offline-first (ligne `profiles` locale PowerSync).
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Mon profil',
      child: _Body(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowAsync = ref.watch(myProfileRowProvider);
    return rowAsync.when(
      loading: () =>
          const FormSkeleton(sections: 3, maxWidth: double.infinity),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (profile) {
        if (profile == null) {
          return const AdminEmptyState(
            icon: Icons.person_off_rounded,
            title: 'Profil indisponible',
            message: 'Votre profil ne peut pas être affiché hors-ligne. '
                'Reconnectez-vous au réseau puis réessayez.',
          );
        }
        return _ProfileForm(profile: profile);
      },
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});
  final ProfileModel profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _init = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _error = 'Le prénom et le nom sont obligatoires');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await updateMyProfile(
        id: widget.profile.id,
        firstName: _first.text,
        lastName: _last.text,
        phone: _phone.text.trim().isEmpty ? null : _phone.text,
      );
      // Rafraîchit l'en-tête (best-effort en ligne ; sans effet hors-ligne).
      await ref.read(authNotifierProvider.notifier).reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: kGreen, content: Text('Profil mis à jour.')));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final email = ref.watch(currentUserProvider)?.email ?? '—';
    final schoolName =
        ref.watch(currentSchoolProvider).valueOrNull?['name'] as String?;
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    // Hydrate les champs une seule fois (la ligne offline reste la source de vérité).
    if (!_init) {
      _first.text = p.firstName;
      _last.text = p.lastName;
      _phone.text = p.phone ?? '';
      _init = true;
    }
    _email.text = email;

    final roleLabel = staffRoleLabel(p.role);
    final infoSection = StaffSection(
      title: 'Informations personnelles',
      icon: Icons.edit_note_rounded,
      child: _personalInfoCard(email),
    );
    final aboutSection = StaffSection(
      title: 'À propos du compte',
      icon: Icons.verified_user_rounded,
      child: AboutAccountCard(profile: p, schoolName: schoolName),
    );

    // Pleine largeur — même gabarit que les pages admin_groupe.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ── En-tête de page ──────────────────────────────────────────────────
        StaffPageHeader(
          icon: Icons.person_rounded,
          title: p.fullName.isEmpty ? 'Mon profil' : p.fullName,
          subtitle:
              schoolName == null ? roleLabel : '$roleLabel · $schoolName',
          badges: [
            HeaderChip(label: roleLabel, icon: Icons.shield_rounded),
            if (schoolName != null)
              HeaderChip(label: schoolName, icon: Icons.business_rounded),
          ],
        ),
        const SizedBox(height: 24),

        // ── Identité ─────────────────────────────────────────────────────────
        StaffSection(
          title: 'Identité',
          icon: Icons.badge_rounded,
          child:
              StaffIdentityCard(profile: p, schoolName: schoolName, email: email),
        ),
        const SizedBox(height: 24),

        // ── Infos personnelles + À propos (2 colonnes sur ≥ 1100) ────────────
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: infoSection),
            const SizedBox(width: 22),
            Expanded(child: aboutSection),
          ])
        else ...[
          infoSection,
          const SizedBox(height: 24),
          aboutSection,
        ],
        const SizedBox(height: 24),

        // ── Sécurité ─────────────────────────────────────────────────────────
        StaffSection(
          title: 'Sécurité',
          icon: Icons.lock_outline_rounded,
          child: _securityCard(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Carte « Informations personnelles » (formulaire éditable) ───────────────
  Widget _personalInfoCard(String email) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _first,
                  decoration: adminInputDecoration('Prénom',
                      icon: Icons.badge_outlined))),
          const SizedBox(width: 12),
          Expanded(
              child: TextField(
                  controller: _last,
                  decoration: adminInputDecoration('Nom'))),
        ]),
        const SizedBox(height: 12),
        TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration:
                adminInputDecoration('Téléphone', icon: Icons.phone_outlined)),
        const SizedBox(height: 12),
        // Email — lecture seule (géré dans auth.users)
        TextField(
          enabled: false,
          controller: _email,
          decoration: adminInputDecoration('Email (non modifiable)',
              icon: Icons.email_outlined),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AdminErrorBanner(message: _error!),
        ],
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          AdminActionButton(
            label: _saving ? 'Enregistrement…' : 'Enregistrer',
            icon: _saving ? Icons.hourglass_empty_rounded : Icons.check_rounded,
            color: kNavy,
            onPressed: _saving ? () {} : _save,
          ),
        ]),
      ]),
    );
  }

  // ── Carte « Sécurité » (mot de passe — action en ligne) ─────────────────────
  Widget _securityCard() {
    return AdminCard(
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.lock_outline_rounded, color: kNavy, size: 20),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mot de passe',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            SizedBox(height: 2),
            Text('Le changement nécessite une connexion internet.',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ]),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => showDialog<void>(
              context: context, builder: (_) => const PasswordChangeDialog()),
          icon: const Icon(Icons.lock_reset_rounded, size: 17),
          label: const Text('Changer le mot de passe'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kNavy,
            side: const BorderSide(color: kBorder),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}
