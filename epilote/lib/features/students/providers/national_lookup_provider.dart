import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE GUICHET NATIONAL D'IDENTIFICATION
//
//  ── POURQUOI CE FICHIER APPELLE SUPABASE, CONTRAIREMENT À LA RÈGLE ─────────
//  Le personnel scolaire lit et écrit par PowerSync, jamais par `supabase`.
//  Cette règle protège le travail hors ligne : ce que l'agent manipule est sur
//  son poste, et rien ne dépend silencieusement du réseau.
//
//  Une recherche NATIONALE échappe à cette règle par nature, pas par entorse :
//  les élèves des autres établissements ne sont pas sur l'appareil, et ils ne
//  doivent pas y être. Aucune synchronisation ne peut donc répondre à la
//  question posée ici. On passe par une RPC, et par une seule.
//
//  Corollaire, tenu par l'appelant : l'assistant d'inscription doit continuer
//  de fonctionner sans réseau. La recherche nationale est un CONFORT qui évite
//  un doublon quand elle est disponible — jamais un passage obligé.
//
//  ── POURQUOI C'EST UN GESTE, ET PAS UNE RECHERCHE PENDANT LA FRAPPE ───────
//  Chaque appel est journalisé côté serveur : une école consulte le registre
//  national, cela laisse une trace. Déclencher à chaque touche saisie
//  remplirait le journal d'audit de bruit et le rendrait inutile — au moment
//  précis où il sert à justifier l'ouverture du registre. D'où un bouton.
// ════════════════════════════════════════════════════════════════════════════

/// Un élève trouvé dans le registre national. Projection volontairement
/// pauvre : de quoi reconnaître l'enfant et voir d'où il vient, rien de plus.
class NationalStudentMatch {
  const NationalStudentMatch({
    required this.ine,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.schoolName,
    required this.department,
    required this.lastYear,
    required this.lastClass,
    required this.status,
    required this.sameSchool,
  });

  final String ine, firstName, lastName;
  final String? dateOfBirth, gender, schoolName, department;
  final String? lastYear, lastClass, status;

  /// Vrai si l'enfant est déjà dans l'établissement de l'agent. Le cas n'est
  /// pas une erreur : c'est le signal qu'il ne faut pas créer un second
  /// dossier mais retrouver celui qui existe.
  final bool sameSchool;

  String get fullName => '$firstName $lastName'.trim();

  /// « CET Ouésso · Sangha · 2025-2026, 5e A »
  String get provenance => [
        if (schoolName?.isNotEmpty ?? false) schoolName,
        if (department?.isNotEmpty ?? false) department,
        if (lastYear?.isNotEmpty ?? false)
          '$lastYear${(lastClass?.isNotEmpty ?? false) ? ', $lastClass' : ''}',
      ].whereType<String>().join(' · ');

  static NationalStudentMatch fromMap(Map<String, dynamic> m) =>
      NationalStudentMatch(
        ine: (m['ine'] as String?) ?? '',
        firstName: (m['first_name'] as String?) ?? '',
        lastName: (m['last_name'] as String?) ?? '',
        dateOfBirth: m['date_of_birth'] as String?,
        gender: m['gender'] as String?,
        schoolName: m['school_name'] as String?,
        department: m['school_department'] as String?,
        lastYear: m['derniere_annee'] as String?,
        lastClass: m['derniere_classe'] as String?,
        status: m['statut'] as String?,
        sameSchool: m['meme_ecole'] == true,
      );
}

/// Ce que l'écran a besoin de savoir : cherché ou pas, en cours, résultat,
/// et le cas particulier de l'absence de réseau — qui n'est pas un échec.
sealed class NationalLookupState {
  const NationalLookupState();
}

class LookupIdle extends NationalLookupState {
  const LookupIdle();
}

class LookupRunning extends NationalLookupState {
  const LookupRunning();
}

class LookupDone extends NationalLookupState {
  const LookupDone(this.matches);
  final List<NationalStudentMatch> matches;
  bool get isEmpty => matches.isEmpty;
}

/// Échec. [offline] distingue « pas de réseau » — normal et sans gravité —
/// d'une vraie erreur, qu'il faut montrer telle quelle.
class LookupFailed extends NationalLookupState {
  const LookupFailed(this.message, {this.offline = false});
  final String message;
  final bool offline;
}

/// Interroge le registre national. Ne lève jamais : un guichet d'inscription
/// ne doit pas s'arrêter parce que la recherche a échoué.
class NationalLookup extends StateNotifier<NationalLookupState> {
  NationalLookup(this._ref) : super(const LookupIdle());
  final Ref _ref;

  void reset() => state = const LookupIdle();

  Future<void> search({
    required String lastName,
    required String firstName,
    required String? dateOfBirth,
  }) async {
    if (lastName.trim().length < 2 ||
        firstName.trim().length < 2 ||
        (dateOfBirth?.isEmpty ?? true)) {
      state = const LookupFailed(
          'Nom, prénom et date de naissance sont nécessaires pour '
          'interroger le registre national.');
      return;
    }

    state = const LookupRunning();
    try {
      final client = _ref.read(supabaseClientProvider);
      final rows = await client.rpc('rechercher_eleve_national', params: {
        'p_last_name': lastName.trim(),
        'p_first_name': firstName.trim(),
        'p_date_of_birth': dateOfBirth,
      }) as List;
      state = LookupDone([
        for (final r in rows)
          NationalStudentMatch.fromMap(Map<String, dynamic>.from(r as Map)),
      ]);
    } catch (e) {
      final s = e.toString();
      // Le poste peut très bien être hors ligne : c'est le mode normal de
      // l'application, pas une panne. On le dit autrement qu'une erreur.
      final offline = s.contains('SocketException') ||
          s.contains('ClientException') ||
          s.contains('Failed host lookup') ||
          s.contains('Connection closed');
      state = LookupFailed(
        offline
            ? 'Registre national injoignable — poste hors ligne. '
                'L\'inscription peut se poursuivre normalement.'
            : 'Recherche impossible : $s',
        offline: offline,
      );
    }
  }
}

final nationalLookupProvider =
    StateNotifierProvider.autoDispose<NationalLookup, NationalLookupState>(
        NationalLookup.new);
