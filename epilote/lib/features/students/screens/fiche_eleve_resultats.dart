part of 'fiche_eleve_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉSULTATS — les bulletins de toute la scolarité, les notes d'une année
//
//  ── LA FICHE NE CALCULE AUCUNE MOYENNE ─────────────────────────────────────
//  ⚠️ Moyenne générale, moyenne de classe, rang et mention sont ÉCRITS par le
//  module Évaluation, qui applique le barème du niveau, les coefficients et
//  les règles de clôture. En recalculer une ici « pour vérifier » produirait
//  deux chiffres pour la même chose, dont un faux, sur la page qu'on ouvre
//  devant une famille.
//
//  La seule opération arithmétique de cette page est le RAMENÉ SUR 20 d'une
//  note isolée — une règle de trois sur une valeur unique, pas une agrégation.
//  Sans elle, un devoir sur 40 et une interrogation sur 10 se lisent côte à
//  côte comme s'ils disaient la même chose.
//
//  ── POURQUOI LES NOTES SONT BORNÉES À UNE ANNÉE ────────────────────────────
//  L'école la plus chargée porte déjà 38 544 notes, et chaque `db.watch` se
//  rejoue à chaque tick de synchronisation, sur un portable d'entrée de gamme.
//  Personne n'ouvre la fiche d'un terminal pour lire ses notes de sixième :
//  on charge l'année regardée, et le sélecteur permet d'aller voir ailleurs.
// ════════════════════════════════════════════════════════════════════════════

class FicheResultats extends ConsumerWidget {
  const FicheResultats({super.key, required this.studentId, required this.annee});

  final String studentId;
  final AnneeFiche? annee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bulletins =
        ref.watch(ficheBulletinsProvider(studentId)).valueOrNull ??
            const <BulletinLigne>[];
    final a = annee;
    final notes = a == null
        ? const <NoteLigne>[]
        : ref.watch(ficheNotesProvider((studentId, a.id))).valueOrNull ??
            const <NoteLigne>[];

    final delAnnee =
        bulletins.where((b) => a == null || b.anneeLabel == a.label).toList();

    return Column(children: [
      _Bulletins(bulletins: bulletins),
      for (final b in delAnnee) _BulletinCarte(bulletin: b),
      _Notes(notes: notes, annee: a),
    ]);
  }
}

class _Bulletins extends StatelessWidget {
  const _Bulletins({required this.bulletins});
  final List<BulletinLigne> bulletins;

  @override
  Widget build(BuildContext context) => FicheSection(
        titre: 'Bulletins',
        icone: Icons.assignment_outlined,
        compte: bulletins.length,
        note: bulletins.isEmpty
            ? null
            : 'Toute la scolarité, du plus récent au plus ancien',
        action: FicheRenvoi(
          label: 'Module Évaluation',
          onTap: () => context.push(Routes.bulletins),
        ),
        enfants: [
          if (bulletins.isEmpty)
            const FicheVide(
              'Aucun bulletin arrêté pour cet élève — aucun conseil de classe '
              "n'a encore statué, ou les bulletins ne sont pas encore publiés.",
            )
          else
            FicheTableau(
              entetes: const [
                'Année',
                'Période',
                'Moyenne',
                'Classe',
                'Rang',
                'Mention',
                'Décision',
                'État',
              ],
              largeurs: const [100, 110, 80, 80, 90, 110, 150, 100],
              lignes: [
                for (final b in bulletins)
                  [
                    b.anneeLabel,
                    b.trimestre,
                    b.moyenne == null ? '' : '${_num1(b.moyenne)}/20',
                    b.moyenneClasse == null ? '' : _num1(b.moyenneClasse),
                    b.rangLabel,
                    b.mention,
                    distinctionConseilLabel(b.decision),
                    bulletinStatutLabel(b.statut),
                  ],
              ],
            ),
        ],
      );
}

/// Un bulletin déplié — les appréciations, que le tableau ne peut pas porter.
class _BulletinCarte extends StatelessWidget {
  const _BulletinCarte({required this.bulletin});
  final BulletinLigne bulletin;

  @override
  Widget build(BuildContext context) {
    final b = bulletin;
    return FicheSection(
      titre: '${b.trimestre} · ${b.anneeLabel}',
      icone: Icons.workspace_premium_outlined,
      couleur: kAccent,
      note: b.publieLe == null
          ? 'Non publié — ${bulletinStatutLabel(b.statut)}'
          : 'Publié le ${_dtLong(b.publieLe)}',
      enfants: [
        FicheStats([
          FicheStat(
            label: 'moyenne générale',
            valeur: b.moyenne == null ? '—' : '${_num1(b.moyenne)}/20',
            couleur: b.moyenne == null
                ? null
                : b.moyenne! >= kPassingMark
                    ? kGreen
                    : kRed,
          ),
          FicheStat(
            label: 'moyenne de la classe',
            valeur: b.moyenneClasse == null ? '—' : _num1(b.moyenneClasse),
          ),
          FicheStat(label: 'rang', valeur: b.rangLabel),
          if (b.mention.isNotEmpty)
            FicheStat(label: 'mention', valeur: b.mention, couleur: kAccent),
        ]),
        if (b.decision.isNotEmpty)
          FicheLigne(
            label: 'Décision du conseil',
            valeur: distinctionConseilLabel(b.decision),
            gras: true,
          ),
        // Les absences du bulletin sont celles ARRÊTÉES par le conseil ; elles
        // peuvent différer du registre d'appel, qui continue de vivre. On dit
        // donc d'où vient le chiffre.
        FicheLigne(
          label: 'Absences retenues au bulletin',
          valeur: b.absences == null ? '' : '${b.absences}',
        ),
        FicheLigne(
          label: 'Retards retenus au bulletin',
          valeur: b.retards == null ? '' : '${b.retards}',
        ),
        if (b.appreciationProf.isNotEmpty)
          FicheLigne(
            label: 'Appréciation du professeur principal',
            valeur: b.appreciationProf,
          ),
        if (b.appreciationDirecteur.isNotEmpty)
          FicheLigne(
            label: 'Appréciation du chef d\'établissement',
            valeur: b.appreciationDirecteur,
          ),
      ],
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.notes, required this.annee});

  final List<NoteLigne> notes;
  final AnneeFiche? annee;

  @override
  Widget build(BuildContext context) {
    // Le regroupement par matière est fait ICI et non en SQL : la requête rend
    // déjà les lignes triées par matière, et un `GROUP BY` obligerait à
    // relire la table une seconde fois pour retrouver le détail.
    final parMatiere = <String, List<NoteLigne>>{};
    for (final n in notes) {
      parMatiere.putIfAbsent(n.matiere.isEmpty ? '—' : n.matiere, () => [])
          .add(n);
    }

    return FicheSection(
      titre: 'Notes',
      icone: Icons.grading_outlined,
      compte: notes.length,
      note: annee == null
          ? null
          : 'Année ${annee!.label} — les autres années se lisent avec le '
              'sélecteur ci-dessus',
      enfants: [
        if (notes.isEmpty)
          const FicheVide(
            'Aucune note saisie pour cette année — soit les évaluations '
            "n'ont pas encore eu lieu, soit elles ne sont pas encore "
            'renseignées.',
          )
        else
          for (final entry in parMatiere.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: kNavy,
                ),
              ),
            ),
            FicheTableau(
              entetes: const [
                'Évaluation',
                'Période',
                'Date',
                'Note',
                'Sur 20',
                'Coef.',
              ],
              largeurs: const [200, 110, 100, 90, 80, 70],
              lignes: [
                for (final n in entry.value)
                  [
                    [n.titre, if (n.type.isNotEmpty) '(${n.type})'].join(' '),
                    n.trimestre,
                    _dt(n.date),
                    // ⚠️ « Absent » et « 0 » ne sont pas la même chose : la
                    // première n'entre pas dans une moyenne, la seconde
                    // l'écrase. Les afficher pareil ferait contester la note.
                    n.absent
                        ? 'Absent'
                        : n.note == null
                            ? ''
                            : '${_num1(n.note)}'
                                '${n.bareme == null ? '' : '/${_num1(n.bareme)}'}',
                    n.absent ? '' : _num1(n.sur20),
                    _num1(n.coefficient),
                  ],
              ],
            ),
          ],
      ],
    );
  }
}
