part of '../administrators_screen.dart';

// Formats de date partagés par les vues et la fiche.

const _moisFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year}';
}

String _fmtDateTime(DateTime? d) {
  if (d == null) return 'Jamais connecté';
  final l = d.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year} à ${hh}h$mm';
}
