import 'package:flutter/material.dart';

/// Point d'injection d'horloge pour les tests de rendu (goldens déterministes) :
/// la vitrine affiche l'heure ET la date courantes, ce qui rendait ses captures
/// non reproductibles (elles cassaient chaque jour). Un test fixe cet instant ;
/// en production, `null` → heure réelle qui défile.
@visibleForTesting
DateTime Function()? debugVitrineClock;

/// Instant courant de la vitrine : heure réelle en production, ou l'horloge de
/// test injectée. Accesseur PUBLIC (les composants de la vitrine passent par ici
/// plutôt que de toucher directement le hook `@visibleForTesting`).
DateTime vitrineNow() => (debugVitrineClock ?? DateTime.now)();

/// Vrai quand une horloge de test est injectée : l'appelant fige alors ses
/// timers et animations pour des captures stables.
bool get vitrineClockFrozen => debugVitrineClock != null;
