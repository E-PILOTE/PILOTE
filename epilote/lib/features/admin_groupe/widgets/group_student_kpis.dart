import 'package:flutter/material.dart';

import '../../../core/widgets/list_chrome.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_students_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  KPI DE LA RECHERCHE ÉLÈVES.
//
//  Volontairement CONTEXTUELS : ils décrivent la sélection à l'écran, pas le
//  réseau entier. Filtrer sur un établissement doit répondre « et pour cette
//  école ? » — sinon ce sont les mêmes chiffres que le Tableau de bord, et un
//  KPI dupliqué n'apprend rien.
//
//  Pour la même raison on ne remet PAS ici « écoles par département » : cet
//  indicateur vit déjà sur le Tableau de bord et sur la Vue régionale.
// ════════════════════════════════════════════════════════════════════════════
class GroupStudentKpis extends StatelessWidget {
  const GroupStudentKpis({
    super.key,
    required this.students,
    required this.scopeLabel,
  });

  final List<GroupStudent> students;

  /// Ce que couvre la sélection (« réseau », nom d'école…) : un pourcentage
  /// sans son périmètre se lit de travers.
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    final total = students.length;
    final girls = students.where((s) => s.isFemale).length;
    final unplaced = students.where((s) => s.isUnplaced).length;
    final schools = students.map((s) => s.schoolName).toSet().length;
    final depts = students
        .map((s) => s.department)
        .whereType<String>()
        .where((d) => d.isNotEmpty)
        .toSet()
        .length;

    // Parité : `null` si la sélection est vide — 0 % dirait « aucune fille »
    // là où il n'y a personne à compter.
    final girlShare = total == 0 ? null : girls / total * 100;

    return KpiGrid(items: [
      KpiData(
        label: 'Élèves affichés',
        value: '$total',
        sub: scopeLabel,
        icon: Icons.groups_rounded,
        color: kNavy,
      ),
      KpiData(
        label: 'Filles',
        value: girlShare == null ? '—' : '${girlShare.toStringAsFixed(0)} %',
        sub: '$girls sur $total',
        icon: Icons.female_rounded,
        color: const Color(0xFF7C3AED),
        progressValue: girlShare == null ? null : girlShare / 100,
      ),
      KpiData(
        label: 'Sans classe',
        value: '$unplaced',
        sub: unplaced == 0
            ? 'tous affectés'
            : 'à affecter pour l\'année en cours',
        icon: Icons.help_outline_rounded,
        color: unplaced == 0 ? kGreen : kRed,
      ),
      KpiData(
        label: 'Couverture',
        value: '$schools',
        sub: '${schools > 1 ? 'établissements' : 'établissement'} · '
            '$depts département${depts > 1 ? 's' : ''}',
        icon: Icons.account_balance_rounded,
        color: kGreen,
      ),
    ]);
  }
}
