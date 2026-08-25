import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart' show kListOrange;
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_fees_provider.dart';
import '../widgets/origine_chip.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SAISIR UN TARIF — le geste que l'école n'a plus.
//
//  ⚠️ Cette boîte POSSÈDE ses contrôleurs et les libère elle-même.
//  `await showDialog` rend la main au `Navigator.pop`, PAS à la fin de
//  l'animation de sortie : les libérer depuis l'appelant les détruit pendant
//  que les champs en dépendent encore, et l'écran vire au rouge sur
//  « _dependents.isEmpty is not true ». Piège déjà vécu deux fois.
//
//  ⚠️ La portée n'est PLUS un `DropdownButtonFormField`. Un ministère de 1 000
//  écoles y déroulait mille entrées non filtrables — inutilisable, et sans
//  virtualisation. Elle passe par un sélecteur cherchable (`_choisirEcole`),
//  dont la liste est bâtie par un `ListView.builder`.
//
//  Le catalogue des types (`kAdminFeeTypes`) vit dans le provider, avec la
//  donnée : l'écran, la ligne de liste et cette boîte le lisent tous les trois.
// ════════════════════════════════════════════════════════════════════════════

/// Au-delà, on demande confirmation. Ce n'est pas un plafond réglementaire —
/// c'est un garde-fou de frappe : sur un clavier, 500000 s'écrit aussi vite
/// que 50000, et le second zéro de trop part en synchro vers toutes les écoles.
const _kMontantSuspect = 1000000;

Future<bool> showAdminFeeForm(
  BuildContext context, {
  required String academicYearId,
  AdminFee? fee,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminFeeForm(academicYearId: academicYearId, fee: fee),
    ) ??
    false;

class _AdminFeeForm extends ConsumerStatefulWidget {
  const _AdminFeeForm({required this.academicYearId, this.fee});
  final String academicYearId;
  final AdminFee? fee;

  @override
  ConsumerState<_AdminFeeForm> createState() => _AdminFeeFormState();
}

class _AdminFeeFormState extends ConsumerState<_AdminFeeForm> {
  late final _nom = TextEditingController(text: widget.fee?.name ?? '');
  late final _montant =
      TextEditingController(text: widget.fee?.amount.toString() ?? '');
  late final _echeance =
      TextEditingController(text: widget.fee?.dueDay?.toString() ?? '');
  late final _source =
      TextEditingController(text: widget.fee?.sourceReference ?? '');

  late String? _schoolId = widget.fee?.schoolId;
  late String? _levelId = widget.fee?.levelId;
  /// Niveau du référentiel partagé — le seul ciblage possible en portée réseau.
  late String? _educationLevelId = widget.fee?.educationLevelId;

  /// L'examen visé par un `frais_examens` (migration 0103).
  late String? _examId = widget.fee?.examId;
  // Pas de valeur par défaut à la création : rien ne doit devenir une
  // mensualité par omission, surtout dans le public où elle n'existe pas.
  late String? _feeType = widget.fee?.feeType;

  String? _erreur;
  bool _saving = false;

  @override
  void dispose() {
    _nom.dispose();
    _montant.dispose();
    _echeance.dispose();
    _source.dispose();
    super.dispose();
  }

  int? get _montantSaisi =>
      int.tryParse(_montant.text.trim().replaceAll(RegExp(r'\s'), ''));

  String? _probleme() {
    if (_feeType == null) return 'Choisissez le type de frais';
    if (_nom.text.trim().isEmpty) return 'Le nom du barème est obligatoire';
    final m = _montantSaisi;
    if (m == null || m <= 0) return 'Montant (> 0) requis';
    if (_feeType == 'mensualite' && _echeance.text.trim().isNotEmpty) {
      final j = int.tryParse(_echeance.text.trim());
      if (j == null || j < 1 || j > 31) {
        return 'L\'échéance est un jour du mois, entre 1 et 31';
      }
    }
    if (_source.text.trim().isEmpty) {
      return 'Indiquez le texte qui fonde ce tarif';
    }
    return null;
  }

  Future<void> _save() async {
    final probleme = _probleme();
    if (probleme != null) {
      setState(() => _erreur = probleme);
      return;
    }
    final montant = _montantSaisi!;
    if (montant >= _kMontantSuspect && !await _confirmerMontant(montant)) return;

    if (!mounted) return;
    final groupId = ref.read(authNotifierProvider).valueOrNull?.groupId;
    if (groupId == null) {
      setState(() => _erreur = 'Groupe introuvable');
      return;
    }
    setState(() {
      _saving = true;
      _erreur = null;
    });
    try {
      await saveAdminFee(
        ref.read(supabaseClientProvider),
        id: widget.fee?.id,
        groupId: groupId,
        academicYearId: widget.academicYearId,
        name: _nom.text.trim(),
        feeType: _feeType!,
        amount: montant,
        schoolId: _schoolId,
        // Deux référentiels, jamais les deux à la fois : un tarif
        // d'établissement vise SES niveaux, un tarif réseau vise le référentiel
        // partagé — « la 6e du pays », pas « la 6e de l'école A ».
        levelId: _schoolId == null ? null : _levelId,
        educationLevelId: _schoolId == null ? _educationLevelId : null,
        // Une dérogation posée sur une session précise l'emporte : les deux
        // ciblages s'excluent (contrainte 0103).
        examId: widget.fee?.examSessionId != null ? null : _examId,
        dueDay: _feeType == 'mensualite'
            ? int.tryParse(_echeance.text.trim())
            : null,
        sourceReference: _source.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          // Un doublon est un refus MÉTIER : son message explique quoi faire.
          // Le reste passe par la traduction commune — jamais l'objet brut.
          _erreur = switch (e) {
            BaremeDoublonException(:final message) => message,
            BaremeInterditException(:final message) => message,
            _ => messageErreur(e),
          };
        });
      }
    }
  }

  Future<bool> _confirmerMontant(int montant) => showAdminConfirm(
        context,
        title: 'Confirmer ${fmtXaf(montant)} ?',
        message:
            'Ce montant est inhabituel pour un tarif scolaire. Il partira vers '
            '${_schoolId == null ? 'TOUTES les écoles du réseau' : 'l\'école visée'} '
            'à la prochaine synchronisation. Vérifiez le nombre de zéros.',
        confirmLabel: 'Oui, publier ce montant',
      );

  @override
  Widget build(BuildContext context) {
    final niveaux = _schoolId == null
        ? const <OptionRef>[]
        : (ref.watch(adminFeeLevelsProvider(_schoolId!)).valueOrNull ??
            const <OptionRef>[]);
    // Référentiel partagé — chargé seulement quand la portée est le réseau.
    final niveauxReferentiel = _schoolId != null
        ? const <NiveauRef>[]
        : (ref.watch(adminEducationLevelsProvider).valueOrNull ??
            const <NiveauRef>[]);

    // Les examens nationaux ne sont chargés que quand la question se pose.
    final examens = _feeType != 'frais_examens'
        ? const <OptionRef>[]
        : (ref.watch(adminNationalExamsProvider).valueOrNull ??
            const <OptionRef>[]);

    // Secteur du groupe, lu en base. La mensualité disparaît du choix dans le
    // public — la loi 25-95 (art. 1) pose la gratuité de l'enseignement public.
    final groupePublic = ref.watch(adminGroupePublicProvider);
    final types = typesDeFraisProposables(
      groupePublic: groupePublic,
      typeActuel: widget.fee?.feeType,
    );

    return AdminFormDialog(
      icon: Icons.request_quote_rounded,
      title: widget.fee == null ? 'Nouveau tarif' : 'Modifier le tarif',
      subtitle: 'Les écoles concernées l\'appliqueront sans pouvoir le changer',
      accent: kNavy,
      width: 520,
      saving: _saving,
      submitLabel: widget.fee == null ? 'Publier le tarif' : 'Enregistrer',
      submitIcon: Icons.check_rounded,
      onSubmit: _saving ? null : _save,
      body: Column(mainAxisSize: MainAxisSize.min, children: [
        // La portée d'abord : c'est la décision structurante, tout le reste
        // en découle (le ciblage par niveau n'existe qu'en portée école).
        _PorteeField(
          schoolId: _schoolId,
          // Changer de portée change de RÉFÉRENTIEL de niveaux : on lâche celui
          // qui ne s'applique plus, sinon la contrainte 0101 refuserait la
          // ligne (un tarif ne vise jamais les deux à la fois).
          onChanged: (v) => setState(() {
            _schoolId = v;
            if (v == null) {
              _levelId = null;
            } else {
              _educationLevelId = null;
            }
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _feeType,
          isExpanded: true,
          decoration:
              adminFilledInput('Type de frais', icon: Icons.category_rounded),
          hint: const Text('À choisir'),
          items: [
            for (final e in types.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _feeType = v),
        ),
        // Expliquer une ABSENCE : sans ce mot, « où est passée la mensualité ? »
        // devient un ticket de support.
        if (groupePublic == true) ...[
          const SizedBox(height: 8),
          _note(
            'Réseau public : la mensualité n\'est pas proposée. La loi 25-95 '
            '(art. 1) pose que l\'enseignement public est gratuit. '
            'L\'inscription, les frais d\'examen et la cotisation APE restent '
            'possibles.',
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _nom,
          decoration: adminFilledInput(
              _feeType == 'autre'
                  ? 'Intitulé du frais (ex. Cantine, Transport)'
                  : 'Nom du barème (ex. Inscription 2025-2026)',
              icon: Icons.label_outline_rounded),
        ),
        // Sur un frais annexe, l'intitulé n'est plus une étiquette : c'est
        // l'IDENTITÉ de la ligne (migration 0108). Deux frais au même nom sont
        // refusés ; deux noms distincts cohabitent et s'ADDITIONNENT dans ce
        // que la famille doit. Le dire ici évite qu'une école croie devoir
        // cumuler la cantine et le bus sur une seule ligne fourre-tout.
        if (_feeType == 'autre') ...[
          const SizedBox(height: 8),
          _note(
            'L\'intitulé distingue ce frais des autres frais annexes : cantine, '
            'transport et tenue peuvent coexister, et se cumulent dans ce que '
            'la famille doit. Deux lignes portant le même nom sont refusées.',
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _montant,
              keyboardType: TextInputType.number,
              // Un montant ne contient que des chiffres. Sans ce filtre, une
              // lettre passait la saisie pour être refusée à l'enregistrement.
              // La limite à 9 chiffres borne la saisie sous `integer` (PG
              // s'arrête à 2 147 483 647) : au-delà, Postgres renvoyait un
              // 22003 que l'écran ne savait pas traduire — un mur, là où la
              // confirmation « vérifiez le nombre de zéros » suffit.
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: adminFilledInput('Montant (FCFA)',
                  icon: Icons.payments_rounded),
            ),
          ),
          if (_feeType == 'mensualite') ...[
            const SizedBox(width: 12),
            SizedBox(
              // 150 px écrasaient le libellé en « Échéance (1... » : l'icône
              // et les marges en mangent une quarantaine, et c'est justement
              // l'intervalle autorisé qui disparaissait.
              width: 200,
              child: TextField(
                controller: _echeance,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: adminFilledInput('Échéance (1-31)',
                    icon: Icons.event_rounded),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        // ── Le niveau, dans le référentiel qui correspond à la portée ────────
        //
        // Portée ÉCOLE  → ses propres niveaux (`school_levels`).
        // Portée RÉSEAU → le référentiel PARTAGÉ (`education_levels`), ce qui
        //   permet enfin d'écrire une fois « inscription en 6e = X » pour les
        //   1 000 écoles. Avant la migration 0101, ce choix n'existait pas et
        //   un encart expliquait qu'il fallait viser une école — c'est-à-dire
        //   saisir mille lignes.
        if (_schoolId != null)
          DropdownButtonFormField<String?>(
            initialValue: _levelId,
            isExpanded: true,
            decoration: adminFilledInput('Niveau concerné',
                icon: Icons.stairs_rounded),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Tous les niveaux')),
              for (final n in niveaux)
                DropdownMenuItem(value: n.id, child: Text(n.name)),
            ],
            onChanged: (v) => setState(() => _levelId = v),
          )
        else ...[
          DropdownButtonFormField<String?>(
            initialValue: _educationLevelId,
            isExpanded: true,
            // ⚠️ `itemHeight: null` n'est pas cosmétique. Les libellés valent
            // « Cycle · Filière · Niveau » et 12 des 79 niveaux nationaux
            // dépassent la largeur du menu — tous en Formation
            // Professionnelle, le cœur de métier du METP. Sur une seule ligne,
            // « … · BTP (Bâtiment et Travaux Publics) · 1ère année » et sa
            // 2ème année s'affichaient IDENTIQUES : c'est l'année, seule partie
            // discriminante, que l'ellipse mangeait. Quatre filières étaient
            // dans ce cas — donc 12 niveaux impossibles à choisir sûrement.
            // Les items se replient maintenant sur plusieurs lignes.
            itemHeight: null,
            decoration: adminFilledInput('Niveau concerné (tout le réseau)',
                icon: Icons.stairs_rounded),
            // Le champ FERMÉ, lui, reste sur une ligne : sans cela il change de
            // hauteur selon le niveau choisi et fait sauter la boîte.
            selectedItemBuilder: (_) => [
              const Text('Tous les niveaux',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              for (final n in niveauxReferentiel)
                Text(n.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Tous les niveaux')),
              for (final n in niveauxReferentiel)
                DropdownMenuItem(
                    value: n.id,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        Expanded(
                          child: Text(n.name,
                              style: const TextStyle(height: 1.25)),
                        ),
                        // Dire d'où vient l'entrée : le référentiel affiché
                        // mélange le squelette national et ce que le groupe a
                        // créé, et deux entrées peuvent décrire la même année.
                        if (n.duGroupe) ...[
                          const SizedBox(width: 8),
                          const OrigineChip(),
                        ],
                      ]),
                    )),
            ],
            onChanged: (v) => setState(() => _educationLevelId = v),
          ),
          if (_educationLevelId != null) ...[
            const SizedBox(height: 8),
            _note(
              'Ce niveau vient du référentiel partagé : le tarif s\'appliquera '
              'au même niveau dans TOUTES les écoles du réseau. Chaque école le '
              'reconnaîtra dans sa propre structure, sans rien saisir.',
            ),
            // Un niveau propre au groupe ne couvre QUE les écoles qui s'y sont
            // rattachées — les autres suivent l'entrée nationale équivalente et
            // ne verront pas ce tarif. C'est l'écart que l'écran de
            // rattachement rend visible.
            if (niveauxReferentiel
                .any((n) => n.id == _educationLevelId && n.duGroupe)) ...[
              const SizedBox(height: 8),
              _note(
                'Ce niveau a été créé par votre groupe : seules les écoles qui '
                's\'y rattachent recevront ce tarif. Celles rattachées au '
                'niveau national équivalent ne le verront pas. Vérifiez-le dans '
                '« Rattachement des niveaux ».',
                alerte: true,
              ),
            ],
          ],
        ],
        // ── L'EXAMEN VISÉ ───────────────────────────────────────────────────
        //
        // Avant la migration 0103, ce bloc n'était qu'un avertissement : le
        // tarif ne pouvait se rattacher qu'à une SESSION, depuis un autre
        // écran. Résultat mesuré : sur 35 sessions, 6 années et 7 groupes,
        // pas un seul rattachement. On demande donc l'examen — stable — et
        // chaque poste résout la session de son année scolaire.
        if (_feeType == 'frais_examens') ...[
          const SizedBox(height: 12),
          if (widget.fee?.examSessionId != null)
            // Dérogation posée sur UNE session : ne pas la piétiner.
            _note(
              'Ce tarif est rattaché à une session précise. Il garde ce '
              'rattachement ; le choix par examen ne s\'applique qu\'aux '
              'tarifs qui n\'en ont pas.',
            )
          else ...[
            DropdownButtonFormField<String?>(
              initialValue: _examId,
              isExpanded: true,
              itemHeight: null,
              decoration: adminFilledInput('Examen concerné',
                  icon: Icons.workspace_premium_rounded),
              selectedItemBuilder: (_) => [
                const Text('À rattacher — non visible du module Examens',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                for (final e in examens)
                  Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              items: [
                const DropdownMenuItem(
                    value: null,
                    child: Text('À rattacher — non visible du module Examens')),
                for (final e in examens)
                  DropdownMenuItem(
                      value: e.id,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child:
                            Text(e.name, style: const TextStyle(height: 1.25)),
                      )),
              ],
              onChanged: (v) => setState(() => _examId = v),
            ),
            const SizedBox(height: 8),
            if (_examId == null)
              _note(
                'Sans examen visé, le module Examens ne verra pas ce tarif et '
                'la caisse de l\'examen restera fermée — l\'école affichera un '
                'montant qu\'elle ne pourra pas encaisser.',
                alerte: true,
              )
            else
              _note(
                'Le tarif s\'appliquera à la session de cet examen pour '
                'l\'année scolaire choisie. Vous pouvez le publier avant '
                'l\'ouverture des inscriptions : chaque école le retrouvera '
                'dès que la session s\'ouvrira.',
              ),
          ],
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _source,
          maxLines: 2,
          decoration: adminFilledInput(
              'Texte fondateur — arrêté, note de service, délibération…',
              icon: Icons.gavel_rounded),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Obligatoire : un montant sans texte qui le fonde n\'est pas un '
            'tarif, c\'est un chiffre.',
            style: TextStyle(fontSize: 11, color: kTextMuted),
          ),
        ),
        if (_erreur != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_erreur!,
                style: TextStyle(
                    fontSize: 12, color: kRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }

  Widget _note(String text, {bool alerte = false}) {
    final tone = alerte ? kListOrange : kNavy;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(alerte ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: 15, color: tone),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style:
                  TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35)),
        ),
      ]),
    );
  }
}

// ─── Portée : « Tout le réseau » ou une école, cherchable ────────────────────
//
// Un `DropdownButtonFormField` déroulait la liste ENTIÈRE des écoles du groupe,
// sans recherche ni virtualisation. À 37 écoles c'était pénible ; à 1 000 c'est
// inutilisable, et c'est l'échelle visée.
class _PorteeField extends ConsumerWidget {
  const _PorteeField({required this.schoolId, required this.onChanged});

  final String? schoolId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminFeeSchoolsProvider);
    final ecoles = async.valueOrNull ?? const <OptionRef>[];
    final trouvee = ecoles.where((e) => e.id == schoolId);
    final nom = schoolId == null
        ? 'Tout le réseau'
        : (trouvee.isEmpty ? 'École sélectionnée' : trouvee.first.name);

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: async.isLoading
          ? null
          : () async {
              final choix = await _choisirEcole(context, ecoles, schoolId);
              if (choix != null) onChanged(choix.isEmpty ? null : choix);
            },
      child: InputDecorator(
        decoration: adminFilledInput('Portée',
            icon: Icons.account_balance_rounded),
        child: Row(children: [
          Expanded(
            child: Text(nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: kTextPrimary)),
          ),
          if (async.isLoading)
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(Icons.unfold_more_rounded, size: 18, color: kTextMuted),
        ]),
      ),
    );
  }
}

/// Retourne `null` si l'utilisateur renonce, `''` pour « tout le réseau »,
/// sinon l'identifiant de l'école. Le vide est un CHOIX, pas une absence de
/// choix — d'où les deux valeurs distinctes.
Future<String?> _choisirEcole(
  BuildContext context,
  List<OptionRef> ecoles,
  String? courant,
) {
  final recherche = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final q = recherche.text.trim().toLowerCase();
        final filtrees = q.isEmpty
            ? ecoles
            : ecoles.where((e) => e.name.toLowerCase().contains(q)).toList();
        return AlertDialog(
          backgroundColor: kCardBg,
          title: const Text('Portée du tarif', style: TextStyle(fontSize: 16)),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: SizedBox(
            width: 460,
            height: 420,
            child: Column(children: [
              TextField(
                controller: recherche,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: adminFilledInput('Rechercher une école…',
                    icon: Icons.search_rounded),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('${filtrees.length} école(s)',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  // +1 : « Tout le réseau » ouvre toujours la liste.
                  itemCount: filtrees.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _ligneChoix(
                        ctx,
                        libelle: 'Tout le réseau',
                        sousTitre: 'S\'applique à toutes les écoles du groupe',
                        icone: Icons.public_rounded,
                        choisi: courant == null,
                        valeur: '',
                      );
                    }
                    final e = filtrees[i - 1];
                    return _ligneChoix(
                      ctx,
                      libelle: e.name,
                      icone: Icons.account_balance_rounded,
                      choisi: courant == e.id,
                      valeur: e.id,
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
          ],
        );
      },
    ),
  ).whenComplete(recherche.dispose);
}

Widget _ligneChoix(
  BuildContext ctx, {
  required String libelle,
  required IconData icone,
  required bool choisi,
  required String valeur,
  String? sousTitre,
}) =>
    ListTile(
      dense: true,
      leading: Icon(icone, size: 18, color: choisi ? kNavy : kTextMuted),
      title: Text(libelle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13,
              fontWeight: choisi ? FontWeight.w800 : FontWeight.w500)),
      subtitle: sousTitre == null
          ? null
          : Text(sousTitre, style: TextStyle(fontSize: 11, color: kTextMuted)),
      trailing:
          choisi ? Icon(Icons.check_rounded, size: 18, color: kNavy) : null,
      onTap: () => Navigator.pop(ctx, valeur),
    );
