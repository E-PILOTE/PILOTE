// ════════════════════════════════════════════════════════════════════════════
//  Nom de fichier sûr sur la plateforme de DÉPLOIEMENT — Windows.
//
//  Le développement se fait sous Linux, qui n'interdit que deux caractères dans
//  un nom de fichier : « / » et l'octet nul. Windows en interdit neuf, refuse
//  les points et espaces finaux, et réserve une poignée de noms hérités du DOS.
//  Un export dont le nom vient d'une donnée saisie — nom d'élève, libellé de
//  classe, intitulé de filière — passe donc sans bruit ici et échoue là-bas.
//
//  On ASSAINIT plutôt que de rejeter : l'agent qui exporte veut son fichier, pas
//  un message d'erreur sur un caractère qu'il n'a pas choisi.
// ════════════════════════════════════════════════════════════════════════════

/// Caractères interdits par Windows dans un nom de fichier, plus les caractères
/// de contrôle (0x00-0x1F) que l'API Win32 refuse également.
final RegExp _forbidden = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

/// Noms réservés du DOS, toujours refusés par Windows — avec ou sans extension.
/// `CON.pdf` est aussi invalide que `CON`.
const Set<String> _reserved = {
  'CON', 'PRN', 'AUX', 'NUL',
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};

/// Longueur maximale retenue pour la partie « nom ». Le plafond dur de Windows
/// porte sur le CHEMIN complet (260 caractères par défaut) ; comme le dossier
/// est choisi par l'agent et nous est inconnu, on se réserve une marge large.
const int _maxLength = 120;

/// Rend [raw] utilisable comme nom de fichier sur Windows comme sur POSIX.
///
/// [fallback] sert lorsqu'il ne reste rien d'exploitable — un libellé composé
/// uniquement de caractères interdits, par exemple.
///
/// L'extension éventuelle est préservée : `safeFileName('6ème A/B.pdf')` rend
/// `6ème A-B.pdf`, et non un nom tronqué qui perdrait le type du fichier.
String safeFileName(String raw, {String fallback = 'export'}) {
  var name = raw.trim();

  // Isoler l'extension AVANT tout traitement : la troncature de longueur doit
  // manger le nom, jamais le « .pdf » qui dit à Windows quoi ouvrir.
  //
  // On exige des caractères alphanumériques APRÈS le point : sans cela, un nom
  // se terminant par « ... » voyait son dernier point pris pour une extension,
  // qui échappait ensuite au nettoyage des points finaux et revenait se coller
  // au résultat. Cinq caractères au plus — au-delà, « Rapport.2026.annuel »
  // n'est pas un fichier « .annuel », c'est un nom qui contient des points.
  var ext = '';
  final m = RegExp(r'\.[A-Za-z0-9]{1,5}$').firstMatch(name);
  if (m != null && m.start > 0) {
    ext = name.substring(m.start);
    name = name.substring(0, m.start);
  }

  // Le tiret plutôt que le souligné : il se lit comme une séparation, là où
  // « _ » se confond avec les jointures déjà présentes dans nos gabarits
  // (`Candidats_BAC_2025-2026`).
  name = name.replaceAll(_forbidden, '-');

  // Espaces et tirets multiples compactés — le remplacement en produit.
  name = name.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'-{2,}'), '-');

  // Windows retire silencieusement les points et espaces finaux, ce qui peut
  // faire diverger le nom demandé de celui écrit. On tranche nous-mêmes.
  name = name.replaceAll(RegExp(r'^[.\s-]+|[.\s-]+$'), '');

  if (name.length > _maxLength) {
    name = name.substring(0, _maxLength).trimRight();
  }

  if (name.isEmpty) name = fallback;
  if (_reserved.contains(name.toUpperCase())) name = '$name-fichier';

  return '$name$ext';
}
