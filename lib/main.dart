// Entry point de NB Sound Mobile.
//
// Arranque: abre la BD local (Drift) y la siembra si está vacía, inicializa el
// servicio de audio (audio_service + just_audio) y monta el ProviderScope
// (Riverpod) raíz proveyendo ambos. Tema y routing los resuelve [NbSoundApp].

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/nb_sound_app.dart';
import 'core/di/providers.dart';
import 'core/network/pinned_http_overrides.dart';
import 'data/db/daos/sync_state_dao.dart';
import 'data/db/database.dart';
import 'data/db/seed/dev_seed.dart';
import 'features/player/application/nb_audio_handler.dart';
import 'features/player/application/player_controller.dart';
import 'shared/theme/nb_theme.dart';
import 'shared/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pinning TLS global para NetworkImage y el proxy de just_audio (rutas que no
  // pasan por dio). La huella del PC emparejado la fija NbSoundApp.
  HttpOverrides.global = NbHttpOverrides();

  final AppDatabase database = AppDatabase();
  await applyDevSeedIfEmpty(database);

  // Preferencias persistidas (sobreviven reinicios): tema y estado global del
  // reproductor (aleatorio/repetición).
  final SyncStateDao syncState = database.syncStateDao;
  final NbThemeId initialTheme =
      NbThemeId.fromName(await syncState.getValor(kTemaPrefKey));
  final bool initialShuffle =
      await syncState.getValor(SyncStateDao.kAleatorio) == '1';
  final String? repeatPref = await syncState.getValor(SyncStateDao.kRepeticion);
  final RepeatMode initialRepeat = RepeatMode.values.firstWhere(
    (RepeatMode m) => m.name == repeatPref,
    orElse: () => RepeatMode.off,
  );

  final Directory docsDir = await getApplicationDocumentsDirectory();
  final Directory audioDir = Directory(p.join(docsDir.path, 'audio'));

  // audio_service / just_audio solo tienen implementación en móvil. En
  // escritorio/web se usa un handler "preview" (UI sin audio real).
  final bool mobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final NbAudioHandler audioHandler = mobile
      ? await AudioService.init(
          builder: NbAudioHandler.new,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.nbsound.audio',
            androidNotificationChannelName: 'NB Sound',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
          ),
        )
      : NbAudioHandler(preview: true);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        audioHandlerProvider.overrideWithValue(audioHandler),
        appAudioDirProvider.overrideWithValue(audioDir),
        initialThemeProvider.overrideWithValue(initialTheme),
        initialShuffleProvider.overrideWithValue(initialShuffle),
        initialRepeatProvider.overrideWithValue(initialRepeat),
      ],
      child: const NbSoundApp(),
    ),
  );
}
