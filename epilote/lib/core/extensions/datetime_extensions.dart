import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  /// Format court : 25/05/2026
  String get toDateFr => DateFormat('dd/MM/yyyy').format(this);

  /// Format long : Lundi 25 mai 2026
  String get toLongDateFr =>
      DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(this);

  /// Format avec heure : 25/05/2026 à 14:30
  String get toDateTimeFr =>
      DateFormat("dd/MM/yyyy 'à' HH:mm", 'fr_FR').format(this);

  /// Format mois/année : Mai 2026
  String get toMonthYearFr =>
      DateFormat('MMMM yyyy', 'fr_FR').format(this);

  /// Début d'année scolaire (Sep) → on est en quelle année scolaire ?
  /// Ex: 25/11/2025 → "2025-2026", 20/06/2026 → "2025-2026"
  String get toAcademicYear {
    final sep = month >= 9;
    final start = sep ? year : year - 1;
    return '$start-${start + 1}';
  }

  /// Temps relatif en français
  String get timeAgoFr {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} jour(s)';
    return toDateFr;
  }
}

extension NullableDateTimeExtensions on DateTime? {
  String get toDateFrOrEmpty => this?.toDateFr ?? '—';
}
