// ════════════════════════════════════════════════════════════════════════════
//  LA CARRIÈRE D'UN AGENT, LUE COMME UNE SUITE DE POSTES
//
//  C'est la phrase que la plateforme ne savait pas écrire : « il a servi à
//  Kinkala de 2019 à 2026, puis à Brazzaville ». Elle vaut une ancienneté,
//  donc des droits — et jusqu'ici elle n'était nulle part.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/mouvement_agent.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_carriere_provider.dart';
import '../providers/admin_users_provider.dart';

String _moisAn(DateTime d) {
  const mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.',
                'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${mois[d.month - 1]} ${d.year}';
}

class AgentCarrierePanel extends ConsumerWidget {
  const AgentCarrierePanel({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(agentCarriereProvider(profileId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => AdminErrorBanner(message: 'Carrière indisponible : $e'),
      data: (postes) {
        if (postes.isEmpty) {
          return const AdminEmptyState(
            icon: Icons.work_history_outlined,
            title: 'Aucune affectation enregistrée',
            message: 'La carrière se remplit au premier mouvement — mutation, '
                'départ ou réintégration.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < postes.length; i++)
              _LignePoste(poste: postes[i], dernier: i == postes.length - 1),
          ],
        );
      },
    );
  }
}

class _LignePoste extends StatelessWidget {
  const _LignePoste({required this.poste, required this.dernier});
  final Affectation poste;
  final bool dernier;

  @override
  Widget build(BuildContext context) {
    final courant = poste.isCurrent;
    final couleur = courant ? kGreen : kNavy;
    final repris  = poste.arrivalMotif == 'reprise_historique';

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Filet vertical : la continuité de la carrière, littéralement.
        Column(children: [
          Container(
            width: 12, height: 12,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: courant ? couleur : Colors.transparent,
              border: Border.all(color: couleur, width: 2),
              shape: BoxShape.circle,
            ),
          ),
          if (!dernier)
            Expanded(
              child: Container(
                width: 2,
                color: kNavy.withValues(alpha: 0.18),
              ),
            ),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: dernier ? 0 : 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(poste.schoolName,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                ),
                if (courant)
                  AdminBadge('Poste actuel', color: kGreen),
              ]),
              const SizedBox(height: 3),
              Text(
                '${roleLabel(poste.role)} · ${_moisAn(poste.startDate)} → '
                '${poste.endDate == null ? "aujourd'hui" : _moisAn(poste.endDate!)}'
                '  (${poste.duree})',
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _Puce(
                  icon: Icons.login_rounded,
                  texte: 'Arrivée : ${mouvementLabel(poste.arrivalMotif)}',
                  couleur: repris ? Colors.orange.shade800 : kNavy,
                ),
                if (poste.departureMotif != null)
                  _Puce(
                    icon: Icons.logout_rounded,
                    texte: 'Départ : ${mouvementLabel(poste.departureMotif)}',
                    couleur: kRed,
                  ),
                if (poste.acteReference != null)
                  _Puce(
                    icon: Icons.description_outlined,
                    texte: poste.acteReference!,
                    couleur: Colors.black54,
                  ),
              ]),
              if (repris) ...[
                const SizedBox(height: 6),
                Text(
                  "⚠️ Date d'entrée reprise automatiquement : la date réelle "
                  "n'était pas enregistrée. À corriger au vu du dossier.",
                  style: TextStyle(
                      fontSize: 11.5, color: Colors.orange.shade900, height: 1.35),
                ),
              ],
              if (poste.notes != null && poste.notes!.trim().isNotEmpty && !repris) ...[
                const SizedBox(height: 6),
                Text(poste.notes!,
                    style: const TextStyle(
                        fontSize: 11.5, color: Colors.black54, height: 1.35)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Puce extends StatelessWidget {
  const _Puce({required this.icon, required this.texte, required this.couleur});
  final IconData icon;
  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: couleur.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: couleur),
          const SizedBox(width: 5),
          Text(texte,
              style: TextStyle(
                  fontSize: 11, color: couleur, fontWeight: FontWeight.w600)),
        ]),
      );
}
