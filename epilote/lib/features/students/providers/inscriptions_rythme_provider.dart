import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/navigation/providers/permissions_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  BILAN DE L'ANNÉE — toutes les inscriptions, pas seulement celles qui restent
//  au guichet.
//
//  La liste de cette page est volontairement le PIPELINE : `inscriptionsDataProvider`
//  écarte `status = 'active'`, parce qu'un dossier validé n'a plus rien à y
//  faire — l'élève inscrit vit dans la page Élèves. C'est un bon découpage.
//
//  Mais les compteurs, eux, en héritaient : sur une école qui avait inscrit
//  trente élèves et en avait réinscrit trente et un, la carte « Nouvelles —
//  premières inscriptions » affichait **0**, et « Réinscriptions » **1**. Non
//  pas approximativement : le chiffre décrivait les deux dossiers non traités
//  qui traînaient, pas le travail de l'année. Aucune ligne à l'écran ne
//  permettait de s'en douter, et la question la plus simple qu'on pose à un
//  module d'inscription — « combien d'élèves avez-vous inscrits ? » — n'avait
//  aucune réponse dans la page qui porte ce nom.
//
//  D'où cette agrégation distincte, sur TOUTES les inscriptions de l'année.
//  Elle compte des lignes, pas des personnes : un élève réinscrit après un
//  rejet a deux dossiers, et c'est bien deux dossiers qu'a traités le
//  secrétariat. L'effectif, lui, se lit sur les inscriptions actives.
// ════════════════════════════════════════════════════════════════════════════
class YearInscriptionTotals {
  const YearInscriptionTotals({
    this.enrolled = 0,
    this.newCount = 0,
    this.reinscription = 0,
    this.transfer = 0,
    this.repeating = 0,
    this.evolution = const [],
  });

  /// Inscriptions ACTIVES : l'effectif réellement scolarisé cette année.
  final int enrolled;

  /// Dossiers de l'année par type, tous statuts confondus.
  final int newCount, reinscription, transfer;

  /// Dossiers portant la mention « redoublant ».
  final int repeating;

  /// Le rythme de la campagne, mois par mois — entrées du mois et effectif
  /// cumulé à la fin de ce mois.
  ///
  /// ⚠️ Il se calcule ICI, sur l'année entière, et non plus dans les stats du
  /// guichet. Le graphe lisait le PIPELINE (`status != 'active'`) : une école
  /// ayant inscrit trois cents élèves et validé les trois cents affichait une
  /// courbe plate. Le titre disait « Rythme des inscriptions » ; ce qui était
  /// tracé était le rythme des dossiers en souffrance. Exactement le défaut
  /// déjà corrigé sur les cartes KPI juste au-dessus, et resté sur le graphe.
  final List<EnrollPoint> evolution;
}

/// ── ⚠️ MÊMES FILTRES QUE LA LISTE, OU LE GRAPHE MENT ────────────────────────
/// Ces compteurs et cette courbe sont posés au-dessus de la liste du guichet,
/// sur la même page, pour la même année. Depuis que `inscriptionsDataProvider`
/// applique le périmètre du profil d'accès, une requête d'école entière ici
/// ferait exactement ce que `graphe-effectif-vs-kpi` décrit : un enseignant
/// restreint lirait la campagne de l'établissement sous ses propres lignes.
final yearInscriptionTotalsProvider =
    StreamProvider.autoDispose<YearInscriptionTotals>((ref) {
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(const YearInscriptionTotals());
  }
  if (!permissionsLoaded(ref)) return const Stream.empty();
  final scope = classScopeClause(ref, 'inscriptions', column: 'class_id');
  // Une seule requête pour les totaux ET le rythme : on groupe par mois, puis
  // Dart additionne. `substr(...,1,7)` plutôt que `strftime` — la date est
  // stockée en texte « AAAA-MM-JJ » et le découpage ne dépend alors d'aucune
  // conversion de fuseau.
  return db
      .watch(
        '''
        SELECT
          substr(COALESCE(enrollment_date, ''), 1, 7)                       AS mois,
          SUM(CASE WHEN status = 'active'                 THEN 1 ELSE 0 END) AS enrolled,
          SUM(CASE WHEN status = 'pending_validation'     THEN 1 ELSE 0 END) AS att,
          SUM(CASE WHEN inscription_type = 'reinscription' THEN 1 ELSE 0 END) AS re,
          SUM(CASE WHEN inscription_type = 'transfer'      THEN 1 ELSE 0 END) AS tr,
          SUM(CASE WHEN COALESCE(inscription_type, 'new') NOT IN
                        ('reinscription', 'transfer')      THEN 1 ELSE 0 END) AS nw,
          SUM(CASE WHEN is_repeating = 1                  THEN 1 ELSE 0 END) AS rep
        FROM class_enrollments
        WHERE school_id = ? AND academic_year_id = ?
        ${scope?.clause ?? ''}
        GROUP BY mois
        ORDER BY mois
        ''',
        parameters: [schoolId, yearId, ...?scope?.params],
      )
      .map((rows) {
        var enrolled = 0, nw = 0, re = 0, tr = 0, rep = 0;
        final valideesParMois = <String, int>{};
        final attenteParMois = <String, int>{};
        for (final r in rows) {
          int n(String k) => (r[k] as int?) ?? 0;
          enrolled += n('enrolled');
          nw += n('nw');
          re += n('re');
          tr += n('tr');
          rep += n('rep');
          final mois = (r['mois'] as String?) ?? '';
          // Une inscription sans date ne se place sur aucun mois : elle compte
          // dans les totaux, pas dans le rythme. L'écarter des totaux aussi
          // ferait un graphe cohérent et des compteurs faux.
          if (mois.length == 7) {
            valideesParMois[mois] = n('enrolled');
            attenteParMois[mois] = n('att');
          }
        }

        return YearInscriptionTotals(
          evolution: construireRythmeInscriptions(valideesParMois, attenteParMois),
          enrolled: enrolled,
          newCount: nw,
          reinscription: re,
          transfer: tr,
          repeating: rep,
        );
      });
});

// ─── Le rythme, mois par mois ────────────────────────────────────────────────

const _kMoisCourt = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

/// Au-delà, la plage vient d'une date aberrante (saisie à quatre chiffres
/// fautive), pas d'une campagne d'inscription : on ne comble pas.
const _kMaxMoisComblables = 36;

/// Transforme deux relevés « AAAA-MM → effectif » en une suite CONTINUE de mois.
///
/// ⚠️ POURQUOI COMBLER LES TROUS. `GROUP BY mois` ne rend que les mois où
/// quelque chose s'est passé. Une école qui inscrit en septembre, rien en
/// octobre, puis douze élèves en novembre obtenait deux colonnes CÔTE À CÔTE :
/// l'axe étant catégoriel, le mois creux n'existait pas — même pas comme
/// espace. Le graphe s'appelle « Rythme des inscriptions » et c'était
/// précisément le rythme qu'il effaçait : la pause d'octobre se lisait comme
/// une reprise immédiate. Les mois vides valent zéro et se dessinent.
List<EnrollPoint> construireRythmeInscriptions(
  Map<String, int> validees,
  Map<String, int> attente,
) {
  final connus = <String>{...validees.keys, ...attente.keys}.toList()..sort();
  if (connus.isEmpty) return const [];

  // « AAAA-MM » → index absolu de mois, pour itérer sans arithmétique de date.
  int? index(String ym) {
    final p = ym.split('-');
    if (p.length != 2) return null;
    final a = int.tryParse(p[0]), m = int.tryParse(p[1]);
    if (a == null || m == null || m < 1 || m > 12) return null;
    return a * 12 + (m - 1);
  }

  final indices = [for (final m in connus) index(m)].nonNulls.toList();
  if (indices.isEmpty) return const [];
  final debut = indices.reduce((a, b) => a < b ? a : b);
  final fin = indices.reduce((a, b) => a > b ? a : b);

  final continu = (fin - debut) < _kMaxMoisComblables
      ? [for (var i = debut; i <= fin; i++) i]
      : indices;

  var cumul = 0;
  final points = <EnrollPoint>[];
  for (final i in continu) {
    final annee = i ~/ 12, mois = i % 12;
    // L'année est REMISE sur quatre chiffres : la clé d'origine est le
    // `substr(date, 1, 7)` de SQLite, donc « 0025-09 » pour une saisie fautive.
    // Sans le remplissage, la clé reconstruite valait « 25-09 » et ne
    // retrouvait plus sa propre ligne — le mois s'affichait à zéro.
    final aaaa = annee.toString().padLeft(4, '0');
    final ym = '$aaaa-${(mois + 1).toString().padLeft(2, '0')}';
    final v = validees[ym] ?? 0;
    cumul += v;
    points.add(EnrollPoint(
      // « sept. 25 » plutôt que « 09/2025 » : même convention que la page
      // Élèves, et deux fois moins large sur un axe qui porte douze mois.
      '${_kMoisCourt[mois]} ${aaaa.substring(2)}',
      v,
      cumul,
      pending: attente[ym] ?? 0,
    ));
  }
  return points;
}

// ─── Agrégations dérivées (KPI / cycles / évolution) ─────────────────────────

/// Un point d'évolution : entrées du mois, cumul à ce mois, dossiers déposés ce
/// mois-là et toujours en attente de validation.
class EnrollPoint {
  const EnrollPoint(this.label, this.count, this.cumul, {this.pending = 0});
  final String label;           // « sept. 25 »
  final int count;              // entrées VALIDÉES du mois (rythme)
  final int cumul;              // effectif cumulé à la fin du mois
  final int pending;            // dossiers du mois encore en attente
}
