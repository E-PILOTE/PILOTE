import 'package:flutter/material.dart';

import '../../../core/widgets/app_shell.dart';
import '../widgets/merit_passage_view.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MEILLEURS ÉLÈVES — écran du ministère (admin_groupe, online).
//
//  ── POURQUOI LES EXAMENS D'ÉTAT NE SONT PAS CLASSÉS ICI ─────────────────────
//  Un classement suppose un ORDRE. Or la DEC ne renvoie pas de notes : elle
//  publie des LISTES D'ADMIS. « Admis / ajourné » est binaire — on ne classe
//  pas soixante admis entre eux, et rien n'autorise à le faire.
//
//  Le partage des rôles est le même dans les deux sens :
//   • la plateforme TRANSMET à la DEC la liste des candidats ;
//   • la DEC PROCLAME les admis, que les établissements enregistrent.
//  À aucun moment la plateforme ne calcule un résultat d'examen.
//
//  Un onglet « Examens d'État » a existé ici. Il classait sur
//  `exam_candidates.average` — une colonne facultative, que la DEC n'alimente
//  pas et qu'une école ne saisit que si elle dispose d'un relevé. À l'échelle
//  du réseau, elle est vide : le classement aurait été vide en séance, ou pire,
//  rempli par les seules écoles ayant saisi quelque chose. Il a été retiré.
//
//  Ce que le ministère peut légitimement lire des examens — taux de réussite,
//  admis, transmission des dossiers, par filière et par département — vit sur
//  « Examens nationaux », qui ne demande que l'admission. Pas de doublon ici.
//
//  Reste donc une seule base, et elle est propre : les CLASSES DE PASSAGE
//  (6e, 5e, 4e, 2nde, 1ère, CP→CM1), dont le passage au niveau supérieur se
//  décide sur le travail de l'année. Là, la plateforme détient les notes et
//  calcule les moyennes — par trimestre.
// ════════════════════════════════════════════════════════════════════════════
class AdminMeritScreen extends StatelessWidget {
  const AdminMeritScreen({super.key});

  @override
  Widget build(BuildContext context) => const AppShell(
        title: 'Meilleurs élèves du réseau',
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: MeritPassageView(),
        ),
      );
}
