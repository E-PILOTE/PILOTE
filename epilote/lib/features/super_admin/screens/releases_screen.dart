// ════════════════════════════════════════════════════════════════════════════
//  VERSIONS PUBLIÉES — le seul endroit d'où part une correction
//
//  Mille postes interrogent `derniere_version()` à chaque ouverture. Ce qu'on
//  déclare ici est ce qu'ils installeront. Une ligne fausse ne se rattrape pas :
//  au moment où l'on s'en aperçoit, le parc l'a déjà lue.
//
//  L'écran est donc écrit comme un formulaire de sécurité, pas comme un CRUD :
//  il refuse avant d'envoyer, il explique ce qu'il refuse, et il rappelle à
//  chaque étape ce que le parc va faire de la ligne.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/releases_provider.dart';
import 'release_form_dialog.dart';

class ReleasesScreen extends ConsumerWidget {
  const ReleasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Versions de l\'application',
      child: _ReleasesBody(),
    );
  }
}

class _ReleasesBody extends ConsumerWidget {
  const _ReleasesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(releasesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Avertissement(),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: Text(
              'Ce que les postes voient',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: kNavy),
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              final publie = await showReleaseFormDialog(context);
              if (publie && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: kGreen,
                  content: const Text('Version publiée — les postes la '
                      'verront à leur prochaine ouverture'),
                ));
              }
            },
            icon: const Icon(Icons.publish_outlined, size: 17),
            style: FilledButton.styleFrom(
              backgroundColor: kNavy,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            ),
            label: const Text('Publier une version'),
          ),
        ]),
        const SizedBox(height: 16),
        async.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: kNavy)),
          ),
          error: (e, _) => AdminErrorBanner(message: 'Chargement : $e'),
          data: (rows) => rows.isEmpty
              ? const AdminEmptyState(
                  icon: Icons.system_update_outlined,
                  title: 'Aucune version publiée',
                  message:
                      'Tant que rien n\'est publié, aucun poste ne peut se '
                      'mettre à jour. Publiez la version issue de la dernière '
                      'compilation.',
                )
              : _Liste(rows: rows),
        ),
      ]),
    );
  }
}

class _Avertissement extends StatelessWidget {
  const _Avertissement();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kAccent.withValues(alpha: 0.32)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.campaign_outlined, size: 20, color: kAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Une publication s\'adresse à tout le parc',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 5),
                  Text(
                    'Reprenez le numéro de build, l\'adresse et l\'empreinte '
                    'SHA-256 depuis le fichier manifest.json produit par la '
                    'compilation — jamais de valeur retapée. Le poste refuse '
                    'd\'installer un fichier dont l\'empreinte ne correspond '
                    'pas, et l\'école se retrouverait bloquée sans savoir '
                    'pourquoi.',
                    style: TextStyle(
                        fontSize: 12, color: kTextMuted, height: 1.45),
                  ),
                ]),
          ),
        ]),
      );
}

class _Liste extends ConsumerWidget {
  const _Liste({required this.rows});
  final List<ReleasePubliee> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La plus haute par plateforme/canal : c'est elle, et elle seule, que
    // `derniere_version()` renvoie aux postes.
    final courantes = <String, int>{};
    for (final r in rows) {
      final k = '${r.platform}/${r.channel}';
      courantes[k] = (courantes[k] ?? 0) > r.buildNumber
          ? courantes[k]!
          : r.buildNumber;
    }

    return Column(children: [
      for (final r in rows)
        _Carte(
          r: r,
          servie: courantes['${r.platform}/${r.channel}'] == r.buildNumber,
        ),
    ]);
  }
}

class _Carte extends ConsumerWidget {
  const _Carte({required this.r, required this.servie});
  final ReleasePubliee r;
  final bool servie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: servie ? kGreen.withValues(alpha: 0.45) : kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${r.version}  ·  build ${r.buildNumber}',
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const SizedBox(width: 10),
          AdminBadge(r.platform, color: kNavy),
          const SizedBox(width: 6),
          AdminBadge(r.channel,
              color: r.channel == 'stable' ? kGreen : kAccent),
          if (r.isMandatory) ...[
            const SizedBox(width: 6),
            AdminBadge('obligatoire', color: kRed),
          ],
          const Spacer(),
          if (servie)
            Row(children: [
              Icon(Icons.podcasts_rounded, size: 14, color: kGreen),
              const SizedBox(width: 5),
              Text('servie aux postes',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kGreen)),
            ]),
          IconButton(
            tooltip: 'Retirer',
            onPressed: () => _retirer(context, ref),
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: kRed),
          ),
        ]),
        const SizedBox(height: 8),
        _ligne(Icons.link_rounded, r.downloadUrl, copiable: true),
        _ligne(Icons.fingerprint_rounded, r.sha256, copiable: true, mono: true),
        _ligne(Icons.data_usage_rounded,
            '${r.taille}'
            '${r.minBuild != null ? '  ·  refuse en dessous du build ${r.minBuild}' : ''}'
            '${r.publishedAt != null ? '  ·  publiée le ${_jour(r.publishedAt!)}' : ''}'),
        if (r.notes != null && r.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(r.notes!,
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4)),
        ],
      ]),
    );
  }

  Widget _ligne(IconData i, String texte,
          {bool copiable = false, bool mono = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(i, size: 13, color: kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    color: kTextMuted,
                    fontFamily: mono ? 'monospace' : null)),
          ),
          if (copiable)
            IconButton(
              tooltip: 'Copier',
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: texte)),
              icon: Icon(Icons.copy_rounded, size: 13, color: kTextMuted),
            ),
        ]),
      );

  static String _jour(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _retirer(BuildContext context, WidgetRef ref) async {
    final ok = await showAdminConfirm(
      context,
      title: 'Retirer la version ${r.version} ?',
      // On ne promet pas ce qu'on ne peut pas tenir : les postes qui l'ont
      // déjà téléchargée l'ont déjà.
      message: 'Les postes qui ne l\'ont pas encore vue ne la verront plus. '
          'Ceux qui l\'ont déjà installée la gardent — retirer une ligne ne '
          'désinstalle rien. Pour corriger, publiez plutôt un build supérieur.',
      confirmLabel: 'Retirer',
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(releasesServiceProvider).retirer(r.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text('Erreur : $e')));
      }
    }
  }
}
