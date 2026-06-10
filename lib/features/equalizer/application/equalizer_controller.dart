import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/di/providers.dart';
import '../../player/application/nb_audio_handler.dart';
import '../../player/application/player_controller.dart';

/// Presets del ecualizador. Cada uno define una curva de 5 puntos (graves →
/// agudos) en dB que se **remuestrea** al número real de bandas del dispositivo.
enum EqPreset {
  plano,
  grave,
  agudo,
  vocal,
  rock,
  pop,
  electronica,
  custom;

  String get etiqueta => switch (this) {
        EqPreset.plano => 'Plano',
        EqPreset.grave => 'Graves',
        EqPreset.agudo => 'Agudos',
        EqPreset.vocal => 'Voz',
        EqPreset.rock => 'Rock',
        EqPreset.pop => 'Pop',
        EqPreset.electronica => 'Electrónica',
        EqPreset.custom => 'Personalizado',
      };

  /// Curva base (null para [custom], que la define el usuario).
  List<double>? get curva => switch (this) {
        EqPreset.plano => const <double>[0, 0, 0, 0, 0],
        EqPreset.grave => const <double>[6, 3, 0, -1, -2],
        EqPreset.agudo => const <double>[-3, -1, 0, 3, 6],
        EqPreset.vocal => const <double>[-2, 0, 4, 2, -1],
        EqPreset.rock => const <double>[5, 2, -1, 2, 4],
        EqPreset.pop => const <double>[-1, 2, 4, 1, -2],
        EqPreset.electronica => const <double>[6, 4, 0, 3, 5],
        EqPreset.custom => null,
      };
}

/// Estado del ecualizador para la UI.
class EqEstado {
  const EqEstado({
    this.soportado = false,
    this.bandasListas = false,
    this.habilitado = false,
    this.preset = EqPreset.plano,
    this.frecuencias = const <double>[],
    this.ganancias = const <double>[],
    this.minDb = -15,
    this.maxDb = 15,
    this.normalizar = false,
    this.omitirSilencios = false,
    this.presetsGuardados = const <String, List<double>>{},
  });

  /// Hay ecualizador en esta plataforma (Android con reproductor real).
  final bool soportado;

  /// Las bandas ya se leyeron del dispositivo (ocurre tras empezar a reproducir).
  final bool bandasListas;

  final bool habilitado;
  final EqPreset preset;
  final List<double> frecuencias;
  final List<double> ganancias;
  final double minDb;
  final double maxDb;
  final bool normalizar;
  final bool omitirSilencios;

  /// Presets que el usuario ha guardado (nombre → ganancias por banda).
  final Map<String, List<double>> presetsGuardados;

  EqEstado copyWith({
    bool? soportado,
    bool? bandasListas,
    bool? habilitado,
    EqPreset? preset,
    List<double>? frecuencias,
    List<double>? ganancias,
    double? minDb,
    double? maxDb,
    bool? normalizar,
    bool? omitirSilencios,
    Map<String, List<double>>? presetsGuardados,
  }) {
    return EqEstado(
      soportado: soportado ?? this.soportado,
      bandasListas: bandasListas ?? this.bandasListas,
      habilitado: habilitado ?? this.habilitado,
      preset: preset ?? this.preset,
      frecuencias: frecuencias ?? this.frecuencias,
      ganancias: ganancias ?? this.ganancias,
      minDb: minDb ?? this.minDb,
      maxDb: maxDb ?? this.maxDb,
      normalizar: normalizar ?? this.normalizar,
      omitirSilencios: omitirSilencios ?? this.omitirSilencios,
      presetsGuardados: presetsGuardados ?? this.presetsGuardados,
    );
  }
}

/// Ganancia (dB) aplicada por el normalizador de volumen cuando está activo. Un
/// boost moderado del `AndroidLoudnessEnhancer` (en just_audio el target es en dB;
/// valores pequeños ya son audibles). No es una normalización perceptual completa.
const double _normGainDb = 3.0;

// Claves kv de persistencia (SyncEstado).
const String _kOn = 'eq_on';
const String _kPreset = 'eq_preset';
const String _kGains = 'eq_gains';
const String _kNorm = 'eq_norm';
const String _kSkip = 'eq_skip';
const String _kCustom = 'eq_custom';

/// Remuestrea una curva de preset al número de bandas [n] (interpolación lineal),
/// acotando a [minDb, maxDb]. Pura.
List<double> gananciasDePreset(
  List<double> curva,
  int n,
  double minDb,
  double maxDb,
) {
  if (n <= 0) {
    return const <double>[];
  }
  if (n == 1) {
    final double avg = curva.reduce((double a, double b) => a + b) / curva.length;
    return <double>[avg.clamp(minDb, maxDb)];
  }
  double muestra(double pos) {
    if (curva.length == 1) {
      return curva.first;
    }
    final double x = (pos * (curva.length - 1)).clamp(0, (curva.length - 1).toDouble());
    final int lo = x.floor();
    final int hi = x.ceil();
    if (lo == hi) {
      return curva[lo];
    }
    final double frac = x - lo;
    return curva[lo] * (1 - frac) + curva[hi] * frac;
  }

  return <double>[
    for (int i = 0; i < n; i++)
      muestra(i / (n - 1)).clamp(minDb, maxDb),
  ];
}

/// Controlador del ecualizador (Android). Lee las bandas reales del dispositivo,
/// aplica presets/ganancias y persiste el estado (se restaura al arrancar; este
/// provider se mantiene vivo desde la raíz para aplicar la config aun sin abrir la
/// pantalla). En iOS/otros `soportado=false`.
class EqualizerController extends Notifier<EqEstado> {
  NbAudioHandler? _handler;
  AndroidEqualizer? _eq;
  AndroidLoudnessEnhancer? _loud;
  AndroidEqualizerParameters? _params;

  @override
  EqEstado build() {
    _handler = ref.watch(audioHandlerProvider);
    _eq = _handler!.equalizer;
    _loud = _handler!.loudness;
    final bool soportado = _eq != null;
    if (soportado) {
      unawaited(_init());
    }
    return EqEstado(soportado: soportado);
  }

  void _persistir(String clave, String valor) =>
      ref.read(syncStateDaoProvider).setValor(clave, valor);

  Future<void> _init() async {
    // Toggles que no dependen de las bandas: se aplican ya (se restauran).
    final bool on = await _getBool(_kOn);
    final bool norm = await _getBool(_kNorm);
    final bool skip = await _getBool(_kSkip);
    final EqPreset preset = _parsePreset(
        await ref.read(syncStateDaoProvider).getValor(_kPreset));

    await _eq?.setEnabled(on);
    await _aplicarNormalizar(norm);
    await _handler?.setSkipSilence(skip);
    state = state.copyWith(
      habilitado: on,
      normalizar: norm,
      omitirSilencios: skip,
      preset: preset,
    );

    // Las bandas reales del dispositivo solo están disponibles cuando el
    // reproductor se conecta a la plataforma (al empezar a reproducir). Se espera
    // a ese momento sin bloquear; mientras, la UI muestra el aviso.
    final AndroidEqualizerParameters? params = await _eq?.parameters;
    if (params == null) {
      return;
    }
    _params = params;
    final int n = params.bands.length;
    final double minDb = params.minDecibels;
    final double maxDb = params.maxDecibels;

    final List<double> ganancias;
    final List<double>? curva = preset.curva;
    if (curva != null) {
      ganancias = gananciasDePreset(curva, n, minDb, maxDb);
    } else {
      ganancias = _parseGains(
        await ref.read(syncStateDaoProvider).getValor(_kGains),
        n,
        minDb,
        maxDb,
      );
    }
    await _aplicarGanancias(ganancias);
    state = state.copyWith(
      bandasListas: true,
      frecuencias: <double>[for (final AndroidEqualizerBand b in params.bands) b.centerFrequency],
      ganancias: ganancias,
      minDb: minDb,
      maxDb: maxDb,
      presetsGuardados: await _cargarPresetsCustom(),
    );
  }

  Future<Map<String, List<double>>> _cargarPresetsCustom() async {
    final String? raw =
        await ref.read(syncStateDaoProvider).getValor(_kCustom);
    if (raw == null || raw.isEmpty) {
      return const <String, List<double>>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return <String, List<double>>{
          for (final MapEntry<Object?, Object?> e in decoded.entries)
            if (e.value is List)
              e.key.toString(): <double>[
                for (final Object? x in (e.value as List))
                  if (x is num) x.toDouble(),
              ],
        };
      }
    } catch (_) {
      // valor corrupto: se ignora.
    }
    return const <String, List<double>>{};
  }

  /// Guarda las ganancias actuales como un preset con [nombre].
  void guardarPreset(String nombre) {
    final String n = nombre.trim();
    if (n.isEmpty || state.ganancias.isEmpty) {
      return;
    }
    final Map<String, List<double>> mapa =
        Map<String, List<double>>.of(state.presetsGuardados);
    mapa[n] = List<double>.of(state.ganancias);
    state = state.copyWith(presetsGuardados: mapa);
    _persistir(_kCustom, jsonEncode(mapa));
  }

  /// Aplica un preset guardado por el usuario.
  Future<void> aplicarPresetGuardado(String nombre) async {
    final List<double>? g = state.presetsGuardados[nombre];
    if (g == null) {
      return;
    }
    await _aplicarGanancias(g);
    state = state.copyWith(preset: EqPreset.custom, ganancias: g);
    _persistir(_kPreset, EqPreset.custom.name);
    _persistir(_kGains, g.map((double v) => v.toStringAsFixed(1)).join(','));
  }

  /// Borra un preset guardado.
  void borrarPresetGuardado(String nombre) {
    final Map<String, List<double>> mapa =
        Map<String, List<double>>.of(state.presetsGuardados)..remove(nombre);
    state = state.copyWith(presetsGuardados: mapa);
    _persistir(_kCustom, jsonEncode(mapa));
  }

  Future<void> _aplicarGanancias(List<double> ganancias) async {
    final AndroidEqualizerParameters? params = _params;
    if (params == null) {
      return;
    }
    for (int i = 0; i < params.bands.length && i < ganancias.length; i++) {
      await params.bands[i].setGain(ganancias[i]);
    }
  }

  Future<void> _aplicarNormalizar(bool on) async {
    await _loud?.setTargetGain(on ? _normGainDb : 0.0);
    await _loud?.setEnabled(on);
  }

  // ── Comandos (UI) ──────────────────────────────────────────────────────────
  Future<void> setHabilitado(bool on) async {
    await _eq?.setEnabled(on);
    state = state.copyWith(habilitado: on);
    _persistir(_kOn, on ? '1' : '0');
  }

  Future<void> seleccionarPreset(EqPreset preset) async {
    final List<double>? curva = preset.curva;
    if (curva == null) {
      // "Personalizado" sin tocar nada: solo marca el preset.
      state = state.copyWith(preset: EqPreset.custom);
      _persistir(_kPreset, preset.name);
      return;
    }
    final List<double> ganancias =
        gananciasDePreset(curva, state.ganancias.length, state.minDb, state.maxDb);
    await _aplicarGanancias(ganancias);
    state = state.copyWith(preset: preset, ganancias: ganancias);
    _persistir(_kPreset, preset.name);
    _persistir(_kGains, ganancias.map((double g) => g.toStringAsFixed(1)).join(','));
  }

  /// Ajusta la ganancia de una banda. Pasa el preset a "Personalizado".
  Future<void> setGanancia(int banda, double db) async {
    final AndroidEqualizerParameters? params = _params;
    if (params == null || banda < 0 || banda >= params.bands.length) {
      return;
    }
    final double g = db.clamp(state.minDb, state.maxDb);
    await params.bands[banda].setGain(g);
    final List<double> nuevas = List<double>.of(state.ganancias);
    if (banda < nuevas.length) {
      nuevas[banda] = g;
    }
    state = state.copyWith(preset: EqPreset.custom, ganancias: nuevas);
    _persistir(_kPreset, EqPreset.custom.name);
    _persistir(_kGains, nuevas.map((double v) => v.toStringAsFixed(1)).join(','));
  }

  Future<void> setNormalizar(bool on) async {
    await _aplicarNormalizar(on);
    state = state.copyWith(normalizar: on);
    _persistir(_kNorm, on ? '1' : '0');
  }

  Future<void> setOmitirSilencios(bool on) async {
    await _handler?.setSkipSilence(on);
    state = state.copyWith(omitirSilencios: on);
    _persistir(_kSkip, on ? '1' : '0');
  }

  // ── Helpers de carga ───────────────────────────────────────────────────────
  Future<bool> _getBool(String clave) async =>
      await ref.read(syncStateDaoProvider).getValor(clave) == '1';

  static EqPreset _parsePreset(String? v) => EqPreset.values.firstWhere(
        (EqPreset p) => p.name == v,
        orElse: () => EqPreset.plano,
      );

  static List<double> _parseGains(
    String? csv,
    int n,
    double minDb,
    double maxDb,
  ) {
    if (csv == null || csv.isEmpty) {
      return List<double>.filled(n, 0);
    }
    final List<double> vals = <double>[
      for (final String s in csv.split(','))
        (double.tryParse(s) ?? 0).clamp(minDb, maxDb),
    ];
    // Ajusta al número real de bandas (rellena con 0 o recorta).
    if (vals.length == n) {
      return vals;
    }
    return <double>[for (int i = 0; i < n; i++) i < vals.length ? vals[i] : 0.0];
  }
}

final NotifierProvider<EqualizerController, EqEstado> equalizerControllerProvider =
    NotifierProvider<EqualizerController, EqEstado>(EqualizerController.new);
