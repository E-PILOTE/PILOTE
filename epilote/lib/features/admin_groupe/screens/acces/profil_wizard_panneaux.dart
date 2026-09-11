part of '../admin_access_screen.dart';

// Les quatre panneaux de l’assistant : en-tete, identite, permissions, pied.

extension _WizardPanneaux on _ProfileWizardDialogState {
  Widget _buildHeader() {
    Widget stepDot(int i, String label, IconData icon) {
      final active = _step == i;
      final done = _step > i;
      final color = active || done ? _kPurple : kTextMuted;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: active
                ? _kPurple
                : done
                    ? _kPurple.withValues(alpha: 0.12)
                    : kSurface,
            shape: BoxShape.circle,
            border: Border.all(color: active ? _kPurple : kBorder),
          ),
          child: Icon(done ? Icons.check_rounded : icon,
              size: 14, color: active ? Colors.white : color),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? kTextPrimary : kTextMuted)),
      ]);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 14, 16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _kPurple.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield_rounded, color: _kPurple, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isEdit ? 'Modifier le profil' : "Nouveau profil d'accès",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            stepDot(0, 'Identité', Icons.badge_outlined),
            Container(
                width: 22, height: 1.4, color: kBorder,
                margin: const EdgeInsets.symmetric(horizontal: 8)),
            stepDot(1, 'Permissions', Icons.tune_rounded),
          ]),
        ])),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close_rounded, size: 20, color: kTextMuted),
          tooltip: 'Fermer',
        ),
      ]),
    );
  }

  // ── Étape 1 : Identité ─────────────────────────────────────────────────────
  Widget _buildIdentity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      child: Form(
        key: _formKey,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 14, color: _kPurple),
                const SizedBox(width: 6),
                Text('Modèles de profil',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kPurple.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('pré-remplit nom, type et droits',
                      style: TextStyle(
                          fontSize: 10, color: _kPurple, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in _kPresets)
                  _PresetChip(
                    preset: p,
                    selected: _selectedPreset == p.roleType,
                    onTap: () => _applyPreset(p),
                  ),
              ]),
              const SizedBox(height: 18),
              Divider(color: kBorder, height: 1),
              const SizedBox(height: 18),
              Text('Nom du profil *',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                decoration: adminInputDecoration(
                    'Ex : Proviseur, Comptable, Enseignant…',
                    icon: Icons.label_outline),
              ),
              const SizedBox(height: 14),
              Text('Type de profil',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _roleType,
                isExpanded: true,
                decoration: adminInputDecoration('Choisir un type…',
                    icon: Icons.workspace_premium_outlined),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— Non spécifié —')),
                  for (final p in _kPresets)
                    DropdownMenuItem(
                        value: p.roleType,
                        child: Row(children: [
                          Icon(p.icon, size: 16, color: p.color),
                          const SizedBox(width: 8),
                          Text(p.label),
                        ])),
                ],
                onChanged: (v) => rafraichir(() => _roleType = v),
              ),
              const SizedBox(height: 14),
              Text('Description',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _desc,
                maxLines: 3,
                decoration: adminInputDecoration(
                    'Décrivez les responsabilités et le périmètre de ce profil…',
                    icon: Icons.notes_rounded),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kNavy.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: kNavy.withValues(alpha: 0.7)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                    'À l\'étape suivante, choisissez précisément les modules accessibles '
                    'et les actions autorisées (voir, créer, modifier, supprimer, exporter…).',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.5),
                  )),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                AdminErrorBanner(message: _error!),
              ],
              const SizedBox(height: 6),
            ]),
      ),
    );
  }

  // ── Étape 2 : Permissions ──────────────────────────────────────────────────
  Widget _buildPermissions() {
    final q = _search.text.trim().toLowerCase();
    List<ModuleInfo> visibleMods(ModuleCategory c) => q.isEmpty
        ? c.modules
        : c.modules
            .where((m) => m.name.toLowerCase().contains(q))
            .toList();

    final cats = widget.categories
        .where((c) => visibleMods(c).isNotEmpty)
        .toList();

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Barre outils : recherche + résumé
      Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _search,
                onChanged: (_) => rafraichir(() {}),
                decoration: InputDecoration(
                  hintText: 'Rechercher un module…',
                  hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: kTextMuted, size: 19),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 17, color: kTextMuted),
                          onPressed: () => rafraichir(() => _search.clear()))
                      : null,
                  filled: true,
                  fillColor: kCardBg,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: kBorder),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AdminBadge('$_grantedCount module${_grantedCount > 1 ? 's' : ''}',
              color: _kPurple, icon: Icons.widgets_rounded),
          const SizedBox(width: 8),
          AdminBadge('$_sensitiveCount sensible${_sensitiveCount > 1 ? 's' : ''}',
              color: _sensitiveCount > 0 ? _kOrange : kTextMuted,
              icon: Icons.warning_amber_rounded),
        ]),
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _MatrixLegend(),
            const SizedBox(height: 12),
            if (cats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: Text('Aucun module ne correspond à la recherche.',
                        style: TextStyle(color: kTextMuted))),
              )
            else
              for (final cat in cats)
                _MatrixCategory(
                  category: cat,
                  modules: visibleMods(cat),
                  collapsed: _collapsed.contains(cat.id),
                  rowFor: _rowFor,
                  onUpdate: _update,
                  onToggleCollapse: () => rafraichir(() {
                    if (!_collapsed.add(cat.id)) _collapsed.remove(cat.id);
                  }),
                  onGrantAll: () => _bulkCategory(cat, grant: true),
                  onClearAll: () => _bulkCategory(cat, grant: false),
                ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              AdminErrorBanner(message: _error!),
            ],
          ]),
        ),
      ),
    ]);
  }

  // ── Pied de page ────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        if (_step == 1)
          OutlinedButton.icon(
            onPressed: _saving ? null : () => rafraichir(() => _step = 0),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Identité'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kTextMuted,
              side: BorderSide(color: kBorder),
            ),
          )
        else
          OutlinedButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: kTextMuted,
              side: BorderSide(color: kBorder),
            ),
            child: const Text('Annuler'),
          ),
        const Spacer(),
        if (_step == 0)
          ElevatedButton.icon(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                rafraichir(() => _step = 1);
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Suivant : Permissions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(_isEdit ? Icons.save_rounded : Icons.check_rounded, size: 16),
            label: Text(_isEdit ? 'Enregistrer' : 'Créer le profil'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
          ),
      ]),
    );
  }
}
