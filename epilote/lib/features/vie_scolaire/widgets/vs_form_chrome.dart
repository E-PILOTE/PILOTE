import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Chrome de dialogue-formulaire partagé (vie scolaire) : en-tête (icône +
//  titre + fermer) et barre d'actions (Annuler / Créer·Enregistrer). Garantit
//  un rendu identique entre les formulaires Discipline / Infirmerie.
// ════════════════════════════════════════════════════════════════════════════
Widget vsFormHeader(BuildContext context, String title, IconData icon) =>
    Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
      child: Row(children: [
        Icon(icon, size: 18, color: kNavy),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
        ),
        IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context)),
      ]),
    );

Widget vsFormActions(
        BuildContext context, bool saving, VoidCallback onSave, bool isEdit) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(isEdit ? 'Enregistrer' : 'Créer'),
          ),
        ),
      ]),
    );
