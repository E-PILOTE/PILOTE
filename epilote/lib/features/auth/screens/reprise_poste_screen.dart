import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../providers/active_agent_provider.dart';
import '../providers/auth_provider.dart';
import '../services/session_keeper.dart';
import 'widgets/auth_colors.dart';

part 'reprise_poste_parts.dart';

// ════════════════════════════════════════════════════════════════════════════
//  REPRISE DU POSTE — l'école n'est plus enfermée dehors
//
//  Cet écran remplace l'écran de connexion le jour où la session serveur meurt
//  alors que la base locale, elle, est intacte. Il existe parce que l'écran de
//  connexion est un MUR dans une école congolaise : les agents ne connaissent
//  que leur code à quatre chiffres, et le mot de passe du compte de
//  l'établissement a été saisi une fois, le jour de l'installation, par
//  quelqu'un qui n'est peut-être plus là.
//
//  Il dit trois choses, dans cet ordre :
//    1. « Ce poste est bien le vôtre » — le nom de l'école, lu en local. C'est
//       la première chose à rétablir : voir son propre nom rassure plus que
//       n'importe quel message d'erreur ;
//    2. « Reprenez le travail » — un agent enrôlé, son code, et l'application
//       s'ouvre sur les données déjà là. Les écritures s'empilent et partiront
//       à la prochaine connexion ;
//    3. « Reconnectez le poste » — la porte du mot de passe, adresse déjà
//       remplie, pour celui qui la connaît.
//
//  ⚠️ Ce que cet écran N'EST PAS : un contournement d'authentification. Les
//  données sont déjà sur la machine — lisibles dans le fichier SQLite sans
//  aucune application. Aucune écriture ne franchit la RLS sans jeton valide.
//  Ce qui est rendu ici, c'est le droit de continuer à travailler, pas un accès
//  nouveau. Cf. `session_keeper.dart` pour le raisonnement complet.
// ════════════════════════════════════════════════════════════════════════════

/// Un agent enrôlé sur CE poste : il y a déjà posé un code PIN. C'est la seule
/// preuve d'identité vérifiable sans serveur.
class _AgentDuPoste {
  const _AgentDuPoste(this.id, this.nom, this.role);
  final String id, nom, role;
}

/// Ce que le poste sait de lui-même, lu dans la base locale : le nom de l'école
/// et les agents qui y ont enrôlé un code.
final _memoireDuPosteProvider = FutureProvider.autoDispose<
    ({String? ecole, List<_AgentDuPoste> agents})>((ref) async {
  final identite = ref.watch(repriseProposeeProvider);
  if (identite == null) return (ecole: null, agents: const <_AgentDuPoste>[]);

  String? ecole;
  try {
    final row = await db.getOptional(
      'SELECT s.name AS n FROM profiles p '
      'JOIN schools s ON s.id = p.school_id WHERE p.id = ? LIMIT 1',
      [identite.userId],
    );
    ecole = row?['n'] as String?;
  } catch (_) {/* le nom est un confort, pas une condition */}

  final enroles = await const AgentPinService().enrolledIds();
  final agents = <_AgentDuPoste>[];
  if (enroles.isNotEmpty) {
    try {
      final marques = List.filled(enroles.length, '?').join(',');
      final rows = await db.getAll(
        'SELECT id, first_name, last_name, role FROM profiles '
        'WHERE id IN ($marques) ORDER BY last_name, first_name',
        enroles.toList(),
      );
      for (final r in rows) {
        final nom = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
        agents.add(_AgentDuPoste(r['id'] as String,
            nom.isEmpty ? 'Agent' : nom, r['role'] as String? ?? ''));
      }
    } catch (_) {/* base illisible → on retombe sur la porte du mot de passe */}
  }
  return (ecole: ecole, agents: agents);
});

class ReprisePosteScreen extends ConsumerStatefulWidget {
  const ReprisePosteScreen({super.key});
  @override
  ConsumerState<ReprisePosteScreen> createState() => _State();
}

class _State extends ConsumerState<ReprisePosteScreen> {
  final _pin = TextEditingController();
  final _mdp = TextEditingController();

  String? _agentId;
  String? _erreurPin;
  String? _erreurMdp;
  bool _occupe = false;

  @override
  void dispose() {
    _pin.dispose();
    _mdp.dispose();
    super.dispose();
  }

  /// Rouvre le travail hors ligne. Le code PIN est exigé dès qu'un agent en a
  /// posé un sur ce poste ; s'il n'en existe aucun, la porte reste ouverte —
  /// exiger un code qui n'a jamais été créé enfermerait dehors, à coup sûr,
  /// l'établissement qu'on prétend protéger. Cf. [exigePinPourReprise].
  Future<void> _reprendre(List<_AgentDuPoste> agents) async {
    setState(() { _occupe = true; _erreurPin = null; });
    try {
      if (exigePinPourReprise(agents.length)) {
        final id = _agentId;
        if (id == null) {
          setState(() { _erreurPin = 'Choisissez votre nom.'; _occupe = false; });
          return;
        }
        final service = ref.read(agentPinServiceProvider);
        final jusqua = await service.lockedUntil(id);
        if (jusqua != null) {
          setState(() {
            _erreurPin = 'Trop d\'essais. Réessayez dans un instant.';
            _occupe = false;
          });
          return;
        }
        if (!await service.verifyPin(id, _pin.text)) {
          await service.recordFail(id);
          setState(() { _erreurPin = 'Code incorrect.'; _occupe = false; });
          return;
        }
        await service.clearFails(id);
        await service.recordUsage(id);
        ref.read(selectedAgentIdProvider.notifier).state = id;
      }
      final ok = await ref.read(authNotifierProvider.notifier).reprendreHorsLigne();
      if (!ok && mounted) {
        setState(() {
          _erreurPin = 'Les données de l\'école ne sont plus sur ce poste : '
              'seule une reconnexion au serveur peut les rétablir.';
          _occupe = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _erreurPin = '$e'; _occupe = false; });
    }
  }

  Future<void> _reconnecter(String email) async {
    setState(() { _occupe = true; _erreurMdp = null; });
    await ref.read(authNotifierProvider.notifier).signIn(email, _mdp.text);
    final etat = ref.read(authNotifierProvider);
    if (!mounted) return;
    setState(() {
      _occupe = false;
      _erreurMdp = etat.hasError ? '${etat.error}' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final identite = ref.watch(repriseProposeeProvider);
    final memoire = ref.watch(_memoireDuPosteProvider).valueOrNull;
    final agents = memoire?.agents ?? const <_AgentDuPoste>[];

    // Le provider a été vidé (reconnexion réussie ailleurs) : plus rien à
    // reprendre, le routeur va s'en charger.
    if (identite == null) {
      return const Scaffold(
        backgroundColor: kAuthNavyDeep,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final jours = identite.joursDepuisLaDerniereSession(DateTime.now());

    return Scaffold(
      backgroundColor: kAuthNavyDeep,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _EnTete(ecole: memoire?.ecole, jours: jours),
                const SizedBox(height: 24),
                LayoutBuilder(builder: (context, c) {
                  final etroit = c.maxWidth < 720;
                  final portes = [
                    _PorteReprise(
                      agents: agents,
                      agentId: _agentId,
                      pin: _pin,
                      erreur: _erreurPin,
                      occupe: _occupe,
                      onAgent: (v) => setState(() {
                        _agentId = v;
                        _erreurPin = null;
                      }),
                      onValider: () => _reprendre(agents),
                    ),
                    _PorteReconnexion(
                      email: identite.email,
                      mdp: _mdp,
                      erreur: _erreurMdp,
                      occupe: _occupe,
                      onValider: () => _reconnecter(identite.email),
                    ),
                  ];
                  return etroit
                      ? Column(children: [
                          portes[0],
                          const SizedBox(height: 16),
                          portes[1],
                        ])
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: portes[0]),
                            const SizedBox(width: 16),
                            Expanded(child: portes[1]),
                          ]);
                }),
                const SizedBox(height: 20),
                const _AucuneDesDeux(),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
