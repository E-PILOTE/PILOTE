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
import '../providers/frais_provider.dart';
import '../providers/paiements_provider.dart';

part 'paiements_sheet.dart';

const _kSlug = 'paiements-eleves';

// ════════════════════════════════════════════════════════════════════════════
//  PAIEMENTS ÉLÈVES — encaissements. KPI hero (encaissé, paiements, en attente,
//  élèves payeurs) → panneau Cycle ▸ Niveau ▸ Classe (recouvrement = élèves
//  ayant payé) → couverture par classe ; ouvrir = liste élèves (total payé) →
//  fiche élève (historique + nouveau paiement). 100% offline.
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

  void _openStudent(StudentPayRow r) {
    final readOnly = ref.read(yearReadOnlyProvider);
    final canEdit =
        ref.read(canProvider((slug: _kSlug, action: 'update'))) && !readOnly;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentPaymentsSheet(
        row: r,
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
              child: Center(child: Text('Erreur : $e'))),
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
    final rate = ov.students == 0 ? 0 : ov.payers * 100 ~/ ov.students;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VsHeroKpis(cards: [
        (Icons.account_balance_wallet_rounded, 'Encaissé',
            fmtCompact(ov.collected), kGreen, 'FCFA confirmés'),
        (Icons.receipt_long_rounded, 'Paiements', '${ov.confirmedCount}', kNavy,
            'confirmés'),
        (Icons.hourglass_bottom_rounded, 'En attente', '${ov.pendingCount}',
            ov.pendingCount == 0 ? kTextMuted : const Color(0xFFF59E0B),
            'à confirmer'),
        (Icons.groups_2_rounded, 'Élèves à jour', '${ov.payers}/${ov.students}',
            const Color(0xFF0EA5E9), '$rate% ont payé'),
      ]),
      const SizedBox(height: 16),
      ScopeDrilldownPanel(
        title: 'Recouvrement',
        metricLabel: 'Ont payé',
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
          metricLabel: 'ont payé',
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
  final ValueChanged<StudentPayRow> onOpen;
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
          error: (e, _) => Center(child: Text('Erreur : $e')),
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

  Widget _row(StudentPayRow r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: InkWell(
        onTap: () => widget.onOpen(r),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: (r.hasPaid ? kGreen : kTextMuted).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(
                  r.hasPaid ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 17,
                  color: r.hasPaid ? kGreen : kTextMuted),
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
                        r.count == 0
                            ? 'Aucun paiement'
                            : '${r.count} paiement${r.count > 1 ? 's' : ''}'
                                '${r.lastDate != null ? ' · dernier ${r.lastDate}' : ''}',
                        style: TextStyle(fontSize: 11.5, color: kTextMuted)),
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
