import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';
import '../theme/nb_theme.dart';

/// Cuerpo provisional para pantallas aún sin datos cableados (Fase D los
/// reemplaza con UI real sobre los providers).
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.soft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 30, color: c.accent),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: NbFonts.display,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.text2,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
