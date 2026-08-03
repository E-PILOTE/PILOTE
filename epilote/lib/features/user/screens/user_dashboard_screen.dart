import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/staff_ui.dart';
import '../../communication/widgets/user_avatar.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../data/models/class_model.dart';
import '../../../features/communication/providers/announcements_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../features/structure/widgets/demarrage_card.dart';
import '../../../features/structure/providers/academic_year_provider.dart';
import '../../../features/navigation/providers/module_navigation_provider.dart';
import '../../../features/navigation/providers/permissions_provider.dart';
import '../providers/user_profile_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import '../providers/dashboard_provider.dart';
import '../../examens/providers/examens_provider.dart';
import '../../stages/providers/stages_provider.dart';

part 'dashboard_year_parts.dart';
part 'dashboard_kpi_parts.dart';
part 'dashboard_chart_parts.dart';
part 'dashboard_block_parts.dart';
part 'dashboard_examens_parts.dart';
part 'dashboard_cards_parts.dart';
part 'dashboard_modules_parts.dart';
part 'dashboard_skeleton_parts.dart';

/// Ombre portée du texte de la bannière — garantit le contraste du blanc sur le
/// verre translucide (fond variable derrière l'aurora).
List<Shadow> get _kBannerTextShadow => [
  Shadow(color: kNavyDeep, blurRadius: 8, offset: const Offset(0, 1)),
];

/// Palette cyclique pour les tuiles / graphes.
List<Color> get _kPalette => [
  kNavy,
  kGreen,
  const Color(0xFF0EA5E9),
  const Color(0xFF7C3AED),
  const Color(0xFFEF4444),
  const Color(0xFFF59E0B),
  const Color(0xFF0891B2),
  const Color(0xFFDB2777),
];

// ════════════════════════════════════════════════════════════════════════════
//  ORDRE DES BLOCS = CHARGE RÉELLE, jamais l'ACCÈS.
//  L'accès reste gouverné par les permissions (profil d'accès = source de
//  vérité — cf profil-source-de-verite-droits). L'ORDRE des blocs autorisés
//  suit la charge réellement attribuée par l'admin groupe (modules accordés),
//  PAS l'étiquette de rôle : si un secrétaire/directeur reçoit la Finance (ex.
//  pas de comptable, ou comptable en congé), Finances remonte automatiquement ;
//  quand on lui retire ces modules, ça redescend. Le rôle ne sert qu'à départager
//  à charge égale. Un bloc non autorisé ne s'affiche jamais.
// ════════════════════════════════════════════════════════════════════════════
enum _Section { scolarite, examens, personnel, finance, medical, discipline }

/// Modules représentatifs de chaque domaine (alignés sur les `show*` du build).
const Map<_Section, List<String>> _sectionSlugs = {
  _Section.scolarite: ['classes', 'eleves', 'inscriptions'],
  _Section.examens: ['examens', 'stages'],
  _Section.personnel: ['personnel'],
  _Section.finance: ['paiements-eleves', 'frais-scolarite', 'depenses', 'budget'],
  _Section.medical: ['infirmerie'],
  _Section.discipline: ['discipline'],
};

/// Poids d'un domaine pour CET agent, déduit de ses permissions accordées :
/// lire = +1 (je consulte), écrire = +2 (j'y travaille), valider/approuver = +1
/// (je décide). Plus le poids est élevé, plus le domaine occupe l'agent.
int _sectionWeight(_Section s, Map<String, ModulePermission> perms) {
  var w = 0;
  for (final slug in _sectionSlugs[s]!) {
    final p = perms[slug];
    if (p == null || !p.canRead) continue;
    w += 1;
    if (p.canWrite) w += 2;
    if (p.canValidate || p.canApprove) w += 1;
  }
  return w;
}

/// Ordre canonique de DÉPARTAGE à charge égale (selon le métier du rôle).
List<_Section> _roleTiebreak(String role) {
  const overview = [
    _Section.scolarite,
    _Section.examens,
    _Section.personnel,
    _Section.finance,
    _Section.discipline,
    _Section.medical,
  ];
  return switch (role) {
    'comptable' => const [
        _Section.finance,
        _Section.scolarite,
        _Section.examens,
        _Section.personnel,
        _Section.discipline,
        _Section.medical,
      ],
    'infirmier' => const [
        _Section.medical,
        _Section.scolarite,
        _Section.examens,
        _Section.personnel,
        _Section.finance,
        _Section.discipline,
      ],
    'cpe' || 'surveillant' => const [
        _Section.discipline,
        _Section.scolarite,
        _Section.examens,
        _Section.personnel,
        _Section.finance,
        _Section.medical,
      ],
    _ => overview,
  };
}

/// Ordre final des blocs : charge réelle (poids) décroissante, puis départage
/// par le métier du rôle. C'est le miroir de ce que l'admin groupe a attribué.
List<_Section> _orderedSections(String role, Map<String, ModulePermission> perms) {
  final tiebreak = _roleTiebreak(role);
  final all = _Section.values.toList()
    ..sort((a, b) {
      final dw = _sectionWeight(b, perms) - _sectionWeight(a, perms);
      if (dw != 0) return dw;
      return tiebreak.indexOf(a) - tiebreak.indexOf(b);
    });
  return all;
}

/// Libellé contextuel du rôle pour le bandeau (s'adapte au type d'établissement
/// pour la direction : proviseur = lycée, directeur = collège/école).
String? _roleContextLabel(String role) => switch (role) {
      'proviseur' => 'Proviseur',
      'directeur' => 'Directeur',
      'secretaire' => 'Secrétariat',
      'comptable' => 'Comptabilité',
      'cpe' => 'Vie scolaire · CPE',
      'surveillant' => 'Vie scolaire · Surveillance',
      'infirmier' => 'Infirmerie',
      'enseignant' => 'Enseignant',
      'responsable_cantine' => 'Cantine',
      _ => null,
    };

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(title: 'Tableau de bord', child: _DashboardBody());
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authNotifierProvider).valueOrNull;
    final activeYear = ref.watch(activeYearProvider);
    final schoolAsync = ref.watch(currentSchoolProvider);
    final syncState = ref.watch(syncIndicatorProvider);
    final permsAsync = ref.watch(myPermissionsProvider);
    final perms = permsAsync.valueOrNull ?? const {};

    final school = schoolAsync.valueOrNull;
    final schoolName = school?['name'] as String? ?? '—';
    // Identité visuelle de l'établissement : logo propre de l'école, sinon
    // héritage du logo du groupe scolaire (l'école en est une émanation),
    // sinon repli sur les initiales. Tout est disponible offline.
    final schoolLogoUrl = school?['logo_url'] as String?;
    final groupLogoUrl = ref.watch(currentGroupLogoProvider).valueOrNull;
    // Agent ACTIF au clavier (poste partagé) : sa photo + son identité de repli.
    final agent = ref.watch(myProfileRowProvider).valueOrNull;

    // Présence de modules accordés (plan ∩ can_read). On NE rend PAS de grille
    // « Accès rapide » : ce serait un doublon de la sidebar. On s'en sert
    // uniquement pour décider d'afficher un message si le membre n'a AUCUN module.
    final groupedAsync = ref.watch(modulesGroupedByCategoryProvider);
    final grouped = groupedAsync.valueOrNull ?? const {};
    final modulesSyncing =
        (groupedAsync.isLoading && !groupedAsync.hasValue) ||
        (permsAsync.isLoading && !permsAsync.hasValue);
    final modulesError = groupedAsync.hasError || permsAsync.hasError;

    var hasModules = false;
    for (final entry in grouped.entries) {
      if (entry.value.any((m) => perms[m.slug]?.canRead ?? false)) {
        hasModules = true;
        break;
      }
    }

    // Squelette shimmer tant que le dashboard n'a pas de contenu STABLE :
    // 1) vrai premier chargement (aucune valeur produite : `isLoading && !hasValue`),
    // 2) le piège PowerSync : `db.watch()` émet une liste VIDE avant la première
    //    synchro (hasValue=true, isLoading=false). Sans garde, « Aucun module »
    //    et des KPI à zéro clignotent une fraction de seconde avant que les
    //    données descendent. On garde donc la silhouette tant qu'aucun module
    //    n'est là ET que la synchro initiale n'a JAMAIS abouti (`lastSyncedAt`
    //    est persisté : après la 1ʳᵉ synchro, un relancement offline s'affiche
    //    instantanément et un re-sync de fond ne clignote jamais par-dessus le
    //    contenu vivant).
    final everSynced = ref.watch(lastSyncedAtProvider) != null;
    final firstLoad = (permsAsync.isLoading && !permsAsync.hasValue) ||
        (groupedAsync.isLoading && !groupedAsync.hasValue) ||
        (schoolAsync.isLoading && !schoolAsync.hasValue);
    final awaitingFirstSync = !hasModules && !everSynced && !modulesError;
    if (firstLoad || awaitingFirstSync) return const _DashboardSkeleton();

    // Permissions d'affichage des blocs métier.
    final showClasses = perms['classes']?.canRead ?? false;
    final showEleves = (perms['eleves']?.canRead ?? false) ||
        (perms['inscriptions']?.canRead ?? false);
    final showInscriptions = perms['inscriptions']?.canRead ?? false;
    final canValidate = perms['inscriptions']?.canValidate ?? false;

    // Blocs métier composés selon les PERMISSIONS (→ adaptatif au rôle).
    final showScolarite = showClasses || showEleves;
    final showExamensMod = perms['examens']?.canRead ?? false;
    final showStagesMod = perms['stages']?.canRead ?? false;
    final showExamens = showExamensMod || showStagesMod;
    final showPersonnel = perms['personnel']?.canRead ?? false;
    final showFinance = (perms['paiements-eleves']?.canRead ?? false) ||
        (perms['frais-scolarite']?.canRead ?? false) ||
        (perms['depenses']?.canRead ?? false) ||
        (perms['budget']?.canRead ?? false);
    final showMedical = perms['infirmerie']?.canRead ?? false;
    final showDiscipline = perms['discipline']?.canRead ?? false;
    final anyBlock = showScolarite ||
        showExamens ||
        showPersonnel ||
        showFinance ||
        showMedical ||
        showDiscipline;

    final role = profile?.role ?? '';
    final isParent = role == 'parent';
    final isEleve = role == 'eleve';

    // Blocs métier AUTORISÉS (permissions) → rangés selon la persona du rôle.
    final blocks = <_Section, Widget>{
      if (showScolarite)
        _Section.scolarite: _ScolariteBlock(
          showClasses: showClasses,
          showEleves: showEleves,
          showInscriptions: showInscriptions,
        ),
      if (showExamens)
        _Section.examens: _ExamensBlock(
          showExamens: showExamensMod,
          showStages: showStagesMod,
        ),
      if (showPersonnel) _Section.personnel: const _PersonnelBlock(),
      if (showFinance) _Section.finance: const _FinanceBlock(),
      if (showMedical) _Section.medical: const _MedicalBlock(),
      if (showDiscipline) _Section.discipline: const _DisciplineBlock(),
    };
    final orderedBlocks = [
      for (final s in _orderedSections(role, perms))
        if (blocks[s] != null) blocks[s]!,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
      children: [
        _SchoolBanner(
          schoolName: schoolName,
          // Salue l'AGENT ACTIF (poste partagé), pas le compte appareil.
          firstName: agent?.firstName ?? profile?.firstName ?? '',
          roleLabel: _roleContextLabel(agent?.role ?? role),
          schoolLogoUrl: schoolLogoUrl,
          groupLogoUrl: groupLogoUrl,
          agentName: agent != null
              ? '${agent.firstName} ${agent.lastName}'.trim()
              : (profile != null
                  ? '${profile.firstName} ${profile.lastName}'.trim()
                  : ''),
          agentRole: agent?.role ?? profile?.role,
          agentAvatarUrl: agent?.avatarUrl,
        ),
        const SizedBox(height: 18),

        // Le premier matin, un établissement ouvre l'application sur du vide.
        // Cette carte dit par où commencer, puis s'efface d'elle-même.
        const DemarrageCard(),

        if (activeYear != null) ...[
          _AcademicYearCard(year: activeYear, syncState: syncState),
          const SizedBox(height: 12),
          _CalendarStrip(yearId: activeYear.id),
          const SizedBox(height: 22),
        ],

        // ── Blocs métier, RANGÉS selon la persona du rôle (accès = permissions)
        ...orderedBlocks,

        // ── À traiter : inscriptions en attente ─────────────────────────────
        if (showInscriptions) _PendingInscriptionsCard(canValidate: canValidate),

        // ── Accueil parent / élève (pas de modules de gestion) ──────────────
        if ((isParent || isEleve) && !anyBlock)
          _ParentWelcomeCard(isParent: isParent),

        // ── Accès rapide aux modules : déplacé dans le lanceur du top header
        // (icône grille, à droite du thème). Le corps du dashboard mène par
        // l'information (KPI/insights), la navigation transverse vit dans le
        // chrome — pattern « app switcher » (Notion/Linear). `hasModules` reste
        // utilisé plus bas pour l'état « aucun module ».

        // ── Annonces récentes ───────────────────────────────────────────────
        const _RecentAnnouncementsCard(),

        // ── État modules (informatif uniquement, pas de doublon sidebar) ────
        if (!hasModules && !anyBlock) ...[
          if (modulesSyncing)
            const _SyncingModulesCard()
          else if (modulesError)
            const _ModulesErrorCard()
          else
            const _NoModulesCard(),
        ],
      ],
    );
  }
}

// ─── Bannière école (avec état de synchro offline-first) ───────────────────────
class _SchoolBanner extends StatefulWidget {
  const _SchoolBanner({
    required this.schoolName,
    required this.firstName,
    required this.roleLabel,
    required this.schoolLogoUrl,
    required this.groupLogoUrl,
    required this.agentName,
    required this.agentRole,
    required this.agentAvatarUrl,
  });
  final String schoolName;
  final String firstName;
  final String? roleLabel;
  final String? schoolLogoUrl;
  final String? groupLogoUrl;
  final String agentName;
  final String? agentRole;
  final String? agentAvatarUrl;

  @override
  State<_SchoolBanner> createState() => _SchoolBannerState();
}

class _SchoolBannerState extends State<_SchoolBanner> {
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: Container(
        // Aplat MONO — aligné sur la bannière admin_groupe.
        //
        // `kNavyDeep` et non `kNavy` : depuis la refonte des thèmes, `kNavy` est
        // un jeton de PREMIER PLAN (il s'éclaircit en sombre) — peindre une
        // grande carte avec donnerait un aplat bleu clair sous du texte blanc.
        // `kNavyDeep` reste un fond sombre dans les 3 thèmes (garanti par
        // `palette_test.dart` : blanc lisible dessus).
        decoration: BoxDecoration(
          color: kNavyDeep,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kNavy.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Photo de l'AGENT ACTIF (qui je suis), repli initiales.
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Semantics(
                        label: widget.agentName.isNotEmpty
                            ? 'Photo de profil de ${widget.agentName}'
                            : 'Photo de profil',
                        image: true,
                        child: UserAvatarCircle(
                          name: widget.agentName,
                          role: widget.agentRole,
                          avatarUrl: widget.agentAvatarUrl,
                          radius: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${_greeting()}${widget.firstName.isNotEmpty ? ", ${widget.firstName}" : ""} 👋',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  shadows: _kBannerTextShadow)),
                          const SizedBox(height: 5),
                          Text(widget.schoolName,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  shadows: _kBannerTextShadow),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (widget.roleLabel != null) ...[
                            const SizedBox(height: 5),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.badge_rounded,
                                  size: 13, color: Colors.white60),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(widget.roleLabel!,
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                        shadows: _kBannerTextShadow),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Logo de l'ÉTABLISSEMENT (où je suis) : logo école →
                    // héritage logo groupe → initiales. Voir [_SchoolLogoBadge].
                    _SchoolLogoBadge(
                      schoolLogoUrl: widget.schoolLogoUrl,
                      groupLogoUrl: widget.groupLogoUrl,
                      schoolName: widget.schoolName,
                    ),
                  ],
                ),
              ),
              // Bord lumineux (fin liseré clair — finition « glass »).
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1),
                    ),
                  ),
                ),
              ),
              // Liseré tricolore (identité nationale, discret en pied de card).
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _TricolorStrip(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Peintre d'aurora : 3 halos colorés diffus qui dérivent lentement derrière le
// verre. MaskFilter.blur donne la luminescence « fluo » à faible coût.
// ─── Logo établissement (cascade école → groupe → initiales) ───────────────────
// L'école est une émanation du groupe scolaire : si elle n'a pas son propre logo,
// elle hérite naturellement de celui du groupe. Dernier repli : ses initiales.
class _SchoolLogoBadge extends StatelessWidget {
  const _SchoolLogoBadge({
    required this.schoolLogoUrl,
    required this.groupLogoUrl,
    required this.schoolName,
  });
  final String? schoolLogoUrl;
  final String? groupLogoUrl;
  final String schoolName;

  bool _ok(String? u) =>
      u != null && u.trim().isNotEmpty && u.trim().startsWith('http');

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    final url = _ok(schoolLogoUrl)
        ? schoolLogoUrl!.trim()
        : (_ok(groupLogoUrl) ? groupLogoUrl!.trim() : null);

    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: Colors.white.withValues(alpha: 0.12),
      child: Text(
        avatarInitials(schoolName == '—' ? null : schoolName),
        style: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
      ),
    );

    final Widget inner = url == null
        ? initials
        : CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, _) => initials,
            errorWidget: (_, _, _) => initials,
          );

    return Semantics(
      label: schoolName == '—'
          ? "Logo de l'établissement"
          : 'Logo de $schoolName',
      image: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: inner,
      ),
    );
  }
}

// ─── Liseré tricolore (République du Congo) ────────────────────────────────────
// Identité nationale conservée mais discrète : un fin trait vert · jaune · rouge
// en pied de la card, qui ne dispute pas la vedette au logo de l'établissement.
class _TricolorStrip extends StatelessWidget {
  const _TricolorStrip();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 4,
        child: Row(children: [
          Expanded(child: ColoredBox(color: kGreen)),
          Expanded(child: ColoredBox(color: kAccent)),
          Expanded(child: ColoredBox(color: kRed)),
        ]),
      );
}
