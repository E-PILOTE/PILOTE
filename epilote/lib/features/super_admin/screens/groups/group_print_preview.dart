part of '../school_groups_screen.dart';

// Aperçu avant impression de la liste.

class _PrintPreviewModal extends StatefulWidget {
  const _PrintPreviewModal({required this.group});
  final GroupDetail group;

  @override
  State<_PrintPreviewModal> createState() => _PrintPreviewModalState();
}

class _PrintPreviewModalState extends State<_PrintPreviewModal> {
  bool _printing    = false;
  bool _downloading = false;

  GroupDetail get g => widget.group;

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    try {
      await GroupPdfService.printGroup(g);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Impression')),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _handleDownload() async {
    setState(() => _downloading = true);
    try {
      final path = await GroupPdfService.downloadGroup(g);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(
            path != null ? 'PDF sauvegardé : $path' : 'PDF généré',
            overflow: TextOverflow.ellipsis,
          )),
        ]),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Téléchargement')),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _copyToClipboard(BuildContext context) {
    final g = widget.group;
    final now = DateFormat('dd/MM/yyyy HH:mm', 'fr').format(DateTime.now());
    final lines = [
      '════════════════════════════════════════',
      '  E-PILOTE CONGO — FICHE OFFICIELLE',
      '  Groupe Scolaire • Générée le $now',
      '════════════════════════════════════════',
      '',
      '  ${g.name.toUpperCase()}',
      '  Statut : ${g.statusLabel}  |  Type : ${g.groupTypeLabel}  |  Plan : ${g.planName}',
      if (g.foundedYear != null) '  Fondé en : ${g.foundedYear}',
      '',
      '── COORDONNÉES ──────────────────────────',
      '  Email       : ${g.adminEmail}',
      '  Téléphone   : ${g.phone ?? '—'}',
      '  Département : ${g.department ?? '—'}',
      '  Adresse     : ${g.address ?? '—'}',
      '',
      '── ABONNEMENT ───────────────────────────',
      '  Plan        : ${g.planName}',
      '  Tarif       : ${_fmtXaf(g.priceXaf.toDouble())} / ${g.periodSuffix}',
      if (g.subscriptionStart != null)
        '  Début       : ${DateFormat('dd/MM/yyyy').format(g.subscriptionStart!)}',
      if (g.subscriptionEnd != null)
        '  Expiration  : ${DateFormat('dd/MM/yyyy').format(g.subscriptionEnd!)}',
      '',
      '── CAPACITÉ ─────────────────────────────',
      '  Écoles      : ${g.schoolCount} / ${g.maxSchools == -1 ? "Illimité" : "${g.maxSchools}"}',
      '  Élèves max  : ${g.maxStudents == -1 ? "Illimité" : "${g.maxStudents}"}',
      '',
      '── HISTORIQUE ───────────────────────────',
      '  Création    : ${DateFormat('dd MMMM yyyy', 'fr').format(g.createdAt)}',
      '  Mis à jour  : ${DateFormat('dd MMMM yyyy', 'fr').format(g.updatedAt)}',
      '',
      '════════════════════════════════════════',
      '  Document généré via E-PILOTE CONGO',
      '  Réf. : ${g.id.substring(0, 8).toUpperCase()}',
      '════════════════════════════════════════',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Fiche copiée dans le presse-papiers'),
      ]),
      backgroundColor: _kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final now  = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref_ = g.id.substring(0, 8).toUpperCase();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 820),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(children: [
          // ── Barre modale ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
            decoration: BoxDecoration(
              color: _kNavy,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_rounded,
                    color: Colors.white, size: 17),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fiche officielle du groupe',
                    style: TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w800)),
                Text('Réf. $ref_  •  $now',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10.5)),
              ]),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
              ),
            ]),
          ),

          // ── Aperçu PDF réel ────────────────────────────────────────────────
          Expanded(
            child: PdfPreview(
              build: (format) => GroupPdfService.buildPdf(g),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              maxPageWidth: 680,
              pdfFileName: 'Fiche_${g.name.replaceAll(' ', '_')}.pdf',
            ),
          ),

          // ── Footer actions ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(18)),
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              // Fermer
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.close_rounded, size: 13, color: _kMuted),
                      const SizedBox(width: 5),
                      Text('Fermer', style: TextStyle(
                          color: _kMuted, fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const Spacer(),
              // Copier texte
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => _copyToClipboard(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.copy_rounded, size: 13, color: _kMuted),
                      const SizedBox(width: 5),
                      Text('Copier', style: TextStyle(
                          color: _kMuted, fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Imprimer
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: _printing ? null : _handlePrint,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.06),
                      border: Border.all(color: _kNavy.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_printing)
                        SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kNavy))
                      else
                        Icon(Icons.print_rounded,
                            size: 14, color: _kNavy),
                      const SizedBox(width: 6),
                      Text(_printing ? 'Impression…' : 'Imprimer',
                          style: TextStyle(
                              color: _kNavy, fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Télécharger PDF
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: _downloading ? null : _handleDownload,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kNavy,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(
                        color: _kNavy.withValues(alpha: 0.30),
                        blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_downloading)
                        const SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.download_rounded,
                            size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(_downloading ? 'Génération…' : 'Télécharger PDF',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

// Couleur du point plan dans le dropdown
Color _planDotColor(String plan) => switch (plan.toLowerCase()) {
  String p when p.contains('premium')       => _kGold,
  String p when p.contains('pro')           => _kNavy,
  String p when p.contains('institution')   => _kPurple,
  String p when p.contains('gratuit')       => _kMuted,
  _                                          => _kGreen,
};

/// Icône du SECTEUR. Deux valeurs, comme l'enum.
IconData _typeIcon(String secteur) =>
    secteur == 'public' ? Icons.account_balance_rounded : Icons.business_rounded;

/// Icône du CARACTÈRE — l'autre axe. Les trois symboles confessionnels
/// vivaient dans `_typeIcon`, pour des valeurs de secteur qui n'existaient pas.
IconData iconeCaractere(String? c) => switch (c) {
      'catholique' => Icons.church_rounded,
      'islamique'  => Icons.mosque_rounded,
      'protestant' => Icons.volunteer_activism_rounded,
      'laic'       => Icons.balance_rounded,
      _            => Icons.groups_rounded,
    };

// Label de section minimaliste
