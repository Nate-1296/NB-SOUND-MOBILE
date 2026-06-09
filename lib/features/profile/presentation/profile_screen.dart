import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/secure_store.dart';
import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/section_label.dart';
import '../../../shared/widgets/sub_header.dart';
import '../../sync/application/sync_controller.dart';
import '../../library/application/library_providers.dart';
import '../application/profile_providers.dart';

/// Pantalla de perfil/ajustes. En Bloque 0 incluye el selector de tema en vivo
/// (valida el sistema de temas); en Fase D crecerá con perfil y accesos a sync.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final NbThemeId active = ref.watch(themeControllerProvider);
    final PerfilLocal? perfil = ref.watch(perfilProvider).value;
    final PairedPc? pc = ref.watch(syncControllerProvider).pc;
    // Conteos LOCALES (lo realmente sincronizado en el teléfono), no el total
    // del PC: el perfil del PC informa toda su biblioteca y confundía ("dice
    // 2225, muestra N").
    final int nPistas = ref.watch(pistasProvider).value?.length ?? 0;
    final int nFavoritas = ref.watch(favoritasProvider).value?.length ?? 0;

    final String nombre = (perfil?.nombre.isNotEmpty ?? false)
        ? perfil!.nombre
        : 'NB Sound';
    final String inicial = nombre.substring(0, 1).toUpperCase();
    final String estado = pc != null
        ? 'Conectado · ${pc.nombre}'
        : 'Modo local · sin PC conectado';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            const SubHeader(title: 'Perfil'),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.soft,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.line2, width: 1.5),
                    ),
                    child: Text(
                      inicial,
                      style: TextStyle(
                        fontFamily: NbFonts.display,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: c.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: NbFonts.display,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Icon(
                              pc != null ? AppIcons.wifi : AppIcons.laptop,
                              size: 13,
                              color: pc != null
                                  ? const Color(0xFF3DDC84)
                                  : c.text3,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                estado,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: NbFonts.ui,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: pc != null
                                      ? const Color(0xFF3DDC84)
                                      : c.text2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (nPistas > 0 || nFavoritas > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Row(
                  children: <Widget>[
                    _Stat(valor: '$nPistas', etiqueta: 'pistas'),
                    const SizedBox(width: 12),
                    _Stat(valor: '$nFavoritas', etiqueta: 'favoritas'),
                  ],
                ),
              ),
            const SectionLabel(
              label: 'Apariencia',
              padding: EdgeInsets.fromLTRB(22, 0, 18, 12),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              // Grid de 2 columnas: los chips quedan del mismo ancho (cada celda
              // ocupa la mitad), sin depender del largo de la etiqueta.
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < NbThemeId.values.length; i += 2)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i + 2 < NbThemeId.values.length ? 10 : 0,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _chip(ref, NbThemeId.values[i], active),
                          ),
                          const SizedBox(width: 10),
                          if (i + 1 < NbThemeId.values.length)
                            Expanded(
                              child: _chip(
                                ref,
                                NbThemeId.values[i + 1],
                                active,
                              ),
                            )
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel(
              label: 'Dispositivo',
              padding: EdgeInsets.fromLTRB(22, 0, 18, 12),
            ),
            _Tile(
              icon: AppIcons.cast,
              label: 'Sincronizar con PC',
              onTap: () => context.push('/sync'),
            ),
            _Tile(
              icon: AppIcons.download,
              label: 'Descargas',
              onTap: () => context.push('/descargas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(WidgetRef ref, NbThemeId id, NbThemeId active) => _ThemeChip(
    id: id,
    active: id == active,
    onTap: () => ref.read(themeControllerProvider.notifier).select(id),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.valor, required this.etiqueta});
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              valor,
              style: TextStyle(
                fontFamily: NbFonts.display,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: c.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.id,
    required this.active,
    required this.onTap,
  });

  final NbThemeId id;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Color dot = NbPalettes.byId(id).accent;
    return Material(
      color: active ? c.soft : c.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: active ? c.accent : c.line2, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  id.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? c.accent : c.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: c.text2, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      trailing: Icon(AppIcons.chevronRight, color: c.text3, size: 20),
    );
  }
}
