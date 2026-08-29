import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/parc_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE PARC — ce qu'on sait, et surtout ce qu'on ignore
//
//  Cet encart existe pour empêcher une décision, pas pour rassurer. Tant qu'un
//  seul profil n'a rien signalé, il dit NON à « le parc a-t-il suivi ? ».
//
//  ── POURQUOI « JAMAIS SIGNALÉ » EST ÉCRIT EN PREMIER ───────────────────────
//  Parce que c'est le chiffre qu'on ne regarde pas. Un tableau qui ouvre sur
//  « 340 postes à jour » se lit comme un feu vert ; le même tableau ouvrant sur
//  « 4 postes muets » se lit comme ce qu'il est. Les deux disent la même chose.
// ════════════════════════════════════════════════════════════════════════════
class ParcSection extends ConsumerWidget {
  const ParcSection({super.key, this.seuil = kBuildSansFirebase});

  final int seuil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couverture = ref.watch(parcCouvertureProvider(seuil));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionTitle(
          'Le parc',
          icon: Icons.devices_rounded,
          subtitle: 'Quelle version tourne réellement, seuil build $seuil',
        ),
        const SizedBox(height: 8),
        couverture.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AdminErrorBanner(
            message: 'Relevé du parc indisponible : $e',
          ),
          data: (c) => _Verdict(c: c),
        ),
        const SizedBox(height: 14),
        ref.watch(parcVersionsProvider).maybeWhen(
              data: (lignes) => lignes.isEmpty
                  ? const SizedBox.shrink()
                  : _Repartition(lignes: lignes, seuil: seuil),
              orElse: () => const SizedBox.shrink(),
            ),
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.c});
  final CouvertureParc c;

  @override
  Widget build(BuildContext context) {
    final sur = c.certitude;
    final couleur = sur ? kGreen : kRed;

    return AdminCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(sur ? Icons.verified_rounded : Icons.gpp_maybe_rounded,
                color: couleur, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sur
                    ? 'Tout le parc connu est en build ${c.seuil} ou plus'
                    : 'Le parc n’a pas suivi — ou on ne peut pas l’affirmer',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: couleur),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            sur
                ? 'Les migrations qui exigent que tous les postes aient reçu le '
                    'build peuvent être appliquées.'
                : 'Une migration qui supprime une colonne encore envoyée par un '
                    'poste en retard bloquerait sa synchronisation en silence, '
                    'sans un message à l’écran. Ne pas appliquer 0146.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.45),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            // ⚠️ En PREMIER, et affiché même à zéro : c'est lui qui décide.
            _Chiffre('${c.jamaisSignale}', 'n’ont rien signalé',
                c.jamaisSignale == 0 ? kGreen : kRed),
            _Chiffre('${c.enRetard}', 'en retard',
                c.enRetard == 0 ? kGreen : kRed),
            _Chiffre('${c.aJour}', 'à jour', kNavy),
            _Chiffre('${c.totalProfils}', 'profils au total', kTextMuted),
            if (c.plusAncien != null)
              _Chiffre('${c.plusAncien}', 'build le plus ancien vu', kTextMuted),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Les versions antérieures au relevé ne savent pas se signaler : '
              'un profil absent de ce tableau est soit sur une version '
              'ancienne, soit jamais revenu. On ne peut pas les distinguer, '
              'donc on les compte ensemble — c’est la lecture qui refuse de '
              'conclure.\n'
              'Connaissance du parc : ${c.partConnue.toStringAsFixed(1)} % '
              '(${c.connus} profils sur ${c.totalProfils}).',
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Repartition extends StatelessWidget {
  const _Repartition({required this.lignes, required this.seuil});
  final List<LigneParc> lignes;
  final int seuil;

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Répartition des versions signalées',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kNavy)),
            const SizedBox(height: 10),
            for (final l in lignes) _Ligne(l: l, seuil: seuil),
          ],
        ),
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.l, required this.seuil});
  final LigneParc l;
  final int seuil;

  @override
  Widget build(BuildContext context) {
    final ok = l.buildNumber >= seuil;
    final quand = l.dernierSignalement;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        AdminBadge('build ${l.buildNumber}', color: ok ? kGreen : kRed),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l.version} · ${l.platform}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (quand != null)
                Text(
                  'vu pour la dernière fois le '
                  '${DateFormat('dd/MM/yyyy à HH:mm', 'fr').format(quand)}',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
            ],
          ),
        ),
        Text('${l.profils}',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
        const SizedBox(width: 4),
        Text('profil${l.profils > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 11.5, color: kTextMuted)),
      ]),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(this.valeur, this.label, this.couleur);
  final String valeur, label;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(valeur,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: couleur)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
}
