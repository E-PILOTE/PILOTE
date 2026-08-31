import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/billing_period.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/economie_provider.dart';

part 'economie/licence_form_dialog.dart';
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
//  L'écran le DIT. Il ignore les impayés, les délais d'encaissement — un
//  marché public se règle en mois, parfois en année — et tout ce qui n'a pas
//  été saisi. Un tableau qui se donnerait pour un résultat comptable ferait
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
            KpiGrid(items: _kpis(d)),
            const SizedBox(height: 12),
            const _Avertissement(),
            const SizedBox(height: 24),
            _SectionLicences(data: d),
            const SizedBox(height: 24),
            _SectionCouts(data: d),
          ],
        ),
      ),
    );
  }

  List<KpiData> _kpis(EconomieData d) {
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
      ),
      KpiData(
        label: 'Licences de tutelle',
        value: fmtXaf(d.mrrLicencesXaf),
        sub: d.soldeDuXaf > 0
            ? '${fmtXaf(d.soldeDuXaf)} restant à encaisser'
            : 'par mois, licences actives',
        icon: Icons.account_balance_rounded,
        color: const Color(0xFF7C3AED),
      ),
      KpiData(
        label: 'Coût d\'exploitation',
        value: fmtXaf(d.coutMensuelXaf),
        // La phrase qui rend le chiffre utilisable.
        sub: '$seuil groupe${seuil > 1 ? 's' : ''} mono-école le couvre'
            '${seuil > 1 ? 'nt' : ''}',
        icon: Icons.dns_rounded,
        color: const Color(0xFFFF6B35),
      ),
      KpiData(
        label: 'Marge mensuelle',
        value: fmtXaf(marge),
        sub: taux == null ? 'aucune recette' : '${taux.round()} % du revenu',
        icon: marge >= 0
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        color: marge >= 0 ? kGreen : const Color(0xFFEF4444),
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
              'impayés et les délais d\'encaissement ne sont pas comptés — un '
              'marché public se règle en mois, parfois en année.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
            ),
          ),
        ]),
      );
}

// ─── Licences ───────────────────────────────────────────────────────────────

class _SectionLicences extends ConsumerWidget {
  const _SectionLicences({required this.data});
  final EconomieData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EnTeteSection(
            titre: 'Licences annuelles de tutelle',
            sousTitre: 'Ce qu\'un ministère achète pour SUPERVISER son réseau — '
                'distinct de l\'abonnement de ses propres écoles.',
            boutonLabel: 'Nouvelle licence',
            onAjouter: () => _ouvrirLicence(context, ref),
          ),
          const SizedBox(height: 12),
          if (data.licences.isEmpty)
            const _VideSection(
                texte: 'Aucune licence enregistrée. Les montants sont libres et '
                    'modifiables à tout moment : un marché se négocie, se révise '
                    'par avenant et se règle en tranches.')
          else
            for (final l in data.licences) ...[
              _CarteLicence(licence: l),
              const SizedBox(height: 10),
            ],
        ],
      );
}

class _CarteLicence extends ConsumerWidget {
  const _CarteLicence({required this.licence});
  final LicenceTutelle licence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = licence;
    final couleur = _couleurStatut(l.statut);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _Puce(texte: _labelStatut(l.statut), couleur: couleur),
              if (l.referenceMarche != null) ...[
                const SizedBox(width: 8),
                Text(l.referenceMarche!,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: kTextMuted)),
              ],
            ]),
            const SizedBox(height: 6),
            Text(l.groupeNom,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              '${l.intitule} · du ${_d(l.dateDebut)} au ${_d(l.dateFin)}'
              '${l.estActive && l.joursRestants >= 0 ? ' · ${l.joursRestants} j restants' : ''}',
              style: TextStyle(fontSize: 11.5, color: kTextMuted),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtXaf(l.montantXaf),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            Text('${fmtXaf(l.mensuelXaf)} / mois',
                style: TextStyle(fontSize: 11, color: kTextMuted)),
            const SizedBox(height: 6),
            // ⚠️ Le solde est AFFICHÉ même à zéro : « réglé » est une
            // information, et son absence se lirait comme un oubli de saisie.
            Text(
              l.soldeXaf == 0
                  ? 'Intégralement réglée'
                  : 'Reste ${fmtXaf(l.soldeXaf)}',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: l.soldeXaf == 0 ? kGreen : const Color(0xFFFF6B35)),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _ouvrirLicence(context, ref, edition: l),
          icon: const Icon(Icons.edit_rounded, size: 17),
          tooltip: 'Modifier',
        ),
      ]),
    );
  }
}

Future<void> _ouvrirLicence(BuildContext context, WidgetRef ref,
    {LicenceTutelle? edition}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _LicenceFormDialog(edition: edition),
  );
  ref.invalidate(economieProvider);
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
                      _Puce(texte: 'INACTIF', couleur: kTextMuted),
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

class _Puce extends StatelessWidget {
  const _Puce({required this.texte, required this.couleur});
  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(texte,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
                color: couleur)),
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

Color _couleurStatut(String s) => switch (s) {
      'active' => kGreen,
      'echue' => const Color(0xFFFF6B35),
      'resiliee' => const Color(0xFFEF4444),
      _ => kTextMuted,
    };

String _labelStatut(String s) => switch (s) {
      'active' => 'ACTIVE',
      'echue' => 'ÉCHUE',
      'resiliee' => 'RÉSILIÉE',
      _ => 'BROUILLON',
    };

IconData _iconeCategorie(String c) => switch (c) {
      'base_de_donnees' => Icons.storage_rounded,
      'synchronisation' => Icons.sync_rounded,
      'stockage' => Icons.folder_rounded,
      'domaine' => Icons.language_rounded,
      'messagerie' => Icons.mail_rounded,
      'boutique' => Icons.store_rounded,
      _ => Icons.receipt_long_rounded,
    };

String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
