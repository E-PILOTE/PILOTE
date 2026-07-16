import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin_groupe/providers/admin_users_provider.dart'
    show roleLabel;
import '../../providers/active_agent_provider.dart';
import 'auth_colors.dart';

const _kAccent = kAuthAccent;

/// Modal de sélection d'agent (feuille bleu nuit). Recherche, rangée
/// « Récemment utilisés », grille défilable **à l'intérieur du modal** (la page
/// mère ne défile jamais) et apparition en cascade des cartes.
class AgentGrid extends ConsumerStatefulWidget {
  const AgentGrid({super.key, required this.agents, required this.onPick});
  final List<AgentOption> agents;
  final ValueChanged<AgentOption> onPick;

  @override
  ConsumerState<AgentGrid> createState() => _AgentGridState();
}

class _AgentGridState extends ConsumerState<AgentGrid>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late final AnimationController _intro;
  String _q = '';
  List<String> _recentIds = const [];

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 620))
      ..forward();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final ids = await ref.read(agentPinServiceProvider).recentIds();
    if (mounted) setState(() => _recentIds = ids);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _intro.dispose();
    super.dispose();
  }

  List<AgentOption> get _recents {
    final byId = {for (final a in widget.agents) a.id: a};
    return [
      for (final id in _recentIds)
        if (byId[id] != null) byId[id]!
    ].take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final searching = q.isNotEmpty;
    final list = widget.agents.where((a) {
      if (!searching) return true;
      return a.fullName.toLowerCase().contains(q) ||
          roleLabel(a.role).toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) =>
          a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()));

    final recents = searching ? const <AgentOption>[] : _recents;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(count: widget.agents.length),
        const SizedBox(height: 4),
        Text('Sélectionnez votre profil — vos saisies seront enregistrées à '
            'votre nom.',
            style:
                TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.6))),
        const SizedBox(height: 14),
        _SearchField(controller: _ctrl, query: _q, onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 14),
        if (recents.isNotEmpty) ...[
          const _SectionLabel('⏱  Récemment utilisés'),
          const SizedBox(height: 8),
          _RecentsRow(agents: recents, onPick: widget.onPick),
          const SizedBox(height: 14),
          const _SectionLabel('Tout le personnel'),
          const SizedBox(height: 8),
        ],
        if (list.isEmpty)
          const _Empty()
        else
          // Prend la place disponible dans la feuille (bornée à la hauteur
          // visible par le parent) : compacte quand peu d'agents, défile en
          // interne quand ils sont nombreux — la feuille elle-même ne défile
          // jamais.
          Flexible(
            child: Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              child: GridView.builder(
                controller: _scrollCtrl,
                shrinkWrap: true,
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                // Responsive : `maxCrossAxisExtent` arrondit le nb de colonnes
                // à la HAUSSE → 340 donne 2 colonnes larges (~298 px, nom
                // complet) sur la feuille de 640, et 1 colonne en fenêtre
                // étroite. (280 donnait 3 colonnes trop étroites.)
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  mainAxisExtent: 66,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => _Staggered(
                  controller: _intro,
                  index: i,
                  child: _AgentTile(
                      agent: list[i], onTap: () => widget.onPick(list[i])),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(
            child: Text('Qui utilise ce poste ?',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          Text('$count agent${count > 1 ? 's' : ''}',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
        ],
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.5)));
}

class _SearchField extends StatelessWidget {
  const _SearchField(
      {required this.controller, required this.query, required this.onChanged});
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(kAuthRadius),
        borderSide: BorderSide(color: c, width: w));
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 15, color: Colors.white),
      cursorColor: _kAccent,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Rechercher un nom ou un rôle…',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIcon: Icon(Icons.search_rounded,
            size: 22, color: Colors.white.withValues(alpha: 0.6)),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 20, color: Colors.white.withValues(alpha: 0.6)),
                tooltip: 'Effacer',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.white.withValues(alpha: 0.12)),
        focusedBorder: border(_kAccent, 1.5),
      ),
    );
  }
}

class _RecentsRow extends StatelessWidget {
  const _RecentsRow({required this.agents, required this.onPick});
  final List<AgentOption> agents;
  final ValueChanged<AgentOption> onPick;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final a in agents)
            Expanded(
              child: InkWell(
                onTap: () => onPick(a),
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(kAuthRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      _AgentAvatar(agent: a, size: 48, ring: true),
                      const SizedBox(height: 6),
                      Text(a.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      Text(roleLabel(a.role),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 9.5,
                              color: Colors.white.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ),
            ),
          for (var i = agents.length; i < 4; i++) const Expanded(child: SizedBox()),
        ],
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
            child: Text('Aucun agent ne correspond.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55), fontSize: 14))),
      );
}

/// Entrée en cascade (fondu + translation) pilotée par un seul contrôleur.
class _Staggered extends StatelessWidget {
  const _Staggered(
      {required this.controller, required this.index, required this.child});
  final AnimationController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.05).clamp(0.0, 0.5);
    final anim = CurvedAnimation(
        parent: controller,
        curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeOut));
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
            offset: Offset(0, (1 - anim.value) * 12), child: child),
      ),
      child: child,
    );
  }
}

class _AgentTile extends StatelessWidget {
  const _AgentTile({required this.agent, required this.onTap});
  final AgentOption agent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(kAuthRadius),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(kAuthRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kAuthRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _AgentAvatar(agent: agent, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text(roleLabel(agent.role),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.55))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar(
      {required this.agent, required this.size, this.ring = false});
  final AgentOption agent;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final has = agent.avatarUrl != null && agent.avatarUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D74B8), Color(0xFF23568C)],
        ),
        border: ring
            ? Border.all(color: const Color(0xFFFCDD09), width: 2)
            : Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      child: has
          ? CachedNetworkImage(
              imageUrl: agent.avatarUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() => Center(
        child: Text(agent.initials,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.34)),
      );
}
