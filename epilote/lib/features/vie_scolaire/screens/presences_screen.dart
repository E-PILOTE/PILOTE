import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/bandeau_jour_non_ouvre.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_provider.dart'
    show currentSchoolProvider;
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/assiduite_mensuelle_provider.dart';
import '../services/assiduite_pdf_service.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/presences_provider.dart';
import '../widgets/vs_kit.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/utils/date_scolaire.dart';

part 'presences_roll.dart';

const _kSlug = kSlugPresences;

// ════════════════════════════════════════════════════════════════════════════
//  PRÉSENCES ÉLÈVES — appel quotidien. En-tête (date + période AM/PM) → KPI hero
//  (présents / absents / retards / classes faites) → panneau Cycle ▸ Niveau ▸
//  Classe (couverture de l'appel) → couverture par classe ; ouvrir une classe =
//  feuille d'appel (présent/absent/retard, heure, justification, finaliser).
// ════════════════════════════════════════════════════════════════════════════
class PresencesScreen extends ConsumerWidget {
  const PresencesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Présences',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  DateTime _date = DateTime.now();
  String _period = 'AM';
  ScopeSel _scope = const ScopeSel();
  String? _openClassId;

  String get _dateKey => _date.toIso8601String().substring(0, 10);
  String get _dateLabel =>
      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
  AttendanceDay get _day => (date: _dateKey, period: _period);

  String? get _activeClassId => _openClassId ?? _scope.classId;

  Future<void> _pickDate() async {
    final picked = await choisirDateScolaire(context, ref,
        initiale: _date, plafond: DateTime.now().add(const Duration(days: 1)));
    if (picked != null) {
      setState(() {
        _date = picked;
        _scope = const ScopeSel();
        _openClassId = null;
      });
    }
  }

  void _openRoll(VsCoverageRow r) {
    // ⚠️ POINTER, C'EST INSÉRER PUIS METTRE À JOUR. Le premier appui sur un
    // élève non pointé fait un INSERT, que la base réserve au verbe `create`
    // (RLS). Garder l'écran sur le seul `update` laissait un profil doté
    // d'`update` sans `create` voir une feuille active, appuyer, et recevoir un
    // 42501 — code FATAL pour le connecteur : le LOT ENTIER en attente est
    // jeté. Les deux moitiés doivent bouger ensemble.
    final readOnly = ref.read(yearReadOnlyProvider);
    final canEdit = ref.read(canProvider((slug: _kSlug, action: 'create'))) &&
        ref.read(canProvider((slug: _kSlug, action: 'update'))) &&
        !readOnly;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RollSheet(
        args: (classId: r.classId, date: _dateKey, period: _period),
        className: r.className,
        breadcrumb: vsCrumb(r.cycleCode, r.levelCode),
        dateLabel: '$_dateLabel · ${_period == 'AM' ? 'Matin' : 'Après-midi'}',
        canEdit: canEdit,
        onChanged: () => ref.invalidate(attendanceOverviewProvider(_day)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(attendanceOverviewProvider(_day));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        VsHeader(
          title: 'Appel du jour',
          subtitle: 'Présences par cycle, niveau et classe',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            VsPickerBox(
              icon: Icons.event_rounded,
              width: 180,
              onTap: _pickDate,
              child: Text(_dateLabel,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
            const SizedBox(width: 10),
            _PeriodToggle(
              period: _period,
              onChange: (p) => setState(() {
                _period = p;
                _scope = const ScopeSel();
                _openClassId = null;
              }),
            ),
            const SizedBox(width: 10),
            // LE RELEVE DU MOIS. L'appel etait saisi chaque jour et totalise
            // nulle part : l'ecole detenait la donnee et devait la recompter a
            // la main pour la circonscription. Le mois est celui de la date
            // affichee -- le selecteur de date sert deja a le choisir.
            _BoutonReleve(
              mois: (annee: _date.year, mois: _date.month),
              libelle: libelleMois((annee: _date.year, mois: _date.month)),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // Un dimanche, un jour férié ou une date hors année scolaire, l'écran
        // listait les classes avec « 0 appel fait » — un reproche pour un
        // travail qui n'avait pas lieu d'être. Il le dit maintenant.
        BandeauJourNonOuvre(date: _date),
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

  Widget _content(AttendanceOverview ov) {
    if (ov.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: AdminEmptyState(
          icon: Icons.fact_check_outlined,
          title: 'Aucune classe',
          message: 'Aucune classe active dans votre périmètre cette année.',
        ),
      );
    }
    final rate = ov.recorded == 0
        ? 0
        : (ov.present + ov.late) * 100 ~/ ov.recorded;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VsHeroKpis(cards: [
        (Icons.how_to_reg_rounded, 'Présents', '${ov.present}', kGreen,
            '$rate% des pointés'),
        (Icons.person_off_rounded, 'Absents', '${ov.absent}',
            ov.absent == 0 ? kTextMuted : kRed, 'à justifier'),
        (Icons.timelapse_rounded, 'Retards', '${ov.late}',
            ov.late == 0 ? kTextMuted : const Color(0xFFF59E0B), null),
        (Icons.checklist_rounded, 'Appels faits',
            '${ov.classesDone}/${ov.classesTotal}', kNavy, 'classes finalisées'),
      ]),
      const SizedBox(height: 16),
      ScopeDrilldownPanel(
        title: 'Couverture de l\'appel',
        metricLabel: 'Pointés',
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
      VsSectionLabel(
          icon: Icons.touch_app_rounded,
          text: _activeClassId == null
              ? 'Ouvrez une classe pour faire l\'appel'
              : 'Appel — ${_nameOf(ov, _activeClassId!)}'),
      const SizedBox(height: 12),
      VsCoverageList(
        rows: vsFilterScope(ov.rows, _scope),
        metricLabel: 'pointés',
        openLabel: 'Faire l\'appel',
        onOpen: _openRoll,
      ),
    ]);
  }

  String _nameOf(AttendanceOverview ov, String classId) => ov.rows
      .where((r) => r.classId == classId)
      .map((r) => r.className)
      .firstOrNull ??
      '';
}

// ─── Bascule AM / PM ─────────────────────────────────────────────────────────
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChange});
  final String period;
  final ValueChanged<String> onChange;
  @override
  Widget build(BuildContext context) {
    Widget seg(String code, String label) {
      final sel = period == code;
      return InkWell(
        onTap: () => onChange(code),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : kTextMuted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('AM', 'Matin'),
        seg('PM', 'Après-midi'),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  LE RELEVÉ MENSUEL — la sortie qui manquait à un calcul qui existait
//
//  `attendanceOverviewProvider` répond à « où en est l'appel CE MATIN ». La
//  circonscription, elle, demande le relevé DU MOIS. Il était calculable et
//  n'était calculé nulle part : l'école recomptait à la main.
//
//  ⚠️ Le bouton suit `export`, pas `update` : produire l'état est une lecture.
//  Un enseignant qui pointe sans droit d'export ne le voit pas ; un directeur
//  qui ne pointe jamais le voit.
// ════════════════════════════════════════════════════════════════════════════
class _BoutonReleve extends ConsumerWidget {
  const _BoutonReleve({required this.mois, required this.libelle});

  final MoisScolaire mois;
  final String libelle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canProvider((slug: _kSlug, action: 'export')))) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: 'Relevé d\'assiduité de $libelle — par classe, plus les élèves '
          'à suivre',
      child: OutlinedButton.icon(
        onPressed: () => _ouvrir(context, ref),
        icon: const Icon(Icons.summarize_outlined, size: 16),
        label: const Text('Relevé du mois'),
        style: OutlinedButton.styleFrom(foregroundColor: kNavy),
      ),
    );
  }

  Future<void> _ouvrir(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final EtatAssiduiteMensuel etat;
    try {
      etat = await ref.read(assiduiteMensuelleProvider(mois).future);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(messageErreur(e)), backgroundColor: kRed));
      return;
    }
    if (!context.mounted) return;

    // ⚠️ « Je ne sais pas » n'est pas « zéro ». Tant que le périmètre n'est
    // pas chargé, produire le document donnerait un état VIDE qui se lit
    // comme un établissement sans aucune classe.
    if (!etat.perimetreCharge) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Vos droits d\'accès chargent encore — réessayez '
              'dans un instant.')));
      return;
    }

    final school =
        ref.read(currentSchoolProvider).valueOrNull?['name'] as String?;
    final year = ref.read(activeYearProvider)?.label;

    showPdfPreviewDialog(
      context,
      title: 'Relevé d\'assiduité — $libelle',
      // Le sous-titre dit la VÉRITÉ du document avant de l'ouvrir : un mois
      // sans aucun appel se signale ici, pas seulement à la page 1.
      subtitle: etat.aucunPointage
          ? 'Aucun appel enregistré ce mois-ci'
          : '${etat.classes.length} classe(s) · ${etat.demiJournees} '
              'demi-journée(s) d\'appel'
              '${etat.alertes.isEmpty ? '' : ' · ${etat.alertes.length} élève(s) à suivre'}',
      pdfFileName:
          'Assiduite_${mois.annee}-${mois.mois.toString().padLeft(2, '0')}.pdf',
      build: (_) => AssiduitePdfService.buildPdf(
          etat: etat, schoolName: school, yearLabel: year),
      onDownload: () => AssiduitePdfService.downloadDoc(
          etat: etat, schoolName: school, yearLabel: year),
    );
  }
}
