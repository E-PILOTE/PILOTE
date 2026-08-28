import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/academic_year_model.dart';
import '../../features/structure/providers/academic_year_context.dart';
import '../widgets/admin_tokens.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE DATE DE FAIT SCOLAIRE TOMBE DANS L'ANNÉE SCOLAIRE
//
//  Vingt-trois tables métier portent `academic_year_id`. Quand la ligne porte
//  l'année ET une date, les deux doivent s'accorder : une séance du cahier de
//  textes datée du 31 décembre 2027 était enregistrée avec l'`academic_year_id`
//  de 2025-2026. Toutes les requêtes filtrent par l'année — elles la rendaient
//  donc dans l'année courante, à une date qui n'en fait pas partie. Le fait
//  n'est pas seulement mal saisi : il est mal CLASSÉ, et aucun écran ne peut
//  plus le montrer là où il devrait être.
//
//  Le relevé du 2026-08-28 a trouvé le même repli « année civile ± 1 » (ou
//  ± 2, ou 2020→2100) sur HUIT formulaires, dans six domaines. C'est la même
//  faute que le sélecteur de vacances de l'onglet Calendrier : une borne prise
//  sur l'année CIVILE alors que le fait appartient à l'année SCOLAIRE.
//
//  `AdminDateField` (espace admin groupe) portait déjà la bonne règle, écrite
//  noir sur blanc : « rien ne justifie de pouvoir pointer une date hors de
//  l'année scolaire ». L'espace personnel ne l'avait jamais reçue.
//
//  ── CE QUI EST BORNÉ, ET CE QUI NE L'EST PAS ──────────────────────────────
//  Seules les dates écrites sur une ligne QUI PORTE `academic_year_id`. Une
//  entrée de cantine ou un prêt de bibliothèque n'ont pas de colonne d'année :
//  leur date ne contredit rien, et les borner n'apporterait qu'une gêne.
//
//  ── LE PLAFOND N'EST JAMAIS DESSERRÉ ──────────────────────────────────────
//  Là où l'écran interdisait déjà le futur (un paiement, une dépense, un
//  passage à l'infirmerie ne se constatent pas d'avance), [plafond] le
//  conserve. On AJOUTE la borne de l'année ; on n'en retire aucune.
// ════════════════════════════════════════════════════════════════════════════

/// Bornes utilisables d'un sélecteur de date, pour un fait de l'année [annee].
///
/// [souhaitee] est la date que l'écran voudrait présenter ; elle est ramenée
/// dans l'intervalle, faute de quoi `showDatePicker` lève une assertion.
/// [plafond] borne le futur (typiquement `DateTime.now()`) quand le fait ne
/// peut pas être constaté d'avance.
///
/// Rend `null` quand aucune date n'est choisissable — année inconnue, ou année
/// entièrement postérieure au plafond. L'appelant doit alors le DIRE, et non
/// se rabattre sur des bornes inventées : c'est ce repli-là qui était le
/// défaut.
({DateTime premiere, DateTime derniere, DateTime initiale})? bornesScolaires(
  AcademicYearModel? annee, {
  required DateTime souhaitee,
  DateTime? plafond,
}) {
  if (annee == null) return null;
  final premiere = _jour(annee.startDate);
  var derniere = _jour(annee.endDate);
  if (plafond != null) {
    final p = _jour(plafond);
    if (p.isBefore(derniere)) derniere = p;
  }
  if (derniere.isBefore(premiere)) return null;

  var initiale = _jour(souhaitee);
  if (initiale.isBefore(premiere)) initiale = premiere;
  if (initiale.isAfter(derniere)) initiale = derniere;
  return (premiere: premiere, derniere: derniere, initiale: initiale);
}

/// Sélecteur de date borné par l'année scolaire active.
///
/// À utiliser partout où la date saisie part sur une ligne portant
/// `academic_year_id`. Rend `null` si l'utilisateur annule — ou si aucune date
/// n'est choisissable, auquel cas le motif est affiché.
Future<DateTime?> choisirDateScolaire(
  BuildContext context,
  WidgetRef ref, {
  required DateTime initiale,
  DateTime? plafond,
  String? aide,
}) async {
  final annee = ref.read(activeYearProvider);
  final bornes =
      bornesScolaires(annee, souhaitee: initiale, plafond: plafond);
  if (bornes == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(annee == null
            ? 'Année scolaire pas encore chargée — réessayez dans un instant.'
            : 'Aucune date saisissable : l\'année ${annee.label} n\'a pas '
                'encore commencé.'),
        backgroundColor: kRed,
      ));
    }
    return null;
  }
  if (!context.mounted) return null;
  return showDatePicker(
    context: context,
    initialDate: bornes.initiale,
    firstDate: bornes.premiere,
    lastDate: bornes.derniere,
    helpText: aide,
    locale: const Locale('fr', 'FR'),
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: kNavy)),
      child: child!,
    ),
  );
}

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);
