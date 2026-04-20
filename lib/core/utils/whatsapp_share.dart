import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class WhatsAppShare {
  static const _channel = MethodChannel('com.binaryscript.promoreel/whatsapp');

  /// Share video directly to WhatsApp on Android.
  /// Falls back to system share sheet if WhatsApp is not installed.
  static Future<void> shareVideo(String videoPath) async {
    if (!Platform.isAndroid) {
      await _fallback(videoPath);
      return;
    }
    try {
      final installed = await _channel.invokeMethod<bool>('isWhatsAppInstalled') ?? false;
      if (!installed) {
        await _fallback(videoPath);
        return;
      }
      await _channel.invokeMethod('shareToWhatsApp', {'path': videoPath});
    } on PlatformException {
      await _fallback(videoPath);
    }
  }

  static Future<void> _fallback(String videoPath) async {
    await Share.shareXFiles(
      [XFile(videoPath, mimeType: 'video/mp4', name: 'status_video.mp4')],
      subject: 'Check out my latest offer!',
    );
  }
}
