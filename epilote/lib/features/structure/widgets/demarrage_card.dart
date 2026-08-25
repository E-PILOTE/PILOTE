// ════════════════════════════════════════════════════════════════════════════
//  LA CARTE DE DÉMARRAGE — ce qu'un établissement voit le premier matin
//
//  Elle met en avant UNE action, la prochaine. Proposer cinq choses à qui n'en
//  a jamais fait aucune, c'est n'en proposer aucune. Les autres étapes restent
//  visibles, en retrait, pour qu'on voie où l'on va.
//
//  Elle DISPARAÎT quand tout est fait : une liste de démarrage permanente
//  devient du mobilier, et un tableau de bord encombré cesse d'être lu.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/demarrage_provider.dart';

class DemarrageCard extends ConsumerWidget {
  const DemarrageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(demarrageProvider).valueOrNull;
    if (d == null || d.total == 0 || d.termine) return const SizedBox.shrink();
    final prochaine = d.prochaine!;

    return Container(
      // L'espacement appartient à la carte, pas au tableau de bord : quand elle
      // s'efface, elle ne doit pas laisser un trou derrière elle.
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNavy.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.flag_outlined, size: 20, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Mise en route de l\'établissement',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
          ),
          Text('${d.faites} / ${d.total}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: kTextMuted)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: d.avancement,
            minHeight: 6,
            backgroundColor: kNavy.withValues(alpha: 0.10),
          ),
        ),
        const SizedBox(height: 16),

        // ── L'action du moment ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kNavy.withValues(alpha: 0.22)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prochaine étape — ${prochaine.titre}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(prochaine.pourquoi,
                        style: const TextStyle(fontSize: 12.5, height: 1.4)),
                    const SizedBox(height: 6),
                    Text(prochaine.bloque,
                        style: TextStyle(
                            fontSize: 11.5, color: kRed, height: 1.4)),
                  ]),
            ),
            const SizedBox(width: 14),
            FilledButton.icon(
              onPressed: () => context.go(prochaine.route),
              icon: Icon(
                  prochaine.parLeReseau
                      ? Icons.visibility_outlined
                      : Icons.arrow_forward_rounded,
                  size: 16),
              // On ne dit pas « Commencer » sur une étape que l'établissement
              // ne peut pas faire : il chercherait un bouton qui n'existe pas.
              label: Text(prochaine.parLeReseau ? 'Voir' : 'Commencer'),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Le chemin complet, en retrait ─────────────────────────────────
        for (final e in d.etapes)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(
                  e.faite
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: e.faite ? kGreen : kTextMuted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(e.titre,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: e.faite ? kTextMuted : kTextPrimary,
                      fontWeight:
                          e.faite ? FontWeight.w400 : FontWeight.w600,
                      decoration: e.faite ? TextDecoration.lineThrough : null,
                    )),
              ),
              if (e.compte > 0)
                Text('${e.compte}',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              if (e.parLeReseau) ...[
                const SizedBox(width: 8),
                Text('réseau',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: kTextMuted,
                        fontStyle: FontStyle.italic)),
              ],
            ]),
          ),
      ]),
    );
  }
}
