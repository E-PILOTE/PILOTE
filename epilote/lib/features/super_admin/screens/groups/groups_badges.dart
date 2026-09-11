part of '../school_groups_screen.dart';

// Pastille, badges de statut, type, tutelle, caractère, plan.

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.name, this.size = 38, this.logoUrl});
  final String  name;
  final double  size;
  final String? logoUrl;

  static List<Color> get _colors => [_kNavy, _kGreen, _kPurple, _kOrange, const Color(0xFF0EA5E9)];

  String get _initials => initialesEtablissement(name);

  Color get _color => _colors[name.codeUnitAt(0) % _colors.length];

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.startsWith('http');
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasLogo ? _kBorder : _color.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: logoUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => Center(child: Text(_initials,
                style: TextStyle(color: _color,
                    fontSize: size * 0.37, fontWeight: FontWeight.w800))),
              errorWidget: (_, _, _) => Center(child: Text(_initials,
                style: TextStyle(color: _color,
                    fontSize: size * 0.37, fontWeight: FontWeight.w800))),
            )
          : Center(child: Text(_initials, style: TextStyle(
              color: _color, fontSize: size * 0.37, fontWeight: FontWeight.w800,
            ))),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});
  final String status, label;

  Color get _color => switch (status) {
    'active'    => _kGreen,
    'trial'     => _kPurple,
    'suspended' => _kOrange,
    'cancelled' => _kRed,
    _           => _kMuted,
  };

  IconData get _icon => switch (status) {
    'active'    => Icons.check_circle_rounded,
    'trial'     => Icons.hourglass_top_rounded,
    'suspended' => Icons.pause_circle_rounded,
    'cancelled' => Icons.cancel_rounded,
    _           => Icons.help_rounded,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_icon, size: 11, color: _color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
          color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.label});
  final String type, label;

  Color get _color => type == 'public' ? _kNavy : _kGold;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(
        color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

/// Pastille du ministère de tutelle.
///
/// ⚠️ Elle NE DISPARAÎT PAS quand la tutelle manque : elle affiche « Sans
/// ministère » en rouge. Une pastille absente se confond avec un écran qui n'en
/// affiche pas ; une pastille qui dit le manque se voit dans une liste de
/// mille groupes, et c'est le seul endroit où la lacune peut encore être
/// corrigée avant qu'elle ne bloque une inscription à un examen d'État.
class _TutelleBadge extends StatelessWidget {
  const _TutelleBadge({required this.tutelle});
  final String? tutelle;

  @override
  Widget build(BuildContext context) {
    final connue = tutelleConnue(tutelle);
    final couleur = connue ? couleurTutelle(tutelle) : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: connue ? null : Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!connue) ...[
          Icon(Icons.error_outline_rounded, size: 11, color: couleur),
          const SizedBox(width: 4),
        ],
        Text(
          connue ? sigleTutelle(tutelle)! : 'Sans ministère',
          style: TextStyle(
              color: couleur, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}

/// Pastille du CARACTÈRE — l'axe confessionnel, distinct du secteur.
///
/// ⚠️ Absente quand le caractère n'est pas renseigné : « non renseigné » n'est
/// pas un caractère, et une pastille grise sur cinq groupes sur sept dirait
/// seulement que personne n'a encore répondu.
class _CaractereBadge extends StatelessWidget {
  const _CaractereBadge({required this.caractere, required this.label});
  final String caractere, label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _kPurple.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(iconeCaractere(caractere), size: 11, color: _kPurple),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(
          color: _kPurple, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan, required this.price});
  final String plan;
  final int price;

  Color get _color => switch (plan) {
    'Gratuit'       => _kMuted,
    'Premium'       => _kGold,
    'Pro'           => _kNavy,
    'Institutionnel' => _kPurple,
    _               => _kMuted,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _color.withValues(alpha: 0.2)),
    ),
    child: Text(plan, style: TextStyle(
        color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64),
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.school_rounded, size: 56, color: _kBorder),
      const SizedBox(height: 16),
      Text('Aucun groupe trouvé', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez un nouveau groupe.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Modal Détails ────────────────────────────────────────────────────────────
