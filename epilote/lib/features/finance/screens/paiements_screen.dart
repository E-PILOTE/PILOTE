import '../../../core/utils/write_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../../vie_scolaire/widgets/vs_form_chrome.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/decompte_du_provider.dart';
import '../providers/paiements_provider.dart';
import '../services/obligation.dart';
import '../services/recu_pdf_service.dart';
import '../widgets/decompte_card.dart';
import 'paiements_remboursement.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/utils/date_scolaire.dart';

part 'paiements_sheet.dart';
part 'paiements_form.dart';

/// ⚠️ Une seule déclaration, dans le provider, à côté des requêtes que ce slug
/// borne. Le littéral était recopié ici : deux endroits à changer, un seul
/// changé, et le périmètre dérive sans bruit.
const _kSlug = kSlugPaiements;

// ════════════════════════════════════════════════════════════════════════════
//  PAIEMENTS ÉLÈVES — encaissements. KPI hero (encaissé, paiements, reste dû,
//  élèves à jour) → panneau Cycle ▸ Niveau ▸ Classe → couverture par classe ;
//  ouvrir = liste élèves (état + reste dû) → fiche élève (historique, nouveau
//  paiement, reçu, annulation). 100% offline.
//
//  ⚠️ « À jour » signifie « a SOLDÉ son dû », pas « a versé quelque chose ».
//  Sans aucun barème applicable, aucun taux n'est calculable : l'écran affiche
//  « Barème non défini » plutôt que 0 %.
// ════════════════════════════════════════════════════════════════════════════
class PaiementsScreen extends ConsumerWidget {
  const PaiementsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Paiements',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  ScopeSel _scope = const ScopeSel();
  String? _openClassId;

  String? get _activeClassId => _openClassId ?? _scope.classId;

  void _openStudent(StudentPayRow r, String className) {
    // ⚠️ ENCAISSER, C'EST INSÉRER — REMBOURSER ET ANNULER, C'EST METTRE À JOUR.
    // Un seul `canEdit`, lu sur `update`, ouvrait les trois. Or la RLS de
    // `student_payments` réserve l'INSERT au verbe `create` : un profil doté
    // d'`update` sans `create` voyait « Nouveau paiement », encaissait, et
    // recevait un 42501 — code FATAL pour le connecteur, qui jette le LOT
    // ENTIER en attente. Au guichet, ce lot, ce sont les encaissements de la
    // matinée. Les deux verbes se lisent donc séparément.
    final readOnly = ref.read(yearReadOnlyProvider);
    final canCreate =
        ref.read(canProvider((slug: _kSlug, action: 'create'))) && !readOnly;
    final canEdit =
        ref.read(canProvider((slug: _kSlug, action: 'update'))) && !readOnly;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentPaymentsSheet(
        row: r,
        className: className,
        canCreate: canCreate,
        canEdit: canEdit,
        onChanged: () => ref.invalidate(paymentsOverviewProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(paymentsOverviewProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const VsHeader(
          title: 'Encaissements',
          subtitle: 'Recouvrement par cycle, niveau et classe',
        ),
        const SizedBox(height: 20),
        overview.when(
          loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text(messageErreur(e)))),
          data: _content,
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _content(PaymentsOverview ov) {
    if (ov.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: AdminEmptyState(
          icon: Icons.payments_outlined,
          title: 'Aucune classe',
          message: 'Aucune classe active dans votre périmètre cette année.',
        ),
      );
    }
    // ⚠️ « À jour » = a soldé son dû, PAS « a versé quelque chose ». Sans
    // barème, aucun taux n'est calculable : l'annoncer à 0 % accuserait d'un
    // échec de collecte une école qui n'a rien à collecter (cf. spec §6.5).
    final rate = ov.students == 0 ? 0 : ov.aJour * 100 ~/ ov.students;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VsHeroKpis(cards: [
        (Icons.account_balance_wallet_rounded, 'Encaissé',
            fmtCompact(ov.collected), kGreen, 'FCFA confirmés'),
        (Icons.receipt_long_rounded, 'Paiements', '${ov.confirmedCount}', kNavy,
            'confirmés'),
        if (ov.sansBareme)
          (Icons.request_quote_outlined, 'Reste dû', '—', kTextMuted,
              libelleEtat(EtatObligation.sansBareme))
        else
          (Icons.request_quote_rounded, 'Reste dû', fmtCompact(ov.resteDu),
              ov.resteDu == 0 ? kGreen : const Color(0xFFF59E0B),
              'sur ${fmtCompact(ov.duTotal)} FCFA'),
        if (ov.sansBareme)
          (Icons.groups_2_rounded, 'Élèves à jour', '—', kTextMuted,
              libelleEtat(EtatObligation.sansBareme))
        else
          (Icons.groups_2_rounded, 'Élèves à jour',
              '${ov.aJour}/${ov.students}',
              const Color(0xFF0EA5E9), '$rate% ont soldé'),
      ]),
      const SizedBox(height: 16),
      // Sans barème, le panneau de recouvrement affiche « 0 à jour · 0 % » en
      // rouge et contredit l'en-tête. Ce bandeau lève l'ambiguïté et désigne
      // qui doit agir — l'école ne peut rien y faire, les barèmes appartiennent
      // au groupe (cf. spec D2).
      if (ov.sansBareme) ...[
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kAccent.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 18, color: kAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aucun barème de frais n\'est défini pour cette année. Tant '
                'qu\'il n\'y en a pas, aucun montant n\'est dû : les taux de '
                'recouvrement ci-dessous ne veulent rien dire.',
                style: TextStyle(fontSize: 12.5, color: kTextMuted),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
      ],
      ScopeDrilldownPanel(
        title: 'Recouvrement',
        metricLabel: 'À jour',
        unitNoun: 'élèves',
        selected: _scope,
        onSelect: (s) => setState(() {
          _scope = s;
          _openClassId = null;
        }),
        units: vsScopeUnits(ov.rows),
      ),
      if (_scope.active || _openClassId != null) ...[
        const SizedBox(height: 12),
        VsScopeChip(
          label: _activeClassId != null
              ? 'Classe : ${_nameOf(ov, _activeClassId!)}'
              : _scope.label,
          onClear: () => setState(() {
            _scope = const ScopeSel();
            _openClassId = null;
          }),
        ),
      ],
      const SizedBox(height: 18),
      if (_activeClassId != null)
        _ClassPayments(
          classId: _activeClassId!,
          className: _nameOf(ov, _activeClassId!),
          breadcrumb: _crumbOf(ov, _activeClassId!),
          onOpen: _openStudent,
        )
      else ...[
        const VsSectionLabel(
            icon: Icons.touch_app_rounded,
            text: 'Ouvrez une classe pour voir et enregistrer les paiements'),
        const SizedBox(height: 12),
        VsCoverageList(
          rows: vsFilterScope(ov.rows, _scope),
          metricLabel: 'à jour',
          openLabel: 'Ouvrir',
          onOpen: (r) => setState(() => _openClassId = r.classId),
        ),
      ],
    ]);
  }

  String _nameOf(PaymentsOverview ov, String classId) => ov.rows
          .where((r) => r.classId == classId)
          .map((r) => r.className)
          .firstOrNull ??
      '';
  String _crumbOf(PaymentsOverview ov, String classId) {
    final r = ov.rows.where((r) => r.classId == classId).firstOrNull;
    return r == null ? '' : vsCrumb(r.cycleCode, r.levelCode);
  }
}

// ─── Atelier d'une classe : élèves + total payé (recherche) ──────────────────
class _ClassPayments extends ConsumerStatefulWidget {
  const _ClassPayments({
    required this.classId,
    required this.className,
    required this.breadcrumb,
    required this.onOpen,
  });
  final String classId, className, breadcrumb;
  /// Le nom de la classe voyage avec l'élève : le reçu doit le porter, et la
  /// fiche seule ne le connaît pas.
  final void Function(StudentPayRow row, String className) onOpen;
  @override
  ConsumerState<_ClassPayments> createState() => _ClassPaymentsState();
}

class _ClassPaymentsState extends ConsumerState<_ClassPayments> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(classPaymentsProvider(widget.classId));
    return Container(
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.class_rounded, size: 18, color: kNavy),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.breadcrumb.isNotEmpty)
              Text(widget.breadcrumb,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted,
                      letterSpacing: 0.2)),
            Text(widget.className,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
          ]),
        ]),
        const SizedBox(height: 14),
        async.when(
          loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Text(messageErreur(e))),
          data: (rows) {
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: AdminEmptyState(
                  icon: Icons.group_off_outlined,
                  title: 'Aucun élève',
                  message: 'Cette classe n\'a pas d\'élève actif inscrit.',
                ),
              );
            }
            final q = _q.trim().toLowerCase();
            final filtered = q.isEmpty
                ? rows
                : [
                    for (final r in rows)
                      if (r.studentName.toLowerCase().contains(q) ||
                          (r.matricule ?? '').toLowerCase().contains(q))
                        r,
                  ];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (rows.length > 8) ...[
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Rechercher un élève parmi ${rows.length}…',
                    hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 19, color: kTextMuted),
                    filled: true,
                    fillColor: kCardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: kBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                      child: Text('Aucun élève trouvé',
                          style: TextStyle(color: kTextMuted))),
                )
              else
                for (final r in filtered) _row(r),
            ]);
          },
        ),
      ]),
    );
  }

  /// L'ambre de l'avance partielle est délibéré : ni le vert du soldé, ni le
  /// rouge de l'impayé. Un parent qui a versé la moitié n'est pas un mauvais
  /// payeur, et l'écran ne doit pas le désigner comme tel.
  Color _etatColor(EtatObligation e) => switch (e) {
        EtatObligation.aJour => kGreen,
        // Vert lui aussi : il n'y a rien à réclamer. Ce qui distingue les deux,
        // c'est l'icône — un boursier n'a pas « payé », il est dispensé.
        EtatObligation.exonere => kGreen,
        EtatObligation.partiel => const Color(0xFFF59E0B),
        EtatObligation.impaye => kRed,
        EtatObligation.sansBareme => kTextMuted,
      };

  IconData _etatIcon(EtatObligation e) => switch (e) {
        EtatObligation.aJour => Icons.check_circle_rounded,
        EtatObligation.exonere => Icons.volunteer_activism_rounded,
        EtatObligation.partiel => Icons.timelapse_rounded,
        EtatObligation.impaye => Icons.error_outline_rounded,
        EtatObligation.sansBareme => Icons.circle_outlined,
      };

  Widget _row(StudentPayRow r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: InkWell(
        onTap: () => widget.onOpen(r, widget.className),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: _etatColor(r.etat).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(_etatIcon(r.etat), size: 17, color: _etatColor(r.etat)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(
                        r.etat == EtatObligation.sansBareme
                            ? (r.count == 0
                                ? 'Aucun paiement'
                                : '${r.count} paiement${r.count > 1 ? 's' : ''}')
                            : '${libelleEtat(r.etat)}'
                                '${r.reste > 0 ? ' · reste ${fmtXaf(r.reste)}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: _etatColor(r.etat))),
                  ]),
            ),
            Text(r.paid == 0 ? '—' : fmtXaf(r.paid),
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: r.hasPaid ? kGreen : kTextMuted)),
            Icon(Icons.chevron_right_rounded, color: kTextMuted),
          ]),
        ),
      ),
    );
  }
}
