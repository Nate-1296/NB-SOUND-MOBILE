import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';
import '../theme/nb_theme.dart';
import 'app_icons.dart';
import 'cover.dart';

/// Mini-reproductor flotante. Espejo de `MiniPlayer` del diseño; prop-based,
/// el cableado al controlador de reproducción ocurre en la capa de feature.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.progress,
    this.cover,
    this.coverGradient,
    this.positionLabel,
    this.durationLabel,
    this.onTap,
    this.onToggle,
    this.onNext,
  });

  final String title;
  final String subtitle;
  final bool playing;

  /// Progreso normalizado 0..1.
  final double progress;
  final ImageProvider? cover;
  final Gradient? coverGradient;
  final String? positionLabel;
  final String? durationLabel;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: c.bg2.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: c.line2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x73000000),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: <Widget>[
                        Cover(
                          image: cover,
                          gradient: coverGradient,
                          size: 44,
                          radius: 9,
                          shadow: false,
                        ),
                        const SizedBox(width: 11),
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
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: NbFonts.ui,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: c.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (positionLabel != null && durationLabel != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            '$positionLabel / $durationLabel',
                            style: TextStyle(
                              fontFamily: NbFonts.ui,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: c.text3,
                            ),
                          ),
                        ],
                        IconButton(
                          onPressed: onToggle,
                          icon: Icon(
                            playing ? AppIcons.pause : AppIcons.play,
                            size: 19,
                            color: c.text,
                          ),
                        ),
                        IconButton(
                          onPressed: onNext,
                          icon: Icon(AppIcons.next, size: 18, color: c.text2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 2.5,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(color: c.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
