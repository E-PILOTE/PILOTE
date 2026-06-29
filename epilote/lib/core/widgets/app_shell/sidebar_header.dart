import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../admin_ui.dart' show kNavyDeep, kGreen;
import 'app_shell_theme.dart';

/// En-tête de la sidebar : logo + identité plateforme.
class SidebarHeader extends StatelessWidget {
  const SidebarHeader({super.key, required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kShellHeaderHeight,
      padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 10),
      decoration: BoxDecoration(
        color: kNavyDeep,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/logo.svg',
            width: expanded ? 42 : 36,
            height: expanded ? 42 : 36,
          ),
          if (expanded) ...[
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'E-PILOTE CONGO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'Gestion scolaire',
                    style: TextStyle(
                      color: kGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
