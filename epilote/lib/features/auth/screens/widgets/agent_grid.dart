import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin_groupe/providers/admin_users_provider.dart'
    show roleLabel;
import '../../providers/active_agent_provider.dart';
import 'auth_colors.dart';

const _kAccent = kAuthAccent;

/// Sélecteur d'agent de l'écran-verrou (feuille bleu nuit). Par défaut, ne
/// montre que les profils **enrôlés sur ce poste** (déjà connus de la machine,
/// comme la mire Linux Mint / macOS) — court, privé, rapide. Un bouton « Autre
/// profil » ouvre l'annuaire complet, recherchable, pour une première connexion.
/// Grille défilable **à l'intérieur du modal** (la page mère ne défile jamais).
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
  Set<String>? _enrolled; // null = pas encore lu du disque
  bool _showDirectory = false; // annuaire complet (première connexion)

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 620))
      ..forward();
    _loadEnrolled();
  }

  Future<void> _loadEnrolled() async {
    final ids = await ref.read(agentPinServiceProvider).enrolledIds();
    if (!mounted) return;
    setState(() {
      _enrolled = ids;
      // Poste neuf (aucun profil enrôlé) → ouvrir directement l'annuaire pour
      // que le premier agent puisse s'enrôler.
      if (!widget.agents.any((a) => ids.contains(a.id))) _showDirectory = true;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _intro.dispose();
    super.dispose();
  }

  List<AgentOption> get _enrolledAgents {
    final ids = _enrolled ?? const <String>{};
    return [for (final a in widget.agents) if (ids.contains(a.id)) a]
      ..sort((a, b) =>
          a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final loading = _enrolled == null;
    final enrolled = _enrolledAgents;
    // Mode annuaire : bascule explicite, ou aucun profil connu de ce poste.
    final directory = _showDirectory || (!loading && enrolled.isEmpty);

    final q = _q.trim().toLowerCase();
    final source = directory ? widget.agents : enrolled;
    final list = source.where((a) {
      if (!directory || q.isEmpty) return true;
      return a.fullName.toLowerCase().contains(q) ||
          roleLabel(a.role).toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) =>
          a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(count: directory ? widget.agents.length : enrolled.length),
        const SizedBox(height: 4),
        Text(
            directory
                ? 'Sélectionnez votre profil — vos saisies seront enregistrées à '
                    'votre nom.'
                : 'Profils déjà utilisés sur ce poste.',
            style: TextStyle(
                fontSize: 12.5, color: Colors.white.withValues(alpha: 0.6))),
        const SizedBox(height: 14),
        if (directory) ...[
          _SearchField(
              controller: _ctrl,
              query: _q,
              onChanged: (v) => setState(() => _q = v)),
          const SizedBox(height: 14),
        ],
        if (loading)
          const _LoadingRow()
        else if (list.isEmpty)
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
                // Une seule colonne : la feuille est étroite (ancrée en bas à
                // gauche façon Mint) et la liste enrôlée est courte.
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 460,
                  mainAxisExtent: 66,
                  mainAxisSpacing: 10,
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
        if (!loading) ...[
          const SizedBox(height: 10),
          if (!directory)
            _LinkButton(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Autre profil — première connexion',
              onTap: () => setState(() => _showDirectory = true),
            )
          else if (enrolled.isNotEmpty)
            _LinkButton(
              icon: Icons.arrow_back_rounded,
              label: 'Profils de ce poste',
              onTap: () => setState(() {
                _showDirectory = false;
                _q = '';
                _ctrl.clear();
              }),
            ),
        ],
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
          Text('$count profil${count > 1 ? 's' : ''}',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
        ],
      );
}

/// Lien discret (bascule annuaire ↔ profils du poste).
class _LinkButton extends StatelessWidget {
  const _LinkButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 17, color: _kAccent),
          label: Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
      );
}

/// Placeholder le temps de lire les profils enrôlés (évite un flash annuaire).
class _LoadingRow extends StatelessWidget {
  const _LoadingRow();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 34),
        child: Center(
          child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: _kAccent)),
        ),
      );
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
  const _AgentAvatar({required this.agent, required this.size});
  final AgentOption agent;
  final double size;

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
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
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
