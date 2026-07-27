import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../widgets/merit_exam_view.dart';
import '../widgets/merit_passage_view.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MEILLEURS ÉLÈVES — écran du ministère (admin_groupe, online).
//
//  ── DEUX BASES, JAMAIS FONDUES ──────────────────────────────────────────────
//  Le mérite d'un réseau ne se lit pas sur une seule échelle, parce que la
//  plateforme ne joue pas le même rôle selon la classe :
//
//   • CLASSES DE PASSAGE (6e, 5e, 4e, 2nde, 1ère, CP→CM1) — le passage au
//     niveau supérieur se décide sur le travail de l'année. La plateforme
//     détient les notes et CALCULE les moyennes. C'est sa base propre, et
//     elle est trimestrielle.
//
//   • CLASSES D'EXAMEN (CM2 → CEPE, 3e → BET, Tle → Bac) — la plateforme
//     transmet à la DEC la LISTE DES CANDIDATS ; c'est la DEC qui organise
//     l'épreuve et proclame les résultats. La plateforme ne les calcule pas,
//     elle les enregistre. Quand ils existent, ils sont la seule base
//     comparable entre établissements.
//
//  Les mêler donnerait un classement qui ne veut rien dire : on comparerait
//  une moyenne d'établissement à une note d'épreuve nationale. D'où deux
//  onglets, et deux documents distincts.
//
//  Le titre dit ce que la page FAIT ; les documents imprimés gardent le
//  vocabulaire officiel (« Palmarès des lauréats »).
// ════════════════════════════════════════════════════════════════════════════

/// Base de classement affichée.
enum MeritBasis { passage, exam }

/// La base par défaut est celle que la plateforme CALCULE. Ouvrir sur les
/// examens ferait croire qu'elle en produit les résultats.
final meritBasisProvider =
    StateProvider.autoDispose<MeritBasis>((ref) => MeritBasis.passage);

class AdminMeritScreen extends ConsumerWidget {
  const AdminMeritScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final basis = ref.watch(meritBasisProvider);

    return AppShell(
      title: 'Meilleurs élèves du réseau',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BasisSwitch(
              basis: basis,
              onChanged: (b) =>
                  ref.read(meritBasisProvider.notifier).state = b,
            ),
            const SizedBox(height: 20),
            if (basis == MeritBasis.passage)
              const MeritPassageView()
            else
              const MeritExamView(),
          ],
        ),
      ),
    );
  }
}

// ─── Bascule entre les deux bases ───────────────────────────────────────────
class _BasisSwitch extends StatelessWidget {
  const _BasisSwitch({required this.basis, required this.onChanged});

  final MeritBasis basis;
  final ValueChanged<MeritBasis> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          _Tab(
            label: 'Classes de passage',
            hint: 'moyennes calculées ici',
            icon: Icons.workspace_premium_rounded,
            selected: basis == MeritBasis.passage,
            onTap: () => onChanged(MeritBasis.passage),
          ),
          const SizedBox(width: 5),
          _Tab(
            label: 'Examens d\'État',
            hint: 'résultats proclamés par la DEC',
            icon: Icons.emoji_events_rounded,
            selected: basis == MeritBasis.exam,
            onTap: () => onChanged(MeritBasis.exam),
          ),
        ]),
      );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Material(
          color: selected ? kNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [
                Icon(icon,
                    size: 18,
                    color: selected ? Colors.white : kTextMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color:
                                  selected ? Colors.white : kTextPrimary)),
                      // Le sous-titre porte la distinction de fond : qui
                      // calcule quoi. Sans lui, les deux onglets passeraient
                      // pour deux filtres du même classement.
                      Text(hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5,
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : kTextMuted)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
