import 'dart:io';

import 'package:epilote/features/super_admin/providers/comptes_admin_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ADRESSE AFFICHÉE N'ÉTAIT PAS CELLE QUI OUVRE UNE SESSION
//
//  ── CE QUI S'EST PASSÉ (2026-09-04) ───────────────────────────────────────
//  Le fondateur a voulu ouvrir l'espace d'un client. Il a lu l'adresse
//  affichée sous le nom du groupe, sur sa propre page Abonnements —
//  `admin@edec.cg` — et la connexion a échoué. Il a conclu à un mot de passe
//  perdu et a demandé une réinitialisation. Le mot de passe était bon : le
//  compte s'appelle `admin.edec@epilote.cg`.
//
//  `school_groups.admin_email` est une colonne de CONTACT. Vérifié sur les
//  HUIT comptes d'administrateur de la base : huit adresses affichées, ZÉRO
//  correspondance avec le compte réel.
//
//  ── POURQUOI C'EST GRAVE ──────────────────────────────────────────────────
//  Cet écran est celui qu'on ouvre quand un client appelle parce qu'il
//  n'arrive pas à se connecter. Il donnait l'adresse qui ne marche pas — et il
//  la donnait avec l'autorité d'un logiciel.
// ════════════════════════════════════════════════════════════════════════════

const _abonnements =
    'lib/features/super_admin/screens/subscriptions_screen.dart';
const _groupes = 'lib/features/super_admin/screens/school_groups_screen.dart';
const _provider =
    'lib/features/super_admin/providers/comptes_admin_provider.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

CompteAdmin _compte(String email, {bool actif = true, String nom = 'A B'}) =>
    CompteAdmin(id: email, email: email, nom: nom, actif: actif);

void main() {
  group('Le compte de connexion se lit dans auth.users', () {
    test('⚠️ il vient de la RPC, pas de la colonne de contact', () {
      // `auth.users` n'est pas exposée par PostgREST : sans la RPC, l'écran
      // n'a AUCUN moyen de connaître l'identifiant. C'est ce qui l'avait fait
      // retomber sur la colonne de contact.
      final src = _lire(_provider);
      expect(src.contains("rpc('get_platform_admins')"), isTrue);
      expect(src.contains("m['role'] != 'admin_groupe'"), isTrue,
          reason: 'Les super_admin reviennent dans la carte : ils n’ont pas '
              'de groupe, ils n’ont rien à y faire.');
    });

    test('un seul appel pour tout le parc', () {
      // Une requête par ligne tiendrait à sept groupes et pas à mille.
      final src = _lire(_provider);
      expect("rpc(".allMatches(src).length, 1);
    });

    test('les comptes actifs passent devant', () {
      // C'est l'adresse qui FONCTIONNE qu'on lit au téléphone.
      final m = {
        'g1': [_compte('z@x.cg', actif: false), _compte('a@x.cg')],
      };
      for (final l in m.values) {
        l.sort((a, b) {
          if (a.actif != b.actif) return a.actif ? -1 : 1;
          return a.email.compareTo(b.email);
        });
      }
      expect(compteDeConnexion(m, 'g1'), 'a@x.cg');
    });

    test('un groupe sans compte connu ne fabrique pas d’adresse', () {
      // Mieux vaut retomber sur le contact ÉTIQUETÉ que d'inventer.
      expect(compteDeConnexion(const {}, 'g1'), isNull);
      expect(compteDeConnexion(const {'g1': <CompteAdmin>[]}, 'g1'), isNull);
    });
  });

  group('Les deux écrans montrent l’identifiant, pas le contact', () {
    test('la page Abonnements', () {
      final src = _lire(_abonnements);
      expect(src.contains('compteDeConnexion(m, s.id)'), isTrue,
          reason: 'La ligne réaffiche l’e-mail de contact là où on lit un '
              'identifiant.');
      expect(src.contains("'E-mail de contact'"), isTrue,
          reason: 'Le contact a repris le libellé « E-mail admin » : le '
              'malentendu revient par l’étiquette.');
      expect(src.contains("'Compte de connexion'"), isTrue);
    });

    test('la page Groupes scolaires', () {
      final src = _lire(_groupes);
      expect(src.contains('compteDeConnexion(m, g.id)'), isTrue);
      expect(src.contains("'E-mail de contact'"), isTrue);
      expect(src.contains("_DetailRow(Icons.email_outlined, 'Email',"), isFalse,
          reason: 'Le libellé « Email » est revenu sur le contact : c’est '
              'exactement ce qui se lisait comme un identifiant.');
    });

    test('⚠️ un compte désactivé le dit', () {
      // Lire une adresse qui ne peut plus ouvrir de session, sans le savoir,
      // relance le même quiproquo un cran plus loin.
      for (final f in [_abonnements, _groupes]) {
        expect(_lire(f).contains("(désactivé)"), isTrue,
            reason: '$f ne signale plus un compte désactivé.');
      }
    });
  });
}
