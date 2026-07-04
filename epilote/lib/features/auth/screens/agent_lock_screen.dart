import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart' show kNavy;
import '../../structure/providers/academic_year_provider.dart'
    show currentSchoolProvider;
import '../providers/active_agent_provider.dart';
import '../providers/auth_provider.dart';
import 'widgets/agent_grid.dart';
import 'widgets/agent_lock_background.dart';
import 'widgets/agent_pin_pad.dart';

/// Écran-verrou plein écran (poste scolaire partagé). Sélection d'agent + PIN,
/// session Supabase de l'appareil préservée. Affiché en overlay par AgentLockGate.
class AgentLockScreen extends ConsumerStatefulWidget {
  const AgentLockScreen({super.key});

  @override
  ConsumerState<AgentLockScreen> createState() => _AgentLockScreenState();
}

class _AgentLockScreenState extends ConsumerState<AgentLockScreen> {
  AgentOption? _picked;
  bool _isCreate = false;

  Future<void> _pick(AgentOption a) async {
    final hasPin = await ref.read(agentPinServiceProvider).hasPin(a.id);
    if (!mounted) return;
    setState(() {
      _picked = a;
      _isCreate = !hasPin;
    });
  }

  void _unlock() {
    final a = _picked;
    if (a == null) return;
    ref.read(selectedAgentIdProvider.notifier).state = a.id;
    // Pas de navigation : needsAgentUnlockProvider repasse à false → l'overlay
    // se retire de lui-même (AgentLockGate).
  }

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(switchableAgentsProvider).valueOrNull ?? const [];
    final school = ref.watch(currentSchoolProvider).valueOrNull;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AgentLockBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SchoolHeader(
                      name: school?['name'] as String? ?? 'E-PILOTE CONGO',
                      logoUrl: school?['logo_url'] as String?,
                    ),
                    const SizedBox(height: 16),
                    _Card(
                      child: _picked == null
                          ? AgentGrid(agents: agents, onPick: _pick)
                          : AgentPinPad(
                              agent: _picked!,
                              isCreate: _isCreate,
                              onBack: () => setState(() => _picked = null),
                              onSuccess: _unlock,
                            ),
                    ),
                    const SizedBox(height: 18),
                    _DeviceLogout(ref: ref),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolHeader extends StatelessWidget {
  const _SchoolHeader({required this.name, required this.logoUrl});
  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final has = logoUrl != null && logoUrl!.isNotEmpty;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: has
              ? CachedNetworkImage(
                  imageUrl: logoUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const _LogoFallback(),
                )
              : const _LogoFallback(),
        ),
        const SizedBox(height: 12),
        Text(name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('Poste partagé · République du Congo',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: kNavy,
        child: Center(
          child: Icon(Icons.school_rounded, color: Colors.white, size: 32),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 12)),
          ],
        ),
        child: child,
      );
}

class _DeviceLogout extends StatelessWidget {
  const _DeviceLogout({required this.ref});
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () async {
          ref.read(selectedAgentIdProvider.notifier).state = null;
          await ref.read(authNotifierProvider.notifier).signOut();
        },
        icon: Icon(Icons.logout_rounded,
            size: 16, color: Colors.white.withValues(alpha: 0.75)),
        label: Text('Déconnecter le poste',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
      );
}
