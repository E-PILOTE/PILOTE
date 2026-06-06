extension StringExtensions on String {
  /// Capitalise la première lettre
  String get capitalize =>
      isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';

  /// Capitalise chaque mot
  String get titleCase => split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// Troncature avec ellipsis
  String truncate(int maxLength) =>
      length > maxLength ? '${substring(0, maxLength)}…' : this;

  /// Vérification e-mail basique
  bool get isValidEmail => contains('@') && contains('.');

  /// Vérification téléphone Congo (format: 0X XX XX XX ou +242 XX XXX XXXX)
  bool get isValidCongolesPhone {
    final phone = replaceAll(RegExp(r'[\s\-\+]'), '');
    return RegExp(r'^(242)?\d{9}$').hasMatch(phone);
  }
}

extension NullableStringExtensions on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  String get orEmpty => this ?? '';
}
