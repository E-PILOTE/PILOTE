import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_merit_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PODIUM — les trois premiers lauréats du périmètre courant.
//
//  Un palmarès se lit d'abord des yeux : le tableau sert la commission, le
//  podium sert la salle. Chaque marche porte l'ÉTABLISSEMENT autant que le nom
//  — dans un réseau national, c'est l'école qui est distinguée avec l'élève.
//
//  Les ex æquo sont affichés comme tels : deux lauréats à 17,70 occupent la
//  même marche, on ne les départage pas pour faire joli.
// ════════════════════════════════════════════════════════════════════════════
class MeritPodium extends StatelessWidget {
  const MeritPodium({super.key, required this.rows});

  final List<RankedMerit> rows;

  static const _gold = Color(0xFFD4AF37);
  static const _silver = Color(0xFF9AA5B1);
  static const _bronze = Color(0xFFB87333);

  static Color medalColor(int rank) => switch (rank) {
        1 => _gold,
        2 => _silver,
        _ => _bronze,
      };

  @override
  Widget build(BuildContext context) {
    // Les trois premiers RANGS (pas les trois premières lignes) : un rang
    // partagé amène ses deux lauréats sur la même marche.
    final top = rows.where((r) => r.rank <= 3).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle(
          'Podium',
          icon: Icons.emoji_events_rounded,
          subtitle: 'Meilleures moyennes du périmètre sélectionné',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final narrow = c.maxWidth < 640;
          if (narrow) {
            return Column(
              children: [
                for (final r in top)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Step(row: r, compact: true),
                  ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final r in top)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _Step(row: r),
                  ),
                ),
            ],
          );
        }),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.row, this.compact = false});

  final RankedMerit row;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final e = row.entry;
    final color = MeritPodium.medalColor(row.rank);
    // La 1ʳᵉ marche est plus haute : la hiérarchie se lit sans lire les rangs.
    //
    // HAUTEUR MINIMALE, jamais fixe : une marche ex æquo porte une ligne de
    // plus, et une hauteur figée la faisait déborder d'un pixel. Le minimum
    // conserve l'effet de podium quand le contenu est court, et cède quand il
    // ne l'est pas — y compris si l'utilisateur agrandit la police système.
    final minHeight =
        compact ? 0.0 : switch (row.rank) { 1 => 128.0, 2 => 112.0, _ => 100.0 };

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text('${row.rank}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: kTextPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(e.schoolName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: kTextMuted, fontSize: 11)),
                if (e.filiere != null)
                  Text(e.filiere!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: kTextMuted, fontSize: 10.5)),
                const SizedBox(height: 10),
                Row(children: [
                  Text(e.average.toStringAsFixed(2),
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  Text(' /20',
                      style: TextStyle(color: kTextMuted, fontSize: 10)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      row.exAequo ? 'ex æquo' : e.mention,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: kTextMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
