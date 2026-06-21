import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/congo_flag.dart';
import '../../admin_groupe/providers/admin_users_provider.dart' show roleLabel;
import '../../auth/providers/active_agent_provider.dart';

// Teintes par agent — strictement la palette plateforme (navy / vert Congo /
// rouge Congo) + deux tons déjà employés ailleurs dans l'app (bleu, violet).
const List<Color> _agentPalette = [
  kNavy,
  kGreen,
  kRed,
  Color(0xFF0EA5E9), // bleu (carte régionale)
  Color(0xFF7C3AED), // violet (carte régionale)
];
Color _agentColor(String id) =>
    _agentPalette[id.hashCode.abs() % _agentPalette.length];

enum _Sort { name, role }

/// Sélecteur d'agent local — postes partagés hors-ligne.
/// Choix du profil + PIN court (créé la 1ʳᵉ fois). 100% offline.
class StaffAgentSwitchScreen extends ConsumerStatefulWidget {
  const StaffAgentSwitchScreen({super.key});

  @override
  ConsumerState<StaffAgentSwitchScreen> createState() =>
      _StaffAgentSwitchScreenState();
}

class _StaffAgentSwitchScreenState
    extends ConsumerState<StaffAgentSwitchScreen> {
  String _query = '';
  _Sort _sort = _Sort.name;

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(switchableAgentsProvider);
    final activeId = ref.watch(activeAgentIdProvider);

    return AppShell(
      title: 'Changer d’agent',
      child: agentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erreur de chargement')),
        data: (all) {
          final q = _query.trim().toLowerCase();
          final list = all.where((a) {
            if (q.isEmpty) return true;
            return a.fullName.toLowerCase().contains(q) ||
                roleLabel(a.role).toLowerCase().contains(q) ||
                (a.phone?.toLowerCase().contains(q) ?? false);
          }).toList()
            ..sort((a, b) => _sort == _Sort.name
                ? a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase())
                : roleLabel(a.role).compareTo(roleLabel(b.role)));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Header(count: all.length),
              const SizedBox(height: 18),
              _Toolbar(
                query: _query,
                sort: _sort,
                onQuery: (v) => setState(() => _query = v),
                onSort: (s) => setState(() => _sort = s),
              ),
              const SizedBox(height: 18),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                      child: Text('Aucun agent ne correspond.',
                          style: TextStyle(color: kTextMuted))),
                )
              else
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 1280
                      ? 3
                      : c.maxWidth >= 820
                          ? 2
                          : 1;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 3.0,
                    children: [
                      for (var i = 0; i < list.length; i++)
                        _AnimatedIn(
                          delayMs: 35 * i,
                          child: _AgentCard(
                            agent: list[i],
                            active: list[i].id == activeId,
                            onTap: () => _pick(list[i]),
                          ),
                        ),
                    ],
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pick(AgentOption a) async {
    final hasPin = await ref.read(agentPinServiceProvider).hasPin(a.id);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PinDialog(agent: a, isCreate: !hasPin),
    );
    if (ok == true && mounted) {
      ref.read(selectedAgentIdProvider.notifier).state = a.id;
      context.go(Routes.userDashboard);
    }
  }
}

// ─── En-tête (navy plateforme + drapeau Congo) ───────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kNavyDark, kNavy],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: kNavy.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.switch_account_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Qui utilise cet appareil ?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    '$count agent${count > 1 ? 's' : ''} · sélectionnez votre '
                    'profil, vos saisies seront enregistrées à votre nom',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Drapeau de la République du Congo
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const CongoFlag(width: 46, height: 31),
          ),
        ],
      ),
    );
  }
}

// ─── Recherche + tri ─────────────────────────────────────────────────────────
class _Toolbar extends StatelessWidget {
  const _Toolbar(
      {required this.query,
      required this.sort,
      required this.onQuery,
      required this.onSort});
  final String query;
  final _Sort sort;
  final ValueChanged<String> onQuery;
  final ValueChanged<_Sort> onSort;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          onChanged: onQuery,
          decoration: InputDecoration(
            hintText: 'Rechercher un agent, un rôle…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder)),
          ),
        ),
      ),
      const SizedBox(width: 10),
      _SortBtn(
          label: 'Nom',
          icon: Icons.sort_by_alpha_rounded,
          active: sort == _Sort.name,
          onTap: () => onSort(_Sort.name)),
      const SizedBox(width: 6),
      _SortBtn(
          label: 'Rôle',
          icon: Icons.badge_outlined,
          active: sort == _Sort.role,
          onTap: () => onSort(_Sort.role)),
    ]);
  }
}

class _SortBtn extends StatelessWidget {
  const _SortBtn(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: active ? kNavy : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? kNavy : kBorder),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: active ? Colors.white : kTextMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : kTextMuted)),
          ]),
        ),
      );
}

// ─── Entrée animée (fade + slide, staggered léger) ───────────────────────────
class _AnimatedIn extends StatelessWidget {
  const _AnimatedIn({required this.child, required this.delayMs});
  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + delayMs.clamp(0, 500)),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0, 1),
          child:
              Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
        ),
        child: child,
      );
}

// ─── Carte agent — sobre, blanche, accent latéral coloré ─────────────────────
class _AgentCard extends StatefulWidget {
  const _AgentCard(
      {required this.agent, required this.active, required this.onTap});
  final AgentOption agent;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<_AgentCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.agent;
    final color = _agentColor(a.id);
    final dob = a.dateOfBirth;
    final highlight = _hover || widget.active;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: highlight ? color : kBorder,
                width: highlight ? 1.5 : 1),
            boxShadow: [
              BoxShadow(
                color: highlight
                    ? color.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: highlight ? 16 : 8,
                offset: Offset(0, highlight ? 7 : 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Accent latéral coloré
              Container(width: 5, color: color),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _Avatar(agent: a, color: color),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(a.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: kTextPrimary)),
                        ),
                        if (widget.active) const _ActiveBadge(),
                      ]),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(roleLabel(a.role),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                      if ((a.phone != null && a.phone!.isNotEmpty) ||
                          dob != null) ...[
                        const SizedBox(height: 7),
                        if (a.phone != null && a.phone!.isNotEmpty)
                          _InfoLine(icon: Icons.phone_rounded, text: a.phone!),
                        if (dob != null)
                          _InfoLine(
                              icon: Icons.cake_rounded,
                              text:
                                  '${DateFormat('dd/MM/yyyy', 'fr').format(dob)} · ${_age(dob)} ans'),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.chevron_right_rounded,
                    color: highlight ? color : kTextMuted, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _age(DateTime d) {
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a;
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: kGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_rounded, size: 12, color: kGreen),
          SizedBox(width: 3),
          Text('Actif',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800, color: kGreen)),
        ]),
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.agent, required this.color, this.size = 46});
  final AgentOption agent;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = agent.avatarUrl != null && agent.avatarUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasPhoto
            ? null
            : LinearGradient(colors: [color, color.withValues(alpha: 0.72)]),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? CachedNetworkImage(
              imageUrl: agent.avatarUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _Initials(agent: agent, size: size),
            )
          : _Initials(agent: agent, size: size),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.agent, this.size = 46});
  final AgentOption agent;
  final double size;
  @override
  Widget build(BuildContext context) => Center(
        child: Text(agent.initials,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.34)),
      );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(icon, size: 12, color: kTextMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: kTextMuted)),
          ),
        ]),
      );
}

// ─── Dialogue PIN centré (créer / saisir) ────────────────────────────────────
class _PinDialog extends ConsumerStatefulWidget {
  const _PinDialog({required this.agent, required this.isCreate});
  final AgentOption agent;
  final bool isCreate;

  @override
  ConsumerState<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends ConsumerState<_PinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pin.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'Le PIN doit comporter au moins 4 chiffres.');
      return;
    }
    if (widget.isCreate && pin != _confirm.text.trim()) {
      setState(() => _error = 'Les deux codes ne correspondent pas.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final svc = ref.read(agentPinServiceProvider);
    if (widget.isCreate) {
      await svc.setPin(widget.agent.id, pin);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final ok = await svc.verifyPin(widget.agent.id, pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() { _busy = false; _error = 'Code PIN incorrect.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _agentColor(widget.agent.id);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _Avatar(agent: widget.agent, color: color, size: 50),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.agent.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      Text(roleLabel(widget.agent.role),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: kTextMuted,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ]),
              const SizedBox(height: 14),
              Text(
                  widget.isCreate
                      ? 'Choisissez un code à 4-6 chiffres. Il protège vos saisies.'
                      : 'Saisissez votre code pour accéder à vos modules.',
                  style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
              const SizedBox(height: 16),
              _PinField(controller: _pin, label: 'Code PIN', autofocus: true),
              if (widget.isCreate) ...[
                const SizedBox(height: 12),
                _PinField(controller: _confirm, label: 'Confirmer le PIN'),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: kRed, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy
                      ? '…'
                      : widget.isCreate
                          ? 'Définir et continuer'
                          : 'Continuer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField(
      {required this.controller, required this.label, this.autofocus = false});
  final TextEditingController controller;
  final String label;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
}
