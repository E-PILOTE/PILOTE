part of '../admin_users_screen.dart';

// Les champs du formulaire : décorations, saisies, listes déroulantes.

extension _UserFormFields on _UserFormDialogState {
  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Text(title, style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: kTextMuted, letterSpacing: 0.5,
    )),
  );

  InputDecoration _inputDec(String label, IconData icon, {bool readOnly = false}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16, color: kTextMuted),
        filled: true,
        fillColor: readOnly ? kSurface.withValues(alpha: 0.5) : kSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: readOnly
              ? BorderSide(color: kBorder)
              : BorderSide(color: kNavy, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(12),
      );

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int maxLines = 1,
    Widget? suffix,
    VoidCallback? onTap,
    bool readOnly = false,
  }) =>
      TextFormField(
        controller: c,
        validator: validator,
        keyboardType: keyboard,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(fontSize: 13, color: readOnly ? kTextMuted : kTextPrimary),
        decoration: _inputDec(label, icon, readOnly: readOnly).copyWith(suffixIcon: suffix),
      );

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Requis' : null;

  Widget _passwordField() => TextFormField(
    controller: _password,
    obscureText: _obscure,
    style: TextStyle(fontSize: 13, color: kTextPrimary),
    validator: (v) {
      if (v == null || v.isEmpty) return 'Mot de passe requis';
      if (v.length < 6) return 'Au moins 6 caractères';
      return null;
    },
    decoration: _inputDec('Mot de passe *', Icons.lock_outline).copyWith(
      suffixIcon: IconButton(
        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20, color: kTextMuted),
        onPressed: () => rafraichir(() => _obscure = !_obscure),
      ),
    ),
  );

  Widget _genderDropdown() => DropdownButtonFormField<String?>(
    initialValue: _gender,
    isExpanded: true,
    decoration: _inputDec('Genre', Icons.wc_rounded),
    items: const [
      DropdownMenuItem(value: null,    child: Text('— Non renseigné')),
      DropdownMenuItem(value: 'M',     child: Text('Masculin')),
      DropdownMenuItem(value: 'F',     child: Text('Féminin')),
      DropdownMenuItem(value: 'autre', child: Text('Autre')),
    ],
    onChanged: (v) => rafraichir(() => _gender = v),
  );

  Widget _dobField() => _field(
    _dob, 'Date de naissance (JJ/MM/AAAA)', Icons.cake_outlined,
    keyboard: TextInputType.datetime,
    suffix: IconButton(
      icon: Icon(Icons.calendar_today_rounded, size: 18, color: kTextMuted),
      onPressed: _pickDate,
    ),
    validator: (v) {
      if (v == null || v.trim().isEmpty) return null;
      if (_parseDob(v) == null) return 'Format JJ/MM/AAAA';
      return null;
    },
  );

  Widget _employmentStatusDropdown() => DropdownButtonFormField<String?>(
    initialValue: _employmentStatus,
    isExpanded: true,
    decoration: _inputDec('Statut', Icons.badge_outlined),
    items: [
      const DropdownMenuItem(value: null, child: Text('— Non renseigné')),
      for (final (v, l) in _UserFormDialogState._kEmploymentStatuses)
        DropdownMenuItem(value: v, child: Text(l)),
    ],
    onChanged: (v) => rafraichir(() => _employmentStatus = v),
  );

  Future<void> _pickHireDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDateD ?? now,
      firstDate: DateTime(1970),
      lastDate: now,
      locale: const Locale('fr', 'FR'),
      helpText: 'Date de prise de service',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
    );
    if (picked != null) {
      rafraichir(() {
        _hireDateD = picked;
        _hireDate.text = _fmtDob(picked);
      });
    }
  }

  Widget _hireDateField() => _field(
    _hireDate, 'Prise de service', Icons.event_available_outlined,
    keyboard: TextInputType.datetime,
    suffix: IconButton(
      icon: Icon(Icons.calendar_today_rounded, size: 18, color: kTextMuted),
      onPressed: _pickHireDate,
    ),
    validator: (v) {
      if (v == null || v.trim().isEmpty) return null;
      if (_parseDob(v) == null) return 'Format JJ/MM/AAAA';
      return null;
    },
  );

  Widget _schoolDropdown() => DropdownButtonFormField<String>(
    initialValue: _schoolId,
    isExpanded: true,
    decoration: _inputDec('École *', Icons.account_balance_outlined),
    items: widget.data.schools
        .map((s) => DropdownMenuItem(value: s.id,
            child: Text(s.name, overflow: TextOverflow.ellipsis)))
        .toList(),
    validator: (v) => v == null ? 'École requise' : null,
    onChanged: (v) => rafraichir(() => _schoolId = v),
  );

  Widget _roleDropdown() => DropdownButtonFormField<String>(
    initialValue: _role,
    isExpanded: true,
    decoration: _inputDec('Rôle *', Icons.badge_outlined),
    items: _roleItems
        .map((r) => DropdownMenuItem(value: r.value,
            child: Text(r.label, overflow: TextOverflow.ellipsis)))
        .toList(),
    onChanged: (v) => rafraichir(() => _role = v ?? 'enseignant'),
  );

  Widget _accessProfileDropdown() => DropdownButtonFormField<String?>(
    initialValue: _accessProfileId,
    isExpanded: true,
    decoration: _inputDec("Profil d'accès", Icons.shield_outlined),
    items: [
      const DropdownMenuItem(value: null, child: Text('Aucun (rôle par défaut)')),
      ...widget.data.accessProfiles.map((a) =>
          DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))),
    ],
    onChanged: (v) => rafraichir(() => _accessProfileId = v),
  );

}
