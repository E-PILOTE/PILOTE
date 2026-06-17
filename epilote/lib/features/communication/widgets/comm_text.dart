import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Texte & identité — dates françaises, couleurs/labels de rôle, hashtags.
// Ré-exporté par staff_feed_ui.dart (imports existants inchangés).
// ═════════════════════════════════════════════════════════════════════════════

// ─── Dates françaises (sans dépendance locale intl) ─────────────────────────
const kMoisCourtFr = [
  'jan', 'fév', 'mars', 'avr', 'mai', 'juin',
  'juil', 'août', 'sep', 'oct', 'nov', 'déc'
];
const kMoisLongFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];
const kJoursFr = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
];

/// 12 juin 2026
String fmtDateFr(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${kMoisCourtFr[l.month - 1]} ${l.year}';
}

/// Vendredi 12 juin 2026
String fmtDateFullFr(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  final jour = kJoursFr[l.weekday - 1];
  return '${jour[0].toUpperCase()}${jour.substring(1)} '
      '${l.day} ${kMoisLongFr[l.month - 1]} ${l.year}';
}

/// Temps relatif court (« à l'instant », « il y a 3 h », « hier », « il y a 4 j »)
/// puis bascule sur la date absolue au-delà d'une semaine. Style fil social.
String fmtRelativeFr(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inSeconds < 60) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  return fmtDateFr(d);
}

// ─── Identité visuelle des rôles (partagée annonces / messagerie / commentaires)
Color roleColor(String? role) => switch (role) {
      'directeur' || 'proviseur'      => const Color(0xFF0D47A1),
      'censeur'                       => const Color(0xFF2E7D32),
      'enseignant'                    => const Color(0xFF6A1B9A),
      'secretaire'                    => const Color(0xFF00695C),
      'comptable'                     => const Color(0xFF004D40),
      'cpe'                           => const Color(0xFFE65100),
      'surveillant'                   => const Color(0xFF37474F),
      'infirmier'                     => const Color(0xFFC62828),
      'responsable_cantine'           => const Color(0xFF558B2F),
      'super_admin' || 'admin_groupe' => kNavy,
      _                               => const Color(0xFF455A64),
    };

String roleLabelFr(String? role) => switch (role) {
      'directeur'           => 'Directeur',
      'proviseur'           => 'Proviseur',
      'censeur'             => 'Censeur',
      'enseignant'          => 'Enseignant',
      'secretaire'          => 'Secrétaire',
      'comptable'           => 'Comptable',
      'surveillant'         => 'Surveillant',
      'cpe'                 => 'CPE',
      'infirmier'           => 'Infirmier',
      'responsable_cantine' => 'Resp. Cantine',
      'parent'              => 'Parent',
      'eleve'               => 'Élève',
      'super_admin'         => 'Plateforme',
      'admin_groupe'        => 'Admin Groupe',
      _                     => 'Personnel',
    };

// ─── Texte enrichi : #hashtags surlignés et cliquables ───────────────────────
final _hashtagRe = RegExp(r'#[\p{L}0-9_]+', unicode: true);

/// Contenu de publication avec hashtags mis en valeur (navy, gras) et
/// cliquables — `onHashtag` reçoit le tag SANS le « # » (filtre du fil).
class HashtagText extends StatelessWidget {
  const HashtagText(
    this.text, {
    super.key,
    required this.style,
    this.onHashtag,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final String text;
  final TextStyle style;
  final ValueChanged<String>? onHashtag;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _hashtagRe.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final tag = m.group(0)!;
      spans.add(TextSpan(
        text: tag,
        style: style.copyWith(color: kNavy, fontWeight: FontWeight.w800),
        recognizer: onHashtag == null
            ? null
            : (TapGestureRecognizer()
              ..onTap = () => onHashtag!(tag.substring(1))),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

