import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA PHOTO D'UN AGENT SE DEMANDE — ELLE NE S'ÉCRIT PAS.
//
//  ── CE QUE CE TEST GARDE, ET POURQUOI IL EST INDISPENSABLE ─────────────────
//  `profiles_update` n'autorise que super_admin, admin_groupe du groupe, ou
//  l'agent lui-même. Un DIRECTEUR qui corrige la fiche d'un autre agent n'entre
//  dans aucune des trois. Écrire `profiles.avatar_url` par PowerSync
//  reviendrait donc en `42501` — code que le connecteur tient pour FATAL — et
//  ferait abandonner la transaction entière : les notes et les paiements
//  saisis dans la même fenêtre partiraient avec.
//
//  La migration 0113 ouvre la seule porte qui ne relâche aucun droit : l'école
//  dépose une DEMANDE dans `staff_photo_requests`, le serveur l'applique par
//  trigger avec l'autorité exacte de `corriger_fiche_agent`.
//
//  Trois choses peuvent défaire cela d'une ligne, et aucune ne lèverait
//  d'erreur à la compilation :
//   1. réécrire `profiles` directement « puisque c'est plus simple » ;
//   2. repasser la photo à la RPC — elle accepte encore les paramètres — et
//      l'appliquer deux fois, avec deux traces d'audit pour un seul geste ;
//   3. oublier que l'écran doit lire la DEMANDE tant qu'elle n'est pas
//      appliquée, ce qui ferait voir à l'agent l'ancienne photo.
// ════════════════════════════════════════════════════════════════════════════

const _kService = 'lib/features/staff/services/agent_photo_service.dart';
const _kProvider = 'lib/features/staff/providers/staff_photo_provider.dart';
const _kFiche = 'lib/features/staff/screens/agent_fiche_dialog.dart';
const _kRpc = 'lib/features/staff/providers/agent_creation_provider.dart';
const _kAvatar = 'lib/features/communication/widgets/user_avatar.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync();
}

List<File> _dartsSous(String chemin) => Directory(chemin)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  group('L\'école dépose une demande, elle n\'écrit pas la fiche', () {
    test('rien n\'écrit `profiles.avatar_url` en local', () {
      // La forme fautive : un UPDATE local sur `profiles` touchant l'avatar.
      // Il serait refusé par la RLS à la remontée, et emporterait le lot.
      final fautes = <String>[];
      for (final f in _dartsSous('lib')) {
        final src = f.readAsStringSync();
        if (RegExp(r'UPDATE\s+profiles\b[\s\S]{0,400}?avatar_url')
            .hasMatch(src)) {
          fautes.add(f.path);
        }
      }
      expect(fautes, isEmpty,
          reason: 'Écrire `profiles.avatar_url` par PowerSync revient en 42501, '
              'code fatal : la transaction ENTIÈRE est abandonnée. Passer par '
              '`deposerDemandePhotoAgent`.\n\n${fautes.join('\n')}');
    });

    test('la préparation met les octets en file, sans réseau', () {
      final src = _lire(_kService);
      expect(src.contains('queueAvatarUpload('), isTrue);
      expect(src.contains('uploadBinary('), isFalse,
          reason: 'Un envoi direct rendrait le geste impossible hors ligne.');
    });

    test('la fiche dépose la demande et NE repasse PAS la photo à la RPC', () {
      final fiche = _lire(_kFiche);
      expect(fiche.contains('deposerDemandePhotoAgent('), isTrue);

      final rpc = _lire(_kRpc);
      // La RPC accepte encore ces paramètres côté serveur ; l'application ne
      // doit plus les envoyer, sinon la photo s'applique deux fois.
      expect(rpc.contains("'p_avatar_url'"), isFalse,
          reason: 'La photo a UNE seule porte : la demande. La repasser ici '
              'l\'appliquerait deux fois et inscrirait deux corrections au '
              'journal d\'audit pour un seul geste.');
      expect(rpc.contains("'p_effacer_photo'"), isFalse);
    });
  });

  group('Ce que l\'écran doit lire tant que rien n\'est appliqué', () {
    test('une demande appliquée ne fait plus foi', () {
      // `profiles.avatar_url` porte alors la vérité. Garder la demande
      // afficherait indéfiniment une photo « en attente » déjà arrivée.
      final src = _lire(_kProvider);
      expect(src.contains('applied_at IS NULL'), isTrue,
          reason: 'Seules les demandes NON abouties doivent être retenues.');
    });

    test('la file se lit en UNE requête, pas une par pastille', () {
      // Deux cents pastilles sur une liste de personnel, et autant à chaque
      // reconstruction : la version par-pastille ne tient pas à l'échelle.
      final src = _lire(_kProvider);
      expect(src.contains('Map<String, DemandePhotoAgent>'), isTrue);
      final famille = RegExp(r'StreamProvider\.autoDispose\s*\n?\s*\.family')
          .hasMatch(src);
      expect(famille, isFalse,
          reason: 'La demande d\'UN agent se dérive de la carte, sans requête.');
    });

    test('la pastille sait résoudre une demande en attente', () {
      final src = _lire(_kAvatar);
      expect(src.contains('photoAffichee('), isTrue,
          reason: 'Sans cela la pastille montrerait l\'ANCIENNE photo, et le '
              'chef qui vient d\'en choisir une autre recommencerait.');
      expect(src.contains('fichierLocalEnAttente('), isTrue,
          reason: 'Et sans cela, elle montrerait un rond cassé : le fichier '
              'est encore sur le poste.');
    });

    test('le refus du serveur remonte à l\'écran', () {
      // Le trigger ne lève jamais — une exception ferait abandonner le lot.
      // Le motif redescend dans la demande, et la fiche est le seul endroit
      // où l'agent peut l'apprendre.
      final src = _lire(_kFiche);
      expect(src.contains('demandePhotoAgentProvider('), isTrue);
      expect(src.contains('Photo refusée'), isTrue,
          reason: 'Sans affichage, la photo ne changerait jamais, sans un mot.');
    });
  });
}
