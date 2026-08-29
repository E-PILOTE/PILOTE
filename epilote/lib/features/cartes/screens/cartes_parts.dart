import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/photo_avatar.dart';
import '../../navigation/widgets/module_scaffold.dart' show PermissionGate;
import '../providers/cartes_provider.dart';
import '../services/cartes_actions.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Les pièces de l'écran Cartes scolaires.
//
//  `CampagneCartes`   — l'avancement des photos, avant toute autre chose.
//  `TuileClasseCartes`— une classe, son état, son bouton d'impression.
//  `ListeElevesCartes`— les élèves de la classe, dépliés, carte par carte.
// ════════════════════════════════════════════════════════════════════════════

/// L'en-tête de campagne : combien d'élèves, combien de visages.
class CampagneCartes extends StatelessWidget {
  const CampagneCartes({
    super.key,
    required this.eleves,
    required this.avecPhoto,
    required this.classes,
    required this.yearLabel,
  });

  final int eleves, avecPhoto, classes;
  final String yearLabel;

  int get sansPhoto => eleves - avecPhoto;
  double get part => eleves == 0 ? 0 : avecPhoto / eleves;

  @override
  Widget build(BuildContext context) {
    final planches = (eleves + 9) ~/ 10;

    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.badge_rounded, color: kNavy, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Campagne $yearLabel',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kNavy)),
                  Text(
                    '$eleves élève${eleves > 1 ? 's' : ''} inscrit'
                    '${eleves > 1 ? 's' : ''} · $classes classe'
                    '${classes > 1 ? 's' : ''} · $planches planche'
                    '${planches > 1 ? 's' : ''} A4',
                    style: TextStyle(fontSize: 12.5, color: kTextMuted),
                  ),
                ],
              ),
            ),
            AdminBadge(
              '${(part * 100).round()} % de photos',
              color: part >= 0.9
                  ? kGreen
                  : part >= 0.4
                      ? kAccent
                      : kRed,
              icon: Icons.photo_camera_rounded,
            ),
          ]),
          const SizedBox(height: 14),
          AdminProgressBar(value: avecPhoto, max: eleves == 0 ? 1 : eleves,
              color: part >= 0.9 ? kGreen : part >= 0.4 ? kAccent : kRed),
          const SizedBox(height: 12),
          // ── La phrase qui décide si le module sert à quelque chose ────────
          // Une carte sans visage n'identifie personne. Tant que les photos
          // manquent, c'est le travail restant — et il n'appartient qu'à
          // l'école : la plateforme ne peut pas photographier à sa place.
          if (sansPhoto > 0)
            _Avertissement(
              icone: avecPhoto == 0
                  ? Icons.no_photography_rounded
                  : Icons.photo_camera_back_rounded,
              couleur: avecPhoto == 0 ? kRed : kAccent,
              texte: avecPhoto == 0
                  ? "Aucun élève n'a de photo. Les cartes sortiront avec un "
                      "cadre vide — lisibles, mais elles n'identifieront "
                      "personne. La photo s'ajoute depuis la fiche de l'élève, "
                      'et fonctionne hors ligne.'
                  : '$sansPhoto élève${sansPhoto > 1 ? 's' : ''} sans photo : '
                      'leur${sansPhoto > 1 ? 's' : ''} carte'
                      '${sansPhoto > 1 ? 's' : ''} sortira'
                      '${sansPhoto > 1 ? 'ont' : ''} avec un cadre vide.',
            )
          else
            _Avertissement(
              icone: Icons.verified_rounded,
              couleur: kGreen,
              texte: 'Tous les élèves inscrits ont une photo : les planches '
                  'sont complètes.',
            ),
        ],
      ),
    );
  }
}

class _Avertissement extends StatelessWidget {
  const _Avertissement(
      {required this.icone, required this.couleur, required this.texte});
  final IconData icone;
  final Color couleur;
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: couleur.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, size: 17, color: couleur),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte,
                style: TextStyle(
                    fontSize: 12.5, color: kTextMuted, height: 1.45)),
          ),
        ]),
      );
}

/// Une classe dans la liste : effectif, photos, bouton d'impression, et la
/// liste dépliable de ses élèves.
class TuileClasseCartes extends ConsumerWidget {
  const TuileClasseCartes({
    super.key,
    required this.classe,
    required this.ouverte,
    required this.onToggle,
    required this.onImprimerClasse,
  });

  final CarteClasse classe;
  final bool ouverte;
  final VoidCallback onToggle, onImprimerClasse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planches = (classe.eleves + 9) ~/ 10;

    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              Icon(ouverte ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20, color: kTextMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(classe.className,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: kNavy)),
                    Text(
                      '${classe.eleves} élève${classe.eleves > 1 ? 's' : ''} · '
                      '$planches planche${planches > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, color: kTextMuted),
                    ),
                  ],
                ),
              ),
              AdminBadge(
                classe.complet
                    ? 'Photos complètes'
                    : '${classe.sansPhoto} sans photo',
                color: classe.complet ? kGreen : kAccent,
                icon: classe.complet
                    ? Icons.check_rounded
                    : Icons.photo_camera_back_rounded,
              ),
              const SizedBox(width: 10),
              // L'impression est un EXPORT : c'est le verbe que la base
              // reconnaît pour « sortir de la donnée », et il se règle
              // séparément de la consultation.
              PermissionGate(
                slug: 'cartes',
                action: 'export',
                child: FilledButton.icon(
                  onPressed: onImprimerClasse,
                  style: FilledButton.styleFrom(backgroundColor: kNavy),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('Imprimer'),
                ),
              ),
            ]),
          ),
        ),
        if (ouverte) ...[
          Divider(height: 1, color: kBorder),
          ListeElevesCartes(classId: classe.classId),
        ],
      ]),
    );
  }
}

/// Les élèves d'une classe, un par ligne, avec leur carte individuelle.
class ListeElevesCartes extends ConsumerWidget {
  const ListeElevesCartes({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cartesElevesProvider(classId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: AdminErrorBanner(message: '$e'),
      ),
      data: (eleves) {
        if (eleves.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Aucune inscription active dans cette classe.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted),
            ),
          );
        }
        return Column(
          children: [
            for (final e in eleves) _LigneEleve(eleve: e),
          ],
        );
      },
    );
  }
}

class _LigneEleve extends ConsumerWidget {
  const _LigneEleve({required this.eleve});
  final CarteEleveRow eleve;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(children: [
          PhotoAvatar(
              name: eleve.fullName, photoUrl: eleve.photoUrl, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eleve.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  eleve.ine == null || eleve.ine!.isEmpty
                      ? 'Matricule ${eleve.matricule} · identifiant national '
                          'en attente'
                      : 'Matricule ${eleve.matricule}',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ],
            ),
          ),
          if (!eleve.aUnePhoto)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AdminBadge('Sans photo',
                  color: kAccent, icon: Icons.photo_camera_back_rounded),
            ),
          PermissionGate(
            slug: 'cartes',
            action: 'export',
            child: IconButton(
              tooltip: 'Carte de cet élève',
              icon: const Icon(Icons.badge_outlined, size: 19),
              onPressed: () =>
                  imprimerCarteEleve(context, ref, eleve: eleve),
            ),
          ),
        ]),
      );
}
