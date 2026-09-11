import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE ÉCRITURE QUE LA RLS REFUSE NE DIT RIEN
//
//  ── LA FAUTE, TROUVÉE TROIS FOIS LE MÊME JOUR (2026-08-30) ────────────────
//  Un UPDATE ou un DELETE que le `USING` d'une politique écarte ne lève PAS
//  d'erreur : il touche ZÉRO ligne et PostgREST répond 204. L'écran affiche
//  « enregistré », et rien n'est enregistré. Mesuré en base, trois fois :
//
//   1. `school_groups` — le BARÈME DE PASSAGE, la barre au-dessus de laquelle
//      un élève passe en classe supérieure, était inmodifiable par l'admin
//      groupe à qui l'écran est destiné. (0154)
//   2. `support_tickets` — la RELANCE d'un ticket résolu n'y changeait rien :
//      le message partait, le ticket restait « résolu », le support ne le
//      revoyait jamais. (0157)
//   3. `national_exams` / `exam_sessions` / `exam_eligibility_rules` — la
//      faute inverse : AUCUNE portée de groupe. Un admin de groupe PRIVÉ
//      pouvait modifier le BAC national et réécrire 35 sessions officielles
//      d'un coup. (0155)
//
//  ── CE QUE CE GARDE PEUT, ET CE QU'IL NE PEUT PAS ─────────────────────────
//  Un test hors ligne ne lit pas les politiques de la base : il ne peut pas
//  vérifier qu'une écriture est autorisée. Il peut faire l'essentiel — obliger
//  à ce que toute NOUVELLE table écrite depuis l'application soit inscrite
//  ici, DÉLIBÉRÉMENT, après avoir vérifié ses politiques.
//
//  La liste ci-dessous n'est donc pas une permission : c'est la trace d'un
//  contrôle. Ajouter une ligne sans avoir ouvert les politiques de la table
//  vide le garde de son sens.
//
//  ── LA PROCÉDURE, QUAND CE TEST ÉCHOUE ────────────────────────────────────
//  1. Interroger `pg_policy` pour la table, verbe par verbe (`polcmd` :
//     a = INSERT, w = UPDATE, d = DELETE, r = SELECT, * = tout).
//  2. Vérifier que le rôle qui écrit satisfait le `USING` **et** le
//     `WITH CHECK` correspondants.
//  3. Sonder en base sous l'identité réelle de ce rôle et LIRE `ROW_COUNT` :
//     zéro ligne sans erreur, c'est la faute.
//  4. Seulement ensuite, ajouter la table ici.
// ════════════════════════════════════════════════════════════════════════════

/// Écritures PostgREST connues, par espace applicatif. Relevé du 2026-08-30,
/// chaque table confrontée à ses politiques.
const _kEcrituresConnues = <String, Set<String>>{
  // Espace admin_groupe — en ligne, `supabase.from(...)`.
  'admin_groupe': {
    'academic_years',
    'access_profiles',
    'education_levels',
    'education_programs',
    'exam_eligibility_rules',
    'exam_official_results',
    'exam_publications',
    'exam_sessions',
    'fee_structures',
    'group_settings',
    'national_exams',
    'notifications',
    'payment_configs',
    'profiles',
    'school_groups',
    'school_holidays',
    'school_projects',
    'schools',
    'sequences',
    'support_tickets',
    'trimesters',
  },
  // Espace super_admin — en ligne, `supabase.from(...)`.
  'super_admin': {
    'app_releases',
    'group_invoices',
    'module_categories',
    'modules',
    'payment_configs',
    'plan_modules',
    // Donnees de FONDATEUR (migration 0160). RLS : super_admin seul, en
    // lecture comme en ecriture. Verifie : `platform_costs_super_admin`
    // et `tutelle_licences_super_admin`, FOR ALL, USING + WITH CHECK.
    'platform_costs',
    'tutelle_licences',
    'platform_partners',
    'platform_service_messages',
    'platform_settings',
    'profiles',
    'school_groups',
    'subscription_plans',
    'support_tickets',
  },
  // Modules PARTAGÉS, scope-aware, en ligne : communication et profil.
  'autre': {
    'announcement_comments',
    // ⚠️ `circulaires` a quitte ce releve le 2026-09-02 : l'application n'y
    // ecrit plus rien. La circulaire de tutelle ajoutait un quatrieme canal
    // de communication a cote des annonces, de la messagerie et des tickets,
    // pour un objet dont la base ne comptait aucune ligne ; un ministere ecrit
    // desormais a un groupe supervise par la MESSAGERIE. La table survit en
    // base, dormante — la retirer suppose de defaire cinq migrations et des
    // regles PowerSync.
    'announcement_reactions',
    'announcements',
    'conversation_members',
    'conversations',
    'events',
    'messages',
    // « Mon profil » (features/profil) écrit SA PROPRE ligne.
    // Politiques relevées le 2026-09-04 : `profiles_update` accepte
    // `id = auth.uid()` — troisième branche du USING, celle qui vaut ici.
    // ⚠️ Et le déclencheur `profiles_garde_colonnes_de_pouvoir` (0188) GÈLE
    // en silence `role`, `access_profile_id`, `school_id`, `group_id`,
    // `is_active` et les trois `sync_*` sur sa propre ligne : la page n'écrit
    // donc que `first_name`, `last_name`, `phone` et `avatar_url`. Les autres
    // afficheraient « enregistré » sur une valeur remise comme avant.
    'profiles',
    'notifications',
    'saved_announcements',
    'stories',
    'story_views',
    'support_ticket_messages',
    'support_tickets',
  },
};

/// `.from('table')` suivi — éventuellement après un saut de ligne — d'un verbe
/// d'écriture. Le saut de ligne compte : `dart format` coupe volontiers là.
final _motif = RegExp(
    r"\.from\(\s*'([a-z_0-9]+)'\s*\)\s*(?:\r?\n\s*)?"
    r'\.(update|insert|upsert|delete)\b');

String _espaceDe(String chemin) {
  if (chemin.contains('/features/super_admin/')) return 'super_admin';
  if (chemin.contains('/features/admin_groupe/')) return 'admin_groupe';
  return 'autre';
}

void main() {
  test('toute table écrite via PostgREST est inscrite au relevé', () {
    final trouvees = <String, Map<String, String>>{
      for (final e in _kEcrituresConnues.keys) e: <String, String>{},
    };

    final racine = Directory('lib');
    expect(racine.existsSync(), isTrue,
        reason: 'Sonde aveugle : `lib/` introuvable depuis le dossier de test.');

    for (final f in racine.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final chemin = f.path.replaceAll(r'\', '/');
      final espace = _espaceDe(chemin);
      for (final m in _motif.allMatches(f.readAsStringSync())) {
        trouvees[espace]![m.group(1)!] = chemin;
      }
    }

    // Garde du garde : si le motif ne trouve plus rien, le test « passerait »
    // en n'ayant rien regardé. C'est la panne la plus trompeuse d'une sonde.
    final total = trouvees.values.fold<int>(0, (s, m) => s + m.length);
    expect(total, greaterThan(30),
        reason: 'Seulement $total écritures détectées : le motif ne reconnaît '
            'probablement plus la syntaxe employée. Corriger la sonde AVANT '
            'de conclure quoi que ce soit.');

    final nouvelles = <String>[];
    for (final espace in trouvees.keys) {
      for (final entree in trouvees[espace]!.entries) {
        if (!_kEcrituresConnues[espace]!.contains(entree.key)) {
          nouvelles.add('$espace → ${entree.key}  (${entree.value})');
        }
      }
    }

    expect(nouvelles, isEmpty,
        reason: 'Écriture vers une table NON RELEVÉE. Vérifier ses politiques '
            'RLS pour ce rôle — un refus sur UPDATE/DELETE est MUET — puis '
            'inscrire la table dans `_kEcrituresConnues` :\n'
            '${nouvelles.join('\n')}');
  });

  test('le relevé ne garde pas de tables devenues mortes', () {
    // Une entrée qui ne correspond plus à aucune écriture donne à croire
    // qu'on a contrôlé quelque chose qui n'existe plus.
    final vues = <String, Set<String>>{
      for (final e in _kEcrituresConnues.keys) e: <String>{},
    };
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final espace = _espaceDe(f.path.replaceAll(r'\', '/'));
      for (final m in _motif.allMatches(f.readAsStringSync())) {
        vues[espace]!.add(m.group(1)!);
      }
    }
    final mortes = <String>[];
    for (final espace in _kEcrituresConnues.keys) {
      for (final t in _kEcrituresConnues[espace]!) {
        if (!vues[espace]!.contains(t)) mortes.add('$espace → $t');
      }
    }
    expect(mortes, isEmpty,
        reason: 'Entrées du relevé sans écriture correspondante : '
            '${mortes.join(', ')}');
  });
}
