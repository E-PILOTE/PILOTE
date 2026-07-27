import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/exam_archives_provider.dart';
import '../widgets/exam_archives_section.dart';
import '../widgets/exam_history_section.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉSULTATS & ARCHIVES — page propre, et non un ajout à « Examens nationaux ».
//
//  ── POURQUOI DEUX PAGES ─────────────────────────────────────────────────────
//  « Examens nationaux » suit la SESSION EN COURS : quelles écoles ont inscrit,
//  déposé, transmis ; laquelle est en retard. On l'ouvre tous les jours pendant
//  la campagne, et ses chiffres viennent de NOS écoles.
//
//  Cette page-ci répond à une autre question, une fois l'an : qu'a proclamé la
//  DEC, et où le réseau se situe-t-il dans le temps. Ses chiffres viennent de
//  la DEC.
//
//  Les avoir empilées sur un même écran mettait côte à côte deux « réussites
//  par département » — l'une calculée sur nos saisies, l'autre officielle —
//  avec des valeurs différentes et rien pour dire laquelle fait autorité. Les
//  séparer n'est pas du rangement : c'est ce qui empêche de confondre une
//  estimation avec un résultat proclamé.
// ════════════════════════════════════════════════════════════════════════════
class AdminExamResultsScreen extends ConsumerWidget {
  const AdminExamResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final figures = ref.watch(officialFiguresProvider).valueOrNull ?? const [];
    final pubs = ref.watch(examPublicationsProvider).valueOrNull ?? const [];

    return AppShell(
      title: 'Résultats & archives',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Intro(),
            const SizedBox(height: 20),
            KpiGrid(items: _kpis(figures, pubs)),
            const SizedBox(height: 20),
            const ExamHistorySection(),
            const SizedBox(height: 20),
            const ExamArchivesSection(),
          ],
        ),
      ),
    );
  }

  /// Quatre mesures de l'ARCHIVE elle-même, pas des résultats : ce que le
  /// ministère détient, et à quel point il peut s'y fier. Le taux national
  /// figure déjà dans l'historique — le répéter ici serait un doublon.
  List<KpiData> _kpis(List<OfficialFigure> figures, List<ExamPublication> pubs) {
    final histories = buildNationalHistory(figures);
    // Examen de référence = le plus gros effectif, comme dans l'historique.
    final main = histories.isEmpty
        ? null
        : ([...histories]..sort((a, b) =>
            (b.latest?.present ?? 0).compareTo(a.latest?.present ?? 0))).first;
    final last = main?.latest;

    final sessions = figures.map((f) => f.sessionId).toSet().length;
    final departments = figures
        .where((f) => f.scope == PubScope.departement && f.department != null)
        .map((f) => f.department)
        .toSet()
        .length;
    // Une pièce sans empreinte reste consultable, mais son intégrité ne peut
    // pas être prouvée — l'archive doit le dire d'elle-même.
    final sealed = pubs.where((p) => p.sha256 != null).length;
    final unsourced = figures.where((f) => !f.hasSource).length;

    return [
      KpiData(
        label: 'Dernière session',
        value: last == null ? '—' : '${last.rate.toStringAsFixed(2)} %',
        sub: last == null
            ? 'aucun chiffre officiel enregistré'
            : '${main!.examShortName} · ${last.yearLabel}',
        icon: Icons.verified_rounded,
        color: kNavy,
        trend: last?.deltaPoints == null
            ? 'référence'
            : '${last!.deltaPoints! >= 0 ? '+' : ''}'
                '${last.deltaPoints!.toStringAsFixed(2)} pt',
        trendUp: (last?.deltaPoints ?? 0) >= 0,
      ),
      KpiData(
        label: 'Sessions archivées',
        value: '$sessions',
        sub: sessions > 1
            ? 'l\'historique se lit sur $sessions sessions'
            : 'une seule session : pas encore de tendance',
        icon: Icons.history_rounded,
        color: kGreen,
      ),
      KpiData(
        label: 'Pièces conservées',
        value: '${pubs.length}',
        sub: pubs.isEmpty
            ? 'aucun document de la DEC déposé'
            : '$sealed sur ${pubs.length} vérifiable(s) par empreinte',
        icon: Icons.inventory_2_rounded,
        color: pubs.isEmpty ? kTextMuted : kListPurple,
        progressValue: pubs.isEmpty ? 0 : sealed / pubs.length,
      ),
      KpiData(
        label: 'Chiffres sans source',
        // Le point faible de l'archive : des taux enregistrés qu'aucune pièce
        // n'appuie. Zéro est la seule valeur satisfaisante.
        value: '$unsourced',
        sub: unsourced == 0
            ? '✅ chaque chiffre est adossé à un document'
            : 'à rattacher à leur publication',
        icon: Icons.link_off_rounded,
        color: unsourced == 0 ? kGreen : kListOrange,
        trend: '$departments département(s) couverts',
      ),
    ];
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => AdminCard(
        accent: kGreen,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_rounded, size: 26, color: kGreen),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ce que la DEC a proclamé',
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(height: 5),
              Text(
                'La plateforme transmet à la Direction des Examens et Concours '
                'la liste des candidats ; la DEC organise l\'épreuve, proclame '
                'les admis et publie ses documents. Aucun résultat d\'examen '
                'd\'État n\'est calculé ici : les chiffres de cette page sont '
                'relevés sur les publications, et chaque pièce reçue y est '
                'conservée. Le suivi de la session en cours — dossiers, '
                'transmissions, écoles en retard — se lit sur « Examens '
                'nationaux ».',
                style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.45),
              ),
            ]),
          ),
        ]),
      );
}
