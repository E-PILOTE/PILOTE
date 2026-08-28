import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../staff/providers/staff_directory_provider.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/academic_structure_provider.dart';
import '../providers/academic_year_context.dart';
import '../providers/rooms_provider.dart';
import '../providers/school_holidays_provider.dart';
import '../providers/school_periods_provider.dart';
import '../providers/teacher_availability_provider.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/utils/date_scolaire.dart';

part 'edt_rooms_tab.dart';
part 'edt_periods_tab.dart';
part 'edt_periods_form.dart';
part 'edt_availability_tab.dart';
part 'edt_calendar_tab.dart';

const _kSlug = 'emploi-du-temps';

/// Ouvre les paramètres EDT dans un TIROIR latéral droit (pas un onglet) :
///  • Salles : registre des locaux typés (fiabilise les conflits de salle) ;
///  • Trame horaire : la grille de créneaux de l'école (séances/récré/pause) ;
///  • Disponibilités : indispos/préférences enseignant (construit en Vague 3).
/// Le commutateur est un SEGMENT (cohérent avec la page parente sans onglets).
///
/// [initialSegment] ouvre directement la bonne section — cf. [kEdtSegCalendar].
/// Un appelant qui vient consulter les vacances ne doit pas retomber sur les
/// salles et devoir chercher.
void openEdtSettingsDrawer(BuildContext context, {int initialSegment = 0}) {
  showGeneralDialog(
    context: context,
    barrierLabel: 'Paramètres de l\'emploi du temps',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, _, _) => Align(
      alignment: Alignment.centerRight,
      child: EdtSettingsView(initialSegment: initialSegment),
    ),
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  PARAMÈTRES EMPLOI DU TEMPS — panneau de tiroir : en-tête + segment +
//  contenu (IndexedStack pour préserver l'état entre les sections).
// ════════════════════════════════════════════════════════════════════════════
/// Index du segment « Calendrier » (vacances et jours fériés) dans le tiroir.
/// Nommé pour que les appelants n'aient pas à coder un 3 en dur.
const int kEdtSegCalendar = 3;

class EdtSettingsView extends StatefulWidget {
  const EdtSettingsView({super.key, this.initialSegment = 0});
  final int initialSegment;
  @override
  State<EdtSettingsView> createState() => _EdtSettingsViewState();
}

class _EdtSettingsViewState extends State<EdtSettingsView> {
  late int _seg = widget.initialSegment;

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String)>[
      (Icons.meeting_room_outlined, 'Salles'),
      (Icons.schedule_rounded, 'Trame horaire'),
      (Icons.event_busy_outlined, 'Disponibilités'),
      (Icons.beach_access_outlined, 'Calendrier'),
    ];
    final w = MediaQuery.of(context).size.width;
    return Material(
      color: kCardBg,
      child: SizedBox(
        width: w < 620 ? w : 560,
        height: double.infinity,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // En-tête.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder))),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 19, color: kNavy),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Paramètres de l\'emploi du temps',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
          ),
          // Segment (remplace les onglets).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kBorder),
              ),
              child: Row(children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _seg = i),
                      borderRadius: BorderRadius.circular(7),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _seg == i ? kNavy : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(items[i].$1,
                                  size: 15,
                                  color:
                                      _seg == i ? Colors.white : kTextMuted),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(items[i].$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _seg == i
                                            ? Colors.white
                                            : kTextMuted)),
                              ),
                            ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _seg,
              sizing: StackFit.expand,
              children: const [
                _RoomsTab(),
                _PeriodsTab(),
                _AvailabilityTab(),
                _CalendarTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// Sélecteur d'heure 24h partagé entre les onglets → renvoie 'HH:MM'.
Future<String?> _pickHhmm(BuildContext context, String initial) async {
  final p = initial.split(':');
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: int.tryParse(p.first) ?? 8,
      minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
    ),
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (picked == null) return null;
  return '${picked.hour.toString().padLeft(2, '0')}:'
      '${picked.minute.toString().padLeft(2, '0')}';
}

int _hhmmToMin(String hhmm) {
  final p = hhmm.split(':');
  if (p.isEmpty) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 +
      (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
}

// Petit champ « heure » cliquable réutilisé dans les deux formulaires.
class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onTap});
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: adminFilledInput(label, icon: Icons.schedule_rounded),
          child: Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
        ),
      );
}
