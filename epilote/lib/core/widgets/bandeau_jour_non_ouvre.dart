import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/structure/providers/academic_year_context.dart';
import '../../features/structure/providers/school_holidays_provider.dart';
import 'admin_tokens.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « CE JOUR-LÀ, IL N'Y A PAS CLASSE »
//
//  ── LE TROU ────────────────────────────────────────────────────────────────
//  Les écrans du quotidien — appel des présences, service de cantine — ouvrent
//  sur `DateTime.now()`, ce qui est juste : un surveillant qui arrive le matin
//  veut la feuille du matin, pas un sélecteur de date.
//
//  Mais ils ouvraient sur `now()` MÊME UN DIMANCHE, même le 25 décembre, même
//  en pleine période de congés, même hors des bornes de l'année scolaire. Ils
//  affichaient alors la liste des classes avec « 0 appel fait » — c'est-à-dire
//  un reproche : l'écran réclamait un travail qui n'avait aucune raison
//  d'exister. Le premier réflexe est de chercher la panne.
//
//  ── L'INFORMATION EXISTAIT DÉJÀ ────────────────────────────────────────────
//  `school_holidays` porte les fériés ET les périodes de congés, et
//  `holidayOn()` sait dire lequel couvre une date. `activeYearProvider` porte
//  les bornes de l'année. Rien à calculer : seulement à dire.
//
//  ⚠️ L'écran n'est PAS bloqué. Un établissement rattrape parfois un samedi,
//  et un secrétariat saisit en retard l'appel de la veille. Le bandeau
//  informe, il n'interdit pas — sans quoi il empêcherait un travail légitime
//  le jour où il se trompe.
// ════════════════════════════════════════════════════════════════════════════

/// Bandeau d'information quand [date] n'est pas un jour de classe.
/// Ne rend rien du tout si le jour est ouvré : le silence est le cas normal.
class BandeauJourNonOuvre extends ConsumerWidget {
  const BandeauJourNonOuvre({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motif = _motif(ref);
    if (motif == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccent.withValues(alpha: 0.28)),
      ),
      child: Row(children: [
        Icon(Icons.event_busy_rounded, size: 18, color: kAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            motif,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary),
          ),
        ),
      ]),
    );
  }

  /// Pourquoi ce jour n'est pas un jour de classe, ou `null` s'il l'est.
  ///
  /// L'ordre compte : hors année d'abord (le plus englobant), puis les congés
  /// nommés, puis le week-end. Un dimanche de vacances doit se lire
  /// « vacances », pas « dimanche » — c'est la raison la plus utile.
  String? _motif(WidgetRef ref) {
    final annee = ref.watch(activeYearProvider);
    if (annee != null) {
      final j = DateTime(date.year, date.month, date.day);
      final debut =
          DateTime(annee.startDate.year, annee.startDate.month, annee.startDate.day);
      final fin =
          DateTime(annee.endDate.year, annee.endDate.month, annee.endDate.day);
      if (j.isBefore(debut) || j.isAfter(fin)) {
        return 'Hors de l\'année scolaire ${annee.label} '
            '(${_court(debut)} → ${_court(fin)}).';
      }
    }

    final conges = ref.watch(schoolHolidaysProvider).valueOrNull ?? const [];
    final h = holidayOn(date, conges);
    if (h != null) {
      return h.kind == 'ferie'
          ? 'Jour férié — ${h.label}.'
          : 'Période de congés — ${h.label}.';
    }

    if (date.weekday == DateTime.saturday) return 'Samedi — pas de classe.';
    if (date.weekday == DateTime.sunday) return 'Dimanche — pas de classe.';
    return null;
  }

  static String _court(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
