import '../domain/ports.dart';

/// [Clock] réel. `wallNow` = horloge murale (falsifiable, peut reculer sur
/// pile CMOS morte) ; `sessionElapsed` = durée monotone depuis l'instanciation
/// (non falsifiable en cours de session). La combinaison des deux, avec le
/// repère haute-eau persisté, donne le « meilleur temps connu » côté service.
class MonotonicClock implements Clock {
  MonotonicClock() : _watch = Stopwatch()..start();
  final Stopwatch _watch;

  @override
  DateTime wallNow() => DateTime.now().toUtc();

  @override
  Duration sessionElapsed() => _watch.elapsed;
}
