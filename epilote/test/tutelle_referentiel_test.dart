import 'dart:io';

import 'package:epilote/core/constants/tutelle.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE MINISTÈRE DE TUTELLE N'EXISTE QU'À UN SEUL ENDROIT
//
//  ── CE QUI A MOTIVÉ CE GARDE ──────────────────────────────────────────────
//  Le libellé et la couleur de la tutelle étaient écrits TROIS fois :
//    • `_libelleTutelle` dans le PDF de l'état de rentrée,
//    • `tutColor` dans le tableau de bord d'examens de l'admin_groupe,
//    • `tutColor` dans celui du super_admin.
//  Et les deux `tutColor` avaient DÉJÀ divergé — 0xFF7C3AED d'un côté,
//  0xFF8B5CF6 de l'autre. Deux violets pour un seul ministère, sur deux écrans
//  qui se lisent l'un après l'autre.
//
//  C'est exactement l'histoire du barème des mentions : quatre exemplaires,
//  dont un donnait « Passable » pour 8/20. Un référentiel dupliqué ne reste
//  pas identique ; il attend juste qu'on regarde ailleurs.
//
//  ── CE QUE CE GARDE TIENT ─────────────────────────────────────────────────
//  1. Les valeurs connues sont EXACTEMENT celles de l'enum `tutelle_enum`.
//  2. Une tutelle inconnue ne devient JAMAIS « MEPSA » par défaut.
//  3. Aucun fichier de `lib/` ne réécrit un aiguillage `'mepsa'` / `'metp'`
//     hors du référentiel.
// ════════════════════════════════════════════════════════════════════════════

/// L'enum `tutelle_enum`, relevé en base le 2026-08-30. Écrit À LA MAIN :
/// si quelqu'un ajoute une valeur à `kTutelles` sans toucher l'enum, la
/// confrontation doit échouer — sinon le garde suivrait l'erreur.
const _kEnumServeur = {'mepsa', 'metp'};

void main() {
  test('les tutelles connues sont exactement celles de l\'enum serveur', () {
    expect(kTutelles.toSet(), _kEnumServeur);
    // Ordre stable : c'est celui dans lequel le formulaire les présente.
    expect(kTutelles, ['mepsa', 'metp']);
  });

  test('chaque tutelle a un sigle, un nom et un domaine', () {
    for (final t in kTutelles) {
      expect(sigleTutelle(t), isNotNull, reason: 'sigle manquant pour $t');
      expect(nomTutelle(t), isNotNull, reason: 'nom manquant pour $t');
      expect(domaineTutelle(t), isNotNull, reason: 'domaine manquant pour $t');
      expect(tutelleConnue(t), isTrue);
    }
  });

  // ⚠️ LE TEST QUI COMPTE. Retomber sur « MEPSA » quand la tutelle est absente
  // rangerait un lycée technique sous le ministère de l'enseignement général —
  // silencieusement, et jusqu'à l'inscription aux examens d'État.
  test('une tutelle absente ou inconnue ne devient pas MEPSA', () {
    for (final inconnue in [null, '', 'MEPSA', 'mesrs', 'metp ', 'inconnu']) {
      expect(sigleTutelle(inconnue), isNull,
          reason: '« $inconnue » ne doit pas produire de sigle');
      expect(tutelleConnue(inconnue), isFalse);
    }
    // Là où le vide n'est pas affichable, il est DIT, pas masqué.
    expect(sigleTutelleOuTiret(null), '—');
    expect(sigleTutelleOuTiret('metp'), 'METP');
  });

  test('aucun fichier de lib/ ne réécrit l\'aiguillage de tutelle', () {
    final coupables = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final chemin = f.path.replaceAll('\\', '/');
      // Le référentiel lui-même, évidemment.
      if (chemin.endsWith('core/constants/tutelle.dart')) continue;
      final src = f.readAsStringSync().replaceAll('\r\n', '\n');
      // Un `switch` ou un `?:` qui traduit 'mepsa' en quelque chose. On ne
      // traque PAS toute mention de 'mepsa' (une clause SQL, un filtre ou une
      // valeur par défaut sont légitimes) — seulement la RÉÉCRITURE du
      // libellé, reconnaissable à sa flèche de switch.
      if (RegExp(r"'mepsa'\s*=>").hasMatch(src)) coupables.add(chemin);
    }
    expect(coupables, isEmpty,
        reason: 'Ces fichiers refont le référentiel de tutelle au lieu '
            'd\'utiliser core/constants/tutelle.dart : $coupables');
  });
}
