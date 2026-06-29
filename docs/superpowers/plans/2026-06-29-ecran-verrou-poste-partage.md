# Écran-verrou « poste partagé » — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer la bascule d'agent in-shell par un écran-verrou plein écran, style login, imposé au lancement et sur demande, offline-safe, qui supprime le trou d'attribution au démarrage.

**Architecture:** Un provider pur (`needsAgentUnlockProvider`) décide du verrouillage. Un overlay (`AgentLockGate`) câblé dans `MaterialApp.builder` peint `AgentLockScreen` par-dessus tout quand c'est verrouillé. La session Supabase de l'appareil n'est jamais touchée ; seul le PIN local (existant) déverrouille l'agent.

**Tech Stack:** Flutter, Riverpod (StateProvider/Provider/StreamProvider), PowerSync (offline `db.watch`), flutter_svg, `crypto`+`shared_preferences` (PIN, existant).

## Global Constraints

- Fichiers Dart **≤ 500 lignes**, découpe par responsabilité (alerte 400).
- `flutter analyze` doit rester à **0 issue**.
- Architecture non négociable : personnel scolaire = **offline PowerSync `db.watch`** uniquement, jamais `supabase.from()`. (Ici on ne lit que des providers existants déjà conformes.)
- `super_admin` / `admin_groupe` **intouchés** (jamais de verrou).
- `.withValues(alpha:)` (pas `withOpacity`). Lints projet stricts.
- Binaire : `/home/melack/flutter/bin/flutter`, commandes depuis `epilote/`.
- Réutiliser sans dupliquer : `selectedAgentIdProvider`, `switchableAgentsProvider`, `agentPinServiceProvider`, `AgentOption`, `currentSchoolProvider`, `auth_colors.dart`, `AnimatedTricolorLine`.

---

### Task 1: Décision de verrouillage (logique pure + provider)

**Files:**
- Modify: `epilote/lib/features/auth/providers/active_agent_provider.dart` (ajout en fin de fichier)
- Test: `epilote/test/agent_lock_test.dart`

**Interfaces:**
- Produces:
  - `bool agentLockApplies(String? role)` — vrai si le rôle relève d'un agent de poste partagé (≠ super_admin/admin_groupe/parent/eleve, non vide).
  - `bool computeNeedsAgentUnlock({required String? deviceRole, required bool hasAgents, required String? selectedAgentId})` — décision pure.
  - `final needsAgentUnlockProvider = Provider<bool>` — câble les providers existants à `computeNeedsAgentUnlock`.
- Consumes (existant) : `authNotifierProvider`, `switchableAgentsProvider`, `selectedAgentIdProvider`, `AppConstants`.

- [ ] **Step 1: Write the failing test**

Créer `epilote/test/agent_lock_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';

void main() {
  group('agentLockApplies', () {
    test('staff scolaire → vrai', () {
      expect(agentLockApplies('enseignant'), isTrue);
      expect(agentLockApplies('secretaire'), isTrue);
      expect(agentLockApplies('directeur'), isTrue);
      expect(agentLockApplies('comptable'), isTrue);
    });
    test('super_admin / admin_groupe / parent / eleve → faux', () {
      expect(agentLockApplies('super_admin'), isFalse);
      expect(agentLockApplies('admin_groupe'), isFalse);
      expect(agentLockApplies('parent'), isFalse);
      expect(agentLockApplies('eleve'), isFalse);
    });
    test('null / vide → faux', () {
      expect(agentLockApplies(null), isFalse);
      expect(agentLockApplies(''), isFalse);
    });
  });

  group('computeNeedsAgentUnlock', () {
    test('staff, agents dispo, aucun agent choisi → verrou', () {
      expect(
        computeNeedsAgentUnlock(
            deviceRole: 'enseignant', hasAgents: true, selectedAgentId: null),
        isTrue,
      );
    });
    test('agent déjà choisi → pas de verrou', () {
      expect(
        computeNeedsAgentUnlock(
            deviceRole: 'enseignant', hasAgents: true, selectedAgentId: 'a1'),
        isFalse,
      );
    });
    test('aucun agent synchronisé → pas de verrou (anti-blocage)', () {
      expect(
        computeNeedsAgentUnlock(
            deviceRole: 'enseignant', hasAgents: false, selectedAgentId: null),
        isFalse,
      );
    });
    test('super_admin → jamais de verrou', () {
      expect(
        computeNeedsAgentUnlock(
            deviceRole: 'super_admin', hasAgents: true, selectedAgentId: null),
        isFalse,
      );
    });
    test('rôle null (pas de session) → pas de verrou', () {
      expect(
        computeNeedsAgentUnlock(
            deviceRole: null, hasAgents: true, selectedAgentId: null),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd epilote && /home/melack/flutter/bin/flutter test test/agent_lock_test.dart`
Expected: FAIL — `agentLockApplies`/`computeNeedsAgentUnlock` non définis (erreur de compilation).

- [ ] **Step 3: Write minimal implementation**

Dans `epilote/lib/features/auth/providers/active_agent_provider.dart`, ajouter l'import en tête (sous les imports existants) :

```dart
import '../../../core/constants/app_constants.dart';
```

Puis en fin de fichier :

```dart
// ─── Verrouillage « poste partagé » ─────────────────────────────────────────
// Rôles qui NE sont PAS des agents d'un poste scolaire partagé.
const Set<String> _nonAgentRoles = {
  AppConstants.roleSuperAdmin,
  AppConstants.roleAdminGroupe,
  AppConstants.roleParent,
  AppConstants.roleEleve,
};

/// Le verrou (et le menu « Changer d'utilisateur ») s'appliquent au personnel
/// scolaire d'un poste partagé — tout rôle non vide hors [_nonAgentRoles].
bool agentLockApplies(String? role) =>
    role != null && role.isNotEmpty && !_nonAgentRoles.contains(role);

/// Décision pure : faut-il imposer l'écran-verrou ?
/// - pas de session (rôle null) → non ;
/// - rôle hors public agent → non ;
/// - aucun agent encore synchronisé → non (on n'enferme jamais dehors) ;
/// - sinon : verrou tant qu'aucun agent n'est sélectionné.
bool computeNeedsAgentUnlock({
  required String? deviceRole,
  required bool hasAgents,
  required String? selectedAgentId,
}) {
  if (!agentLockApplies(deviceRole)) return false;
  if (!hasAgents) return false;
  return selectedAgentId == null;
}

/// Câble la décision aux providers existants.
final needsAgentUnlockProvider = Provider<bool>((ref) {
  final role = ref.watch(authNotifierProvider).valueOrNull?.role;
  final agents = ref.watch(switchableAgentsProvider).valueOrNull ?? const [];
  final selected = ref.watch(selectedAgentIdProvider);
  return computeNeedsAgentUnlock(
    deviceRole: role,
    hasAgents: agents.isNotEmpty,
    selectedAgentId: selected,
  );
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd epilote && /home/melack/flutter/bin/flutter test test/agent_lock_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
cd /home/melack/E-PILOTE && git add epilote/lib/features/auth/providers/active_agent_provider.dart epilote/test/agent_lock_test.dart && git commit -m "feat(auth): décision needsAgentUnlock (verrou poste partagé)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Fond animé sobre (`AgentLockBackground`)

**Files:**
- Create: `epilote/lib/features/auth/screens/widgets/agent_lock_background.dart`

**Interfaces:**
- Produces: `class AgentLockBackground extends StatefulWidget` — fond plein écran (gradient navy + grille de points + filigrane logo qui « respire » + ligne tricolore animée). Aucun paramètre.
- Consumes: `auth_colors.dart` (`kAuthNavyDeep`, `kAuthNavyDark`, `kAuthNavy`, `kAuthCongoGreen/Yellow/Red`), `AnimatedTricolorLine` (`widgets/login_anim_widgets.dart`), asset `assets/icons/logo.svg`.

- [ ] **Step 1: Implémenter le widget**

Créer le fichier :

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'auth_colors.dart';
import 'login_anim_widgets.dart';

/// Fond plein écran de l'écran-verrou : langage visuel du login, sobre et
/// institutionnel. Filigrane logo E-PILOTE en « respiration » très lente +
/// ligne tricolore animée. Aucun clignotement.
class AgentLockBackground extends StatefulWidget {
  const AgentLockBackground({super.key});

  @override
  State<AgentLockBackground> createState() => _AgentLockBackgroundState();
}

class _AgentLockBackgroundState extends State<AgentLockBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient diagonal (login).
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kAuthNavyDeep, kAuthNavyDark, kAuthNavy],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Grille de points décorative.
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
        // Filigrane logo qui respire (échelle 1.0↔1.04, opacité ~5,5 %).
        Center(
          child: AnimatedBuilder(
            animation: _breath,
            builder: (_, child) {
              final t = Curves.easeInOut.transform(_breath.value);
              return Opacity(
                opacity: 0.04 + 0.02 * t,
                child: Transform.scale(scale: 1.0 + 0.04 * t, child: child),
              );
            },
            child: SvgPicture.asset(
              'assets/icons/logo.svg',
              width: 460,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
        // Voile tricolore qui dérive lentement (très discret).
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _breath,
            builder: (_, _) => CustomPaint(
              painter: _TricolorVeilPainter(phase: _breath.value),
            ),
          ),
        ),
        // Ligne tricolore animée en bas (réutilisée du login).
        const Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedTricolorLine(height: 3),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.025);
    const spacing = 36.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter _) => false;
}

class _TricolorVeilPainter extends CustomPainter {
  _TricolorVeilPainter({required this.phase});
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final dy = math.sin(phase * 2 * math.pi) * 0.04;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1, -1 + dy),
        end: Alignment(1, 1 + dy),
        colors: [
          kAuthCongoGreen.withValues(alpha: 0.06),
          Colors.transparent,
          kAuthCongoYellow.withValues(alpha: 0.05),
          Colors.transparent,
          kAuthCongoRed.withValues(alpha: 0.06),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_TricolorVeilPainter old) => old.phase != phase;
}
```

- [ ] **Step 2: Vérifier l'import des tokens**

Run: `cd epilote && grep -n "kAuthNavyDeep\|kAuthCongoGreen" lib/features/auth/screens/widgets/auth_colors.dart`
Expected: les constantes existent. Sinon, ouvrir `auth_colors.dart` et utiliser les noms réels (adapter les références).

Run: `cd epilote && grep -n "class AnimatedTricolorLine" lib/features/auth/screens/widgets/login_anim_widgets.dart`
Expected: la classe existe (sinon adapter l'import).

- [ ] **Step 3: Analyze**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze lib/features/auth/screens/widgets/agent_lock_background.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
cd /home/melack/E-PILOTE && git add epilote/lib/features/auth/screens/widgets/agent_lock_background.dart && git commit -m "feat(auth): fond animé sobre de l'écran-verrou

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Grille de sélection d'agent (`AgentGrid`)

**Files:**
- Create: `epilote/lib/features/auth/screens/widgets/agent_grid.dart`

**Interfaces:**
- Produces: `class AgentGrid extends StatefulWidget` avec
  `AgentGrid({required List<AgentOption> agents, required ValueChanged<AgentOption> onPick})`.
  Affiche en-tête « Qui utilise ce poste ? », champ de recherche, et la grille d'avatars cliquables.
- Consumes: `AgentOption` (`active_agent_provider.dart`), `roleLabel` (`admin_groupe/providers/admin_users_provider.dart`), tokens `admin_ui.dart`, `cached_network_image`.

- [ ] **Step 1: Implémenter le widget**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_ui.dart' show kNavy, kBorder, kTextMuted;
import '../../../admin_groupe/providers/admin_users_provider.dart'
    show roleLabel;
import '../../providers/active_agent_provider.dart';

/// Grille de sélection d'agent dans l'écran-verrou. Recherche + avatars.
class AgentGrid extends StatefulWidget {
  const AgentGrid({super.key, required this.agents, required this.onPick});
  final List<AgentOption> agents;
  final ValueChanged<AgentOption> onPick;

  @override
  State<AgentGrid> createState() => _AgentGridState();
}

class _AgentGridState extends State<AgentGrid> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = widget.agents.where((a) {
      if (q.isEmpty) return true;
      return a.fullName.toLowerCase().contains(q) ||
          roleLabel(a.role).toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) =>
          a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Qui utilise ce poste ?',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: kNavy)),
        const SizedBox(height: 4),
        const Text('Sélectionnez votre profil — vos saisies seront '
            'enregistrées à votre nom.',
            style: TextStyle(fontSize: 12, color: kTextMuted)),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Rechercher un nom, un rôle…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF6F8FB),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorder)),
          ),
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
                child: Text('Aucun agent ne correspond.',
                    style: TextStyle(color: kTextMuted))),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 64,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) =>
                  _AgentTile(agent: list[i], onTap: () => widget.onPick(list[i])),
            ),
          ),
      ],
    );
  }
}

class _AgentTile extends StatelessWidget {
  const _AgentTile({required this.agent, required this.onTap});
  final AgentOption agent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              _AgentAvatar(agent: agent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(roleLabel(agent.role),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 11, color: kTextMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: kTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar({required this.agent});
  final AgentOption agent;

  @override
  Widget build(BuildContext context) {
    final has = agent.avatarUrl != null && agent.avatarUrl!.isNotEmpty;
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: kNavy),
      child: has
          ? CachedNetworkImage(
              imageUrl: agent.avatarUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() => Center(
        child: Text(agent.initials,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      );
}
```

- [ ] **Step 2: Analyze**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze lib/features/auth/screens/widgets/agent_grid.dart`
Expected: No issues found. (Si `roleLabel`/tokens ont un autre chemin, l'analyze le signale → corriger l'import avec le chemin réel via `grep -rn "String roleLabel" lib`.)

- [ ] **Step 3: Commit**

```bash
cd /home/melack/E-PILOTE && git add epilote/lib/features/auth/screens/widgets/agent_grid.dart && git commit -m "feat(auth): grille de sélection d'agent (écran-verrou)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Pavé PIN (`AgentPinPad`)

**Files:**
- Create: `epilote/lib/features/auth/screens/widgets/agent_pin_pad.dart`

**Interfaces:**
- Produces: `class AgentPinPad extends ConsumerStatefulWidget` avec
  `AgentPinPad({required AgentOption agent, required bool isCreate, required VoidCallback onBack, required VoidCallback onSuccess})`.
  Clavier numérique, points de saisie, création (saisie + confirmation) ou vérification ; appelle `onSuccess` quand le PIN est posé/validé.
- Consumes: `agentPinServiceProvider`, `AgentOption` (`active_agent_provider.dart`), tokens `admin_ui.dart`.

- [ ] **Step 1: Implémenter le widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/admin_ui.dart'
    show kNavy, kRed, kTextMuted, kTextPrimary, kBorder;
import '../../providers/active_agent_provider.dart';

/// Pavé PIN de l'écran-verrou. Création (saisie + confirmation) ou vérification.
class AgentPinPad extends ConsumerStatefulWidget {
  const AgentPinPad({
    super.key,
    required this.agent,
    required this.isCreate,
    required this.onBack,
    required this.onSuccess,
  });
  final AgentOption agent;
  final bool isCreate;
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  @override
  ConsumerState<AgentPinPad> createState() => _AgentPinPadState();
}

class _AgentPinPadState extends ConsumerState<AgentPinPad> {
  static const _maxLen = 6;
  String _pin = '';
  String? _firstEntry; // mode création : 1ʳᵉ saisie mémorisée
  String? _error;
  bool _busy = false;

  bool get _confirming => widget.isCreate && _firstEntry != null;

  String get _title {
    if (!widget.isCreate) return 'Saisissez votre code PIN';
    return _confirming ? 'Confirmez votre code' : 'Choisissez un code (4 à 6 chiffres)';
  }

  Future<void> _onDigit(String d) async {
    if (_busy || _pin.length >= _maxLen) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _onBackspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _validate() async {
    if (_pin.length < 4) {
      setState(() => _error = 'Le code doit comporter au moins 4 chiffres.');
      return;
    }
    final svc = ref.read(agentPinServiceProvider);

    if (widget.isCreate) {
      if (!_confirming) {
        setState(() {
          _firstEntry = _pin;
          _pin = '';
        });
        return;
      }
      if (_pin != _firstEntry) {
        setState(() {
          _error = 'Les deux codes ne correspondent pas.';
          _firstEntry = null;
          _pin = '';
        });
        return;
      }
      setState(() => _busy = true);
      await svc.setPin(widget.agent.id, _pin);
      if (mounted) widget.onSuccess();
      return;
    }

    setState(() => _busy = true);
    final ok = await svc.verifyPin(widget.agent.id, _pin);
    if (!mounted) return;
    if (ok) {
      widget.onSuccess();
    } else {
      setState(() {
        _busy = false;
        _error = 'Code PIN incorrect.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              color: kTextMuted,
              onPressed: _busy ? null : widget.onBack,
            ),
            Expanded(
              child: Text(widget.agent.fullName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 6),
        Text(_title,
            style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
        const SizedBox(height: 18),
        _Dots(filled: _pin.length, max: _maxLen),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: kRed, fontSize: 12.5)),
        ],
        const SizedBox(height: 18),
        _Keypad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          onValidate: _validate,
          canValidate: !_busy && _pin.length >= 4,
        ),
        const SizedBox(height: 10),
        Text(
          widget.isCreate
              ? 'Ce code protège vos saisies sur ce poste partagé.'
              : 'Code oublié ? La direction peut le réinitialiser.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: kTextMuted),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.max});
  final int filled;
  final int max;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < max; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? kNavy : Colors.transparent,
                border: Border.all(
                    color: i < filled ? kNavy : kBorder, width: 1.5),
              ),
            ),
        ],
      );
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onValidate,
    required this.canValidate,
  });
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onValidate;
  final bool canValidate;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => SizedBox(
          width: 72,
          height: 56,
          child: Material(
            color: const Color(0xFFF6F8FB),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Center(
                child: child ??
                    Text(label,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary)),
              ),
            ),
          ),
        );

    Widget row(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final c in children)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: c),
            ],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([for (final d in ['1', '2', '3']) key(d, onTap: () => onDigit(d))]),
        row([for (final d in ['4', '5', '6']) key(d, onTap: () => onDigit(d))]),
        row([for (final d in ['7', '8', '9']) key(d, onTap: () => onDigit(d))]),
        row([
          key('', onTap: onBackspace, child: const Icon(Icons.backspace_outlined,
              size: 20, color: kTextMuted)),
          key('0', onTap: () => onDigit('0')),
          SizedBox(
            width: 72,
            height: 56,
            child: Material(
              color: canValidate ? kNavy : kBorder,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: canValidate ? onValidate : null,
                child: const Center(
                    child: Icon(Icons.check_rounded,
                        size: 22, color: Colors.white)),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze lib/features/auth/screens/widgets/agent_pin_pad.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
cd /home/melack/E-PILOTE && git add epilote/lib/features/auth/screens/widgets/agent_pin_pad.dart && git commit -m "feat(auth): pavé PIN de l'écran-verrou (création/vérification)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Écran-verrou (`AgentLockScreen`)

**Files:**
- Create: `epilote/lib/features/auth/screens/agent_lock_screen.dart`

**Interfaces:**
- Produces: `class AgentLockScreen extends ConsumerStatefulWidget` (const, sans paramètre). Assemble fond + carte (en-tête école + grille/PIN) + action « Déconnecter le poste ».
- Consumes: `AgentLockBackground`, `AgentGrid`, `AgentPinPad`, `currentSchoolProvider` (`structure/providers/academic_year_provider.dart`), `switchableAgentsProvider`, `selectedAgentIdProvider`, `agentPinServiceProvider`, `authNotifierProvider`, `AgentOption`.

- [ ] **Step 1: Implémenter le widget**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart'
    show kNavy, kTextMuted, kTextPrimary;
import '../../structure/providers/academic_year_provider.dart'
    show currentSchoolProvider;
import '../providers/active_agent_provider.dart';
import '../providers/auth_provider.dart';
import 'widgets/agent_grid.dart';
import 'widgets/agent_lock_background.dart';
import 'widgets/agent_pin_pad.dart';

/// Écran-verrou plein écran (poste scolaire partagé). Sélection d'agent + PIN,
/// session Supabase de l'appareil préservée. Affiché en overlay par AgentLockGate.
class AgentLockScreen extends ConsumerStatefulWidget {
  const AgentLockScreen({super.key});

  @override
  ConsumerState<AgentLockScreen> createState() => _AgentLockScreenState();
}

class _AgentLockScreenState extends ConsumerState<AgentLockScreen> {
  AgentOption? _picked;
  bool _isCreate = false;

  Future<void> _pick(AgentOption a) async {
    final hasPin = await ref.read(agentPinServiceProvider).hasPin(a.id);
    if (!mounted) return;
    setState(() {
      _picked = a;
      _isCreate = !hasPin;
    });
  }

  void _unlock() {
    final a = _picked;
    if (a == null) return;
    ref.read(selectedAgentIdProvider.notifier).state = a.id;
    // Pas de navigation : needsAgentUnlockProvider repasse à false → l'overlay
    // se retire de lui-même (AgentLockGate).
  }

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(switchableAgentsProvider).valueOrNull ?? const [];
    final school = ref.watch(currentSchoolProvider).valueOrNull;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AgentLockBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SchoolHeader(
                      name: school?['name'] as String? ?? 'E-PILOTE CONGO',
                      logoUrl: school?['logo_url'] as String?,
                    ),
                    const SizedBox(height: 16),
                    _Card(
                      child: _picked == null
                          ? AgentGrid(agents: agents, onPick: _pick)
                          : AgentPinPad(
                              agent: _picked!,
                              isCreate: _isCreate,
                              onBack: () => setState(() => _picked = null),
                              onSuccess: _unlock,
                            ),
                    ),
                    const SizedBox(height: 18),
                    _DeviceLogout(ref: ref),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolHeader extends StatelessWidget {
  const _SchoolHeader({required this.name, required this.logoUrl});
  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final has = logoUrl != null && logoUrl!.isNotEmpty;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: has
              ? CachedNetworkImage(
                  imageUrl: logoUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const _LogoFallback(),
                )
              : const _LogoFallback(),
        ),
        const SizedBox(height: 12),
        Text(name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('Poste partagé · République du Congo',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: kNavy,
        child: Center(
          child: Icon(Icons.school_rounded, color: Colors.white, size: 32),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 12)),
          ],
        ),
        child: child,
      );
}

class _DeviceLogout extends StatelessWidget {
  const _DeviceLogout({required this.ref});
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () async {
          ref.read(selectedAgentIdProvider.notifier).state = null;
          await ref.read(authNotifierProvider.notifier).signOut();
        },
        icon: Icon(Icons.logout_rounded,
            size: 16, color: Colors.white.withValues(alpha: 0.75)),
        label: Text('Déconnecter le poste',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
      );
}
```

- [ ] **Step 2: Vérifier le chemin de `currentSchoolProvider`**

Run: `cd epilote && grep -rn "currentSchoolProvider =" lib`
Expected: `lib/features/structure/providers/academic_year_provider.dart`. Si différent, ajuster l'import. Confirmer aussi que la map expose `'name'` et `'logo_url'` (`SELECT * FROM schools`).

- [ ] **Step 3: Analyze**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze lib/features/auth/screens/agent_lock_screen.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
cd /home/melack/E-PILOTE && git add epilote/lib/features/auth/screens/agent_lock_screen.dart && git commit -m "feat(auth): écran-verrou plein écran (école + grille + PIN)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Overlay `AgentLockGate` + branchement `main.dart`

**Files:**
- Create: `epilote/lib/features/auth/screens/widgets/agent_lock_gate.dart`
- Modify: `epilote/lib/main.dart:74` (ajouter `builder:` à `MaterialApp.router`)
- Test: `epilote/test/agent_lock_gate_test.dart`

**Interfaces:**
- Produces: `class AgentLockGate extends ConsumerWidget` avec `AgentLockGate({required Widget child})`. Empile l'écran-verrou par-dessus `child` quand `needsAgentUnlockProvider` est vrai (avec fondu).
- Consumes: `needsAgentUnlockProvider`, `AgentLockScreen`.

- [ ] **Step 1: Write the failing test**

Créer `epilote/test/agent_lock_gate_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';
import 'package:epilote/features/auth/screens/widgets/agent_lock_gate.dart';

void main() {
  testWidgets('déverrouillé → affiche l\'enfant, pas le verrou', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [needsAgentUnlockProvider.overrideWithValue(false)],
      child: const MaterialApp(
        home: AgentLockGate(child: Text('CONTENU')),
      ),
    ));
    expect(find.text('CONTENU'), findsOneWidget);
    expect(find.text('Qui utilise ce poste ?'), findsNothing);
  });

  testWidgets('verrouillé → empile le verrou par-dessus l\'enfant',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        needsAgentUnlockProvider.overrideWithValue(true),
        switchableAgentsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(
        home: AgentLockGate(child: Text('CONTENU')),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Qui utilise ce poste ?'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd epilote && /home/melack/flutter/bin/flutter test test/agent_lock_gate_test.dart`
Expected: FAIL — `AgentLockGate` non défini (compilation).

- [ ] **Step 3: Write minimal implementation**

Créer `epilote/lib/features/auth/screens/widgets/agent_lock_gate.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/active_agent_provider.dart';
import '../agent_lock_screen.dart';

/// Porte du verrou : empile [AgentLockScreen] par-dessus [child] quand
/// l'appareil doit être déverrouillé (poste partagé, aucun agent choisi).
/// Branché dans `MaterialApp.builder` → couvre toutes les routes.
class AgentLockGate extends ConsumerWidget {
  const AgentLockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(needsAgentUnlockProvider);
    return Stack(
      children: [
        child,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: locked
              ? const AgentLockScreen(key: ValueKey('agent-lock'))
              : const SizedBox.shrink(key: ValueKey('agent-unlocked')),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd epilote && /home/melack/flutter/bin/flutter test test/agent_lock_gate_test.dart`
Expected: PASS (2 tests). *(Le test « verrouillé » couvre l'overlay ; `currentSchoolProvider` renvoie null sans override → l'en-tête bascule sur le repli, OK.)*

- [ ] **Step 5: Brancher dans `main.dart`**

Dans `epilote/lib/main.dart`, ajouter l'import :

```dart
import 'features/auth/screens/widgets/agent_lock_gate.dart';
```

Puis modifier `MaterialApp.router` (vers la ligne 74) pour ajouter `builder:` :

```dart
    return MaterialApp.router(
      title: 'E-PILOTE CONGO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) =>
          AgentLockGate(child: child ?? const SizedBox.shrink()),
      locale: const Locale('fr'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr'), Locale('en')],
    );
```

- [ ] **Step 6: Analyze**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze lib/main.dart lib/features/auth/screens/widgets/agent_lock_gate.dart`
Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
cd /home/melack/E-PILOTE && git add epilote/lib/features/auth/screens/widgets/agent_lock_gate.dart epilote/lib/main.dart epilote/test/agent_lock_gate_test.dart && git commit -m "feat(auth): overlay AgentLockGate branché dans MaterialApp

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Menu « Changer d'utilisateur » + suppression de l'ancienne page

**Files:**
- Modify: `epilote/lib/core/widgets/app_shell/app_header.dart:166,209-217` (libellé, action, visibilité)
- Modify: `epilote/lib/core/router/app_router.dart:583-586` (retirer la route) + son import de `StaffAgentSwitchScreen`
- Modify: `epilote/lib/core/constants/routes.dart:59` (retirer `userAgents`)
- Delete: `epilote/lib/features/user/screens/staff_agent_switch_screen.dart`

**Interfaces:**
- Consumes: `agentLockApplies`, `selectedAgentIdProvider` (`active_agent_provider.dart`).

- [ ] **Step 1: Modifier le menu compte (`app_header.dart`)**

Vérifier l'import de `active_agent_provider.dart` (déjà présent — `selectedAgentIdProvider` y est utilisé ligne 160). Ajouter au besoin rien.

Remplacer le `case 'switch_agent'` (≈ ligne 166) :

```dart
          case 'switch_agent':
            // Poste partagé : reverrouille → AgentLockGate réaffiche l'écran-verrou.
            ref.read(selectedAgentIdProvider.notifier).state = null;
```

Remplacer la visibilité + le libellé de l'item (≈ lignes 208-217). Remplacer :

```dart
        // Poste partagé : bascule d'agent (personnel scolaire uniquement).
        if (isStaff)
          const PopupMenuItem(
            value: 'switch_agent',
            child: Row(children: [
              Icon(Icons.switch_account_outlined, size: 18, color: kNavy),
              SizedBox(width: 10),
              Text('Changer d’agent'),
            ]),
          ),
```

par :

```dart
        // Poste partagé : reverrouiller l'appareil (personnel scolaire, hors
        // parent/élève — même public que le verrou).
        if (agentLockApplies(profile?.role))
          const PopupMenuItem(
            value: 'switch_agent',
            child: Row(children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: kNavy),
              SizedBox(width: 10),
              Text('Changer d’utilisateur'),
            ]),
          ),
```

- [ ] **Step 2: Retirer la route et l'import dans `app_router.dart`**

Supprimer le bloc (≈ lignes 583-586) :

```dart
      GoRoute(
        path: Routes.userAgents,
        builder: (_, _) => const StaffAgentSwitchScreen(),
      ),
```

Puis supprimer l'import devenu inutile :

```dart
import '../../features/user/screens/staff_agent_switch_screen.dart';
```

(le localiser : `grep -n "staff_agent_switch_screen" lib/core/router/app_router.dart`.)

- [ ] **Step 3: Retirer la constante de route**

Dans `epilote/lib/core/constants/routes.dart`, supprimer la ligne 59 :

```dart
  static const String userAgents      = '/user/agents'; // bascule d'agent (poste partagé)
```

- [ ] **Step 4: Supprimer l'ancienne page**

```bash
cd /home/melack/E-PILOTE && git rm epilote/lib/features/user/screens/staff_agent_switch_screen.dart
```

- [ ] **Step 5: Vérifier qu'aucune référence ne subsiste**

Run: `cd epilote && grep -rn "userAgents\|StaffAgentSwitchScreen" lib`
Expected: aucun résultat.

- [ ] **Step 6: Analyze complet + build**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze`
Expected: No issues found! (0 issue sur tout le projet.)

Run: `cd epilote && /home/melack/flutter/bin/flutter build linux --debug`
Expected: build réussi (`Built build/linux/.../epilote`).

- [ ] **Step 7: Lancer la suite de tests**

Run: `cd epilote && /home/melack/flutter/bin/flutter test test/agent_lock_test.dart test/agent_lock_gate_test.dart`
Expected: PASS (10 tests au total).

- [ ] **Step 8: Vérification GUI réelle**

Lancer l'app (`flutter run -d linux`, `GDK_SCALE=1` si écran HiDPI). Vérifier :
1. **Au lancement** (compte personnel scolaire) → l'écran-verrou s'affiche : fond sobre animé, logo + nom de l'école en haut, grille d'agents.
2. Choisir un agent jamais utilisé → création PIN (saisie + confirmation) → entre dans l'app.
3. Menu compte → **« Changer d'utilisateur »** → l'écran-verrou réapparaît ; ressaisir le PIN → re-entre.
4. PIN incorrect → message d'erreur, points réinitialisés.
5. « Déconnecter le poste » → retour à la page de login.
6. Se connecter en **admin_groupe** → **aucun** verrou (entrée directe).

- [ ] **Step 9: Commit**

```bash
cd /home/melack/E-PILOTE && git add -A && git commit -m "feat(auth): « Changer d'utilisateur » reverrouille + retrait page in-shell

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes d'exécution

- **PowerSync & tests** : les tests ne touchent pas `db` (Task 1 = pur ; Task 6 = override `switchableAgentsProvider`). Ne pas tenter d'instancier PowerSync en test.
- **HiDPI** : l'écran de dev est 2× → préfixer `GDK_SCALE=1` au `flutter run` pour la vérif GUI (piège connu du projet).
- **Si un import diffère** (chemin de `roleLabel`, `currentSchoolProvider`, tokens `admin_ui`/`auth_colors`) : `flutter analyze` le signale immédiatement — corriger avec le chemin réel via `grep -rn`.
