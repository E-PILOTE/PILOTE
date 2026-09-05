part of '../admin_access_screen.dart';

// Suppression d’un profil et confirmation d’un profil vide.

class _DeleteProfileDialog extends ConsumerStatefulWidget {
  const _DeleteProfileDialog({required this.profile});
  final AccessProfile profile;

  @override
  ConsumerState<_DeleteProfileDialog> createState() => _DeleteProfileDialogState();
}

class _DeleteProfileDialogState extends ConsumerState<_DeleteProfileDialog> {
  late Future<int> _membersF;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    // On revérifie en direct le nombre de membres rattachés : le compteur
    // affiché dans la liste peut être obsolète (filtre is_active) et la FK
    // refuse la suppression d'un profil encore attribué.
    _membersF = ref.read(adminAccessServiceProvider).countMembers(widget.profile.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30, offset: const Offset(0, 8),
          )],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: kRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.delete_outline_rounded, color: kRed, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text('Supprimer le profil ?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextPrimary))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: FutureBuilder<int>(
              future: _membersF,
              builder: (context, snap) {
                final loading = snap.connectionState == ConnectionState.waiting;
                final attached = snap.data ?? 0;
                final blocked = attached > 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(text: TextSpan(
                      style: TextStyle(fontSize: 13.5, color: kTextMuted, height: 1.5),
                      children: [
                        const TextSpan(text: 'Le profil '),
                        TextSpan(text: '« ${p.name} »',
                            style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary)),
                        const TextSpan(text: ' et toutes ses permissions seront '
                            'définitivement supprimés. Cette action est irréversible.'),
                      ],
                    )),
                    const SizedBox(height: 14),
                    if (loading)
                      Row(children: [
                        SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: kNavy)),
                        const SizedBox(width: 10),
                        Text('Vérification des membres rattachés…',
                            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
                      ])
                    else if (snap.hasError)
                      AdminErrorBanner(message: _friendlyError(snap.error!))
                    else if (blocked)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kOrange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: _kOrange, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            '$attached membre${attached > 1 ? 's sont' : ' est'} encore '
                            'rattaché${attached > 1 ? 's' : ''} à ce profil. Réattribuez-'
                            '${attached > 1 ? 'les' : 'le'} depuis la page Utilisateurs '
                            'avant de pouvoir le supprimer.',
                            style: TextStyle(fontSize: 12, color: kTextPrimary, height: 1.4),
                          )),
                        ]),
                      ),
                  ],
                );
              },
            ),
          ),
          // Pied
          Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<int>(
              future: _membersF,
              builder: (context, snap) {
                final ready = snap.connectionState == ConnectionState.done && !snap.hasError;
                final blocked = (snap.data ?? 0) > 0;
                final canDelete = ready && !blocked && !_deleting;
                return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
                    child: Text('Annuler', style: TextStyle(color: kTextMuted)),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: canDelete
                        ? () {
                            setState(() => _deleting = true);
                            Navigator.of(context).pop(true);
                          }
                        : null,
                    icon: _deleting
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Supprimer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kRed,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: kRed.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Confirmation : profil sans aucune permission ─────────────────────────────
class _ConfirmEmptyPermsDialog extends StatelessWidget {
  const _ConfirmEmptyPermsDialog({required this.isEdit});
  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30, offset: const Offset(0, 8),
          )],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.lock_open_rounded, color: _kOrange, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text('Aucune permission accordée',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              "Ce profil n'autorisera l'accès à aucun module. Les membres qui en "
              'héritent ne pourront rien voir ni faire. Voulez-vous continuer '
              'malgré tout ?',
              style: TextStyle(fontSize: 13.5, color: kTextMuted, height: 1.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Revenir aux permissions',
                    style: TextStyle(color: kTextMuted)),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isEdit ? 'Enregistrer quand même' : 'Créer quand même'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Modal détails profil (style super_admin) ─────────────────────────────────
