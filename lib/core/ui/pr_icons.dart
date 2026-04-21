import 'package:flutter/material.dart';

/// Curated icon aliases — we commit to Material Rounded for everything.
///
/// Why rounded over filled: the default `Icons.xxx` filled set is what every
/// Flutter app on earth uses, which is exactly why we don't. The rounded
/// variants are softer, read as more "authored", and are already bundled
/// with Flutter (no extra dependency weight).
///
/// Add new icons here rather than importing `Icons.xxx_rounded` directly at
/// call sites — makes a future icon-library swap (to Phosphor, Lucide, etc.)
/// a one-file change instead of a mass-find-replace.
abstract final class PrIcons {
  // Navigation / chrome
  static const back = Icons.arrow_back_rounded;
  static const close = Icons.close_rounded;
  static const more = Icons.more_horiz_rounded;
  static const chevronRight = Icons.chevron_right_rounded;
  static const chevronDown = Icons.keyboard_arrow_down_rounded;

  // Primary actions
  static const plus = Icons.add_rounded;
  static const play = Icons.play_arrow_rounded;
  static const pause = Icons.pause_rounded;
  static const edit = Icons.edit_rounded;
  static const save = Icons.bookmark_border_rounded;
  static const check = Icons.check_rounded;
  static const share = Icons.ios_share_rounded;

  // Media / video
  static const camera = Icons.videocam_rounded;
  static const gallery = Icons.photo_library_rounded;
  static const image = Icons.image_rounded;
  static const mic = Icons.mic_rounded;
  static const music = Icons.music_note_rounded;
  static const film = Icons.local_movies_rounded;
  static const sparkle = Icons.auto_awesome_rounded;
  static const layers = Icons.layers_rounded;
  static const text = Icons.text_fields_rounded;
  static const price = Icons.sell_rounded;
  static const qr = Icons.qr_code_2_rounded;
  static const countdown = Icons.timer_rounded;

  // Feedback
  static const success = Icons.check_circle_rounded;
  static const warn = Icons.warning_amber_rounded;
  static const error = Icons.error_outline_rounded;
  static const info = Icons.info_outline_rounded;

  // Affordances
  static const drag = Icons.drag_indicator_rounded;
  static const reorder = Icons.reorder_rounded;
  static const duplicate = Icons.content_copy_rounded;
  static const trash = Icons.delete_outline_rounded;
  static const refresh = Icons.refresh_rounded;
  static const download = Icons.file_download_outlined;
  static const upload = Icons.file_upload_outlined;

  // Brand
  static const pro = Icons.workspace_premium_rounded;
  static const lock = Icons.lock_outline_rounded;
  static const branding = Icons.storefront_rounded;

  // Social
  static const whatsapp = Icons.chat_rounded;

  // Directional / transform
  static const swap = Icons.swap_horiz_rounded;
  static const flip = Icons.flip_rounded;
  static const rotate = Icons.refresh_rounded;
}
