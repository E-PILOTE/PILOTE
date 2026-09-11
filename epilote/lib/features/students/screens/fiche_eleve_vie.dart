part of 'fiche_eleve_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  VIE SCOLAIRE — assiduité, conduite, infirmerie, cantine
//
//  ── QUATRE REGISTRES, DEUX PORTÉES ─────────────────────────────────────────
//  Assiduité et cantine se lisent SUR UNE ANNÉE : « quatorze absences » ne
//  veut rien dire sans année de référence, et ces deux tables portent une
//  ligne par jour — sur une scolarité entière, elles se comptent en milliers.
//
//  Conduite et infirmerie se lisent sur TOUTE la scolarité : trois
//  avertissements en trois ans ne se voient que côte à côte, et un asthme
//  signalé en sixième vaut encore en terminale.
//
//  ── AUCUNE ÉCRITURE ICI, ET C'EST LA RAISON D'ÊTRE DES RENVOIS ─────────────
//  ⚠️ Une absence porte l'agent qui l'a posée et l'heure à laquelle il l'a
//  fait ; une sanction engage celui qui la prononce. Les corriger depuis la
//  fiche effacerait cette responsabilité. Chaque section renvoie donc vers le
//  module qui sait qui écrit.
// ════════════════════════════════════════════════════════════════════════════

class FicheVieScolaire extends ConsumerWidget {
  const FicheVieScolaire({
    super.key,
    required this.studentId,
    required this.annee,
  });

  final String studentId;
  final AnneeFiche? annee;

  /// Les bornes de l'année, sous la forme attendue par `ficheCantineProvider`.
  ///
  /// `canteen_records` date chaque service sans porter d'année scolaire : sans
  /// bornes, il faudrait lire toute la scolarité pour compter une année.
  String get _bornes {
    final d = annee?.debut, f = annee?.fin;
    if (d == null || f == null) return '';
    return '${d.toIso8601String().substring(0, 10)}|'
        '${f.toIso8601String().substring(0, 10)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = annee;
    final assiduite = a == null
        ? null
        : ref.watch(ficheAssiduiteProvider((studentId, a.id))).valueOrNull;
    final incidents =
        ref.watch(ficheDisciplineProvider(studentId)).valueOrNull ??
            const <IncidentLigne>[];
    final visites =
        ref.watch(ficheInfirmerieProvider(studentId)).valueOrNull ??
            const <VisiteLigne>[];
    final cantine = ref.watch(ficheCantineProvider((studentId, _bornes)))
        .valueOrNull;

    return Column(children: [
      _Assiduite(assiduite: assiduite, annee: a),
      _Conduite(incidents: incidents),
      _Infirmerie(visites: visites),
      _Cantine(cantine: cantine, annee: a),
    ]);
  }
}

class _Assiduite extends StatelessWidget {
  const _Assiduite({required this.assiduite, required this.annee});

  final Assiduite? assiduite;
  final AnneeFiche? annee;

  @override
  Widget build(BuildContext context) {
    final a = assiduite;
    return FicheSection(
      titre: 'Assiduité',
      icone: Icons.event_available_outlined,
      compte: a?.manquements.length,
      note: annee == null ? null : 'Année ${annee!.label}',
      action: FicheRenvoi(
        label: 'Module Présences',
        onTap: () => context.push(Routes.presences),
      ),
      enfants: [
        if (a == null || a.vide)
          const FicheVide(
            "Aucun appel enregistré pour cette année — l'assiduité de cet "
            "élève n'a pas encore été relevée.",
          )
        else ...[
          FicheStats([
            FicheStat(
              label: 'séances relevées',
              valeur: '${a.seances}',
            ),
            FicheStat(
              label: a.absences > 1 ? 'absences' : 'absence',
              valeur: '${a.absences}',
              couleur: a.absences > 0 ? kRed : kGreen,
            ),
            FicheStat(
              label: a.retards > 1 ? 'retards' : 'retard',
              valeur: '${a.retards}',
              couleur: a.retards > 0 ? kAccent : null,
            ),
            FicheStat(
              label: 'justifiées',
              valeur: '${a.justifiees}',
            ),
            // ⚠️ Le taux porte sur les séances RELEVÉES, pas sur l'année. Un
            // taux calculé sur un nombre de jours théorique compterait absent
            // un élève d'une séance où l'appel n'a jamais été fait.
            FicheStat(
              label: 'de présence sur les séances relevées',
              valeur: a.tauxPresence == null
                  ? '—'
                  : '${a.tauxPresence!.toStringAsFixed(1)} %',
              couleur: (a.tauxPresence ?? 100) >= 90 ? kGreen : kRed,
            ),
          ]),
          if (a.manquements.isEmpty)
            const FicheVide('Aucune absence ni retard sur cette année.')
          else
            for (final m in a.manquements.take(40))
              FicheChrono(
                date: _dt(m.date),
                titre: [
                  presenceStatutLabel(m.statut),
                  if (m.periode.isNotEmpty) '· ${m.periode}',
                  if (m.classe.isNotEmpty) '· ${m.classe}',
                ].join(' '),
                detail: m.justifie
                    ? 'Justifié : ${m.justification}'
                    : 'Non justifié'
                        '${m.parentPrevenu ? ' · famille prévenue' : ''}',
                couleur: m.statut == 'absent' ? kRed : kAccent,
                badge: m.justifie ? 'Justifié' : null,
              ),
          if (a.manquements.length > 40)
            FicheVide(
              '… et ${a.manquements.length - 40} autres manquements sur cette '
              'année. Le registre complet se lit dans le module Présences.',
            ),
        ],
      ],
    );
  }
}

class _Conduite extends StatelessWidget {
  const _Conduite({required this.incidents});
  final List<IncidentLigne> incidents;

  @override
  Widget build(BuildContext context) {
    final sanctionnes = incidents.where((i) => i.sanction.isNotEmpty).length;
    return FicheSection(
      titre: 'Conduite',
      icone: Icons.gavel_rounded,
      couleur: kRed,
      compte: incidents.length,
      note: incidents.isEmpty ? null : 'Toute la scolarité',
      action: FicheRenvoi(
        label: 'Module Discipline',
        onTap: () => context.push(Routes.discipline),
      ),
      enfants: [
        if (incidents.isEmpty)
          const FicheVide(
            'Aucun fait de conduite enregistré sur toute la scolarité de cet '
            'élève.',
          )
        else ...[
          FicheStats([
            FicheStat(
              label: incidents.length > 1 ? 'faits relevés' : 'fait relevé',
              valeur: '${incidents.length}',
              couleur: kRed,
            ),
            FicheStat(
              label: 'sanctions prononcées',
              valeur: '$sanctionnes',
              couleur: sanctionnes > 0 ? kRed : null,
            ),
          ]),
          for (final i in incidents)
            FicheChrono(
              date: _dt(i.date),
              titre: [
                incidentTypeLabel(i.type),
                if (i.anneeLabel.isNotEmpty) '· ${i.anneeLabel}',
              ].join(' '),
              detail: [
                if (i.description.isNotEmpty) i.description,
                if (i.sanction.isNotEmpty)
                  'Sanction : ${sanctionLabel(i.sanction)}'
                      '${i.dateSanction == null ? '' : ' (${_dt(i.dateSanction)})'}',
                if (i.suivi.isNotEmpty) 'Suivi : ${i.suivi}',
                if (!i.parentPrevenu) 'Famille NON prévenue',
              ].join('\n'),
              couleur: kRed,
              badge: i.sanction.isEmpty ? null : 'Sanctionné',
            ),
        ],
      ],
    );
  }
}

class _Infirmerie extends StatelessWidget {
  const _Infirmerie({required this.visites});
  final List<VisiteLigne> visites;

  @override
  Widget build(BuildContext context) => FicheSection(
        titre: 'Infirmerie',
        icone: Icons.local_hospital_outlined,
        couleur: kRed,
        compte: visites.length,
        // Même avertissement que la section Santé : cette matière ne suit pas
        // sur un document remis à un tiers.
        note: 'Donnée interne — ne figure pas sur la fiche administrative',
        action: FicheRenvoi(
          label: 'Module Infirmerie',
          onTap: () => context.push(Routes.infirmerie),
        ),
        enfants: [
          if (visites.isEmpty)
            const FicheVide(
              "Aucun passage à l'infirmerie enregistré sur toute la scolarité.",
            )
          else
            for (final v in visites)
              FicheChrono(
                date: _dt(v.date),
                titre: [
                  if (v.heure.isNotEmpty) v.heure,
                  v.symptomes.isEmpty ? 'Passage à l\'infirmerie' : v.symptomes,
                ].join(' · '),
                detail: [
                  if (v.diagnostic.isNotEmpty) 'Diagnostic : ${v.diagnostic}',
                  if (v.traitement.isNotEmpty) 'Soins : ${v.traitement}',
                  if (v.medicament.isNotEmpty) 'Médicament : ${v.medicament}',
                  if ((v.reposHeures ?? 0) > 0)
                    'Repos : ${v.reposHeures} h',
                  if (v.suiviRequis)
                    'Suivi requis${v.suivi.isEmpty ? '' : ' — ${v.suivi}'}',
                  if (!v.parentPrevenu) 'Famille NON prévenue',
                ].join('\n'),
                couleur: kRed,
                badge: v.suiviRequis ? 'Suivi' : null,
              ),
        ],
      );
}

class _Cantine extends StatelessWidget {
  const _Cantine({required this.cantine, required this.annee});

  final Cantine? cantine;
  final AnneeFiche? annee;

  @override
  Widget build(BuildContext context) {
    final c = cantine;
    return FicheSection(
      titre: 'Cantine',
      icone: Icons.restaurant_outlined,
      couleur: kGreen,
      compte: c?.services,
      note: annee == null ? null : 'Année ${annee!.label}',
      action: FicheRenvoi(
        label: 'Module Cantine',
        onTap: () => context.push(Routes.cantine),
      ),
      enfants: [
        if (c == null || c.vide)
          const FicheVide(
            'Aucun service de cantine enregistré pour cet élève sur cette '
            "année — il n'y est peut-être pas inscrit.",
          )
        else ...[
          FicheStats([
            FicheStat(label: 'services', valeur: '${c.services}'),
            FicheStat(
              label: 'repas pris',
              valeur: '${c.presences}',
              couleur: kGreen,
            ),
            FicheStat(
              label: 'repas manqués',
              valeur: '${c.absences}',
              couleur: c.absences > 0 ? kAccent : null,
            ),
          ]),
          for (final (date, repas, present) in c.derniers)
            FicheChrono(
              date: _dt(date),
              titre: repasLabel(repas),
              detail: present ? 'Repas pris' : 'Absent au service',
              couleur: present ? kGreen : kAccent,
            ),
        ],
      ],
    );
  }
}
