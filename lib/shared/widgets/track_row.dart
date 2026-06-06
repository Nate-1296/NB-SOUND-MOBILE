import 'package:flutter/material.dart';

import '../../core/utils/duration_format.dart';
import '../theme/nb_colors.dart';
import '../theme/nb_theme.dart';
import 'app_icons.dart';
import 'cover.dart';

/// Fila de pista reutilizable. Espejo de `TrackRow` del diseño; recibe props
/// escalares para no acoplarse a la capa de datos.
class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.cover,
    this.coverGradient,
    this.durationSeconds,
    this.index,
    this.showCover = true,
    this.playing = false,
    this.liked = false,
    this.compact = false,
    this.downloaded = false,
    this.onTap,
    this.onMore,
  });

  final String title;
  final String subtitle;
  final ImageProvider? cover;
  final Gradient? coverGradient;
  final num? durationSeconds;

  /// Número de pista, mostrado cuando [showCover] es false.
  final int? index;
  final bool showCover;
  final bool playing;
  final bool liked;
  final bool compact;

  /// Muestra el indicador de pista descargada (disponible offline).
  final bool downloaded;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Color titleColor = playing ? c.accent : c.text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 7 : 8, horizontal: 4),
        child: Row(
          children: <Widget>[
            if (!showCover && index != null)
              SizedBox(
                width: 22,
                child: playing
                    ? Icon(AppIcons.volume, size: 16, color: c.accent)
                    : Text(
                        '$index',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.text3,
                        ),
                      ),
              ),
            if (showCover) ...<Widget>[
              Cover(
                image: cover,
                gradient: coverGradient,
                size: compact ? 42 : 48,
                radius: 9,
                shadow: false,
              ),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      if (liked) ...<Widget>[
                        Icon(AppIcons.heartFilled, size: 11, color: c.text2),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: NbFonts.ui,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: c.text2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (downloaded) ...<Widget>[
              const SizedBox(width: 8),
              Icon(AppIcons.downloadDone, size: 15, color: c.accent),
            ],
            if (durationSeconds != null) ...<Widget>[
              const SizedBox(width: 10),
              Text(
                formatClock(durationSeconds!),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: c.text3,
                ),
              ),
            ],
            IconButton(
              onPressed: onMore,
              visualDensity: VisualDensity.compact,
              icon: Icon(AppIcons.moreV, size: 18, color: c.text3),
            ),
          ],
        ),
      ),
    );
  }
}
