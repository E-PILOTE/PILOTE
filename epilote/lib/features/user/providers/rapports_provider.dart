import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../finance/providers/paiements_provider.dart';
import '../../staff/providers/staff_directory_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../services/rapport_effectifs.dart';
import '../services/rapport_personnel.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES DONNÉES DES ÉTATS OFFICIELS DE L'ÉTABLISSEMENT
//
//  ⚠️ CE PROVIDER LIT L'ÉCOLE ENTIÈRE, SANS LE PÉRIMÈTRE DE L'AGENT.
//
//  `studentsRegistryProvider` applique `classScopeClause` : il ne rend que les
//  classes que l'agent a le droit de voir. C'est juste pour un annuaire, et
//  faux ici — un enseignant responsable de deux classes aurait imprimé un
//  document intitulé « État des effectifs de l'établissement » contenant deux
//  classes, signé, et transmis à une direction départementale. Le document ne
//  porte aucune trace du filtrage : rien, sur le papier, n'aurait permis de
//  s'en apercevoir.
//
//  La contrepartie est OBLIGATOIRE et vit en deux endroits, comme le Calendrier
//  scolaire : la page n'apparaît que pour `AppConstants.directionRoles` dans la
//  sidebar, ET le routeur renvoie les autres au tableau de bord. Une seule des
//  deux protections laisserait l'URL accessible.
// ════════════════════════════════════════════════════════════════════════════

/// Les élèves de l'ÉCOLE, réduits à ce qu'un état des effectifs compte.
///
/// Le filtre `status = 'active'` reste dans le SQL, mais `effectifsParClasse`
/// le refait : la règle appartient au comptage, pas à la requête, et c'est
/// elle qui est testée.
final elevesPourEtatProvider =
    StreamProvider.autoDispose<List<EleveCompte>>((ref) {
  ref.keepAlive();
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(const []);
  }
  return db
      .watch(
        '''
        SELECT ce.status      AS statut,
               ce.class_id    AS class_id,
               s.gender       AS sexe,
               s.is_boarder   AS interne,
               s.has_scholarship AS boursier,
               c.name         AS class_name,
               c.cycle_code   AS cycle_code,
               c.level_order  AS level_order
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        LEFT   JOIN classes c ON c.id = ce.class_id
        WHERE  ce.school_id = ? AND ce.academic_year_id = ?
               AND COALESCE(s.is_active, 1) <> 0
        ''',
        parameters: [schoolId, yearId],
        triggerOnTables: const ['class_enrollments', 'students', 'classes'],
      )
      .map((rows) => [
            for (final r in rows)
              (
                classId: r['class_id'] as String?,
                className: r['class_name'] as String?,
                cycleCode: r['cycle_code'] as String?,
                levelOrder: (r['level_order'] as num?)?.toInt() ?? 999,
                statut: r['statut'] as String?,
                sexe: r['sexe'] as String?,
                // `== 1` serait le piège habituel : la valeur arrive à 0, 1
                // ou NULL selon qu'elle vient du serveur ou d'une saisie locale.
                interne: ((r['interne'] as num?) ?? 0) != 0,
                boursier: ((r['boursier'] as num?) ?? 0) != 0,
              ),
          ]);
});

/// L'état des effectifs prêt à imprimer : classes triées, blocs de cycle,
/// total général.
typedef EtatEffectifs = ({
  List<LigneEffectif> classes,
  List<BlocCycle> blocs,
  LigneEffectif total,
});

final etatEffectifsProvider = Provider.autoDispose<EtatEffectifs?>((ref) {
  final eleves = ref.watch(elevesPourEtatProvider).valueOrNull;
  if (eleves == null) return null;
  final classes = effectifsParClasse(eleves);
  return (
    classes: classes,
    blocs: blocsParCycle(classes),
    total: cumul('TOTAL ÉTABLISSEMENT', classes),
  );
});

/// L'état du personnel prêt à imprimer.
typedef EtatPersonnel = ({
  List<LignePersonnel> categories,
  List<LignePersonnel> statuts,
  LignePersonnel total,
  bool directionEnPoste,
});

/// ⚠️ Bâti sur `staffDirectoryProvider`, la MÊME source que la page Personnel :
/// l'annuaire et l'état signé doivent compter les mêmes agents. C'est aussi
/// pourquoi le correctif `actifOffline` comptait — l'annuaire rendait
/// « inactif » un agent que le tableau de bord comptait en fonction, et l'état
/// aurait hérité de l'un des deux au hasard.
final etatPersonnelProvider = Provider.autoDispose<EtatPersonnel?>((ref) {
  final membres = ref.watch(staffDirectoryProvider).valueOrNull;
  if (membres == null) return null;
  final agents = [
    for (final m in membres)
      (role: m.role, actif: m.isActive, statutEmploi: m.employmentStatus),
  ];
  final categories = personnelParCategorie(agents);
  return (
    categories: categories,
    statuts: personnelParStatut(agents),
    total: cumulPersonnel('TOTAL ÉTABLISSEMENT', categories),
    directionEnPoste: aUneDirectionEnPoste(agents),
  );
});

/// Une ligne de l'état de recouvrement.
typedef LigneRecouvrement = ({
  String className,
  int effectif,
  int aJour,
  int du,
  int encaisse,
});

int resteDe(LigneRecouvrement l) => (l.du - l.encaisse).clamp(0, l.du);

/// L'état de recouvrement par classe.
///
/// ⚠️ Construit sur `paymentsOverviewProvider`, PAS sur un second calcul :
/// l'écran Paiements et ce document doivent annoncer les mêmes nombres. Deux
/// chemins vers le même total finissent toujours par diverger, et ici la
/// divergence part sur du papier.
final etatRecouvrementProvider =
    Provider.autoDispose<List<LigneRecouvrement>?>((ref) {
  final o = ref.watch(paymentsOverviewProvider).valueOrNull;
  if (o == null) return null;
  return [
    for (final r in o.rows)
      (
        className: r.className,
        effectif: r.total,
        aJour: r.ok,
        du: o.duParClasse[r.classId] ?? 0,
        encaisse: o.encaisseParClasse[r.classId] ?? 0,
      ),
  ];
});
