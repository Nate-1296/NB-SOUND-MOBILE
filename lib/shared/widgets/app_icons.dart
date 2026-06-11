import 'package:flutter/material.dart';

/// Mapeo único de los nombres de íconos del diseño (`icons.jsx`) a su
/// equivalente en Material Icons (variantes outlined/rounded, estética cercana
/// al stroke del diseño). Centralizado para poder migrar a un set "lucide"
/// mantenido si se busca fidelidad pixel-perfect.
abstract final class AppIcons {
  // Navegación inferior.
  static const IconData home = Icons.home_outlined;
  static const IconData search = Icons.search_rounded;
  static const IconData library = Icons.library_music_outlined;
  static const IconData note = Icons.queue_music_outlined;
  static const IconData list = Icons.list_rounded;

  // Controles de reproducción.
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData next = Icons.skip_next_rounded;
  static const IconData prev = Icons.skip_previous_rounded;
  static const IconData shuffle = Icons.shuffle_rounded;
  static const IconData repeat = Icons.repeat_rounded;
  static const IconData repeatOne = Icons.repeat_one_rounded;
  static const IconData volume = Icons.volume_up_rounded;
  static const IconData queue = Icons.queue_music_rounded;
  static const IconData mic = Icons.mic_none_rounded;

  // Favoritos / valoración.
  static const IconData heart = Icons.favorite_border_rounded;
  static const IconData heartFilled = Icons.favorite_rounded;
  static const IconData star = Icons.star_border_rounded;
  static const IconData starFilled = Icons.star_rounded;

  // Sync / dispositivos.
  static const IconData cast = Icons.cast_rounded;
  static const IconData wifi = Icons.wifi_rounded;
  static const IconData laptop = Icons.computer_rounded;
  static const IconData phone = Icons.smartphone_rounded;
  static const IconData qr = Icons.qr_code_scanner_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData sync = Icons.sync_rounded;

  // Navegación / chrome.
  static const IconData chevronDown = Icons.keyboard_arrow_down_rounded;
  static const IconData chevronLeft = Icons.chevron_left_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData expandMore = Icons.expand_more_rounded;
  static const IconData expandLess = Icons.expand_less_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData moreV = Icons.more_vert_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData plus = Icons.add_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData dragHandle = Icons.drag_handle_rounded;

  // Acciones / utilidades.
  static const IconData download = Icons.download_rounded;
  static const IconData downloadDone = Icons.download_done_rounded;
  static const IconData downloading = Icons.downloading_rounded;
  static const IconData downloadOff = Icons.delete_outline_rounded;
  static const IconData folder = Icons.folder_outlined;
  static const IconData clock = Icons.schedule_rounded;
  static const IconData disc = Icons.album_outlined;
  static const IconData edit = Icons.edit_outlined;
  static const IconData trash = Icons.delete_outline_rounded;
  static const IconData settings = Icons.settings_outlined;
  static const IconData user = Icons.person_outline_rounded;
  static const IconData palette = Icons.palette_outlined;
  static const IconData sliders = Icons.tune_rounded;
  static const IconData equalizer = Icons.graphic_eq_rounded;
  static const IconData pin = Icons.push_pin_outlined;
  static const IconData pinFilled = Icons.push_pin_rounded;
  static const IconData sparkles = Icons.auto_awesome_outlined;
  static const IconData bell = Icons.notifications_none_rounded;
  static const IconData globe = Icons.public_rounded;

  // Modos de visualización (lista / cuadrícula).
  static const IconData viewList = Icons.view_list_rounded;
  static const IconData viewGridSmall = Icons.grid_view_rounded;
  static const IconData viewGrid = Icons.grid_on_rounded;
  static const IconData image = Icons.image_outlined;
  static const IconData palette2 = Icons.color_lens_outlined;

  // Pantalla completa (modo letra inmersivo).
  static const IconData fullscreen = Icons.fullscreen_rounded;
  static const IconData fullscreenExit = Icons.fullscreen_exit_rounded;
}
