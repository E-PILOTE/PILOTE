import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../module_routes.dart';
import '../providers/permissions_provider.dart';
import 'module_scaffold.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Écran « module en préparation » — affiché pour les modules accordés au
//  membre mais dont l'écran métier n'est pas encore bâti.
//
//  ⚠️ Ce n'est PAS un écran métier : il ne fait que présenter le module à venir.
//  Il reste DANS l'AppShell (via ModuleScaffold) → la sidebar, l'en-tête, le
//  sélecteur d'année et la garde `can_read` (verrou 3) sont conservés.
// ════════════════════════════════════════════════════════════════════════════

/// Courte description du rôle de chaque module (vitrine, pas de logique métier).
const Map<String, String> _moduleBlurb = {
  'eleves':
      'Annuaire des élèves : fiches, photos, coordonnées des tuteurs et suivi du dossier scolaire.',
  'inscriptions':
      'Inscriptions et réinscriptions : affectation en classe, pièces justificatives et frais.',
  'classes':
      'Organisation des classes, effectifs et affectation des professeurs principaux.',
  'matieres':
      'Référentiel des matières enseignées, coefficients et rattachement aux niveaux.',
  'notes':
      'Saisie des notes par séquence, calcul des moyennes et appréciations.',
  'bulletins':
      'Génération des bulletins trimestriels, mentions et rang de l\'élève.',
  'presences-eleves':
      'Appel quotidien, suivi des absences et retards, justificatifs.',
  'emploi-du-temps':
      'Construction de l\'emploi du temps des classes et des enseignants.',
  'cahier-textes':
      'Cahier de textes numérique : contenus enseignés et travail à faire.',
  'discipline':
      'Incidents, sanctions et conseils de discipline avec historique.',
  'orientation': 'Vœux et décisions d\'orientation de fin de cycle.',
  'transferts': 'Transferts entrants et sortants entre établissements.',
  'documents':
      'Certificats, attestations et documents administratifs de l\'élève.',
  'frais-scolarite': 'Grilles de frais de scolarité par niveau et échéancier.',
  'paiements-eleves': 'Encaissement des frais, reçus et suivi des impayés.',
  'depenses': 'Suivi des dépenses de l\'établissement par poste budgétaire.',
  'budget': 'Lignes budgétaires prévisionnelles et exécution.',
  'personnel': 'Dossiers du personnel : contrats, fonctions et coordonnées.',
  'presences-personnel': 'Pointage et présence du personnel.',
  'conges': 'Demandes et suivi des congés et absences du personnel.',
  'paie': 'Bulletins de paie et état des salaires.',
  'infirmerie': 'Passages à l\'infirmerie et suivi médical scolaire.',
  'cantine': 'Inscriptions cantine et suivi des repas.',
  'bibliotheque': 'Fonds documentaire, emprunts et retours.',
  'conseils': 'Conseils de classe : préparation, déroulé et décisions.',
};

/// Actions (verrou 3) → libellé lisible, pour montrer ce que le profil pourra faire.
const Map<String, ({String label, IconData icon})> _actionLabels = {
  'create': (label: 'Créer', icon: Icons.add_rounded),
  'update': (label: 'Modifier', icon: Icons.edit_rounded),
  'delete': (label: 'Supprimer', icon: Icons.delete_outline_rounded),
  'validate': (label: 'Valider', icon: Icons.verified_rounded),
  'approve': (label: 'Approuver', icon: Icons.thumb_up_alt_rounded),
  'export': (label: 'Exporter', icon: Icons.download_rounded),
  'import': (label: 'Importer', icon: Icons.upload_rounded),
  'manage': (label: 'Administrer', icon: Icons.settings_rounded),
};

/// Placeholder « en préparation » pour une page de l'espace personnel qui n'est
/// PAS un module du catalogue (ex. Espace Parent, Rapports). Reste dans
/// l'AppShell (sidebar/en-tête conservés) — sans garde verrou-3 ni bouton de
/// déconnexion brut, contrairement à l'ancien placeholder hors-coquille.
class StaffComingSoonScreen extends StatelessWidget {
  const StaffComingSoonScreen({
    super.key,
    required this.title,
    required this.icon,
    this.message =
        'Cette page fait partie de votre espace et sera bientôt disponible.',
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: title,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: kNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: 38, color: kNavy),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AdminBadge('En préparation', color: kAccent),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: kTextMuted,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ModuleComingSoonScreen extends ConsumerWidget {
  const ModuleComingSoonScreen({
    super.key,
    required this.slug,
    required this.title,
  });

  final String slug;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perm = ref.watch(modulePermissionProvider(slug));
    final blurb =
        _moduleBlurb[slug] ??
        'Ce module fait partie de votre espace et sera bientôt disponible.';

    // Capacités accordées par le profil d'accès (au-delà de la lecture).
    final caps = <({String label, IconData icon})>[];
    if (perm != null) {
      for (final e in _actionLabels.entries) {
        if (perm.can(e.key)) caps.add(e.value);
      }
    }

    return ModuleScaffold(
      slug: slug,
      title: title,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: kNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(moduleIcon(slug), size: 38, color: kNavy),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AdminBadge('En préparation', color: kAccent),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  blurb,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: kTextMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: kGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Accès déjà attribué à votre profil',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Dès que l'écran sera activé, il apparaîtra ici sans "
                        'action de votre part.',
                        style: TextStyle(fontSize: 12, color: kTextMuted),
                      ),
                      if (caps.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Vos droits sur ce module',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: kTextMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in caps)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: kSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: kBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(c.icon, size: 13, color: kNavy),
                                    const SizedBox(width: 5),
                                    Text(
                                      c.label,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: kTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
