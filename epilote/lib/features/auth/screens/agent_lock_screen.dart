import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../structure/providers/academic_year_provider.dart'
    show currentSchoolProvider;
import '../providers/active_agent_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/vitrine_messages_provider.dart';
import '../providers/vitrine_partners_provider.dart';
import 'widgets/agent_grid.dart';
import 'widgets/agent_lock_background.dart';
import 'widgets/agent_pin_pad.dart';
import 'widgets/vitrine_shell.dart';

/// Écran-verrou plein écran (poste scolaire partagé) à deux états :
/// **vitrine de sécurité** au repos, puis **feuille profils/PIN** qui monte en
/// fondu au clic sur « Ouvrir une session ». Session Supabase de l'appareil
/// préservée. Affiché en overlay par AgentLockGate.
class AgentLockScreen extends ConsumerStatefulWidget {
  const AgentLockScreen({super.key});

  @override
  ConsumerState<AgentLockScreen> createState() => _AgentLockScreenState();
}

class _AgentLockScreenState extends ConsumerState<AgentLockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal;
  AgentOption? _picked;
  bool _isCreate = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340));
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _open() => _reveal.forward();

  void _close() {
    // Bascule forcée (poste personnel) : fermer = revenir à sa propre session.
    if (ref.read(forceAgentPickerProvider)) {
      ref.read(forceAgentPickerProvider.notifier).state = false;
      return;
    }
    _reveal.reverse();
    setState(() => _picked = null);
  }

  Future<void> _pick(AgentOption a) async {
    final svc = ref.read(agentPinServiceProvider);
    final hasPin = await svc.hasPin(a.id);
    // Reset demandé par admin_groupe (synchro) postérieur au PIN local → il faut
    // en recréer un. Un reset lève aussi un éventuel cooldown en cours.
    final invalidated =
        hasPin && pinResetInvalidates(a.pinResetRequestedAt, await svc.pinSetAt(a.id));
    if (invalidated) await svc.clearFails(a.id);
    if (!mounted) return;
    setState(() {
      _picked = a;
      _isCreate = !hasPin || invalidated;
    });
  }

  void _unlock() {
    final a = _picked;
    if (a == null) return;
    ref.read(agentPinServiceProvider).recordUsage(a.id);
    ref.read(forceAgentPickerProvider.notifier).state = false;
    // needsAgentUnlockProvider repasse à false → l'overlay se retire (gate).
    ref.read(selectedAgentIdProvider.notifier).state = a.id;
  }

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(switchableAgentsProvider).valueOrNull ?? const [];
    final school = ref.watch(currentSchoolProvider).valueOrNull;
    final serviceMessages =
        ref.watch(serviceMessagesProvider).valueOrNull ?? const [];
    final partners =
        ref.watch(vitrinePartnersProvider).valueOrNull ?? const [];
    final partnerOptIn =
        ref.watch(groupPartnerOptInProvider).valueOrNull ?? false;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AgentLockBackground(),
          AnimatedBuilder(
            animation: _reveal,
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(_reveal.value);
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Vitrine : s'estompe et se désactive quand la feuille monte.
                  IgnorePointer(
                    ignoring: t > 0.5,
                    child: Opacity(
                      opacity: 1 - 0.85 * t,
                      child: VitrineShell(
                        schoolName:
                            school?['name'] as String? ?? 'E-PILOTE CONGO',
                        schoolLogoUrl: school?['logo_url'] as String?,
                        onOpen: _open,
                        serviceMessages: serviceMessages,
                        showPartner:
                            showPartnerStrip(partnerOptIn, partners.isNotEmpty),
                        partners: [
                          for (final p in partners)
                            (name: p.name, logoUrl: p.logoUrl),
                        ],
                      ),
                    ),
                  ),
                  // Feuille profils / PIN : monte + fondu.
                  if (t > 0.01)
                    IgnorePointer(
                      ignoring: t < 0.5,
                      child: Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, (1 - t) * 48),
                          child: _RevealSheet(
                            agents: agents,
                            picked: _picked,
                            isCreate: _isCreate,
                            onPick: _pick,
                            onBackToGrid: () => setState(() => _picked = null),
                            onSuccess: _unlock,
                            onClose: _close,
                            onDeviceLogout: _deviceLogout,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deviceLogout() async {
    ref.read(selectedAgentIdProvider.notifier).state = null;
    ref.read(forceAgentPickerProvider.notifier).state = false;
    await ref.read(authNotifierProvider.notifier).signOut();
  }
}

/// Feuille bleu nuit qui contient la grille de profils puis le pavé PIN.
class _RevealSheet extends StatelessWidget {
  const _RevealSheet({
    required this.agents,
    required this.picked,
    required this.isCreate,
    required this.onPick,
    required this.onBackToGrid,
    required this.onSuccess,
    required this.onClose,
    required this.onDeviceLogout,
  });

  final List<AgentOption> agents;
  final AgentOption? picked;
  final bool isCreate;
  final ValueChanged<AgentOption> onPick;
  final VoidCallback onBackToGrid;
  final VoidCallback onSuccess;
  final VoidCallback onClose;
  final VoidCallback onDeviceLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          // La feuille s'ajuste au contenu ; ne défile qu'en dernier recours
          // (fenêtre très basse). La grille interne défile d'elle-même.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
              decoration: BoxDecoration(
                color: const Color(0xF20A182E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 18)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Handle(onClose: onClose, showClose: picked == null),
                  const SizedBox(height: 4),
                  if (picked == null)
                    AgentGrid(agents: agents, onPick: onPick)
                  else
                    AgentPinPad(
                      agent: picked!,
                      isCreate: isCreate,
                      onBack: onBackToGrid,
                      onSuccess: onSuccess,
                    ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: onDeviceLogout,
                    icon: Icon(Icons.logout_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.55)),
                    label: Text('Déconnecter le poste',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.55))),
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

class _Handle extends StatelessWidget {
  const _Handle({required this.onClose, required this.showClose});
  final VoidCallback onClose;
  final bool showClose;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const SizedBox(width: 36),
          Expanded(
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: showClose
                ? IconButton(
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withValues(alpha: 0.6)),
                    tooltip: 'Fermer',
                    onPressed: onClose,
                  )
                : null,
          ),
        ],
      );
}
