part of '../admin_users_screen.dart';

// Mise en page du formulaire utilisateur.

extension _UserFormLayout on _UserFormDialogState {
  /// Le corps de `build`, sorti de la classe : une méthode surchargée ne
  /// peut pas vivre dans une extension, la classe garde donc un `build`
  /// d’une ligne qui appelle celle-ci.
  Widget construireFormulaire(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Container(
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8),
            )],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── En-tête blanc avec boîte icône navy ──────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: kBorder)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF1A2F5A), kNavy],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(
                        color: kNavy.withValues(alpha: 0.30),
                        blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? "Modifier l'utilisateur" : 'Nouvel utilisateur',
                        style: TextStyle(
                          color: kTextPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isEdit ? widget.user!.email : 'Compte du personnel scolaire',
                        style: TextStyle(color: kTextMuted, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder),
                        ),
                        child: Icon(Icons.close_rounded, size: 15, color: kTextMuted),
                      ),
                    ),
                  ),
                ]),
              ),
              // ── Corps scrollable ────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // ── Identité civile ──────────────────────────────────
                      _sectionTitle('IDENTITÉ CIVILE'),
                      ChampPhotoAgent(
                        nom: '${_first.text} ${_last.text}'.trim(),
                        octets: _photoOctets,
                        urlExistante: widget.user?.avatarUrl,
                        retiree: _photoRetiree,
                        actif: !_saving,
                        onChoisir: _choisirPhoto,
                        onRetirer: _retirerPhoto,
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(child: _field(_first, 'Prénom *', Icons.person_outline,
                            validator: _req)),
                        const SizedBox(width: 12),
                        Expanded(child: _field(_last, 'Nom *', Icons.person_outline,
                            validator: _req)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _genderDropdown()),
                        const SizedBox(width: 12),
                        Expanded(child: _dobField()),
                      ]),
                      const SizedBox(height: 12),
                      _field(_birthPlace, 'Lieu de naissance', Icons.location_city_outlined),

                      // ── Coordonnées ──────────────────────────────────────
                      _sectionTitle('COORDONNÉES'),
                      _field(_phone, 'Téléphone', Icons.phone_outlined,
                          keyboard: TextInputType.phone),
                      const SizedBox(height: 12),
                      _field(_address, 'Adresse', Icons.home_outlined,
                          maxLines: 2, keyboard: TextInputType.multiline),

                      // ── Affectation scolaire ─────────────────────────────
                      _sectionTitle('AFFECTATION SCOLAIRE'),
                      _schoolDropdown(),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _roleDropdown()),
                        const SizedBox(width: 12),
                        Expanded(child: _field(_matricule, 'Matricule', Icons.tag_rounded)),
                      ]),
                      const SizedBox(height: 12),
                      _accessProfileDropdown(),

                      // ── Carrière RH (édition : volet migration 0023) ─────
                      if (_isEdit) ...[
                        _sectionTitle('CARRIÈRE'),
                        Row(children: [
                          Expanded(child: _employmentStatusDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _hireDateField()),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _field(_grade, 'Grade', Icons.workspace_premium_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_echelon, 'Échelon', Icons.stairs_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_category, 'Catégorie', Icons.label_outline)),
                        ]),
                        const SizedBox(height: 12),
                        _field(_speciality, 'Spécialité / discipline', Icons.menu_book_outlined),
                      ],

                      // ── Accès au compte (création uniquement) ────────────
                      if (!_isEdit) ...[
                        _sectionTitle('ACCÈS AU COMPTE'),
                        _field(_email, 'Email *', Icons.email_outlined,
                            keyboard: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email requis';
                              return v.contains('@') ? null : 'Email invalide';
                            }),
                        const SizedBox(height: 12),
                        _passwordField(),
                      ],

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        AdminErrorBanner(message: _error!),
                      ],
                    ]),
                  ),
                ),
              ),
              // ── Pied de page ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: kBorder)),
                ),
                child: Row(children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: kBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Annuler', style: TextStyle(
                          color: kTextMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const Spacer(),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      onTap: _saving ? null : _submit,
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _saving
                              ? kNavy.withValues(alpha: 0.70)
                              : kNavy,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(
                            color: kNavy.withValues(alpha: 0.30),
                            blurRadius: 8, offset: const Offset(0, 3),
                          )],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_saving)
                            const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          else
                            Icon(
                              _isEdit ? Icons.save_rounded : Icons.person_add_rounded,
                              size: 15, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _saving
                                ? 'Enregistrement…'
                                : (_isEdit ? 'Enregistrer' : 'Créer le compte'),
                            style: const TextStyle(
                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
