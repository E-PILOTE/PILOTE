import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/billing_period.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/fiche_detail.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/economie_provider.dart';
import 'economie/economie_chrome.dart';

part 'economie/economie_kpi_detail.dart';
part 'economie/cout_form_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉCONOMIE DE LA PLATEFORME
//
//  Ce qui rentre, ce qui sort, l'écart. Trois nombres qu'aucun écran ne
//  rapprochait — et qu'on ne peut pas fixer un prix sans avoir sous les yeux.
//
//  ── LE NOMBRE QUI COMPTE ──────────────────────────────────────────────────
//  Le SEUIL : combien de groupes mono-école couvrent l'infrastructure. Ce
//  n'est pas une projection, c'est le seuil de survie, et il tient en une
//  phrase que tout le monde comprend.
//
//  ── ⚠️ CE N'EST PAS UNE COMPTABILITÉ ──────────────────────────────────────
//  L'écran le DIT. Il ignore les impayés, les délais d'encaissement et tout
//  ce qui n'a pas été saisi. Un tableau qui se donnerait pour un résultat comptable ferait
//  prendre des décisions sur un chiffre faux.
//
//  ⚠️ Écran de FONDATEUR. `platform_costs` est fermée au super_admin par RLS ;
//  aucun groupe scolaire ne voit jamais ce que coûte l'infrastructure.
// ════════════════════════════════════════════════════════════════════════════

class EconomieScreen extends ConsumerWidget {
  const EconomieScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const AppShell(
        title: 'Économie de la plateforme',
        child: _Corps(),
      );
}

class _Corps extends ConsumerWidget {
  const _Corps();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(economieProvider);
    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const ListShimmer(),
      error: (e, _) => _Erreur(
        message: messageErreur(e, contexte: 'Économie'),
        onRetry: () => ref.invalidate(economieProvider),
      ),
      data: (d) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KpiGrid(items: _kpis(context, ref, d)),
            const SizedBox(height: 12),
            const _Avertissement(),
            const SizedBox(height: 24),
            _SectionCouts(data: d),
          ],
        ),
      ),
    );
  }

  List<KpiData> _kpis(BuildContext context, WidgetRef ref, EconomieData d) {
    final marge = d.margeMensuelleXaf;
    final taux = d.tauxMarge;
    // 30 000 XAF = le tarif du plan Standard pour une école (migration 0159).
    final seuil = d.seuilEnGroupes(30000);
    return [
      KpiData(
        label: 'Abonnements',
        value: fmtXaf(d.mrrAbonnementsXaf),
        sub: 'par mois, groupes actifs',
        icon: Icons.school_rounded,
        color: kNavy,
        onTap: () => _ouvrirDetailRevenu(context, d),
      ),
      KpiData(
        label: 'Coût d\'exploitation',
        value: fmtXaf(d.coutMensuelXaf),
        // La phrase qui rend le chiffre utilisable.
        sub: '$seuil groupe${seuil > 1 ? 's' : ''} mono-école le couvre'
            '${seuil > 1 ? 'nt' : ''}',
        icon: Icons.dns_rounded,
        color: kListOrange,
        onTap: () => _ouvrirDetailCouts(context, d),
      ),
      KpiData(
        label: 'Marge mensuelle',
        value: fmtXaf(marge),
        sub: taux == null ? 'aucune recette' : '${taux.round()} % du revenu',
        icon: marge >= 0
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        color: marge >= 0 ? kGreen : kRed,
        onTap: () => _ouvrirDetailMarge(context, d),
      ),
    ];
  }
}

class _Avertissement extends StatelessWidget {
  const _Avertissement();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 15, color: kTextMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Ordre de grandeur d\'exploitation, pas une comptabilité : les '
              'impayés et les délais d\'encaissement ne sont pas comptés.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
            ),
          ),
        ]),
      );
}

// ─── Coûts ──────────────────────────────────────────────────────────────────

class _SectionCouts extends ConsumerWidget {
  const _SectionCouts({required this.data});
  final EconomieData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EnTeteSection(
            titre: 'Coûts d\'exploitation',
            sousTitre: 'Le montant qui fait foi est celui réellement débité en '
                'FCFA. Aucun taux de change n\'est stocké : figé en base, il '
                'devient faux le mois suivant sans que personne ne le voie.',
            boutonLabel: 'Nouveau coût',
            onAjouter: () => _ouvrirCout(context, ref),
          ),
          const SizedBox(height: 12),
          if (data.couts.isEmpty)
            const _VideSection(texte: 'Aucun coût saisi.')
          else
            Container(
              decoration: BoxDecoration(
                color: kCardBg,
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                for (var i = 0; i < data.couts.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _LigneCout(cout: data.couts[i]),
                ],
              ]),
            ),
        ],
      );
}

class _LigneCout extends ConsumerWidget {
  const _LigneCout({required this.cout});
  final CoutPlateforme cout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cout;
    return InkWell(
      onTap: () => _ouvrirCout(context, ref, edition: c),
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(_iconeCategorie(c.categorie),
              size: 17, color: c.isActive ? kNavy : kTextMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(c.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.isActive ? kTextPrimary : kTextMuted)),
                    if (!c.isActive) ...[
                      const SizedBox(width: 8),
                      PuceEconomie(texte: 'INACTIF', couleur: kTextMuted),
                    ],
                  ]),
                  if (c.notes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(c.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: kTextMuted, height: 1.35)),
                    ),
                ]),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${fmtXaf(c.mensuelXaf)} / mois',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            if (c.montantOrigine != null && c.deviseOrigine != null)
              Text(
                  '${c.montantOrigine!.toStringAsFixed(2)} ${c.deviseOrigine} '
                  '/ ${billingPeriodSuffix(c.periodicite)}',
                  style: TextStyle(fontSize: 10.5, color: kTextMuted)),
          ]),
        ]),
      ),
    );
  }
}

Future<void> _ouvrirCout(BuildContext context, WidgetRef ref,
    {CoutPlateforme? edition}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _CoutFormDialog(edition: edition),
  );
  ref.invalidate(economieProvider);
}

// ─── Éléments partagés ──────────────────────────────────────────────────────

class _EnTeteSection extends StatelessWidget {
  const _EnTeteSection({
    required this.titre,
    required this.sousTitre,
    required this.boutonLabel,
    required this.onAjouter,
  });

  final String titre, sousTitre, boutonLabel;
  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(sousTitre,
                      style: TextStyle(
                          fontSize: 11.5, color: kTextMuted, height: 1.45)),
                ]),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: onAjouter,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(boutonLabel),
          ),
        ],
      );
}

class _VideSection extends StatelessWidget {
  const _VideSection({required this.texte});
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(texte,
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5)),
      );
}


class _Erreur extends StatelessWidget {
  const _Erreur({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 36, color: Color(0xFFEF4444)),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Réessayer'),
            ),
          ]),
        ),
      );
}

IconData _iconeCategorie(String c) => switch (c) {
      'base_de_donnees' => Icons.storage_rounded,
      'synchronisation' => Icons.sync_rounded,
      'stockage' => Icons.folder_rounded,
      'domaine' => Icons.language_rounded,
      'messagerie' => Icons.mail_rounded,
      'boutique' => Icons.store_rounded,
      _ => Icons.receipt_long_rounded,
    };
