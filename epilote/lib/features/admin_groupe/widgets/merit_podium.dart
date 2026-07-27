import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
// Volontairement SANS dépendance à un provider : le podium sert les deux bases
// du palmarès (examens d'État et classes de passage), qui n'ont pas le même
// modèle. Il ne connaît qu'un rang, un nom, un lieu et une note.

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
/// Ce dont le podium a besoin — rien de plus.
class PodiumItem {
  const PodiumItem({
    required this.rank,
    required this.fullName,
    required this.schoolName,
    required this.average,
    required this.caption,
    this.subtitle,
    this.exAequo = false,
  });

  final int rank;
  final String fullName;
  final String schoolName;
  final double average;

  /// Mention, ou « ex æquo » — ce qui se lit à droite de la moyenne.
  final String caption;

  /// Filière, classe… selon la base affichée.
  final String? subtitle;
  final bool exAequo;
}

class MeritPodium extends StatelessWidget {
  const MeritPodium({
    super.key,
    required this.rows,
    required this.onTap,
    this.subtitle = 'Cliquez un lauréat pour ouvrir son dossier',
  });

  final List<PodiumItem> rows;
  final String subtitle;

  /// Ouvre le dossier du lauréat. Le podium n'est pas une vignette : c'est la
  /// porte d'entrée vers l'élève.
  final ValueChanged<PodiumItem> onTap;

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
        AdminSectionTitle(
          'Podium',
          icon: Icons.emoji_events_rounded,
          subtitle: subtitle,
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
                    child: _Step(row: r, onTap: () => onTap(r)),
                  ),
              ],
            );
          }
          // Marches de MÊME taille. La hiérarchie est déjà portée par le rang,
          // la médaille et la moyenne ; des hauteurs inégales n'ajoutaient
          // rien et faisaient sauter la ligne dès qu'un ex æquo ajoutait un mot.
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in top)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _Step(row: r, onTap: () => onTap(r)),
                    ),
                  ),
              ],
            ),
          );
        }),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.row, required this.onTap});

  final PodiumItem row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = row;
    final color = MeritPodium.medalColor(row.rank);

    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
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
                // `spaceBetween` plutôt qu'un `Spacer` : il pousse la moyenne
                // en bas de marche quand la hauteur est contrainte (podium
                // large, marches égalisées) et ne fait simplement rien quand
                // elle ne l'est pas (empilement étroit). Un `Spacer` aurait
                // lancé une exception dans ce second cas.
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
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
                        Text(e.subtitle ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: kTextMuted, fontSize: 10.5)),
                        const SizedBox(height: 10),
                      ],
                    ),
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
                          row.caption,
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
        ),
      ),
    );
  }
}
