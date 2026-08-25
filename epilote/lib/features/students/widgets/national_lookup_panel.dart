import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ine.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/national_lookup_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « CET ENFANT EST-IL DÉJÀ SCOLARISÉ QUELQUE PART ? »
//
//  Le rapprochement local répond pour l'école ; il ne voit rien au-delà. Or le
//  cas qui coupe une scolarité en deux est précisément celui d'un enfant qui
//  ARRIVE d'ailleurs. Ce panneau pose la question au registre national.
//
//  ── UN BOUTON, PAS UNE RECHERCHE PENDANT LA FRAPPE ─────────────────────────
//  Chaque interrogation est journalisée côté serveur : une école consulte un
//  registre où figurent des enfants qui ne sont pas les siens, cela doit
//  laisser une trace. Chercher à chaque touche noierait ce journal — au moment
//  même où il sert à justifier l'ouverture du registre.
//
//  ── L'ABSENCE DE RÉSEAU N'EST PAS UN ÉCHEC ─────────────────────────────────
//  L'application inscrit hors ligne. Le panneau le dit sans dramatiser et
//  n'empêche jamais de continuer : l'inscription se termine sans lui, et
//  l'élève reçoit son identifiant à la synchronisation.
// ════════════════════════════════════════════════════════════════════════════

class NationalLookupPanel extends ConsumerWidget {
  const NationalLookupPanel({
    super.key,
    required this.lastName,
    required this.firstName,
    required this.dateOfBirth,
    required this.claimedIne,
    required this.onClaim,
    required this.onClear,
  });

  final String lastName, firstName;
  final String? dateOfBirth;

  /// Identifiant déjà repris, le cas échéant.
  final String? claimedIne;

  final void Function(NationalStudentMatch match) onClaim;
  final VoidCallback onClear;

  bool get _identityComplete =>
      lastName.trim().length >= 2 &&
      firstName.trim().length >= 2 &&
      (dateOfBirth?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (claimedIne != null) return _Claimed(ine: claimedIne!, onClear: onClear);
    if (!_identityComplete) return const SizedBox.shrink();

    final state = ref.watch(nationalLookupProvider);

    return _Frame(
      color: kNavy,
      icon: Icons.travel_explore_rounded,
      title: 'Registre national',
      child: switch (state) {
        LookupIdle() => _Idle(
            onSearch: () => ref.read(nationalLookupProvider.notifier).search(
                  lastName: lastName,
                  firstName: firstName,
                  dateOfBirth: dateOfBirth,
                ),
          ),
        LookupRunning() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Interrogation du registre national…'),
            ]),
          ),
        LookupDone(matches: final m) when m.isEmpty => const _Message(
            'Aucun élève connu sous cette identité. Il s\'agit bien d\'une '
            'première inscription : un identifiant national lui sera attribué.',
          ),
        LookupDone(matches: final m) => _Results(matches: m, onClaim: onClaim),
        LookupFailed(message: final msg, offline: final off) =>
          _Message(msg, warn: !off),
      },
    );
  }
}

// ─── États ──────────────────────────────────────────────────────────────────

class _Idle extends StatelessWidget {
  const _Idle({required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Si cet enfant vient d\'un autre établissement, son identifiant '
            'national existe déjà. Le reprendre évite de couper sa scolarité '
            'en deux.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.35),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Vérifier au niveau national'),
          ),
        ],
      );
}

class _Results extends StatelessWidget {
  const _Results({required this.matches, required this.onClaim});
  final List<NationalStudentMatch> matches;
  final void Function(NationalStudentMatch) onClaim;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            matches.length == 1
                ? 'Un élève porte déjà cette identité :'
                : '${matches.length} élèves portent cette identité :',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (final m in matches) ...[
            _MatchTile(match: m, onClaim: () => onClaim(m)),
            const SizedBox(height: 6),
          ],
        ],
      );
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.onClaim});
  final NationalStudentMatch match;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(match.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(formatIne(match.ine),
                    style: TextStyle(
                        fontFeatures: const [],
                        fontSize: 12.5,
                        color: kNavy,
                        fontWeight: FontWeight.w600)),
                if (match.provenance.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(match.provenance,
                      style: TextStyle(fontSize: 12, color: kTextMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Déjà chez nous : ce n'est pas un rattachement qu'il faut, c'est la
          // fiche existante. Proposer « Rattacher » créerait le doublon que
          // tout ceci cherche à empêcher.
          if (match.sameSchool)
            AdminBadge('Déjà dans votre école', color: kAccent)
          else
            FilledButton.tonal(
              onPressed: onClaim,
              child: const Text('Rattacher'),
            ),
        ],
      ),
    );
  }
}

class _Claimed extends StatelessWidget {
  const _Claimed({required this.ine, required this.onClear});
  final String ine;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => _Frame(
        color: kGreen,
        icon: Icons.link_rounded,
        title: 'Parcours rattaché',
        child: Row(children: [
          Expanded(
            child: Text(
              'La fiche créée portera l\'identifiant ${formatIne(ine)}. '
              'La scolarité de cet enfant reste d\'un seul tenant.',
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('Annuler')),
        ]),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.warn = false});
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.35,
          color: warn ? kRed : kTextMuted,
        ),
      );
}

// ─── Cadre commun ───────────────────────────────────────────────────────────

class _Frame extends StatelessWidget {
  const _Frame({
    required this.color,
    required this.icon,
    required this.title,
    required this.child,
  });
  final Color color;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 9),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: color)),
          ]),
          const SizedBox(height: 9),
          child,
        ]),
      );
}
