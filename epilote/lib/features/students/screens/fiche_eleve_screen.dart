import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/routes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/discipline_vocab.dart';
import '../../../core/utils/ine.dart';
import '../../../core/utils/mention.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/utils/scolarite_libelles.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../../core/widgets/photo_avatar.dart';
import '../../finance/providers/decompte_du_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../models/eleve_libelles.dart';
import '../models/tutor_draft.dart';
import '../providers/fiche_eleve_actes_provider.dart';
import '../providers/fiche_eleve_finance_provider.dart';
import '../providers/fiche_eleve_provider.dart';
import '../providers/fiche_eleve_resultats_provider.dart';
import '../providers/fiche_eleve_vie_provider.dart';
// ⚠️ `show` et non un import nu : `documents_provider.dart` déclare lui aussi
// une classe `StudentDossier`, homonyme de celle du dossier élève. Les deux
// entreraient en conflit, et c'est l'autre qu'il nous faut.
import '../providers/documents_provider.dart' show kRequiredDocTypes;
import '../providers/student_documents_provider.dart';
import '../providers/student_dossier_provider.dart';
import '../services/fiche_eleve_pdf_service.dart';
import '../widgets/fiche_eleve_kit.dart';
import 'eleves_screen.dart' show showStudentEditModal;

part 'fiche_eleve_entete.dart';
part 'fiche_eleve_identite.dart';
part 'fiche_eleve_parcours.dart';
part 'fiche_eleve_resultats.dart';
part 'fiche_eleve_vie.dart';
part 'fiche_eleve_finance.dart';
part 'fiche_eleve_actes.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FICHE DE L'ÉLÈVE — tout ce que l'école sait d'un enfant, sur une page
//
//  ── POURQUOI UNE PAGE ET NON LE TIROIR ─────────────────────────────────────
//  Le tiroir de la liste (`eleves_drawer.dart`) garde son métier : le coup
//  d'œil qu'on fait cinquante fois par jour — qui est cet enfant, quelle
//  classe, quel numéro j'appelle. Il fait 460 pixels de large et ne tiendra
//  jamais onze registres. Alourdir le geste FRÉQUENT pour servir le geste RARE
//  serait exactement le mauvais arbitrage.
//
//  La fiche, elle, répond à l'autre question : celle qu'on pose quand on
//  instruit un dossier, qu'on reçoit une famille, ou qu'un conseil délibère.
//  Elle vit donc sur `/user/eleves/:id` — une route qui existait déjà, qui ne
//  redirigeait vers la liste que faute de destination, et qui devient ici un
//  vrai lien profond.
//
//  ── LA RÈGLE D'ÉCRITURE, EN UNE PHRASE ─────────────────────────────────────
//  ⚠️ La fiche MODIFIE ce qu'elle possède — identité, photo, tuteurs, statuts
//  particuliers. Pour tout le reste, elle RENVOIE au module qui en répond. Une
//  moyenne se corrige dans Évaluation, qui a ses règles de clôture ; un
//  versement dans Finance, où un reçu délivré ne se réécrit pas en silence ;
//  une absence porte l'agent qui l'a posée. Ouvrir l'écriture ici bâtirait une
//  porte dérobée autour de chaque règle que l'application fait respecter — et
//  dans un registre scolaire, c'est ainsi qu'une note change sans trace.
//
//  ── OFFLINE DE BOUT EN BOUT ────────────────────────────────────────────────
//  Les onze tables lues ici sont toutes déclarées dans `powersync_schema.dart`
//  et servies par les sync-rules : la fiche s'ouvre entière sur un poste
//  débranché. Aucun `supabase.from()` — c'est la règle centrale du projet.
// ════════════════════════════════════════════════════════════════════════════

/// Le slug du module, pour les permissions et le chrome.
const _kSlugFiche = 'eleves';

String _dt(DateTime? d) => d == null ? '' : DateFormat('dd/MM/yyyy').format(d);

String _dtLong(DateTime? d) =>
    d == null ? '' : DateFormat('d MMMM yyyy', 'fr').format(d);

String _num1(double? v) => v == null ? '' : v.toStringAsFixed(2);

/// L'année sur laquelle portent les sections bornées (résultats, assiduité,
/// cantine). Le libellé sert au sélecteur, les bornes à la cantine — qui date
/// ses services sans porter d'année scolaire.
typedef AnneeFiche = ({String id, String label, DateTime? debut, DateTime? fin});

class FicheEleveScreen extends ConsumerStatefulWidget {
  const FicheEleveScreen({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<FicheEleveScreen> createState() => _FicheEleveState();
}

class _FicheEleveState extends ConsumerState<FicheEleveScreen> {
  static const _onglets = <(String, IconData)>[
    ('Identité & famille', Icons.person_outline_rounded),
    ('Parcours', Icons.timeline_rounded),
    ('Résultats', Icons.school_outlined),
    ('Vie scolaire', Icons.emoji_people_rounded),
    ('Finances', Icons.payments_outlined),
    ('Actes & pièces', Icons.folder_open_rounded),
  ];

  int _onglet = 0;

  /// L'année choisie à la main. `null` = celle que la fiche a déduite.
  String? _anneeChoisie;

  @override
  Widget build(BuildContext context) {
    final dossier = ref.watch(studentDossierProvider(widget.studentId));

    return ModuleScaffold(
      slug: _kSlugFiche,
      title: dossier.valueOrNull?.nomComplet ?? 'Fiche élève',
      onBack: () => context.canPop()
          ? context.pop()
          : context.go(Routes.eleves),
      child: dossier.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(28),
          child: AdminErrorBanner(message: messageErreur(e)),
        ),
        data: (d) => d.student.isEmpty
            ? _Introuvable(studentId: widget.studentId)
            : _Corps(
                studentId: widget.studentId,
                dossier: d,
                onglet: _onglet,
                onglets: _onglets,
                anneeChoisie: _anneeChoisie,
                onOnglet: (i) => setState(() => _onglet = i),
                onAnnee: (id) => setState(() => _anneeChoisie = id),
              ),
      ),
    );
  }
}

/// L'élève n'est pas (ou pas encore) sur ce poste.
///
/// ⚠️ Ce cas n'est pas théorique dans une application offline-first : un lien
/// profond peut désigner un élève d'une autre école, ou un élève créé sur un
/// autre poste dont la synchronisation n'est pas encore descendue. Un écran
/// blanc laisserait croire à une panne ; on nomme les deux causes.
class _Introuvable extends StatelessWidget {
  const _Introuvable({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AdminEmptyState(
            icon: Icons.person_off_outlined,
            title: 'Élève introuvable sur ce poste',
            message: 'Aucun dossier ne porte cet identifiant dans la base '
                'locale. Soit il appartient à une autre école, soit il vient '
                "d'être créé ailleurs et la synchronisation ne l'a pas encore "
                'descendu.',
            actionLabel: 'Revenir à la liste',
            onAction: () => context.go(Routes.eleves),
          ),
        ),
      );
}

class _Corps extends ConsumerWidget {
  const _Corps({
    required this.studentId,
    required this.dossier,
    required this.onglet,
    required this.onglets,
    required this.anneeChoisie,
    required this.onOnglet,
    required this.onAnnee,
  });

  final String studentId;
  final StudentDossier dossier;
  final int onglet;
  final List<(String, IconData)> onglets;
  final String? anneeChoisie;
  final ValueChanged<int> onOnglet;
  final ValueChanged<String> onAnnee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcours = ref.watch(ficheParcoursProvider(studentId)).valueOrNull ??
        const <ParcoursAnnee>[];
    final annees = _anneesDisponibles(ref, parcours);
    final annee = _anneeRetenue(ref, annees);

    return LayoutBuilder(builder: (context, c) {
      final etroit = c.maxWidth < 900;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(etroit ? 12 : 22, 16, etroit ? 12 : 22, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FicheEntete(
            studentId: studentId,
            dossier: dossier,
            parcours: parcours,
            annee: annee,
            etroit: etroit,
          ),
          const SizedBox(height: 16),
          _Onglets(
            onglets: onglets,
            actif: onglet,
            onChoix: onOnglet,
          ),
          const SizedBox(height: 16),
          // Le sélecteur d'année ne s'affiche QUE pour les sections qu'il
          // gouverne. Le laisser partout ferait croire qu'il filtre aussi
          // l'identité ou les actes, qui n'ont pas d'année.
          if (_ongletBorneParAnnee(onglet) && annees.length > 1) ...[
            _ChoixAnnee(
              annees: annees,
              actif: annee?.id,
              onChoix: onAnnee,
            ),
            const SizedBox(height: 14),
          ],
          switch (onglet) {
            0 => FicheIdentite(studentId: studentId, dossier: dossier),
            1 => FicheParcours(studentId: studentId, parcours: parcours),
            2 => FicheResultats(studentId: studentId, annee: annee),
            3 => FicheVieScolaire(studentId: studentId, annee: annee),
            4 => FicheFinance(
                studentId: studentId,
                parcours: parcours,
                annee: annee,
              ),
            _ => FicheActes(studentId: studentId),
          },
        ]),
      );
    });
  }

  static bool _ongletBorneParAnnee(int i) => i == 2 || i == 3 || i == 4;

  /// Les années que cet élève a réellement vécues dans l'établissement,
  /// enrichies des bornes de date quand le référentiel les connaît.
  ///
  /// ⚠️ On part du PARCOURS et non de la liste des années de l'école : ouvrir
  /// un sélecteur sur douze années dont l'élève n'en a fréquenté que trois
  /// invite à chercher des résultats là où il n'y en a jamais eu.
  List<AnneeFiche> _anneesDisponibles(WidgetRef ref, List<ParcoursAnnee> p) {
    final referentiel = ref.watch(academicYearsProvider).valueOrNull ?? const [];
    final vues = <String, AnneeFiche>{};
    for (final a in p) {
      // Le parcours ne porte pas l'identifiant d'année : on le retrouve par le
      // libellé, seul lien commun entre la ligne d'inscription et le
      // référentiel.
      final ref0 = referentiel.where((y) => y.label == a.anneeLabel).firstOrNull;
      final id = ref0?.id ?? a.anneeLabel;
      vues[id] = (
        id: id,
        label: a.anneeLabel.isEmpty ? '—' : a.anneeLabel,
        debut: ref0?.startDate ?? a.anneeDebut,
        fin: ref0?.endDate,
      );
    }
    return vues.values.toList(growable: false);
  }

  /// L'année affichée : celle qu'on a choisie, sinon l'année active si
  /// l'élève y était inscrit, sinon la plus récente de son parcours.
  AnneeFiche? _anneeRetenue(WidgetRef ref, List<AnneeFiche> annees) {
    if (annees.isEmpty) return null;
    if (anneeChoisie != null) {
      final choisie = annees.where((a) => a.id == anneeChoisie).firstOrNull;
      if (choisie != null) return choisie;
    }
    final active = ref.watch(activeYearIdProvider);
    final surActive = annees.where((a) => a.id == active).firstOrNull;
    return surActive ?? annees.first;
  }
}

/// La barre d'onglets — elle défile plutôt que de se replier.
///
/// ⚠️ Six onglets ne tiennent pas sur le portable d'entrée de gamme qui est le
/// poste réel des écoles. Un `Wrap` les empilerait sur trois lignes et
/// pousserait le contenu hors de l'écran ; on défile horizontalement, et la
/// barre garde une hauteur constante.
class _Onglets extends StatelessWidget {
  const _Onglets({
    required this.onglets,
    required this.actif,
    required this.onChoix,
  });

  final List<(String, IconData)> onglets;
  final int actif;
  final ValueChanged<int> onChoix;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < onglets.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Onglet(
                label: onglets[i].$1,
                icone: onglets[i].$2,
                actif: i == actif,
                onTap: () => onChoix(i),
              ),
            ),
        ]),
      );
}

class _Onglet extends StatelessWidget {
  const _Onglet({
    required this.label,
    required this.icone,
    required this.actif,
    required this.onTap,
  });

  final String label;
  final IconData icone;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: actif ? kNavy : kCardBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: actif ? kNavy : kBorder),
            ),
            child: Row(children: [
              Icon(icone,
                  size: 15, color: actif ? Colors.white : kTextMuted),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: actif ? Colors.white : kTextPrimary,
                ),
              ),
            ]),
          ),
        ),
      );
}

/// Le choix de l'année, pour les sections qui en dépendent.
class _ChoixAnnee extends StatelessWidget {
  const _ChoixAnnee({
    required this.annees,
    required this.actif,
    required this.onChoix,
  });

  final List<AnneeFiche> annees;
  final String? actif;
  final ValueChanged<String> onChoix;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(Icons.event_note_outlined, size: 15, color: kTextMuted),
        const SizedBox(width: 8),
        Text(
          'Année scolaire',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kTextMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final a in annees)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Onglet(
                    label: a.label,
                    icone: Icons.calendar_today_rounded,
                    actif: a.id == actif,
                    onTap: () => onChoix(a.id),
                  ),
                ),
            ]),
          ),
        ),
      ]);
}
