import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
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
class AdminExamResultsScreen extends StatelessWidget {
  const AdminExamResultsScreen({super.key});

  @override
  Widget build(BuildContext context) => const AppShell(
        title: 'Résultats & archives',
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Intro(),
              SizedBox(height: 20),
              ExamHistorySection(),
              SizedBox(height: 20),
              ExamArchivesSection(),
            ],
          ),
        ),
      );
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
