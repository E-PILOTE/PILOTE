import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../providers/frais_provider.dart';
import '../../../core/utils/message_erreur.dart';

const _kSlug = 'frais-scolarite';

// ════════════════════════════════════════════════════════════════════════════
//  FRAIS DE SCOLARITÉ — CONSULTATION.
//
//  Cet écran a créé, modifié et supprimé des barèmes jusqu'au 5 août 2026. Il
//  ne fait plus que lire : un montant est un ACTE DU GROUPE (migration 0096,
//  décision D2). Dans le public il vient d'un arrêté, dans le privé du siège —
//  l'école est un exécutant.
//
//  Il affiche donc DEUX portées : le tarif du réseau (posé pour toutes les
//  écoles) et celui posé pour cet établissement. Dans les deux cas l'auteur est
//  le ministère. 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class FraisScreen extends ConsumerWidget {
  const FraisScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Frais de scolarité',
        child: _Body(),
      );
}

class _Body extends ConsumerWidget {
  const _Body();

  int _maxOf(List<FeeStructure> all, String type) {
    final v = all.where((f) => f.feeType == type).map((f) => f.amount);
    return v.isEmpty ? 0 : v.reduce((a, b) => a > b ? a : b);
  }

  /// Les frais annexes se CUMULENT — cantine, transport, tenue sont trois
  /// choses, toutes dues (migration 0108). En afficher le maximum, comme pour
  /// les autres types, annoncerait le plus cher des trois au lieu de leur
  /// somme : le seul chiffre qui intéresse une famille du privé.
  int _sommeAnnexes(List<FeeStructure> all) => all
      .where((f) => f.feeType == 'autre')
      .fold(0, (a, f) => a + f.amount);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feeStructuresProvider);

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(messageErreur(e))),
      data: (all) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const VsHeader(
              title: 'Barèmes de frais',
              subtitle: 'Tarifs définis par le ministère · consultation',
            ),
            const SizedBox(height: 20),
            VsHeroKpis(cards: [
              (Icons.request_quote_rounded, 'Barèmes', '${all.length}', kNavy,
                  'applicables'),
              (Icons.how_to_reg_rounded, 'Inscription',
                  fmtCompact(_maxOf(all, 'inscription')),
                  const Color(0xFF0EA5E9), 'FCFA'),
              (Icons.event_repeat_rounded, 'Mensualité',
                  fmtCompact(_maxOf(all, 'mensualite')), kGreen, 'FCFA / mois'),
              (Icons.school_rounded, 'Examens',
                  fmtCompact(_maxOf(all, 'frais_examens')),
                  const Color(0xFF8B5CF6), 'FCFA'),
              // Une carte de PLUS, jamais à la place d'une autre : masquer les
              // examens dès qu'une école déclare une cantine lui retirerait un
              // chiffre qu'elle lisait la veille.
              if (_sommeAnnexes(all) > 0)
                (Icons.local_dining_rounded, 'Frais annexes',
                    fmtCompact(_sommeAnnexes(all)), kAccent, 'FCFA · total'),
            ]),
            const SizedBox(height: 18),
            if (all.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                // ⚠️ L'état vide doit DÉSIGNER QUI AGIT. Laisser l'école devant
                // un mur, c'est la pousser à encaisser hors système — ce qui
                // revient à ne rien encaisser du tout.
                child: AdminEmptyState(
                  icon: Icons.request_quote_outlined,
                  title: 'Aucun tarif pour cette année',
                  message:
                      'Les frais de scolarité sont fixés par le ministère. Tant '
                      'qu\'aucun tarif n\'est publié, aucun encaissement n\'est '
                      'possible. Rapprochez-vous de votre administration de '
                      'tutelle.',
                ),
              )
            else
              for (final f in all) _FeeCard(fee: f),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({required this.fee});
  final FeeStructure fee;

  /// D'où vient ce tarif. L'école ne peut rien y changer, mais elle a le droit
  /// de savoir si le montant vaut pour tout le réseau ou seulement pour elle —
  /// c'est la première question posée quand un parent conteste.
  Widget _puceScope(BaremeScope s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: (s == BaremeScope.reseau ? kNavy : kAccent)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          s == BaremeScope.reseau ? 'Réseau' : 'Établissement',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: s == BaremeScope.reseau ? kNavy : kAccent,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final f = fee;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.request_quote_rounded, size: 20, color: kNavy),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(feeTypeLabel(f.feeType),
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: kNavy)),
                  ),
                  const SizedBox(width: 6),
                  _puceScope(f.scope),
                ]),
                const SizedBox(height: 3),
                Text(
                    '${f.levelName ?? 'Toute l\'école'}'
                    '${f.dueDay != null ? ' · échéance le ${f.dueDay}' : ''}',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
                if (f.sourceReference != null &&
                    f.sourceReference!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(f.sourceReference!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: kTextMuted)),
                  ),
              ]),
        ),
        Text(fmtXaf(f.amount),
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: kGreen)),
        const SizedBox(width: 12),
      ]),
    );
  }
}
