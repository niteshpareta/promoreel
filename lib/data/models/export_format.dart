import 'package:flutter/material.dart';

enum ExportFormat { vertical, square, landscape }

extension ExportFormatX on ExportFormat {
  double get outWidth  => this == ExportFormat.landscape ? 1280 : 720;
  double get outHeight => this == ExportFormat.square ? 720 : (this == ExportFormat.landscape ? 720 : 1280);
  double get aspectRatio => outWidth / outHeight;

  String get label => switch (this) {
        ExportFormat.vertical  => '9:16',
        ExportFormat.square    => '1:1',
        ExportFormat.landscape => '16:9',
      };

  IconData get icon => switch (this) {
        ExportFormat.vertical  => Icons.stay_current_portrait_rounded,
        ExportFormat.square    => Icons.crop_square_rounded,
        ExportFormat.landscape => Icons.stay_current_landscape_rounded,
      };
}
