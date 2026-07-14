part of '../admin_schools_screen.dart';

// ─── Sections « Contacts » et « Identité officielle » du formulaire école ────
// Purement déclaratives : aucun état propre, seulement des contrôleurs de texte
// fournis par le formulaire.

class SchoolContactSection extends StatelessWidget {
  const SchoolContactSection({
    super.key,
    required this.phone,
    required this.email,
    required this.website,
    required this.founded,
    required this.capacity,
    required this.motto,
  });

  final TextEditingController phone, email, website, founded, capacity, motto;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  const _SchFormLabel('CONTACTS'),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: schoolInputDec('Téléphone'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        return v.contains('@') ? null : 'Email invalide';
                      },
                      decoration: schoolInputDec('Email'),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: founded,
                      keyboardType: TextInputType.number,
                      decoration: schoolInputDec('Année de fondation'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      controller: capacity,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null;
                        final n = int.tryParse(t);
                        if (n == null || n < 0) return 'Nombre invalide';
                        return null;
                      },
                      decoration: schoolInputDec("Capacité d'accueil (places)"),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: website,
                    keyboardType: TextInputType.url,
                    decoration: schoolInputDec('Site web'),
                  ),
                  const _SchFormDivider(),
                  const _SchFormLabel('IDENTITÉ OFFICIELLE'),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: motto,
                    maxLines: 3,
                    decoration: schoolInputDec('Devise / Motto de l\'établissement'),
                  ),
        ],
      );
}
