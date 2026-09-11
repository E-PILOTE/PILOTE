part of '../administrators_screen.dart';

// Mise en page du formulaire administrateur.

extension _AdminFormLayout on _AdminFormModalState {
  /// Le corps de `build` : une méthode surchargée ne peut pas vivre dans
  /// une extension, la classe garde donc un `build` d’une ligne.
  Widget construireFormulaire(BuildContext context) {
    final data = ref.watch(administratorsProvider).valueOrNull;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(children: [
          // ── En-tête ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [const Color(0xFF1A2F5A), _kNavy]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(
                  _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                  color: Colors.white, size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _isEditing ? 'Modifier l\'administrateur' : 'Nouvel administrateur',
                  style: TextStyle(color: _kText, fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  _isEditing ? 'Mise à jour des informations' : 'Remplissez les champs requis',
                  style: TextStyle(color: _kMuted, fontSize: 11),
                ),
              ]),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8),
                mouseCursor: SystemMouseCursors.click,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Icon(Icons.close_rounded, size: 15, color: _kMuted),
                ),
              ),
            ]),
          ),

          // ── Formulaire ───────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Photo de profil ─────────────────────────────────────
                    Center(child: _AvatarUploadBox(
                      initials:     _initials,
                      color:        _roleColor(_role),
                      avatarUrl:    _uploadedAvatarUrl,
                      previewBytes: _avatarPreviewBytes,
                      uploading:    _uploadingAvatar,
                      onPick:       _pickAndUploadAvatar,
                      onRemove: () => rafraichir(() {
                        _uploadedAvatarUrl  = null;
                        _avatarPreviewBytes = null;
                      }),
                    )),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: _FormField(
                        controller: _firstNameCtrl,
                        label: 'Prénom *',
                        icon: Icons.person_rounded,
                        onChanged: (_) => rafraichir(() {}),
                        validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _FormField(
                        controller: _lastNameCtrl,
                        label: 'Nom de famille *',
                        icon: Icons.person_outline_rounded,
                        onChanged: (_) => rafraichir(() {}),
                        validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                      )),
                    ]),
                    const SizedBox(height: 14),
                    _FormField(
                      controller: _emailCtrl,
                      label: 'Adresse email *',
                      icon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      readOnly: _isEditing,
                      hint: _isEditing ? 'Email non modifiable' : 'exemple@domaine.cg',
                      validator: _isEditing ? null : (v) {
                        if (v!.trim().isEmpty) return 'Requis';
                        if (!v.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    if (!_isEditing) ...[
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePwd,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe *',
                          hintText: 'Min. 8 caractères',
                          prefixIcon: Icon(Icons.lock_rounded, size: 16, color: _kMuted),
                          suffixIcon: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              icon: Icon(_obscurePwd
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                                  size: 16, color: _kMuted),
                              onPressed: () => rafraichir(() => _obscurePwd = !_obscurePwd),
                            ),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _kNavy, width: 1.5),
                          ),
                          filled: true, fillColor: _kSurface,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        validator: (v) {
                          if (v!.isEmpty) return 'Requis';
                          if (v.length < 8) return 'Min. 8 caractères';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    const _SectionTitle('Rôle & Affectation'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kSurface,
                        border: Border.all(color: _kBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _role,
                          isExpanded: true,
                          icon: Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                          style: TextStyle(color: _kText, fontSize: 13),
                          items: [
                            DropdownMenuItem(
                              value: 'super_admin',
                              child: Row(children: [
                                Icon(Icons.shield_rounded, size: 14, color: _kNavy),
                                const SizedBox(width: 8),
                                const Text('Super Admin — accès total plateforme'),
                              ]),
                            ),
                            DropdownMenuItem(
                              value: 'admin_groupe',
                              child: Row(children: [
                                Icon(Icons.business_rounded, size: 14, color: _kGold),
                                const SizedBox(width: 8),
                                const Text('Admin Groupe — accès à un groupe scolaire'),
                              ]),
                            ),
                          ],
                          onChanged: (v) => rafraichir(() {
                            _role = v!;
                            if (v == 'super_admin') _groupId = null;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_role == 'admin_groupe') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kSurface,
                          border: Border.all(
                              color: _groupId == null
                                  ? _kRed.withValues(alpha: 0.5) : _kBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _groupId,
                            isExpanded: true,
                            hint: Text('Sélectionner un groupe *',
                                style: TextStyle(color: _kMuted, fontSize: 13)),
                            icon: Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                            style: TextStyle(color: _kText, fontSize: 13),
                            items: (data?.groups ?? []).map((g) =>
                              DropdownMenuItem(
                                value: g.id,
                                child: Text(g.name, overflow: TextOverflow.ellipsis),
                              ),
                            ).toList(),
                            onChanged: (v) => rafraichir(() => _groupId = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _FormField(
                      controller: _phoneCtrl,
                      label: 'Téléphone (optionnel)',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Footer ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            decoration: BoxDecoration(
              color: _kSurface,
              border: Border(top: BorderSide(color: _kBorder)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Annuler', style: TextStyle(
                        color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: _saving ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
                child: InkWell(
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _saving ? _kNavy.withValues(alpha: 0.5) : _kNavy,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _saving ? [] : [BoxShadow(
                        color: _kNavy.withValues(alpha: 0.30),
                        blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_saving)
                        const SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.save_rounded, color: Colors.white, size: 15),
                      const SizedBox(width: 8),
                      Text(
                        _saving ? 'Enregistrement…'
                            : (_isEditing ? 'Enregistrer' : 'Créer le compte'),
                        style: const TextStyle(color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
