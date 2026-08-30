import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/cartes_filtres.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES FILIÈRES ET L'ÉTAT DES PHOTOS — le second axe du filtre
//
//  `ScopeDrilldownPanel` couvre déjà cycle / niveau / classe, et il est partagé
//  avec Documents et Annuaire. Ce fichier n'ajoute que ce qu'il ne sait pas
//  faire : la FILIÈRE, qui n'est pas un étage de la hiérarchie mais une coupe
//  en travers — au lycée technique une même filière traverse la 2nde, la 1ère
//  et la Terminale ; au collège technique (CET) elle traverse les quatre
//  années qui mènent au CAP.
//
//  ── CHAQUE PASTILLE PORTE SON AVANCEMENT ──────────────────────────────────
//  Une pastille qui ne dirait que « Comptabilité » obligerait à cliquer pour
//  savoir s'il reste du travail. Elle porte donc l'effectif ET les visages
//  manquants, avec la couleur qui va avec : c'est un tableau de bord qu'on
//  lit, pas un menu qu'on explore.
// ════════════════════════════════════════════════════════════════════════════

/// Les filières, en pastilles cliquables. Ne s'affiche pas si AUCUNE classe de
/// l'école n'en porte — voir [bilansFilieres]. Ne jamais conditionner cet
/// affichage au niveau : le collège technique en a.
class FilieresCartes extends StatelessWidget {
  const FilieresCartes({
    super.key,
    required this.bilans,
    required this.choisie,
    required this.onChoisir,
  });

  final List<BilanFiliere> bilans;
  final String? choisie;

  /// `null` = toutes les filières.
  final ValueChanged<String?> onChoisir;

  @override
  Widget build(BuildContext context) {
    if (bilans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionTitle(
          'Filières',
          icon: Icons.account_tree_rounded,
          subtitle: 'Une filière traverse les niveaux — c’est souvent elle qui '
              'décide de l’ordre de passage',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in bilans)
              _Pastille(
                bilan: b,
                active: choisie == b.libelle,
                onTap: () => onChoisir(choisie == b.libelle ? null : b.libelle),
              ),
          ],
        ),
      ],
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.bilan,
    required this.active,
    required this.onTap,
  });

  final BilanFiliere bilan;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // ⚠️ « Sans filière » n'est PAS un manque : toutes les voies n'en
    // définissent pas. Gris neutre, jamais rouge.
    //
    // Ne PAS déduire cela du niveau : le collège technique (CET, tutelle METP)
    // est organisé par métier dès le premier cycle et mène au CAP. Le
    // référentiel porte d'ailleurs `college_technique` au cycle `college`.
    final sansFiliere = bilan.libelle == null;
    final couleur = sansFiliere
        ? kTextMuted
        : bilan.complet
            ? kGreen
            : kNavy;

    return Material(
      color: active ? couleur.withValues(alpha: 0.12) : kCardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? couleur : kBorder,
              width: active ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  sansFiliere
                      ? Icons.remove_rounded
                      : bilan.complet
                          ? Icons.check_circle_rounded
                          : Icons.account_tree_rounded,
                  size: 15,
                  color: couleur,
                ),
                const SizedBox(width: 7),
                Text(
                  bilan.libelle ?? 'Sans filière',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: active ? couleur : kTextPrimary,
                  ),
                ),
              ]),
              const SizedBox(height: 5),
              Text(
                '${bilan.eleves} élève${bilan.eleves > 1 ? 's' : ''} · '
                '${bilan.classes} classe${bilan.classes > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11.5, color: kTextMuted),
              ),
              const SizedBox(height: 4),
              Text(
                bilan.sansPhoto == 0
                    ? 'Tous les visages'
                    : '${bilan.sansPhoto} sans photo',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: bilan.sansPhoto == 0 ? kGreen : kAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le filtre par état des photos, et le bouton qui remet tout à zéro.
///
/// ⚠️ « Tout effacer » n'apparaît QUE si un filtre est actif. Un bouton
/// toujours visible sur un écran non filtré laisse croire qu'il reste quelque
/// chose à défaire.
class BarreEtatPhoto extends StatelessWidget {
  const BarreEtatPhoto({
    super.key,
    required this.etat,
    required this.onEtat,
    required this.filtreActif,
    required this.onEffacer,
    required this.resume,
  });

  final EtatPhoto etat;
  final ValueChanged<EtatPhoto> onEtat;
  final bool filtreActif;
  final VoidCallback onEffacer;

  /// Ce que le filtre laisse voir, en clair — « 3 classes · 84 élèves ».
  final String resume;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (final e in EtatPhoto.values) ...[
          ChoiceChip(
            label: Text(e.libelle),
            selected: etat == e,
            onSelected: (_) => onEtat(e),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: etat == e ? kNavy : kTextMuted,
            ),
            selectedColor: kNavy.withValues(alpha: 0.12),
            backgroundColor: kCardBg,
            side: BorderSide(color: etat == e ? kNavy : kBorder),
            showCheckmark: false,
          ),
          const SizedBox(width: 8),
        ],
        const Spacer(),
        Text(resume, style: TextStyle(fontSize: 12.5, color: kTextMuted)),
        if (filtreActif) ...[
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: onEffacer,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
            label: const Text('Tout effacer'),
            style: TextButton.styleFrom(
              foregroundColor: kTextMuted,
              textStyle: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ]);
}
