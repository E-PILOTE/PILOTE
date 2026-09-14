import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../classes/providers/class_provider.dart';
import 'presences_provider.dart' show kSlugPresences;

// ════════════════════════════════════════════════════════════════════════════
//  ÉTAT MENSUEL D'ASSIDUITÉ — l'agrégat qui manquait sa sortie
//
//  L'appel quotidien était calculé, affiché… et jamais totalisé.
//  `attendanceOverviewProvider` répond à « où en est l'appel CE MATIN ». La
//  circonscription, elle, demande le RELEVÉ DU MOIS : combien de demi-journées
//  ont été faites, quel taux de présence, et surtout **qui** manque.
//
//  ── UNE RÈGLE TIENT TOUT CE FICHIER ───────────────────────────────────────
//  Un taux sans pointage n'est pas 0 %, c'est INCONNU. Une classe où personne
//  n'a fait l'appel du mois afficherait sinon « 0 % de présence » — le pire
//  chiffre possible, présenté comme un fait, sur la classe dont on ne sait
//  précisément rien. D'où [AssiduiteClasse.tauxPresence] qui rend `null`, et
//  un état qui sait dire qu'il est vide.
//
//  ── CE QU'ON COMPTE, ET CE QU'ON NE COMPTE PAS ────────────────────────────
//  Le dénominateur est le nombre de POINTAGES (présent + absent + retard), pas
//  l'effectif × les jours : une classe dont l'appel n'a été fait que huit fois
//  ne doit pas être notée sur vingt. Compter les jours non faits comme des
//  absences transformerait un défaut de saisie en absentéisme d'élèves.
//
//  Un RETARD compte comme une présence au taux — l'élève était là — mais reste
//  décompté à part, parce que c'est lui qu'on veut voir monter.
// ════════════════════════════════════════════════════════════════════════════

/// Un mois civil. L'année scolaire congolaise court d'octobre à juillet ; le
/// relevé, lui, se rend par mois civil, comme le demande la circonscription.
typedef MoisScolaire = ({int annee, int mois});

/// À partir de combien d'absences un élève figure sur la liste d'alerte.
///
/// Quatre demi-journées = deux jours de classe manqués dans le mois. En
/// dessous, la liste se remplirait de rhumes et ne serait plus lue ; c'est le
/// premier signal de déperdition qu'on cherche, pas l'exhaustivité.
const int kSeuilAlerteAbsences = 4;

const List<String> kMoisFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String libelleMois(MoisScolaire m) =>
    '${kMoisFr[(m.mois - 1).clamp(0, 11)]} ${m.annee}';

/// L'assiduité d'une classe sur le mois.
class AssiduiteClasse {
  const AssiduiteClasse({
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.effectif,
    required this.demiJournees,
    required this.finalisees,
    required this.presences,
    required this.absences,
    required this.retards,
    required this.justifiees,
  });

  final String classId, className;
  final String? cycleCode, levelCode;
  final int levelOrder;

  /// Élèves inscrits — le contexte, jamais le dénominateur du taux.
  final int effectif;

  /// Demi-journées pour lesquelles un appel EXISTE, et celles qui ont été
  /// finalisées (l'écart dit ce qui reste ouvert).
  final int demiJournees, finalisees;

  final int presences, absences, retards;

  /// Absences portant une justification renseignée.
  final int justifiees;

  int get pointages => presences + absences + retards;
  int get injustifiees => absences - justifiees;

  /// Taux de présence en %, ou **`null` si aucun pointage** — voir l'en-tête.
  double? get tauxPresence =>
      pointages == 0 ? null : (presences + retards) * 100 / pointages;
}

/// Un élève dont l'absentéisme dépasse le seuil d'alerte sur le mois.
class AssiduiteEleve {
  const AssiduiteEleve({
    required this.studentId,
    required this.nom,
    required this.matricule,
    required this.className,
    required this.absences,
    required this.retards,
    required this.justifiees,
  });

  final String studentId, nom;
  final String? matricule, className;
  final int absences, retards, justifiees;

  int get injustifiees => absences - justifiees;
}

/// Le relevé du mois pour le périmètre de l'agent.
class EtatAssiduiteMensuel {
  const EtatAssiduiteMensuel({
    required this.mois,
    required this.classes,
    required this.alertes,
    required this.joursPointes,
    required this.perimetreCharge,
  });

  /// L'état « les droits ne sont pas encore chargés ». Distinct d'un mois
  /// vide : on ne sait pas encore quelles classes regarder.
  const EtatAssiduiteMensuel.enAttente(this.mois)
      : classes = const [],
        alertes = const [],
        joursPointes = 0,
        perimetreCharge = false;

  final MoisScolaire mois;
  final List<AssiduiteClasse> classes;
  final List<AssiduiteEleve> alertes;

  /// Dates distinctes où au moins un appel a été ouvert.
  final int joursPointes;
  final bool perimetreCharge;

  int get effectif => classes.fold(0, (a, c) => a + c.effectif);
  int get presences => classes.fold(0, (a, c) => a + c.presences);
  int get absences => classes.fold(0, (a, c) => a + c.absences);
  int get retards => classes.fold(0, (a, c) => a + c.retards);
  int get justifiees => classes.fold(0, (a, c) => a + c.justifiees);
  int get injustifiees => absences - justifiees;
  int get pointages => presences + absences + retards;
  int get demiJournees => classes.fold(0, (a, c) => a + c.demiJournees);

  /// Classes où PERSONNE n'a fait l'appel du mois. C'est l'information la plus
  /// utile du document pour un chef d'établissement — et elle disparaîtrait
  /// dans un taux moyen.
  List<AssiduiteClasse> get sansAucunAppel =>
      [for (final c in classes) if (c.pointages == 0) c];

  double? get tauxPresence =>
      pointages == 0 ? null : (presences + retards) * 100 / pointages;

  /// Aucun pointage sur tout le périmètre : le document doit le DIRE, pas
  /// afficher une colonne de zéros.
  bool get aucunPointage => pointages == 0;
}

/// Relevé mensuel d'assiduité, sur le périmètre du module `presences-eleves`.
final assiduiteMensuelleProvider = FutureProvider.autoDispose
    .family<EtatAssiduiteMensuel, MoisScolaire>((ref, mois) async {
  ref.keepAlive();

  // Périmètre de CE module — un enseignant restreint à ses classes ne doit pas
  // produire l'état de tout l'établissement.
  final classes =
      ref.watch(classesForModuleProvider(kSlugPresences)).valueOrNull;
  if (classes == null) return EtatAssiduiteMensuel.enAttente(mois);
  if (classes.isEmpty) {
    return EtatAssiduiteMensuel(
        mois: mois,
        classes: const [],
        alertes: const [],
        joursPointes: 0,
        perimetreCharge: true);
  }

  final ids = [for (final c in classes) c.id];
  final ph = List.filled(ids.length, '?').join(',');
  final m = mois.mois.toString().padLeft(2, '0');
  // `record_date` est du texte ISO zéro-comblé : la comparaison lexicale suit
  // l'ordre chronologique, et « -31 » majore tous les mois sans exception.
  final debut = '${mois.annee}-$m-01';
  final fin = '${mois.annee}-$m-31';

  final rows = await db.getAll(
    '''
    SELECT r.class_id   AS cid,
           r.record_date AS jour,
           r.period      AS periode,
           r.is_finalized AS fin,
           e.student_id  AS sid,
           e.status      AS statut,
           e.justification AS motif,
           s.first_name  AS prenom,
           s.last_name   AS nom,
           s.matricule   AS matricule
    FROM   attendance_entries e
    JOIN   attendance_records r ON r.id = e.attendance_record_id
    LEFT JOIN students s ON s.id = e.student_id
    WHERE  r.record_date >= ? AND r.record_date <= ?
      AND  r.class_id IN ($ph)
    ''',
    [debut, fin, ...ids],
  );

  final parClasse = <String, _Cumul>{};
  final parEleve = <String, _CumulEleve>{};
  final jours = <String>{};
  final feuilles = <String, Set<String>>{};
  final feuillesFinales = <String, Set<String>>{};

  for (final r in rows) {
    final cid = r['cid'] as String? ?? '';
    final jour = r['jour'] as String? ?? '';
    final periode = r['periode'] as String? ?? '';
    final cle = '$jour|$periode';
    jours.add(jour);
    feuilles.putIfAbsent(cid, () => {}).add(cle);
    if (((r['fin'] as int?) ?? 0) == 1) {
      feuillesFinales.putIfAbsent(cid, () => {}).add(cle);
    }

    final c = parClasse.putIfAbsent(cid, _Cumul.new);
    final statut = r['statut'] as String?;
    final motif = (r['motif'] as String?)?.trim();
    final justifie = motif != null && motif.isNotEmpty;

    switch (statut) {
      case 'present':
        c.presences++;
      case 'absent':
        c.absences++;
        if (justifie) c.justifiees++;
      case 'late':
        c.retards++;
    }

    final sid = r['sid'] as String?;
    if (sid != null && (statut == 'absent' || statut == 'late')) {
      final e = parEleve.putIfAbsent(
        sid,
        () => _CumulEleve(
          nom: '${(r['nom'] as String?) ?? ''} '
                  '${(r['prenom'] as String?) ?? ''}'
              .trim(),
          matricule: r['matricule'] as String?,
          classId: cid,
        ),
      );
      if (statut == 'absent') {
        e.absences++;
        if (justifie) e.justifiees++;
      } else {
        e.retards++;
      }
    }
  }

  final nomDeClasse = {for (final c in classes) c.id: c.name};

  final lignes = [
    for (final c in classes)
      AssiduiteClasse(
        classId: c.id,
        className: c.name,
        cycleCode: c.cycleCode,
        levelCode: c.levelCode,
        levelOrder: c.levelOrder ?? 999,
        effectif: c.studentCount ?? 0,
        demiJournees: feuilles[c.id]?.length ?? 0,
        finalisees: feuillesFinales[c.id]?.length ?? 0,
        presences: parClasse[c.id]?.presences ?? 0,
        absences: parClasse[c.id]?.absences ?? 0,
        retards: parClasse[c.id]?.retards ?? 0,
        justifiees: parClasse[c.id]?.justifiees ?? 0,
      ),
  ]..sort((a, b) {
      final o = a.levelOrder.compareTo(b.levelOrder);
      return o != 0 ? o : a.className.compareTo(b.className);
    });

  final alertes = [
    for (final entree in parEleve.entries)
      if (entree.value.absences >= kSeuilAlerteAbsences)
        AssiduiteEleve(
          studentId: entree.key,
          nom: entree.value.nom,
          matricule: entree.value.matricule,
          className: nomDeClasse[entree.value.classId],
          absences: entree.value.absences,
          retards: entree.value.retards,
          justifiees: entree.value.justifiees,
        ),
  ]..sort((a, b) {
      // Les injustifiées d'abord : ce sont elles qui appellent une convocation.
      final o = b.injustifiees.compareTo(a.injustifiees);
      if (o != 0) return o;
      final p = b.absences.compareTo(a.absences);
      return p != 0 ? p : a.nom.compareTo(b.nom);
    });

  return EtatAssiduiteMensuel(
    mois: mois,
    classes: lignes,
    alertes: alertes,
    joursPointes: jours.length,
    perimetreCharge: true,
  );
});

class _Cumul {
  int presences = 0, absences = 0, retards = 0, justifiees = 0;
}

class _CumulEleve {
  _CumulEleve({required this.nom, required this.matricule, required this.classId});
  final String nom;
  final String? matricule;
  final String classId;
  int absences = 0, retards = 0, justifiees = 0;
}
