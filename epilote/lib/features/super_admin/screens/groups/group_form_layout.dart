part of '../school_groups_screen.dart';

// Mise en page du formulaire de groupe.

extension _GroupFormLayout on _GroupFormModalState {
  /// Le corps de `build` : une méthode surchargée ne peut pas vivre dans
  /// une extension, la classe garde donc un `build` d’une ligne.
  Widget construireFormulaire(BuildContext context) {
    final isEdit = widget.existing != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 36),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 40, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                  isEdit ? Icons.edit_note_rounded : Icons.domain_add_rounded,
                  color: Colors.white, size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isEdit ? 'Modifier le groupe' : 'Nouveau groupe scolaire',
                  style: TextStyle(color: _kText, fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  isEdit ? 'Mise à jour des informations'
                      : 'Remplissez les champs requis',
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

          // ── Body — colonne unique scrollable ───────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─ IDENTITÉ ─────────────────────────────────────────
                    const _FormLabel('IDENTITÉ DU GROUPE'),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // ── Logo upload ──────────────────────────────────
                      _LogoUploadBox(
                        name: _name.text.isNotEmpty ? _name.text : 'G',
                        logoUrl: _uploadedLogoUrl,
                        previewBytes: _logoPreviewBytes,
                        uploading: _uploadingLogo,
                        onPick: _pickAndUploadLogo,
                        onRemove: () => rafraichir(() {
                          _uploadedLogoUrl = null;
                          _logoPreviewBytes = null;
                        }),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _name,
                            onChanged: (_) => rafraichir(() {}),
                            decoration: _inputDeco('Nom complet du groupe *'),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            validator: (v) =>
                                v?.trim().isEmpty == true ? 'Champ requis' : null,
                          ),
                          const SizedBox(height: 8),
                          // Année de création
                          TextFormField(
                            controller: _foundedYearCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: _inputDeco('Année de création (ex : 1998)').copyWith(
                              prefixIcon: Icon(Icons.calendar_today_rounded,
                                  size: 15, color: _kMuted),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final y = int.tryParse(v);
                              if (y == null || y < 1800 || y > DateTime.now().year) {
                                return 'Année invalide';
                              }
                              return null;
                            },
                          ),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: DropdownButtonFormField<String>(
                        initialValue: _groupType,
                        decoration: _inputDeco('Secteur *'),
                        items: kSecteursGroupe.map((code) => DropdownMenuItem(
                            value: code,
                            child: Row(children: [
                              Icon(_typeIcon(code), size: 15, color: _kNavy),
                              const SizedBox(width: 8),
                              Text(libelleSecteur(code)),
                            ]))).toList(),
                        onChanged: (v) => rafraichir(() => _groupType = v!),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: DropdownButtonFormField<String?>(
                        initialValue: _department,
                        decoration: _inputDeco('Département'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('— Aucun —')),
                          ..._GroupFormModalState._depts.map((d) =>
                              DropdownMenuItem(value: d, child: Text(d))),
                        ],
                        onChanged: (v) => rafraichir(() => _department = v),
                      )),
                    ]),

                    // ── CARACTÈRE ──────────────────────────────────────
                    // ⚠️ Un champ à part, et pas une valeur de plus dans le
                    // secteur : une école catholique EST une école privée.
                    // Les deux informations sont vraies en même temps, et
                    // c'est faute d'avoir ce champ que « Catholique » s'était
                    // posé dans celui du secteur — où la base le refusait.
                    // Proposé sur un groupe PRIVÉ seulement : un établissement
                    // public n'a pas de caractère propre.
                    if (caractereSeSaisit(_groupType)) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        initialValue:
                            caractereConnu(_caractere) ? _caractere : null,
                        decoration: _inputDeco('Caractère du groupe'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('— Non renseigné —')),
                          ...kCaracteresGroupe.map((code) => DropdownMenuItem(
                                value: code,
                                child: Text(libelleCaractere(code) ?? code),
                              )),
                        ],
                        onChanged: (v) => rafraichir(() => _caractere = v),
                      ),
                    ],

                    const _FormDivider(),

                    // ─ TUTELLE ────────────────────────────────────────
                    const _FormLabel('MINISTÈRE DE TUTELLE'),
                    _TutelleSelector(
                      value: _tutelle,
                      onChanged: (v) => rafraichir(() => _tutelle = v),
                      ecolesConcernees: widget.existing?.schoolCount ?? 0,
                      valeurInitiale: widget.existing?.tutelle,
                    ),

                    const SizedBox(height: 12),
                    _RoleDeTutelle(
                      actif: _estTutelle,
                      tutelle: _tutelle,
                      detenteur: detenteurDuRoleDeTutelle(
                        widget.groupes, _tutelle,
                        saufId: widget.existing?.id,
                      ),
                      valeurInitiale:
                          widget.existing?.administreReferentielNational ??
                              false,
                      onChanged: (v) => rafraichir(() {
                        _estTutelle = v;
                        _alignerLePlan();
                      }),
                    ),

                    _AgrementFields(
                      numero: _agrementNum,
                      type: _agrementType,
                      date: _agrementDate,
                      onType: (v) => rafraichir(() => _agrementType = v),
                      onDate: (v) => rafraichir(() => _agrementDate = v),
                    ),

                    const _FormDivider(),

                    // ─ CONTACT ─────────────────────────────────────────
                    const _FormLabel('CONTACT'),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDeco('Email administrateur *'),
                        validator: (v) {
                          if (v?.trim().isEmpty == true) return 'Champ requis';
                          if (!v!.contains('@')) return 'Email invalide';
                          return null;
                        },
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        controller: _phone,
                        decoration: _inputDeco('Téléphone'),
                        keyboardType: TextInputType.phone,
                      )),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      decoration: _inputDeco('Adresse complète'),
                      maxLines: 2,
                    ),

                    const _FormDivider(),

                    // ─ ABONNEMENT ─────────────────────────────────────
                    const _FormLabel("PLAN D'ABONNEMENT"),
                    DropdownButtonFormField<String>(
                      initialValue: _planId,
                      decoration: _inputDeco('Plan *'),
                      items: _plansOfferts.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Row(children: [
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _planDotColor(p.name),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(p.name, style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(
                            p.priceXaf == 0
                                ? 'Gratuit'
                                : '${_fmtXaf(p.priceXaf.toDouble())}/${p.periodSuffix}',
                            style: TextStyle(
                                color: _kMuted, fontSize: 12),
                          ),
                        ]),
                      )).toList(),
                      onChanged: (v) => rafraichir(() => _planId = v),
                      validator: (v) =>
                          v == null ? 'Sélectionner un plan' : null,
                    ),
                    PlanChangeNotice(
                      existing: widget.existing,
                      plans: _plansOfferts,
                      selectedPlanId: _planId,
                    ),

                    const _FormDivider(),

                    // ─ NOTES ──────────────────────────────────────────
                    const _FormLabel('NOTES INTERNES'),
                    TextFormField(
                      controller: _notes,
                      decoration: _inputDeco(
                          'Remarques, contexte, historique…'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Footer — sorti dans son propre widget : le `build` du modal
          // dépassait 300 lignes, et le pied de page n'a besoin que de trois
          // choses pour se dessiner.
          _GroupFormFooter(isEdit: isEdit, saving: _saving, onSave: _save),
        ]),
      ),
    );
  }
}
