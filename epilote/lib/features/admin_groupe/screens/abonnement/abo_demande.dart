part of '../admin_subscription_screen.dart';

// Demande de changement de formule.

class _DialogChip extends StatelessWidget {
  const _DialogChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: kTextMuted),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextPrimary)),
      ]),
    );
  }
}

// ─── Modal demande de changement ──────────────────────────────────────────────
class RequestPlanChangeDialog extends ConsumerStatefulWidget {
  const RequestPlanChangeDialog({super.key, required this.plan});
  final PlanOption plan;

  @override
  ConsumerState<RequestPlanChangeDialog> createState() => _RequestPlanChangeDialogState();
}

class _RequestPlanChangeDialogState extends ConsumerState<RequestPlanChangeDialog> {
  late final TextEditingController _msg;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Plan visé pré-rempli : un motif d'ouverture éditable par l'utilisateur.
    _msg = TextEditingController(
      text: 'Nous souhaitons faire évoluer notre abonnement vers le plan '
          '${widget.plan.name}.',
    );
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSubscriptionServiceProvider).requestPlanChange(
            targetPlanName: widget.plan.name,
            message: _msg.text.trim().isEmpty
                ? 'Demande de passage au plan ${widget.plan.name}.'
                : _msg.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text('Demande envoyée pour le plan ${widget.plan.name}.'),
        ));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: 'Demander le plan ${widget.plan.name}',
              icon: Icons.swap_horiz_rounded,
              subtitle: 'Votre demande sera transmise à la plateforme',
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: planColor(widget.plan.slug).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: planColor(widget.plan.slug).withValues(alpha: 0.25)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.workspace_premium_rounded, color: planColor(widget.plan.slug), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Plan ${widget.plan.name}', style: TextStyle(fontWeight: FontWeight.w800, color: kTextPrimary)),
                            Text(widget.plan.priceXaf == 0
                                ? 'Gratuit'
                                : '${fmtXaf(widget.plan.priceXaf)} / ${widget.plan.periodSuffix}',
                                style: TextStyle(fontSize: 12, color: kTextMuted)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        _DialogChip(Icons.school_rounded, widget.plan.unlimitedSchools ? 'Écoles illimitées' : '${widget.plan.maxSchools} écoles'),
                        _DialogChip(Icons.groups_rounded, widget.plan.unlimitedStudents ? 'Élèves illimités' : '${fmtInt(widget.plan.maxStudents)} élèves'),
                        _DialogChip(Icons.badge_rounded, widget.plan.unlimitedStaff ? 'Personnel illimité' : '${fmtInt(widget.plan.maxStaff)} personnels'),
                        _DialogChip(Icons.extension_rounded, '${widget.plan.moduleCount} modules'),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _msg,
                    maxLines: 4,
                    decoration: adminInputDecoration('Motif de la demande',
                        hint: 'Précisez le motif de votre demande…'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AdminErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
            AdminDialogFooter(
              saving: _saving,
              submitLabel: 'Envoyer la demande',
              submitIcon: Icons.send_rounded,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
