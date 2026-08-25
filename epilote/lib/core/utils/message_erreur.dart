// ════════════════════════════════════════════════════════════════════════════
//  Traduction des exceptions en messages lisibles
//
//  L'application affichait l'objet exception brut : une secrétaire de Kinkala
//  lisait `PostgrestException(message: JWT expired, code: PGRST303, details:
//  Unauthorized, hint: null)`. Illisible, anxiogène, et surtout INACTIONNABLE —
//  rien n'y dit quoi faire.
//
//  Trois règles tenues ici :
//    1. dire ce qui s'est passé en français ordinaire ;
//    2. dire quoi faire quand il y a quelque chose à faire ;
//    3. garder un code technique court pour le support, entre parenthèses, sur
//       les seuls cas non reconnus — sinon l'agent n'a rien à donner au
//       téléphone et le support travaille à l'aveugle.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/session_morte.dart';

/// Message affichable à l'agent pour [erreur].
///
/// [contexte] nomme l'action tentée quand elle n'est pas évidente à l'écran
/// (« Impression », « Export »…) : « Impression — le service ne répond pas. »
String messageErreur(Object? erreur, {String? contexte}) {
  final texte = _traduire(erreur);
  return contexte == null || contexte.isEmpty ? texte : '$contexte — $texte';
}

String _traduire(Object? erreur) {
  if (erreur == null) return 'Une erreur est survenue.';

  // La session prime sur tout le reste : c'est le seul cas où l'agent doit
  // agir tout de suite, et il explique à lui seul des écrans entiers en erreur.
  if (estSessionMorte(erreur)) {
    return 'Votre session a expiré. Reconnectez-vous pour continuer — '
        'aucune donnée n’a été perdue.';
  }

  if (erreur is PostgrestException) return _postgrest(erreur);
  if (erreur is AuthException) return _auth(erreur);
  if (erreur is StorageException) {
    return 'Le fichier n’a pas pu être transféré. Réessayez ; '
        'si cela persiste, vérifiez sa taille et son format.';
  }
  if (_estCoupureReseau(erreur)) {
    return 'Impossible de joindre le serveur. Vérifiez votre connexion '
        'Internet, puis réessayez.';
  }
  if (erreur is TimeoutException) {
    return 'Le serveur met trop de temps à répondre. Réessayez dans un '
        'instant.';
  }
  if (erreur is FormatException) {
    return 'Une donnée reçue n’a pas le format attendu.';
  }

  return 'Une erreur inattendue est survenue. (${_typeCourt(erreur)})';
}

String _postgrest(PostgrestException e) {
  // Un HINT renseigné est, par convention en base, une phrase déjà rédigée pour
  // l'agent — « Le trimestre « T2 » chevauche « T1 ». Ajustez les dates. » Elle
  // dit la cause ET quoi faire, là où la traduction par code ne peut donner
  // qu'un générique. Elle prime donc. Sans HINT, comportement inchangé.
  final hint = e.hint?.trim();
  if (hint != null && hint.isNotEmpty) return hint;

  switch (e.code) {
    case '42501': // insufficient_privilege — refus RLS
      return 'Vous n’avez pas les droits nécessaires pour cette action.';
    case '23505': // unique_violation
      return 'Cet enregistrement existe déjà.';
    case '23503': // foreign_key_violation
      return 'Impossible : cet élément est encore utilisé ailleurs. '
          'Retirez d’abord ce qui en dépend.';
    case '23502': // not_null_violation
      return 'Un champ obligatoire n’est pas renseigné.';
    case '23514': // check_violation
      return 'Une valeur saisie n’est pas acceptée par le contrôle de saisie.';
    case '22P02': // invalid_text_representation
      return 'Une valeur saisie n’a pas le format attendu.';
    case 'PGRST116': // aucune ligne là où une seule était attendue
      return 'Cet élément est introuvable. Il a peut-être été supprimé '
          'entre-temps.';
    case '57014': // query_canceled
      return 'La recherche a été interrompue : elle prenait trop de temps. '
          'Affinez les filtres.';
  }

  final m = e.message.toLowerCase();
  if (m.contains('permission denied') || m.contains('row-level security')) {
    return 'Vous n’avez pas les droits nécessaires pour cette action.';
  }
  if (m.contains('violates foreign key')) {
    return 'Impossible : cet élément est encore utilisé ailleurs.';
  }
  if (m.contains('duplicate key')) return 'Cet enregistrement existe déjà.';

  final code = e.code;
  return 'Le serveur a refusé l’opération.'
      '${code == null || code.isEmpty ? '' : ' ($code)'}';
}

String _auth(AuthException e) {
  final m = e.message.toLowerCase();
  if (m.contains('invalid login')) return 'E-mail ou mot de passe incorrect.';
  if (m.contains('email not confirmed')) {
    return 'Cette adresse e-mail n’a pas encore été confirmée.';
  }
  if (m.contains('too many')) {
    return 'Trop de tentatives. Patientez quelques minutes.';
  }
  if (m.contains('user already registered')) {
    return 'Un compte existe déjà avec cette adresse.';
  }
  if (m.contains('weak password') || m.contains('at least')) {
    return 'Mot de passe trop faible.';
  }
  return 'La connexion au compte a échoué.';
}

bool _estCoupureReseau(Object erreur) {
  if (erreur is SocketException || erreur is HttpException) return true;
  if (erreur is HandshakeException) return true;
  final t = erreur.toString().toLowerCase();
  return t.contains('socketexception') ||
      t.contains('failed host lookup') ||
      t.contains('connection refused') ||
      t.contains('connection closed') ||
      t.contains('clientexception');
}

/// Nom de type nu, sans le détail : « PostgrestException », pas la ligne
/// entière avec ses champs. Assez pour le support, pas assez pour effrayer.
String _typeCourt(Object erreur) {
  final t = erreur.runtimeType.toString();
  return t.length <= 40 ? t : t.substring(0, 40);
}
