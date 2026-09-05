import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/active_agent_provider.dart';
import 'nav_repli_prefs.dart';

/// État d'expansion de la sidebar (réservé : la largeur réelle est gérée
/// localement par l'AppShell pour permettre le drag-resize).
final sidebarExpandedProvider = StateProvider<bool>((_) => true);


/// Titres des sections de nav repliées (accordéon de la sidebar).
///
/// ⚠️ PERSISTÉ, ET PAR AGENT. C'était un `StateProvider` en mémoire : replier
/// FINANCE tenait jusqu'à la fermeture de l'application, puis tout se
/// rouvrait. Un réglage qu'il faut refaire à chaque lancement n'est pas un
/// réglage — on cesse de s'en servir. La clé suit l'agent au clavier, pas
/// l'appareil : sur un poste partagé, le repli de l'un n'est pas celui de
/// l'autre (voir `nav_repli_prefs.dart`).
///
/// Défaut = ensemble vide → tout est déplié. La section de la page courante
/// est forcée dépliée à l'affichage : on ne cache jamais où l'on se trouve.
class SectionsRepliees extends Notifier<Set<String>> {
  var _touche = false;
  var _vivant = true;

  @override
  Set<String> build() {
    // Comme `ThemeIdNotifier` : une valeur synchrone d'abord (tout déplié),
    // la préférence remonte du disque ensuite. Changer d'agent ré-interroge.
    final agentId = _agent(surveiller: true);
    _touche = false;
    _vivant = true;
    ref.onDispose(() => _vivant = false);
    _charger(agentId);
    return const <String>{};
  }

  /// Qui est au clavier — sans jamais pouvoir empêcher la barre de se rendre.
  ///
  /// ⚠️ LE `try` N'EST PAS DE LA PRUDENCE DÉCORATIVE. `activeAgentIdProvider`
  /// remonte jusqu'à `supabaseClientProvider`, qui lève tant que Supabase
  /// n'est pas initialisé — c'est le cas des tests qui rendent la barre seule
  /// (`sidebar_hardlock_test.dart` est tombé exactement là), et de tout
  /// démarrage où l'écran s'affiche avant l'initialisation. Une PRÉFÉRENCE
  /// D'AFFICHAGE ne doit pas pouvoir casser la navigation : sans agent
  /// connu, on rend simplement la barre entièrement dépliée.
  String? _agent({bool surveiller = false}) {
    try {
      return surveiller
          ? ref.watch(activeAgentIdProvider)
          : ref.read(activeAgentIdProvider);
    } catch (_) {
      return null;
    }
  }

  Future<void> _charger(String? agentId) async {
    final memorise = await loadSectionsRepliees(agentId);
    // Un clic pendant la lecture disque gagne : il est plus récent que ce que
    // le disque raconte, et l'écraser annulerait le geste sous les doigts.
    if (!_vivant || _touche) return;
    state = memorise;
  }

  /// Replie ou déplie [titre], et l'enregistre pour l'agent au clavier.
  Future<void> basculer(String titre) async {
    _touche = true;
    final suivant = {...state};
    suivant.contains(titre) ? suivant.remove(titre) : suivant.add(titre);
    state = suivant;
    // Sans agent identifiable, `saveSectionsRepliees` n'écrit rien : le repli
    // vaut pour la session, il ne se colle pas au mauvais agent.
    await saveSectionsRepliees(_agent(), suivant);
  }
}

final collapsedNavSectionsProvider =
    NotifierProvider<SectionsRepliees, Set<String>>(SectionsRepliees.new);

// ─── Visionneuse confinée au contenu ────────────────────────────────────────
// Une visionneuse (image / PDF) rendue dans la zone de contenu plutôt que via le
// Navigator racine occupe uniquement cette zone → la sidebar reste visible ET
// cliquable.
final contentOverlayProvider = StateProvider<Widget?>((_) => null);

/// Affiche [builder] par-dessus le contenu (sidebar préservée). [close] est
/// passé au builder pour refermer. Lisible depuis n'importe quel BuildContext.
void showContentOverlay(
  BuildContext context,
  Widget Function(VoidCallback close) builder,
) {
  final container = ProviderScope.containerOf(context, listen: false);
  void close() {
    if (container.read(contentOverlayProvider) != null) {
      container.read(contentOverlayProvider.notifier).state = null;
    }
  }

  container.read(contentOverlayProvider.notifier).state = builder(close);
}

void closeContentOverlay(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(contentOverlayProvider.notifier).state = null;
}
