import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/security/secure_store.dart';
import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/sub_header.dart';
import '../application/sync_controller.dart';

/// Flujo de sincronización con el PC: intro → escaneo QR → conexión → conectado.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final SyncState s = ref.watch(syncControllerProvider);

    return Scaffold(
      backgroundColor: s.phase == SyncPhase.scanning ? Colors.black : c.bg,
      body: SafeArea(
        child: switch (s.phase) {
          SyncPhase.scanning => const _Scanner(),
          SyncPhase.connecting => const _Connecting(),
          SyncPhase.connected => _Connected(pc: s.pc),
          SyncPhase.error => _ErrorView(code: s.errorCode),
          SyncPhase.intro => const _Intro(),
        },
      ),
    );
  }
}

class _Intro extends ConsumerWidget {
  const _Intro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    return Column(
      children: <Widget>[
        const SubHeader(title: 'Sincronizar con PC'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              children: <Widget>[
                Icon(AppIcons.laptop, size: 56, color: c.accent),
                const SizedBox(height: 18),
                Text(
                  'Lleva tu música contigo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NbFonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Conecta esta app a NB Sound en tu computadora. Todo viaja por '
                  'tu red local, sin nube.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: c.text2,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.line),
                  ),
                  child: Column(
                    children: <Widget>[
                      Icon(AppIcons.qr, size: 40, color: c.text2),
                      const SizedBox(height: 14),
                      Text(
                        'En tu PC abre NB Sound → Sincronizar y muestra el '
                        'código QR.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          color: c.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        ref.read(syncControllerProvider.notifier).startScan(),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.ink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(AppIcons.qr, color: c.ink),
                    label: Text(
                      'Escanear código QR',
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Alternativa sin cámara (Chromebook, cámara dañada, etc.):
                // escribir la IP del PC. La app descubre el puerto y fija la
                // huella TLS automáticamente; solo hace falta el código del QR.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _mostrarConexionIp(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text2,
                      side: BorderSide(color: c.line2),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(AppIcons.laptop, color: c.text2, size: 18),
                    label: Text(
                      'Sin cámara: conectar por IP',
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: c.text2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Hoja de conexión manual por IP (sin cámara).
Future<void> _mostrarConexionIp(BuildContext context, WidgetRef ref) {
  final NbColors c = context.nb;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.bg2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext _) => const _ManualIpSheet(),
  );
}

class _ManualIpSheet extends ConsumerStatefulWidget {
  const _ManualIpSheet();

  @override
  ConsumerState<_ManualIpSheet> createState() => _ManualIpSheetState();
}

class _ManualIpSheetState extends ConsumerState<_ManualIpSheet> {
  final TextEditingController _dir = TextEditingController();
  final TextEditingController _codigo = TextEditingController();

  @override
  void dispose() {
    _dir.dispose();
    _codigo.dispose();
    super.dispose();
  }

  void _conectar() {
    final String dir = _dir.text.trim();
    final String code = _codigo.text.trim();
    if (dir.isEmpty || code.isEmpty) {
      return;
    }
    // Cierra la hoja; la pantalla principal refleja connecting→connected/error.
    Navigator.of(context).pop();
    ref.read(syncControllerProvider.notifier).conectarPorIp(dir, code);
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Conectar por IP',
            style: TextStyle(
              fontFamily: NbFonts.display,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'En el PC, abre NB Sound → Sincronizar. Escribe la "Dirección en la '
            'red local" y el código del QR.',
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 13,
              height: 1.45,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dir,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: c.text, fontFamily: NbFonts.ui),
            decoration: _dec(c, 'Dirección del PC', 'p. ej. 192.168.1.40:8731'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codigo,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _conectar(),
            style: TextStyle(color: c.text, fontFamily: NbFonts.ui),
            decoration: _dec(c, 'Código de un solo uso', 'el del QR'),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _conectar,
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.ink,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Conectar',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(NbColors c, String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: c.text2, fontFamily: NbFonts.ui),
      hintStyle: TextStyle(color: c.text3, fontFamily: NbFonts.ui),
      filled: true,
      fillColor: c.bg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.line2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.accent),
      ),
    );
  }
}

class _Scanner extends ConsumerStatefulWidget {
  const _Scanner();

  @override
  ConsumerState<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends ConsumerState<_Scanner>
    with WidgetsBindingObserver {
  // Controller propio limitado a QR: ML Kit construye solo el detector de QR
  // (más liviano y evita rutas de otros formatos). Con un controller propio, el
  // ciclo de vida y el dispose los maneja este State; el widget solo lo arranca
  // (autoStart) y lo detiene al desmontarse.
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _manejado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_manejado) {
      return;
    }
    for (final Barcode b in capture.barcodes) {
      final String? raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _manejado = true;
        ref.read(syncControllerProvider.notifier).onQrDetected(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // Errores transitorios al procesar un frame no deben tumbar la UI.
            onDetectError: (Object error, StackTrace stack) {},
            errorBuilder:
                (BuildContext context, MobileScannerException error) =>
                    _ScannerError(
                      error: error,
                      onReintentar: () => unawaited(_controller.start()),
                      onCerrar: () =>
                          ref.read(syncControllerProvider.notifier).cancel(),
                    ),
          ),
        ),
        // Decoraciones (mira, cerrar, ayuda) solo con la cámara activa; si hay
        // error, el errorBuilder ocupa la pantalla y se ocultan.
        Positioned.fill(
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder:
                (BuildContext context, MobileScannerState state, Widget? _) {
                  if (state.error != null) {
                    return const SizedBox.shrink();
                  }
                  return Stack(
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF1FD4E6),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: IconButton(
                          onPressed: () => ref
                              .read(syncControllerProvider.notifier)
                              .cancel(),
                          icon: const Icon(
                            AppIcons.close,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 48,
                        child: Text(
                          'Apunta al código QR de NB Sound',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: NbFonts.ui,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                },
          ),
        ),
      ],
    );
  }
}

/// UI de error del escáner: reemplaza el overlay crudo (en inglés) de
/// mobile_scanner por un mensaje claro en español con reintentar/cerrar. El
/// detalle técnico se muestra en pequeño para diagnóstico (p. ej. errores
/// nativos de ML Kit).
class _ScannerError extends StatelessWidget {
  const _ScannerError({
    required this.error,
    required this.onReintentar,
    required this.onCerrar,
  });

  final MobileScannerException error;
  final VoidCallback onReintentar;
  final VoidCallback onCerrar;

  String get _mensaje => switch (error.errorCode) {
    MobileScannerErrorCode.permissionDenied =>
      'Sin permiso de cámara. Habilítalo para escanear el código QR.',
    MobileScannerErrorCode.unsupported =>
      'Este dispositivo no admite el escáner de cámara.',
    _ => 'No se pudo iniciar la cámara para escanear el QR.',
  };

  @override
  Widget build(BuildContext context) {
    final String? detalle = error.errorDetails?.message;
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(AppIcons.close, color: Colors.white70, size: 44),
            const SizedBox(height: 16),
            Text(
              _mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: Colors.white,
              ),
            ),
            if (detalle != null && detalle.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                detalle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 11.5,
                  color: Colors.white38,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                OutlinedButton(
                  onPressed: onCerrar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('Cerrar'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onReintentar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting();

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(color: c.accent),
          const SizedBox(height: 24),
          Text(
            'Estableciendo conexión…',
            style: TextStyle(
              fontFamily: NbFonts.display,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enlazando con el PC por la red local',
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 13.5,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Connected extends ConsumerWidget {
  const _Connected({required this.pc});
  final PairedPc? pc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final SyncState s = ref.watch(syncControllerProvider);
    return Column(
      children: <Widget>[
        const SubHeader(title: 'Sincronización'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: c.soft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(AppIcons.laptop, color: c.accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              pc?.nombre ?? 'NB Sound PC',
                              style: TextStyle(
                                fontFamily: NbFonts.ui,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Row(
                              children: <Widget>[
                                Icon(
                                  AppIcons.wifi,
                                  size: 13,
                                  color: Color(0xFF3DDC84),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Conectado · misma red local',
                                  style: TextStyle(
                                    fontFamily: NbFonts.ui,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3DDC84),
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: s.syncing
                        ? null
                        : () => ref
                              .read(syncControllerProvider.notifier)
                              .syncNow(),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.ink,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: s.syncing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.ink,
                            ),
                          )
                        : Icon(AppIcons.refresh, color: c.ink, size: 18),
                    label: Text(
                      s.syncing ? 'Sincronizando…' : 'Sincronizar ahora',
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                  ),
                ),
                if (s.lastSync != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _InfoTile(
                    text:
                        '✓ Sincronizado · ${s.lastSync!.totalEntidades} '
                        'entidades · ${s.lastSync!.tombstones} borrados · '
                        'subido ${s.lastSync!.historialSubido} de historial.',
                  ),
                ],
                if (s.syncError != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _InfoTile(
                    text: s.syncError == 'token_invalido_o_expirado'
                        ? 'El PC revocó este dispositivo. Vuelve a emparejar.'
                        : 'No se pudo sincronizar. Verifica que el PC esté en '
                              'la misma red.',
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        ref.read(syncControllerProvider.notifier).disconnect(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text2,
                      side: BorderSide(color: c.line2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Desconectar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 13,
          height: 1.5,
          color: c.text2,
        ),
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.code});
  final String? code;

  static const Map<String, String> _messages = <String, String>{
    'qr_invalido':
        'El código no es válido. Asegúrate de escanear el QR de NB Sound.',
    'token_invalido_o_expirado':
        'El código expiró. Genera uno nuevo en el PC e inténtalo otra vez.',
    'error_red':
        'No se pudo conectar con el PC. Verifica que ambos estén en la misma '
        'red local.',
    'respuesta_invalida': 'El PC respondió algo inesperado.',
    'pc_no_encontrado':
        'No se encontró NB Sound en esa IP. Revisa la dirección y que el '
        'servidor esté encendido en el PC (misma red).',
    'direccion_invalida': 'La dirección no es válida. Usa la IP o IP:puerto.',
    'datos_incompletos': 'Escribe la IP del PC y el código de un solo uso.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    return Column(
      children: <Widget>[
        const SubHeader(title: 'Sincronizar con PC'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(AppIcons.close, size: 48, color: c.text3),
                const SizedBox(height: 16),
                Text(
                  _messages[code] ?? 'No se pudo emparejar (${code ?? '—'}).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: c.text2,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  // Vuelve a la intro: el usuario elige reintentar por QR o IP.
                  onPressed: () =>
                      ref.read(syncControllerProvider.notifier).cancel(),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.ink,
                  ),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
