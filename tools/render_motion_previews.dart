// Renders one animated WebP per:
//   • slide-to-slide TRANSITION (→ assets/motion_previews/transition/<id>.webp)
//   • per-slide CAMERA MOTION  (→ assets/motion_previews/camera/<id>.webp)
//
// Called once from the project root:
//
//     dart tools/render_motion_previews.dart
//
// Re-run after adding / removing a transition or camera option.
//
// Requires `ffmpeg` on PATH — or set the `FFMPEG` env var to a custom
// binary location. Preview dimensions are 180×320 (9:16) at 20 fps.

import 'dart:io';

const int kWidth = 180;
const int kHeight = 320;
const int kFps = 20;

/// 1.2-second clip: 0.3s outgoing hold → 0.6s xfade → 0.3s incoming hold.
const double kClipDur = 1.2;
const double kTransitionDur = 0.6;
const double kOffset = 0.3;

enum _Camera { none, zoomInStandard, zoomInSubtle, kenBurnsPan, quickPulse, popPulse }

/// All transitions exposed in the picker. Transition previews always use
/// `camera=none` so each tile isolates the transition itself.
const List<String> kTransitions = [
  'fade', 'dissolve', 'fadeblack', 'fadewhite',
  'slideup', 'slidedown', 'slideleft', 'slideright',
  'wipeup', 'wipedown', 'wipeleft',
  'wipetl', 'wipetr', 'wipebl', 'wipebr',
  'circleopen', 'circleclose', 'rectcrop',
  'coverleft', 'coverright', 'coverup', 'coverdown',
  'revealleft', 'revealright',
  'fadegrays', 'pixelize', 'hblur',
  'smoothleft', 'smoothright',
];

/// Camera motions exposed in the picker. Camera previews always use
/// `transition=fade` (short) so each tile isolates the motion itself.
const List<(String, _Camera)> kCameras = [
  ('none',         _Camera.none),
  ('slowZoom',     _Camera.zoomInStandard),
  ('zoomInSubtle', _Camera.zoomInSubtle),
  ('kenBurnsPan',  _Camera.kenBurnsPan),
  ('quickPulse',   _Camera.quickPulse),
  ('popPulse',     _Camera.popPulse),
];

Future<void> main() async {
  final ffmpeg = Platform.environment['FFMPEG'] ??
      (await _which('ffmpeg')) ??
      (File('${Platform.environment['HOME']}/.local/bin/ffmpeg').existsSync()
          ? '${Platform.environment['HOME']}/.local/bin/ffmpeg'
          : 'ffmpeg');
  stdout.writeln('Using ffmpeg at: $ffmpeg');

  final repoRoot = Directory.current.path;
  final transitionDir =
      Directory('$repoRoot/assets/motion_previews/transition');
  final cameraDir = Directory('$repoRoot/assets/motion_previews/camera');
  await transitionDir.create(recursive: true);
  await cameraDir.create(recursive: true);

  final slideA = '$repoRoot/build/_motion_previews_A.png';
  final slideB = '$repoRoot/build/_motion_previews_B.png';
  await Directory('$repoRoot/build').create(recursive: true);
  await _generateSlide(ffmpeg,
      out: slideA, fillColor: '0xF2A848', label: 'A');
  await _generateSlide(ffmpeg,
      out: slideB, fillColor: '0x1F3A8A', label: 'B');
  stdout.writeln('Slides ready.\n');

  int ok = 0, failed = 0;

  stdout.writeln('── Transition previews ────────────────');
  for (final t in kTransitions) {
    final outPath = '${transitionDir.path}/$t.webp';
    stdout.write('  transition/$t ... ');
    final r = await _renderClip(ffmpeg,
        slideA: slideA, slideB: slideB,
        xfadeType: t, camera: _Camera.none, outPath: outPath);
    stdout.writeln(r ? 'ok' : 'FAILED');
    r ? ok++ : failed++;
  }

  stdout.writeln('\n── Camera-motion previews ────────────');
  for (final c in kCameras) {
    final outPath = '${cameraDir.path}/${c.$1}.webp';
    stdout.write('  camera/${c.$1} ... ');
    // For camera previews, show a short fade between slides so the
    // viewer sees the camera motion stretched across both slides.
    final r = await _renderClip(ffmpeg,
        slideA: slideA, slideB: slideB,
        xfadeType: 'fade', camera: c.$2, outPath: outPath);
    stdout.writeln(r ? 'ok' : 'FAILED');
    r ? ok++ : failed++;
  }

  File(slideA).deleteSync();
  File(slideB).deleteSync();

  stdout.writeln('\nDone: $ok ok, $failed failed.');
  stdout.writeln('  transitions → ${transitionDir.path}');
  stdout.writeln('  cameras     → ${cameraDir.path}');
  if (failed > 0) exit(1);
}

Future<String?> _which(String cmd) async {
  try {
    final r = await Process.run('which', [cmd]);
    if (r.exitCode == 0) return (r.stdout as String).trim();
  } catch (_) {}
  return null;
}

Future<void> _generateSlide(String ffmpeg,
    {required String out,
    required String fillColor,
    required String label}) async {
  final fontFile = Platform.isMacOS
      ? '/System/Library/Fonts/Helvetica.ttc'
      : '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf';
  final r = await Process.run(ffmpeg, [
    '-y',
    '-f', 'lavfi',
    '-i', 'color=c=$fillColor:s=${kWidth}x$kHeight:d=1',
    '-vf',
    "drawtext=fontfile='$fontFile':text='$label':"
        "fontcolor=white:fontsize=120:"
        "x=(w-text_w)/2:y=(h-text_h)/2-10",
    '-frames:v', '1',
    out,
  ]);
  if (r.exitCode != 0) throw StateError('Slide gen failed:\n${r.stderr}');
}

Future<bool> _renderClip(
  String ffmpeg, {
  required String slideA,
  required String slideB,
  required String xfadeType,
  required _Camera camera,
  required String outPath,
}) async {
  final motionA = _motionFilter(camera, slideIdx: 0);
  final motionB = _motionFilter(camera, slideIdx: 1);
  final filter = StringBuffer()
    ..write('[0:v]fps=$kFps$motionA,format=yuv420p[a]; ')
    ..write('[1:v]fps=$kFps$motionB,format=yuv420p[b]; ')
    ..write('[a][b]xfade=transition=$xfadeType'
        ':duration=$kTransitionDur:offset=$kOffset');
  final r = await Process.run(ffmpeg, [
    '-y',
    '-hide_banner', '-loglevel', 'error',
    '-loop', '1', '-t', kClipDur.toString(), '-i', slideA,
    '-loop', '1', '-t', kClipDur.toString(), '-i', slideB,
    '-filter_complex', filter.toString(),
    '-loop', '0',
    '-lossless', '0',
    '-compression_level', '6',
    '-quality', '70',
    outPath,
  ]);
  if (r.exitCode != 0) {
    stderr.writeln('  ↪ stderr: ${r.stderr}');
  }
  return r.exitCode == 0;
}

/// Mirrors `MotionStyleEngine._motionFilter` — the same math the real
/// export uses — so the preview tile matches the exported slide.
String _motionFilter(_Camera motion, {required int slideIdx}) {
  final dur = kClipDur.toStringAsFixed(3);
  switch (motion) {
    case _Camera.none:
      return '';
    case _Camera.zoomInStandard:
      return ",scale=w='$kWidth*(1+0.15*t/$dur)':h='$kHeight*(1+0.15*t/$dur)':eval=frame"
          ",crop=$kWidth:$kHeight:(iw-$kWidth)/2:(ih-$kHeight)/2";
    case _Camera.zoomInSubtle:
      return ",scale=w='$kWidth*(1+0.08*t/$dur)':h='$kHeight*(1+0.08*t/$dur)':eval=frame"
          ",crop=$kWidth:$kHeight:(iw-$kWidth)/2:(ih-$kHeight)/2";
    case _Camera.quickPulse:
      const expr = '(1.05)-0.05*min(t,0.3)/0.3';
      return ",scale=w='$kWidth*($expr)':h='$kHeight*($expr)':eval=frame"
          ",crop=$kWidth:$kHeight:(iw-$kWidth)/2:(ih-$kHeight)/2";
    case _Camera.popPulse:
      const expr = '(1.12)-0.12*min(t,0.45)/0.45';
      return ",scale=w='$kWidth*($expr)':h='$kHeight*($expr)':eval=frame"
          ",crop=$kWidth:$kHeight:(iw-$kWidth)/2:(ih-$kHeight)/2";
    case _Camera.kenBurnsPan:
      final frames = (kClipDur * kFps).round();
      final scaled = (kWidth * 1.15).round();
      final xMax = (scaled - kWidth).toString();
      final xExpr = slideIdx.isEven
          ? "on/(${frames - 1})*$xMax"
          : "(1-on/(${frames - 1}))*$xMax";
      return ",scale=$scaled:-1,zoompan=z=1.15"
          ":x='$xExpr':y='(ih-oh)/2':d=1:s=${kWidth}x$kHeight:fps=$kFps";
  }
}
