import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/cartes_filtres.dart';
import '../providers/cartes_provider.dart';
import '../services/cartes_actions.dart';
import 'cartes_filtres_barre.dart';
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
//  ── LE BILAN SUIT LE FILTRE, ET LE DIT ─────────────────────────────────────
//  Filtrer sur « Comptabilité » puis lire un bandeau qui compte encore l'école
//  entière n'aurait aucun sens : on filtre justement pour savoir où en est
//  CETTE filière. Le bandeau suit donc la sélection — et il affiche en clair
//  sur quoi il porte, sans quoi un chiffre partiel se lirait comme un total.
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
  FiltreCartes _filtre = FiltreCartes.aucun;

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

        final visibles = filtrerClasses(peuplees, _filtre);
        final eleves = visibles.fold(0, (n, c) => n + c.eleves);
        final photos = visibles.fold(0, (n, c) => n + c.avecPhoto);
        final filieres = bilansFilieres(peuplees);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CampagneCartes(
              eleves: eleves,
              avecPhoto: photos,
              classes: visibles.length,
              yearLabel: year.label,
            ),
            if (_filtre.actif) ...[
              const SizedBox(height: 8),
              _PorteeDuBilan(libelle: _libelleFiltre()),
            ],
            const SizedBox(height: 18),
            ScopeDrilldownPanel(
              units: unitesDepuisClasses(peuplees),
              title: 'Répartition',
              metricLabel: 'Avec photo',
              selected: _filtre.scope,
              onSelect: (s) => setState(() => _filtre = _filtre.avecScope(s)),
            ),
            if (filieres.isNotEmpty) ...[
              const SizedBox(height: 18),
              FilieresCartes(
                bilans: filieres,
                choisie: _filtre.filiere,
                onChoisir: (f) =>
                    setState(() => _filtre = _filtre.avecFiliere(f)),
              ),
            ],
            const SizedBox(height: 18),
            BarreEtatPhoto(
              etat: _filtre.photo,
              onEtat: (e) => setState(() => _filtre = _filtre.avecPhoto(e)),
              filtreActif: _filtre.actif,
              onEffacer: () => setState(() => _filtre = FiltreCartes.aucun),
              resume: '${visibles.length} classe'
                  '${visibles.length > 1 ? 's' : ''} · $eleves élève'
                  '${eleves > 1 ? 's' : ''}',
            ),
            const SizedBox(height: 16),
            _EnTeteClasses(
              nbClasses: visibles.length,
              nbEleves: eleves,
              onImprimerSelection:
                  visibles.isEmpty ? null : () => _imprimerSelection(visibles),
            ),
            const SizedBox(height: 10),
            if (visibles.isEmpty)
              const AdminEmptyState(
                icon: Icons.filter_alt_off_rounded,
                title: 'Aucune classe dans cette sélection',
                message: 'Le filtre ne laisse passer aucune classe. Élargissez-'
                    'le, ou effacez-le pour revoir toute la campagne.',
              )
            else
              ..._parCycle(visibles),
          ],
        );
      },
    );
  }

  String _libelleFiltre() {
    final bouts = <String>[
      if (_filtre.scope.active && _filtre.scope.label.isNotEmpty)
        _filtre.scope.label,
      if (_filtre.filiere != null) _filtre.filiere!,
      if (_filtre.photo != EtatPhoto.toutes) _filtre.photo.libelle,
    ];
    return bouts.isEmpty ? 'sélection en cours' : bouts.join(' · ');
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

  /// Toute la sélection en une planche.
  ///
  /// ⚠️ L'ordre suit celui de l'écran — cycle, niveau, classe — et pas l'ordre
  /// d'arrivée des requêtes. Une planche qui mélangerait les classes se
  /// découperait en tas qu'il faudrait retrier à la main.
  Future<void> _imprimerSelection(List<CarteClasse> classes) async {
    final tous = <CarteEleveRow>[];
    for (final c in classes) {
      tous.addAll(await ref.read(cartesElevesProvider(c.classId).future));
    }
    if (!mounted) return;
    await imprimerPlancheCartes(
      context,
      ref,
      eleves: tous,
      titre: classes.length == 1
          ? classes.first.className
          : _filtre.actif
              ? _libelleFiltre()
              : 'Établissement',
    );
  }
}

/// Sur quoi porte le bandeau quand un filtre est actif.
///
/// Sans cette ligne, un chiffre partiel se lirait comme le total de l'école —
/// et une campagne à moitié faite passerait pour terminée.
class _PorteeDuBilan extends StatelessWidget {
  const _PorteeDuBilan({required this.libelle});
  final String libelle;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(Icons.filter_alt_rounded, size: 15, color: kAccent),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Ces chiffres portent sur : $libelle — pas sur toute l’école.',
            style: TextStyle(
                fontSize: 12.5, color: kAccent, fontWeight: FontWeight.w600),
          ),
        ),
      ]);
}

class _EnTeteClasses extends StatelessWidget {
  const _EnTeteClasses({
    required this.nbClasses,
    required this.nbEleves,
    required this.onImprimerSelection,
  });

  final int nbClasses, nbEleves;
  final VoidCallback? onImprimerSelection;

  @override
  Widget build(BuildContext context) {
    final planches = (nbEleves + 9) ~/ 10;
    return Row(children: [
      const Expanded(
        child: AdminSectionTitle(
          'Classes',
          icon: Icons.class_rounded,
          subtitle: 'Une planche A4 porte 10 cartes, recto-verso',
        ),
      ),
      if (onImprimerSelection != null)
        FilledButton.icon(
          onPressed: onImprimerSelection,
          style: FilledButton.styleFrom(backgroundColor: kNavy),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
          label: Text(nbClasses == 1
              ? 'Éditer la classe'
              : 'Éditer la sélection ($planches planche'
                  '${planches > 1 ? 's' : ''})'),
        ),
    ]);
  }
}
