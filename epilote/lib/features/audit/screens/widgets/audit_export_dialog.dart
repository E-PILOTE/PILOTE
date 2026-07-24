import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/audit_data.dart';
import 'audit_export_parts.dart';

enum _ExportScope { currentPage, allFiltered }

/// Dialog d'export CSV du journal — périmètre courant ([AuditScope]) + choix des
/// colonnes. « Tous les résultats filtrés » recharge tout le périmètre filtré.
class AuditExportDialog extends ConsumerStatefulWidget {
  const AuditExportDialog({
    super.key,
    required this.filters,
    required this.scope,
    required this.currentPageEntries,
    required this.totalCount,
  });
  final AuditFilters filters;
  final AuditScope scope;
  final List<AuditEntry> currentPageEntries;
  final int totalCount;

  @override
  ConsumerState<AuditExportDialog> createState() => _AuditExportDialogState();
}

class _AuditExportDialogState extends ConsumerState<AuditExportDialog> {
  _ExportScope _scope = _ExportScope.allFiltered;
  bool _loading = false;
  bool _done = false;
  String? _filePath;
  int _exportedCount = 0;
  String? _errorMsg;

  late final Map<String, bool> _cols = {
    'Date': true,
    'Action': true,
    'Entité': true,
    'Table DB': false,
    'Auteur': true,
    'Rôle': true,
    // Colonne « École » utile seulement en périmètre groupe.
    if (widget.scope.showSchoolDimension) 'École': true,
    'ID Enregistrement': false,
    'Adresse IP': true,
    'User Agent': false,
  };

  Future<void> _doExport() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    List<AuditEntry> entries;
    if (_scope == _ExportScope.currentPage) {
      entries = widget.currentPageEntries;
    } else {
      try {
        final client = ref.read(supabaseClientProvider);
        entries = await fetchAllAuditForExport(
          client: client,
          scope: widget.scope,
          filters: widget.filters,
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMsg = 'Erreur de récupération : $e';
          });
        }
        return;
      }
    }

    final activeCols =
        _cols.entries.where((e) => e.value).map((e) => e.key).toList();

    final buf = StringBuffer();
    buf.writeln(activeCols.map((c) => '"$c"').join(','));

    for (final e in entries) {
      final row = activeCols.map((col) {
        return switch (col) {
          'Date' => _fmtDate(e.createdAt),
          'Action' => e.actionLabel,
          'Entité' => e.entityLabel,
          'Table DB' => e.tableName,
          'Auteur' => e.userName,
          'Rôle' => e.roleLbl,
          'École' => e.schoolName ?? '',
          'ID Enregistrement' => e.recordId ?? '',
          'Adresse IP' => e.ipAddress ?? '',
          'User Agent' => e.userAgent ?? '',
          _ => '',
        };
      }).map((v) => '"${v.replaceAll('"', '""')}"').join(',');
      buf.writeln(row);
    }

    try {
      final now = DateTime.now();
      final ts = '${now.year}${_p(now.month)}${_p(now.day)}_'
          '${_p(now.hour)}${_p(now.minute)}${_p(now.second)}';
      final path = '/tmp/audit_export_$ts.csv';
      await File(path).writeAsString(buf.toString());
      if (mounted) {
        setState(() {
          _loading = false;
          _done = true;
          _filePath = path;
          _exportedCount = entries.length;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = 'Erreur écriture fichier : $e';
        });
      }
    }
  }

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${_p(dt.day)}/${_p(dt.month)}/${dt.year} ${_p(dt.hour)}:${_p(dt.minute)}';
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: _done
            ? AuditExportSuccess(
                exportedCount: _exportedCount, filePath: _filePath)
            : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    final pageCount = widget.currentPageEntries.length;
    final allCount = widget.totalCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1A2F5A), kNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: kNavy.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: const Icon(Icons.upload_file_rounded,
                  color: Colors.white, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exporter le journal d\'audit',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 2),
                  Text('Format CSV · encodage UTF-8',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ],
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder),
                  ),
                  child: Icon(Icons.close_rounded, size: 16, color: kTextMuted),
                ),
              ),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Périmètre d\'export',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: kTextMuted,
                        letterSpacing: 0.3)),
                const SizedBox(height: 10),
                AuditExportScopeCard(
                  selected: _scope == _ExportScope.allFiltered,
                  icon: Icons.filter_alt_rounded,
                  title: 'Tous les résultats filtrés',
                  subtitle:
                      '$allCount événements correspondant aux filtres actifs',
                  badge:
                      allCount > 1000 ? 'Peut prendre quelques secondes' : null,
                  badgeColor: kAccent,
                  onTap: () =>
                      setState(() => _scope = _ExportScope.allFiltered),
                ),
                const SizedBox(height: 8),
                AuditExportScopeCard(
                  selected: _scope == _ExportScope.currentPage,
                  icon: Icons.list_alt_rounded,
                  title: 'Page courante uniquement',
                  subtitle: '$pageCount événements affichés à l\'écran',
                  onTap: () =>
                      setState(() => _scope = _ExportScope.currentPage),
                ),
                const SizedBox(height: 18),
                Text('Colonnes à inclure',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: kTextMuted,
                        letterSpacing: 0.3)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _cols.keys.map((col) {
                    final active = _cols[col]!;
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() => _cols[col] = !active),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: active
                                ? kNavy.withValues(alpha: 0.08)
                                : kSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: active ? kNavy : kBorder,
                              width: active ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                active
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 14,
                                color: active ? kNavy : kTextMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(col,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: active ? kNavy : kTextMuted)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  AdminErrorBanner(message: _errorMsg!),
                ],
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: kBorder)),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Annuler', style: TextStyle(color: kTextMuted)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _loading || _cols.values.every((v) => !v)
                      ? null
                      : _doExport,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                      _loading ? 'Génération en cours…' : 'Exporter en CSV'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
