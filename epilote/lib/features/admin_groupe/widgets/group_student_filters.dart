import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/admin_schools_provider.dart';
import '../providers/admin_students_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PANNEAU DE RECHERCHE ÉLÈVES — ordre des filtres = ordre de raisonnement.
//
//  Département ▸ Établissement ▸ Filière : c'est ainsi qu'un cabinet formule
//  ses demandes (« les élèves du Niari », puis « ceux du lycée de Dolisie »,
//  puis « en électrotechnique »). Le choix d'un département RESTREINT la liste
//  des établissements — proposer les 14 écoles du réseau alors qu'on vient d'en
//  isoler deux serait laisser l'utilisateur se contredire lui-même.
//
//  Les filtres actifs sont rappelés en pastilles retirables : un tableau filtré
//  dont on a oublié les critères se lit de travers.
// ════════════════════════════════════════════════════════════════════════════
const _kAll = '__all__';

class GroupStudentFilters extends StatelessWidget {
  const GroupStudentFilters({
    super.key,
    required this.controller,
    required this.query,
    required this.schools,
    required this.filieres,
    required this.total,
    required this.onChanged,
    required this.onReset,
  });

  final TextEditingController controller;
  final StudentQuery query;
  final List<SchoolDetail> schools;
  final List<String> filieres;
  final int? total;
  final ValueChanged<StudentQuery> onChanged;
  final VoidCallback onReset;

  /// Départements réellement représentés, tirés des écoles déjà chargées :
  /// aucune requête de plus, et aucun département sans école proposé.
  List<String> get _departments {
    final set = <String>{
      for (final s in schools)
        if ((s.department ?? '').trim().isNotEmpty) s.department!.trim(),
    };
    return set.toList()..sort();
  }

  /// Écoles offertes au choix : celles du département retenu, sinon toutes.
  List<SchoolDetail> get _schoolChoices {
    final d = query.department;
    final kept = d == null
        ? [...schools]
        : schools.where((s) => s.department == d).toList();
    return kept..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Changer de département invalide un établissement qui n'en fait pas partie.
  void _pickDepartment(String? d) {
    final keepSchool = d == null ||
        schools.any((s) => s.id == query.schoolId && s.department == d);
    onChanged(query.copyWith(
      department: d,
      schoolId: keepSchool ? query.schoolId : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final chips = query.activeFilters;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.person_search_rounded, size: 18, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              total == null
                  ? 'Rechercher un élève dans le réseau'
                  : 'Rechercher parmi $total élèves du réseau',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary),
            ),
          ),
          TextButton.icon(
            onPressed: onReset,
            icon: Icon(Icons.filter_alt_off_rounded, size: 14, color: kTextMuted),
            label: Text('Effacer',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          onChanged: (v) => onChanged(query.copyWith(search: v)),
          style: TextStyle(fontSize: 13, color: kTextPrimary),
          decoration: InputDecoration(
            hintText: 'Nom, prénom ou matricule (2 caractères minimum)…',
            hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: kTextMuted, size: 20),
            filled: true,
            fillColor: kSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _Slot(
            width: 210,
            child: ListFilterDropdown(
              icon: Icons.map_rounded,
              label: 'Département',
              value: query.department ?? _kAll,
              // Le libellé du filtre dit déjà « Département » : répéter le mot
              // dans la valeur ne fait que tronquer les deux.
              items: {
                _kAll: 'Tous',
                for (final d in _departments) d: d,
              },
              onChanged: (v) => _pickDepartment(v == _kAll ? null : v),
            ),
          ),
          _Slot(
            width: 280,
            child: ListFilterDropdown(
              icon: Icons.account_balance_rounded,
              label: 'Établissement',
              value: query.schoolId ?? _kAll,
              items: {
                _kAll: query.department == null
                    ? 'Tous'
                    : 'Tous — ${query.department}',
                for (final s in _schoolChoices) s.id: s.name,
              },
              onChanged: (v) =>
                  onChanged(query.copyWith(schoolId: v == _kAll ? null : v)),
            ),
          ),
          _Slot(
            width: 230,
            child: ListFilterDropdown(
              icon: Icons.engineering_rounded,
              label: 'Filière',
              value: query.filiere ?? _kAll,
              items: {
                _kAll: 'Toutes',
                for (final f in filieres) f: f,
              },
              onChanged: (v) =>
                  onChanged(query.copyWith(filiere: v == _kAll ? null : v)),
            ),
          ),
          _Slot(
            width: 175,
            child: ListFilterDropdown(
              icon: Icons.wc_rounded,
              label: 'Sexe',
              value: query.gender ?? _kAll,
              items: const {
                _kAll: 'Filles et garçons',
                'F': 'Filles',
                'M': 'Garçons',
              },
              onChanged: (v) =>
                  onChanged(query.copyWith(gender: v == _kAll ? null : v)),
            ),
          ),
          _Slot(
            width: 185,
            child: ListFilterDropdown(
              icon: Icons.toggle_on_rounded,
              label: 'Statut',
              value: query.activeOnly ? 'actifs' : 'tous',
              items: const {
                'actifs': 'Élèves actifs',
                'tous': 'Actifs et inactifs',
              },
              onChanged: (v) =>
                  onChanged(query.copyWith(activeOnly: v == 'actifs')),
            ),
          ),
        ]),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (label, value) in chips)
              _ActiveChip(
                label: label,
                value: value,
                onRemove: () => onChanged(_without(label)),
              ),
          ]),
        ],
      ]),
    );
  }

  StudentQuery _without(String label) => switch (label) {
        'Recherche' => query.copyWith(search: ''),
        'Département' => query.copyWith(department: null),
        'Filière' => query.copyWith(filiere: null),
        'Sexe' => query.copyWith(gender: null),
        _ => query.copyWith(activeOnly: true),
      };
}

/// Gabarit unique : des menus de hauteurs inégales feraient onduler la ligne.
class _Slot extends StatelessWidget {
  const _Slot({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: width, height: 40, child: child);
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({
    required this.label,
    required this.value,
    required this.onRemove,
  });

  final String label;
  final String value;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kNavy.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label : ',
              style: TextStyle(fontSize: 11, color: kTextMuted)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: kNavy),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, size: 13, color: kNavy),
            tooltip: 'Retirer ce filtre',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            visualDensity: VisualDensity.compact,
          ),
        ]),
      );
}
