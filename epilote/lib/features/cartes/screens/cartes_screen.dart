import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../providers/cartes_provider.dart';
import '../services/cartes_actions.dart';
import 'cartes_parts.dart';
import 'import_photos_dialog.dart';

const String kSlugCartes = 'cartes';

// ════════════════════════════════════════════════════════════════════════════
//  CARTES SCOLAIRES — la campagne de rentrée
//
//  ── POURQUOI CET ÉCRAN COMMENCE PAR COMPTER LES VISAGES ────────────────────
//  Le module a été écrit alors que la base comptait 9 106 élèves et ZÉRO
//  photo. Un écran qui n'offrirait qu'un bouton « Imprimer » produirait neuf
//  mille silhouettes grises, et l'école conclurait que la carte scolaire de
//  cette plateforme ne vaut rien.
//
//  L'avancement des photos est donc l'INFORMATION PRINCIPALE, avant la liste
//  des classes : c'est le travail qui reste, et c'est le seul que la
//  plateforme ne peut pas faire à la place de l'école.
//
//  ── L'IMPRESSION N'EST JAMAIS INTERDITE ────────────────────────────────────
//  Une école peut vouloir des cartes sans photo — accès cantine, prêt de
//  livres, contrôle au portail sur le seul nom. Le rôle de l'écran n'est pas
//  d'empêcher : c'est que personne ne découvre le cadre vide aux ciseaux.
// ════════════════════════════════════════════════════════════════════════════
class CartesScreen extends ConsumerWidget {
  const CartesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: kSlugCartes,
        title: 'Cartes scolaires',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  String? _classeOuverte;

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(activeYearProvider);
    if (year == null) {
      return const AdminEmptyState(
        icon: Icons.event_busy_rounded,
        title: 'Aucune année scolaire active',
        message: "Une carte porte l'année qu'elle couvre : sans année active, "
            'elle ne pourrait rien attester.',
      );
    }

    final classesAsync = ref.watch(cartesClassesProvider(year.id));
    final bilan = ref.watch(cartesBilanProvider(year.id));

    return classesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AdminErrorBanner(message: '$e'),
      data: (classes) {
        final peuplees = classes.where((c) => c.eleves > 0).toList();
        if (peuplees.isEmpty) {
          return const AdminEmptyState(
            icon: Icons.badge_outlined,
            title: 'Aucun élève inscrit',
            message: 'Les cartes se fabriquent à partir des inscriptions '
                "actives de l'année. Commencez par les inscriptions.",
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CampagneCartes(
              eleves: bilan.eleves,
              avecPhoto: bilan.avecPhoto,
              classes: bilan.classes,
              yearLabel: year.label,
            ),
            const SizedBox(height: 18),
            const AdminSectionTitle(
              'Classes',
              icon: Icons.class_rounded,
              subtitle: 'Une planche A4 porte 10 cartes, recto-verso',
            ),
            const SizedBox(height: 10),
            ..._parCycle(peuplees),
          ],
        );
      },
    );
  }

  /// Les classes, groupées par cycle. `level_order` repart à 1 dans chaque
  /// cycle : sans intertitre, la liste entrelacerait CP1, 6ème et 2nde.
  List<Widget> _parCycle(List<CarteClasse> classes) {
    final out = <Widget>[];
    String? cycleCourant;

    for (final c in classes) {
      if (c.cycleName != cycleCourant) {
        cycleCourant = c.cycleName;
        out
          ..add(const SizedBox(height: 6))
          ..add(Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6, top: 8),
            child: Text(
              c.cycleName.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: kTextMuted,
              ),
            ),
          ));
      }

      out.add(TuileClasseCartes(
        classe: c,
        ouverte: _classeOuverte == c.classId,
        onToggle: () => setState(() =>
            _classeOuverte = _classeOuverte == c.classId ? null : c.classId),
        onImprimerClasse: () => _imprimerClasse(c),
        onImporterPhotos: () => ouvrirImportPhotos(
          context,
          ref,
          classId: c.classId,
          className: c.className,
        ),
      ));
      out.add(const SizedBox(height: 8));
    }
    return out;
  }

  Future<void> _imprimerClasse(CarteClasse c) async {
    final eleves = await ref.read(cartesElevesProvider(c.classId).future);
    if (!mounted) return;
    await imprimerPlancheCartes(
      context,
      ref,
      eleves: eleves,
      titre: c.className,
    );
  }
}
