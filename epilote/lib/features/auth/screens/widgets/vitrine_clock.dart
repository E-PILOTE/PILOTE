import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';

/// Point d'injection d'horloge pour les tests de rendu (goldens déterministes) :
/// la vitrine affiche l'heure ET la date courantes, ce qui rendait ses captures
/// non reproductibles (elles cassaient chaque jour). Un test fixe cet instant ;
/// en production, `null` → heure réelle qui défile.
@visibleForTesting
DateTime Function()? debugVitrineClock;

/// Horloge vivante de la vitrine (sobre, pas « borne géante »). Se met à jour
/// chaque seconde ; date en français en dessous.
class VitrineClock extends StatefulWidget {
  const VitrineClock({super.key});

  @override
  State<VitrineClock> createState() => _VitrineClockState();
}

class _VitrineClockState extends State<VitrineClock> {
  Timer? _timer;
  late DateTime _now = (debugVitrineClock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    // Horloge figée (test) → pas de timer : le rendu reste stable.
    if (debugVitrineClock != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const _days = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
  ];
  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
    'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];

  String get _time =>
      '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
  String get _date =>
      '${_days[_now.weekday - 1]} ${_now.day} ${_months[_now.month - 1]} ${_now.year}';

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(_time,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  height: 1)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded,
                  size: 12, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 5),
              Text('$_date · poste sécurisé',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12)),
            ],
          ),
        ],
      );
}
