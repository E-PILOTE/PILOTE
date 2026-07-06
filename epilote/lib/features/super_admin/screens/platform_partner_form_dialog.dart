import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/platform_partners_provider.dart';

final _fmt = DateFormat('dd/MM/yyyy', 'fr_FR');

/// Formulaire de création / modification d'un partenaire (Phase 3b) : logo
/// (upload Storage), nom, catégorie fermée, site, ordre, fenêtre de dates, actif.
class PartnerFormDialog extends ConsumerStatefulWidget {
  const PartnerFormDialog({super.key, this.existing});
  final PartnerModel? existing;

  @override
  ConsumerState<PartnerFormDialog> createState() => _PartnerFormDialogState();
}

class _PartnerFormDialogState extends ConsumerState<PartnerFormDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _site =
      TextEditingController(text: widget.existing?.websiteUrl ?? '');
  late final TextEditingController _order = TextEditingController(
      text: (widget.existing?.sortOrder ?? 0).toString());
  late String _category = widget.existing?.category ?? 'institutionnel';
  late bool _active = widget.existing?.isActive ?? true;
  late DateTime? _starts = widget.existing?.startsAt;
  late DateTime? _ends = widget.existing?.endsAt;
  late String? _logoUrl = widget.existing?.logoUrl;
  bool _uploading = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _site.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref
          .read(partnersAdminServiceProvider)
          .uploadLogo(f.bytes!, f.extension ?? 'png');
      if (mounted) setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur upload : $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (start ? _starts : _ends) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => start ? _starts = d : _ends = d);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Le nom est obligatoire.');
      return;
    }
    if (_starts != null && _ends != null && _ends!.isBefore(_starts!)) {
      setState(() => _error = 'La date de fin précède la date de début.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final svc = ref.read(partnersAdminServiceProvider);
      final order = int.tryParse(_order.text.trim()) ?? 0;
      if (widget.existing == null) {
        await svc.create(
          name: name,
          logoUrl: _logoUrl,
          websiteUrl: _site.text,
          category: _category,
          isActive: _active,
          sortOrder: order,
          startsAt: _starts,
          endsAt: _ends,
          createdBy: ref.read(currentUserProvider)?.id,
        );
      } else {
        await svc.update(
          id: widget.existing!.id,
          name: name,
          logoUrl: _logoUrl,
          websiteUrl: _site.text,
          category: _category,
          isActive: _active,
          sortOrder: order,
          startsAt: _starts,
          endsAt: _ends,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Erreur : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = _logoUrl != null && _logoUrl!.isNotEmpty;
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Nouveau partenaire'
          : 'Modifier le partenaire'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 60,
                  height: 60,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10)),
                  child: _uploading
                      ? const Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : has
                          ? CachedNetworkImage(
                              imageUrl: _logoUrl!, fit: BoxFit.contain)
                          : const Icon(Icons.image_outlined,
                              color: kTextMuted),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickLogo,
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: const Text('Logo'),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Nom du partenaire',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                    labelText: 'Catégorie', border: OutlineInputBorder()),
                items: [
                  for (final e in kPartnerCategories.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _site,
                decoration: const InputDecoration(
                    labelText: 'Site web (informatif)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Ordre d’affichage',
                    border: OutlineInputBorder()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Actif'),
                value: _active,
                activeThumbColor: kGreen,
                onChanged: (v) => setState(() => _active = v),
              ),
              Row(children: [
                Expanded(
                    child: _DateField(
                        label: 'Début',
                        date: _starts,
                        onTap: () => _pickDate(true),
                        onClear: () => setState(() => _starts = null))),
                const SizedBox(width: 12),
                Expanded(
                    child: _DateField(
                        label: 'Fin',
                        date: _ends,
                        onTap: () => _pickDate(false),
                        onClear: () => setState(() => _ends = null))),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: kRed, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kNavy),
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label,
      required this.date,
      required this.onTap,
      required this.onClear});
  final String label;
  final DateTime? date;
  final VoidCallback onTap, onClear;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: date == null
                ? const Icon(Icons.calendar_today_rounded, size: 16)
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: onClear),
          ),
          child: Text(date != null ? _fmt.format(date!) : 'Optionnel',
              style: TextStyle(
                  color: date != null ? kTextPrimary : kTextMuted,
                  fontSize: 13.5)),
        ),
      );
}
