import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_ui.dart' show kNavy, kBorder, kTextMuted;
import '../../../admin_groupe/providers/admin_users_provider.dart'
    show roleLabel;
import '../../providers/active_agent_provider.dart';

/// Grille de sélection d'agent dans l'écran-verrou. Recherche + avatars.
class AgentGrid extends StatefulWidget {
  const AgentGrid({super.key, required this.agents, required this.onPick});
  final List<AgentOption> agents;
  final ValueChanged<AgentOption> onPick;

  @override
  State<AgentGrid> createState() => _AgentGridState();
}

class _AgentGridState extends State<AgentGrid> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _setQuery(String v) => setState(() => _q = v);

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = widget.agents.where((a) {
      if (q.isEmpty) return true;
      return a.fullName.toLowerCase().contains(q) ||
          roleLabel(a.role).toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) =>
          a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Qui utilise ce poste ?',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: kNavy)),
            ),
            Text('${widget.agents.length} agent${widget.agents.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Sélectionnez votre profil — vos saisies seront '
            'enregistrées à votre nom.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
        const SizedBox(height: 16),
        // Barre de recherche agrandie, avec contrôleur + bouton effacer.
        TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 15),
          onChanged: _setQuery,
          decoration: InputDecoration(
            hintText: 'Rechercher un nom ou un rôle…',
            prefixIcon: const Icon(Icons.search_rounded, size: 24),
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Effacer',
                    onPressed: () {
                      _ctrl.clear();
                      _setQuery('');
                    },
                  ),
            filled: true,
            fillColor: const Color(0xFFF6F8FB),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kNavy, width: 1.5)),
          ),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
                child: Text('Aucun agent ne correspond.',
                    style: TextStyle(color: kTextMuted, fontSize: 14))),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 440),
            child: Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              child: GridView.builder(
                controller: _scrollCtrl,
                shrinkWrap: true,
                padding: const EdgeInsets.only(right: 6),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 68,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => _AgentTile(
                    agent: list[i], onTap: () => widget.onPick(list[i])),
              ),
            ),
          ),
      ],
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              _AgentAvatar(agent: agent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(roleLabel(agent.role),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 11, color: kTextMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: kTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar({required this.agent});
  final AgentOption agent;

  @override
  Widget build(BuildContext context) {
    final has = agent.avatarUrl != null && agent.avatarUrl!.isNotEmpty;
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: kNavy),
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
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      );
}
