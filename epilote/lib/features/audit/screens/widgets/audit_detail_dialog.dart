import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../providers/audit_data.dart';
import 'audit_row.dart' show auditActionStyle;

/// Modal détaillé d'une entrée : métadonnées + diff avant/après.
class AuditDetailDialog extends StatelessWidget {
  const AuditDetailDialog({super.key, required this.entry, this.onFilterSchool});
  final AuditEntry entry;
  final VoidCallback? onFilterSchool;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final (color, _) = auditActionStyle(e.action);
    final diff = e.buildDiff();
    final isInsert = e.action.toUpperCase() == 'INSERT';
    final isDelete = e.action.toUpperCase() == 'DELETE';
    final severity = e.severity;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 740),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: '${e.actionLabel} · ${e.entityLabel}',
              subtitle: _fullDate(e.createdAt),
              icon: Icons.history_rounded,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SeverityBadge(severity: severity),
                        const SizedBox(width: 8),
                        AdminBadge(e.actionLabel, color: color),
                        if (e.recordId != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: e.recordId!));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content:
                                    Text('ID copié dans le presse-papier'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: kSurface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: kBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy_rounded,
                                      size: 12, color: kTextMuted),
                                  const SizedBox(width: 5),
                                  Text(
                                    _truncateId(e.recordId!),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: kTextMuted,
                                        fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    AdminDetailCard([
                      AdminDetailRow(Icons.person_outline_rounded, 'Auteur',
                          '${e.userName} (${e.roleLbl})'),
                      AdminDetailRow(Icons.table_rows_rounded, 'Entité',
                          '${e.entityLabel} · ${e.tableName}'),
                      if (e.schoolName != null)
                        AdminDetailRow(
                            Icons.school_outlined, 'École', e.schoolName!),
                      AdminDetailRow(Icons.schedule_rounded, 'Horodatage',
                          _fullDate(e.createdAt)),
                      if (e.ipAddress != null && e.ipAddress!.isNotEmpty)
                        AdminDetailRow(
                            Icons.lan_outlined, 'Adresse IP', e.ipAddress!,
                            mono: true),
                      if (e.userAgent != null && e.userAgent!.isNotEmpty)
                        AdminDetailRow(Icons.devices_rounded, 'Appareil',
                            _simplifyUserAgent(e.userAgent!),
                            last: e.recordId == null),
                      if (e.recordId != null)
                        AdminDetailRow(
                            Icons.tag_rounded, 'ID enregistrement', e.recordId!,
                            mono: true, last: true),
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      const AdminModalSectionTitle('Détail des changements'),
                      const SizedBox(width: 8),
                      if (isInsert)
                        AdminBadge('Création',
                            color: kGreen, icon: Icons.add_rounded)
                      else if (isDelete)
                        AdminBadge('Suppression',
                            color: kRed, icon: Icons.delete_outline_rounded)
                      else
                        AdminBadge(
                          '${diff.where((d) => d.kind == AuditDiffKind.changed).length} champ(s)',
                          color: kAccent,
                          icon: Icons.edit_rounded,
                        ),
                    ]),
                    const SizedBox(height: 10),
                    if (diff.isEmpty)
                      _noDataBox()
                    else
                      _DiffTable(
                          diff: diff,
                          showBefore: !isInsert,
                          showAfter: !isDelete),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: kBorder))),
              child: Row(
                children: [
                  if (onFilterSchool != null)
                    OutlinedButton.icon(
                      onPressed: onFilterSchool,
                      icon: const Icon(Icons.filter_alt_rounded, size: 15),
                      label: const Text('Filtrer cette école'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kNavy,
                        side: BorderSide(color: kBorder),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: kNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _noDataBox() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Text(
          'Aucune donnée détaillée enregistrée pour cet événement.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted),
        ),
      );

  static String _fullDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        'à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _truncateId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  static String _simplifyUserAgent(String ua) {
    if (ua.contains('Flutter')) return 'App Flutter (Mobile/Desktop)';
    if (ua.contains('Chrome')) return 'Navigateur Chrome';
    if (ua.contains('Firefox')) return 'Navigateur Firefox';
    if (ua.contains('Safari') && !ua.contains('Chrome')) return 'Safari';
    if (ua.length > 60) return '${ua.substring(0, 60)}…';
    return ua;
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});
  final AuditSeverity severity;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (severity) {
      AuditSeverity.high => (kRed, 'RISQUE ÉLEVÉ'),
      AuditSeverity.medium => (kAccent, 'RISQUE MOYEN'),
      AuditSeverity.low => (kGreen, 'RISQUE FAIBLE'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5)),
    );
  }
}

class _DiffTable extends StatelessWidget {
  const _DiffTable(
      {required this.diff, required this.showBefore, required this.showAfter});
  final List<AuditFieldDiff> diff;
  final bool showBefore;
  final bool showAfter;

  @override
  Widget build(BuildContext context) {
    final sorted = [...diff]..sort((a, b) {
        int rank(AuditDiffKind k) => switch (k) {
              AuditDiffKind.changed => 0,
              AuditDiffKind.added => 1,
              AuditDiffKind.removed => 1,
              AuditDiffKind.unchanged => 2,
            };
        final r = rank(a.kind).compareTo(rank(b.kind));
        return r != 0 ? r : a.field.compareTo(b.field);
      });

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            _DiffRow(d: sorted[i], showBefore: showBefore, showAfter: showAfter),
            if (i != sorted.length - 1) Divider(height: 1, color: kBorder),
          ],
        ],
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow(
      {required this.d, required this.showBefore, required this.showAfter});
  final AuditFieldDiff d;
  final bool showBefore;
  final bool showAfter;

  @override
  Widget build(BuildContext context) {
    final highlight = d.kind == AuditDiffKind.changed;
    final rowBg = highlight ? kAccent.withValues(alpha: 0.06) : null;

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (highlight)
              Container(
                margin: const EdgeInsets.only(right: 6),
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: kAccent, shape: BoxShape.circle),
              ),
            Expanded(
              child: Text(
                _fieldLabel(d.field),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary),
              ),
            ),
          ]),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBefore) ...[
                Expanded(
                  child: _ValueChip(
                    label: 'Avant',
                    value: d.hasOld ? _fmt(d.before) : null,
                    kind: highlight || d.kind == AuditDiffKind.removed
                        ? _ChipKind.before
                        : _ChipKind.neutral,
                  ),
                ),
                if (showAfter)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 14, color: kTextMuted),
                  ),
              ],
              if (showAfter)
                Expanded(
                  child: _ValueChip(
                    label: showBefore ? 'Après' : 'Valeur',
                    value: d.hasNew ? _fmt(d.after) : null,
                    kind: highlight || d.kind == AuditDiffKind.added
                        ? _ChipKind.after
                        : _ChipKind.neutral,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fieldLabel(String f) => f
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  static String _fmt(dynamic v) {
    if (v == null) return '∅';
    if (v is bool) return v ? 'Oui' : 'Non';
    if (v is Map || v is List) return v.toString();
    final s = v.toString();
    return s.isEmpty ? '∅' : s;
  }
}

enum _ChipKind { before, after, neutral }

class _ValueChip extends StatelessWidget {
  const _ValueChip(
      {required this.label, required this.value, required this.kind});
  final String label;
  final String? value;
  final _ChipKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, border, txt) = switch (kind) {
      _ChipKind.before => (
          kRed.withValues(alpha: 0.06),
          kRed.withValues(alpha: 0.25),
          kRed
        ),
      _ChipKind.after => (
          kGreen.withValues(alpha: 0.07),
          kGreen.withValues(alpha: 0.28),
          kGreen
        ),
      _ChipKind.neutral => (kSurface, kBorder, kTextPrimary),
    };
    final isMissing = value == null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isMissing ? kSurface : bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isMissing ? kBorder : border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: kTextMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(
            value ?? '—',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isMissing ? kTextMuted : txt,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
