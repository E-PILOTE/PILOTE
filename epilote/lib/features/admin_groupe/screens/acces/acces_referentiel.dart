part of '../admin_access_screen.dart';

// Actions, octrois et modeles de profil.

class _ActionDef {
  const _ActionDef(this.key, this.label, this.icon, this.sensitive);
  final String key, label;
  final IconData icon;
  final bool sensitive; // action à risque → mise en évidence (orange + ⚠)
}

const _kActions = <_ActionDef>[
  _ActionDef('read',     'Voir',       Icons.visibility_outlined,     false),
  _ActionDef('create',   'Créer',      Icons.add_circle_outline,      false),
  _ActionDef('update',   'Modifier',   Icons.edit_outlined,           false),
  _ActionDef('delete',   'Supprimer',  Icons.delete_outline_rounded,  true),
  _ActionDef('export',   'Exporter',   Icons.download_rounded,        true),
  _ActionDef('import',   'Importer',   Icons.upload_rounded,          true),
  _ActionDef('validate', 'Valider',    Icons.fact_check_outlined,     true),
  _ActionDef('approve',  'Approuver',  Icons.verified_outlined,       true),
  _ActionDef('manage',   'Paramètres', Icons.settings_outlined,       true),
];

bool _permGet(PermRow r, String k) {
  switch (k) {
    case 'read':     return r.canRead;
    case 'create':   return r.canCreate;
    case 'update':   return r.canUpdate;
    case 'delete':   return r.canDelete;
    case 'export':   return r.canExport;
    case 'import':   return r.canImport;
    case 'validate': return r.canValidate;
    case 'approve':  return r.canApprove;
    default:         return r.canManage;
  }
}

PermRow _permSet(PermRow r, String k, bool v) {
  switch (k) {
    case 'read':     return r.copyWith(canRead: v);
    case 'create':   return r.copyWith(canCreate: v, canRead: v ? true : r.canRead);
    case 'update':   return r.copyWith(canUpdate: v, canRead: v ? true : r.canRead);
    case 'delete':   return r.copyWith(canDelete: v, canRead: v ? true : r.canRead);
    case 'export':   return r.copyWith(canExport: v, canRead: v ? true : r.canRead);
    case 'import':   return r.copyWith(canImport: v, canRead: v ? true : r.canRead);
    case 'validate': return r.copyWith(canValidate: v, canRead: v ? true : r.canRead);
    case 'approve':  return r.copyWith(canApprove: v, canRead: v ? true : r.canRead);
    default:         return r.copyWith(canManage: v, canRead: v ? true : r.canRead);
  }
}

// ─── Droits par défaut (modèle de profil standard) ───────────────────────────
class _Grant {
  const _Grant({
    this.read = false, this.create = false, this.update = false, this.delete = false,
    this.export = false, this.import = false, this.validate = false,
    this.approve = false, this.manage = false, this.scope = 'own_school',
  });
  final bool read, create, update, delete, export, import, validate, approve, manage;
  final String scope;

  PermRow toRow() => PermRow(
        canRead: read, canCreate: create, canUpdate: update, canDelete: delete,
        canExport: export, canImport: import, canValidate: validate,
        canApprove: approve, canManage: manage, dataScope: scope,
      );

  // Raccourcis sémantiques
  static _Grant full({String scope = 'own_school'}) => _Grant(
      read: true, create: true, update: true, delete: true, export: true,
      import: true, validate: true, approve: true, manage: true, scope: scope);
  static _Grant manageData({String scope = 'own_school'}) => _Grant(
      read: true, create: true, update: true, delete: true, export: true,
      import: true, scope: scope);
  static _Grant contribute({String scope = 'own_school'}) =>
      _Grant(read: true, create: true, update: true, scope: scope);
  static _Grant teach({String scope = 'own_classes'}) =>
      _Grant(read: true, create: true, update: true, export: true, scope: scope);
  static _Grant financial({String scope = 'own_school'}) => _Grant(
      read: true, create: true, update: true, export: true, import: true,
      validate: true, scope: scope);
  static _Grant readExport({String scope = 'own_school'}) =>
      _Grant(read: true, export: true, scope: scope);
  static _Grant readOnly({String scope = 'own_school'}) =>
      _Grant(read: true, scope: scope);
}

class _Preset {
  const _Preset({
    required this.roleType, required this.label, required this.name,
    required this.description, required this.icon, required this.color,
    this.categories = const {}, this.modules = const {},
  });
  final String roleType, label, name, description;
  final IconData icon;
  final Color color;
  final Map<String, _Grant> categories; // slug catégorie → droits
  final Map<String, _Grant> modules;     // slug module → droits (priorité)

  _Grant? grantFor(String catSlug, String modSlug) =>
      modules[modSlug] ?? categories[catSlug];
}

final _kPresets = <_Preset>[
  _Preset(
    roleType: 'proviseur', label: 'Proviseur',
    name: 'Proviseur', icon: Icons.account_balance_rounded,
    color: const Color(0xFF4F46E5),
    description: 'Chef d\'établissement (lycée). Autorité complète sur l\'ensemble des modules de l\'école.',
    categories: {
      for (final c in const ['scolarite','enseignement','evaluation','examens','formation-pro','vie-scolaire','finance','rh'])
        c: _Grant.full(),
    },
  ),
  _Preset(
    roleType: 'directeur', label: 'Directeur',
    name: 'Directeur', icon: Icons.manage_accounts_rounded,
    color: const Color(0xFF1D4ED8),
    description: 'Chef d\'établissement (collège / école professionnelle). Gestion complète de l\'école.',
    categories: {
      for (final c in const ['scolarite','enseignement','evaluation','examens','formation-pro','vie-scolaire','finance','rh'])
        c: _Grant.full(),
    },
  ),
  _Preset(
    roleType: 'directeur_etudes', label: 'Directeur des Études',
    name: 'Directeur des Études (D.E)', icon: Icons.menu_book_rounded,
    color: const Color(0xFF0D9488),
    description: 'Pilotage pédagogique : programmes, évaluations, bulletins, conseils de classe.',
    categories: {
      'scolarite': _Grant.manageData(),
      'enseignement': _Grant.full(),
      'evaluation': _Grant.full(),
      'examens': _Grant.full(),
      'vie-scolaire': _Grant.contribute(),
    },
  ),
  _Preset(
    roleType: 'chef_travaux', label: 'Chef des Travaux',
    name: 'Chef des Travaux (C.T)', icon: Icons.engineering_rounded,
    color: const Color(0xFFB45309),
    description: 'Coordination de l\'enseignement technique : matières, emplois du temps, programmes.',
    categories: {
      'scolarite': _Grant.readExport(),
      'examens': _Grant.readExport(),
      'formation-pro': _Grant.full(),
      'enseignement': _Grant.teach(scope: 'own_school'),
      'evaluation': _Grant.teach(scope: 'own_school'),
      'rh': _Grant.readOnly(),
    },
    modules: {
      'matieres': _Grant.manageData(),
      'emploi-du-temps': _Grant.manageData(),
      'programmes': _Grant.manageData(),
    },
  ),
  _Preset(
    roleType: 'secretaire', label: 'Secrétaire',
    name: 'Secrétaire', icon: Icons.edit_document,
    color: const Color(0xFF7C3AED),
    description: 'Dossiers élèves, inscriptions, documents administratifs et messagerie.',
    categories: {
      'scolarite': _Grant.manageData(),
      'examens': _Grant.manageData(),
      'formation-pro': _Grant.manageData(),
      'enseignement': _Grant.readExport(),
      'evaluation': _Grant.readExport(),
      'vie-scolaire': _Grant.readOnly(),
    },
  ),
  _Preset(
    roleType: 'comptable', label: 'Comptable',
    name: 'Comptable', icon: Icons.account_balance_wallet_rounded,
    color: const Color(0xFFD97706),
    description: 'Paiements, facturation, budgets, dépenses et comptabilité. Validation financière.',
    categories: {
      'finance': _Grant.financial(),
      'scolarite': _Grant.readOnly(),
      'examens': _Grant.readOnly(),
    },
  ),
  _Preset(
    roleType: 'enseignant', label: 'Enseignant',
    name: 'Enseignant', icon: Icons.school_rounded,
    color: const Color(0xFF059669),
    description: 'Notes, cahier de textes, évaluations et présences de ses classes uniquement.',
    categories: {
      'enseignement': _Grant.teach(),
      'evaluation': _Grant.teach(),
      'scolarite': _Grant.readOnly(scope: 'own_classes'),
      'examens': _Grant.readOnly(scope: 'own_classes'),
      'vie-scolaire': _Grant.readOnly(scope: 'own_classes'),
    },
  ),
  _Preset(
    roleType: 'surveillant', label: 'Surveillant',
    name: 'Surveillant', icon: Icons.security_rounded,
    color: kRed,
    description: 'Présences, discipline, infirmerie, cantine et vie scolaire au quotidien.',
    categories: {
      'vie-scolaire': _Grant.manageData(),
      'scolarite': _Grant.readOnly(),
    },
    modules: {
      'presences-eleves': _Grant.contribute(),
    },
  ),
  _Preset(
    roleType: 'consultant', label: 'Consultant',
    name: 'Consultant', icon: Icons.insights_rounded,
    color: const Color(0xFF475569),
    description: 'Observateur / analyste : lecture et export de tous les modules, sans modification.',
    categories: {
      for (final c in const ['scolarite','enseignement','evaluation','examens','formation-pro','vie-scolaire','finance','rh'])
        c: _Grant.readExport(),
    },
  ),
  _Preset(
    roleType: 'autre', label: 'Autre',
    name: '', icon: Icons.tune_rounded,
    color: kTextMuted,
    description: 'Profil personnalisé : partez d\'une page vierge et choisissez chaque droit manuellement.',
  ),
];

// ─── Assistant profil unifié (identité + permissions) ───────────────────────
