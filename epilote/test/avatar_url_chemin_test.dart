import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/services/powersync/avatar_upload.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RETROUVER LE CHEMIN D'UNE PHOTO À PARTIR DE SON URL.
//
//  ── CE QUE CE TEST GARDE ───────────────────────────────────────────────────
//  Depuis que la photo se prend hors ligne, deux choses la désignent : la
//  COLONNE porte une URL publique (`students.photo_url`), la FILE D'ENVOI
//  indexe par CHEMIN Storage. Rien ne relie les deux qu'un découpage de chaîne.
//
//  S'il se trompe d'un caractère, la recherche dans la file ne rend rien — et
//  c'est un échec MUET : aucune erreur, aucune trace, simplement une photo qui
//  reste cassée sur le poste de l'agent qui vient de la prendre. C'est-à-dire
//  exactement le défaut qu'on voulait corriger, revenu par la petite porte.
//
//  D'où une fonction pure, isolée du disque et de la base : du texte vers du
//  texte, et des cas qui se relisent.
// ════════════════════════════════════════════════════════════════════════════

const _base = 'https://wqpdamlnrwgozfvzjjpo.supabase.co'
    '/storage/v1/object/public';

void main() {
  group('Une URL publique rend son chemin', () {
    test('le cas normal — bucket avatars, dossier students', () {
      expect(
        storagePathFromPublicUrl('$_base/avatars/students/abc_1f2e3d4c.jpg'),
        'students/abc_1f2e3d4c.jpg',
      );
    });

    test('le bucket est retiré, le reste du chemin est intact', () {
      // Un chemin peut compter plusieurs segments : ne couper QUE le premier.
      expect(
        storagePathFromPublicUrl('$_base/avatars/staff/ecole-1/agent_99.png'),
        'staff/ecole-1/agent_99.png',
      );
    });

    test('les paramètres de transformation sont écartés', () {
      // `getPublicUrl` sait suffixer une requête (redimensionnement) ; la file,
      // elle, a stocké le chemin nu.
      expect(
        storagePathFromPublicUrl('$_base/avatars/students/a.jpg?width=64'),
        'students/a.jpg',
      );
      expect(
        storagePathFromPublicUrl('$_base/avatars/students/a.jpg#apercu'),
        'students/a.jpg',
      );
    });

    test('l\'aller-retour tient sur le chemin que la file a stocké', () {
      // Le vrai contrat : ce que `queueAvatarUpload` met en file doit être ce
      // que cette fonction retrouve. On rejoue la composition.
      const chemin = 'students/e7b1c0d2-4a5f_9c8b7a6d.jpg';
      final url = '$_base/avatars/$chemin';
      expect(storagePathFromPublicUrl(url), chemin);
    });
  });

  group('Ce qui n\'est pas une URL publique ne rend rien', () {
    test('nulle ou vide', () {
      expect(storagePathFromPublicUrl(null), isNull);
      expect(storagePathFromPublicUrl(''), isNull);
    });

    test('une URL signée n\'est PAS une URL publique', () {
      // Les pièces du dossier vivent dans un bucket privé : leur URL passe par
      // `/object/sign/`. Les confondre ferait chercher dans la file un chemin
      // qui n'y est pas — sans conséquence, mais autant le dire.
      expect(
        storagePathFromPublicUrl(
            'https://x.supabase.co/storage/v1/object/sign/docs/a.pdf?token=z'),
        isNull,
      );
    });

    test('une URL quelconque', () {
      expect(storagePathFromPublicUrl('https://example.org/photo.jpg'), isNull);
    });

    test('un bucket sans chemin', () {
      expect(storagePathFromPublicUrl('$_base/avatars/'), isNull);
      expect(storagePathFromPublicUrl('$_base/avatars'), isNull);
    });
  });
}
