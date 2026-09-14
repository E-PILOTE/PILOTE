import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/registre_provider.dart';
import '../services/registre_documents.dart';
import '../services/registre_documents_pdf_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  REGISTRE DES DOCUMENTS DÉLIVRÉS
//
//  ── POURQUOI SOUS `documents`, ET PAS DANS UN MODULE À LUI ────────────────
//  La route est `/user/documents/registre`. `moduleSlugForLocation()` reconnaît
//  les sous-chemins : elle rend `documents`, et l'écran hérite donc du même
//  verrou que les pièces du dossier — sans une ligne de plus au catalogue, ni
//  une entrée de plus dans une barre latérale déjà longue.
//
//  C'est aussi juste sur le fond : `documents` suit les pièces que l'école
//  REÇOIT, ce registre celles qu'elle ÉMET. Les deux faces d'un même métier,
//  tenues par les mêmes mains.
//
//  ── CE QU'IL RÉPOND ───────────────────────────────────────────────────────
//  « Qui a délivré ce certificat, et quand ? » — la question qu'on pose après
//  coup, quand un papier revient contesté. Et « cet élève a-t-il déjà eu une
//  carte ? », la question des duplicatas, qu'on pose au guichet, tout de suite.
// ════════════════════════════════════════════════════════════════════════════
class RegistreDocumentsScreen extends ConsumerWidget {
  const RegistreDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ModuleScaffold(
        slug: 'documents',
        title: 'Documents délivrés',
        onBack: () => Navigator.of(context).maybePop(),
        child: const _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _recherche = TextEditingController();
  String _type = 'tous';

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  /// Ce que le PDF doit ANNONCER, pour qu'un extrait ne passe pas pour le
  /// registre entier. `null` quand rien n'est filtré.
  String? get _libelleFiltre {
    final q = _recherche.text.trim();
    final morceaux = [
      if (_type != 'tous') libelleTypeDocument(_type),
      if (q.isNotEmpty) 'recherche « $q »',
    ];
    return morceaux.isEmpty ? null : 'Extrait filtré — ${morceaux.join(' · ')}';
  }

  void _apercu(List<DocumentEmis> vus) {
    if (vus.isEmpty) return;
    final filtre = _libelleFiltre;
    showPdfPreviewDialog(
      context,
      title: 'Registre des délivrances',
      subtitle: '${vus.length} délivrance${vus.length > 1 ? 's' : ''}'
          '${filtre != null ? ' · extrait filtré' : ''}',
      pdfFileName: 'Registre_delivrances.pdf',
      build: (_) =>
          RegistreDocumentsPdfService.buildPdf(lignes: vus, filtre: filtre),
      onDownload: () =>
          RegistreDocumentsPdfService.download(lignes: vus, filtre: filtre),
    );
  }

  List<DocumentEmis> _filtrer(List<DocumentEmis> tous) {
    final q = _recherche.text.trim().toLowerCase();
    return tous.where((d) {
      if (_type != 'tous' && d.documentType != _type) return false;
      if (q.isEmpty) return true;
      return d.recipientName.toLowerCase().contains(q) ||
          (d.issuedByName ?? '').toLowerCase().contains(q) ||
          (d.recipientRef ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(registreDocumentsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: AdminErrorBanner(message: '$e'),
      ),
      data: (tous) {
        if (tous.isEmpty) {
          return const AdminEmptyState(
            icon: Icons.history_edu_outlined,
            title: 'Aucun document délivré pour le moment',
            message: 'Chaque certificat de scolarité, certificat de radiation, '
                "carte scolaire ou attestation de travail produit par l'école "
                "s'inscrit ici automatiquement, avec l'agent qui l'a délivré.",
          );
        }

        final vus = _filtrer(tous);
        return Column(
          children: [
            _Filtres(
              controleur: _recherche,
              type: _type,
              onType: (t) => setState(() => _type = t),
              onRecherche: () => setState(() {}),
              total: tous.length,
              affiches: vus.length,
              onExportPdf: vus.isEmpty ? null : () => _apercu(vus),
            ),
            Divider(height: 1, color: kBorder),
            Expanded(
              child: vus.isEmpty
                  ? const AdminEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucune ligne ne correspond',
                      message: 'Modifiez la recherche ou le type de document.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      itemCount: vus.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: kBorder),
                      itemBuilder: (_, i) => _Ligne(vus[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Filtres extends StatelessWidget {
  const _Filtres({
    required this.controleur,
    required this.type,
    required this.onType,
    required this.onRecherche,
    required this.total,
    required this.affiches,
    this.onExportPdf,
  });

  final TextEditingController controleur;
  final String type;
  final ValueChanged<String> onType;
  final VoidCallback onRecherche;
  final int total, affiches;
  final VoidCallback? onExportPdf;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controleur,
              onChanged: (_) => onRecherche(),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                hintText: 'Nom du bénéficiaire, classe, agent…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: type,
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem(value: 'tous', child: Text('Tous types')),
              for (final t in TypeDocument.tous)
                DropdownMenuItem(value: t, child: Text(libelleTypeDocument(t))),
            ],
            onChanged: (v) => onType(v ?? 'tous'),
          ),
          const SizedBox(width: 12),
          AdminBadge(
            affiches == total ? '$total' : '$affiches / $total',
            color: kNavy,
            icon: Icons.receipt_long_rounded,
          ),
          if (onExportPdf != null) ...[
            const SizedBox(width: 12),
            AdminPdfButton(onTap: onExportPdf!),
          ],
        ]),
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.d);
  final DocumentEmis d;

  static final _quand = DateFormat('dd/MM/yyyy · HH:mm', 'fr');

  Color get _couleur => switch (d.documentType) {
        TypeDocument.certificatScolarite => kGreen,
        TypeDocument.certificatRadiation => kRed,
        TypeDocument.carteScolaire => kNavy,
        TypeDocument.attestationTravail => kAccent,
        _ => kTextMuted,
      };

  IconData get _icone => switch (d.documentType) {
        TypeDocument.certificatScolarite => Icons.workspace_premium_outlined,
        TypeDocument.certificatRadiation => Icons.logout_rounded,
        TypeDocument.carteScolaire => Icons.badge_outlined,
        TypeDocument.attestationTravail => Icons.work_outline_rounded,
        _ => Icons.description_outlined,
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _couleur.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_icone, size: 17, color: _couleur),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.recipientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  [
                    libelleTypeDocument(d.documentType),
                    if (d.recipientRef != null && d.recipientRef!.isNotEmpty)
                      d.recipientRef!,
                    if (d.purpose != null && d.purpose!.isNotEmpty) d.purpose!,
                  ].join(' · '),
                  maxLines: 2,
                  style: TextStyle(fontSize: 12, color: kTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_quand.format(d.issuedAt),
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              const SizedBox(height: 2),
              // Le nom FIGÉ à l'émission : l'agent a pu quitter l'école depuis,
              // le registre doit continuer de dire qui a signé ce jour-là.
              Text(d.issuedByName ?? 'agent inconnu',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: kNavy,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ]),
      );
}
