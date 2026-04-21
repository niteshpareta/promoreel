import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Target apps supported by the one-tap multi-platform share sheet.
/// Package names kept here are the single source of truth and match the
/// `<queries>` declarations in AndroidManifest.xml.
enum ShareTarget {
  whatsapp('com.whatsapp', 'WhatsApp'),
  whatsappBusiness('com.whatsapp.w4b', 'WhatsApp Business'),
  instagram('com.instagram.android', 'Instagram'),
  facebook('com.facebook.katana', 'Facebook'),
  facebookLite('com.facebook.lite', 'Facebook Lite'),
  telegram('org.telegram.messenger', 'Telegram'),
  youtube('com.google.android.youtube', 'YouTube Shorts'),
  twitter('com.twitter.android', 'X / Twitter'),
  snapchat('com.snapchat.android', 'Snapchat');

  const ShareTarget(this.packageName, this.displayName);
  final String packageName;
  final String displayName;
}

class VideoShareService {
  static const _channel = MethodChannel('com.binaryscript.promoreel/whatsapp');

  /// Share a video directly to a specific target app. Falls back to the
  /// system share sheet when the platform channel can't reach the target
  /// (non-Android, app not installed, or intent error).
  static Future<bool> shareToTarget(ShareTarget target, String videoPath) async {
    if (!Platform.isAndroid) {
      await _fallback(videoPath);
      return false;
    }
    try {
      await _channel.invokeMethod('shareVideoToApp', {
        'path': videoPath,
        'package': target.packageName,
      });
      return true;
    } on PlatformException {
      await _fallback(videoPath);
      return false;
    }
  }

  /// Legacy WhatsApp-specific entry point — kept for callers that haven't
  /// migrated to [shareToTarget]. New code should call [shareToTarget].
  static Future<void> shareVideo(String videoPath) async {
    if (!Platform.isAndroid) {
      await _fallback(videoPath);
      return;
    }
    try {
      final installed =
          await _channel.invokeMethod<bool>('isWhatsAppInstalled') ?? false;
      if (!installed) {
        await _fallback(videoPath);
        return;
      }
      await _channel.invokeMethod('shareToWhatsApp', {'path': videoPath});
    } on PlatformException {
      await _fallback(videoPath);
    }
  }

  /// Returns which of the given targets are actually installed on this device.
  /// Non-Android platforms always return an empty set. Failures are treated
  /// as not-installed so callers get a conservative answer.
  static Future<Set<ShareTarget>> installedTargets(
      Iterable<ShareTarget> candidates) async {
    if (!Platform.isAndroid) return const {};
    final installed = <ShareTarget>{};
    for (final t in candidates) {
      try {
        final ok = await _channel.invokeMethod<bool>('isAppInstalled', {
          'package': t.packageName,
        });
        if (ok == true) installed.add(t);
      } on PlatformException {
        // Treat as not installed.
      } on MissingPluginException {
        return const {};
      }
    }
    return installed;
  }

  /// Opens Android's generic share sheet (all apps that can handle a video/mp4).
  static Future<void> shareWithSystemSheet(String videoPath) => _fallback(videoPath);

  static Future<void> _fallback(String videoPath) async {
    await Share.shareXFiles(
      [XFile(videoPath, mimeType: 'video/mp4', name: 'promoreel.mp4')],
      subject: 'Check out my latest promo!',
    );
  }
}

/// Back-compat alias so existing callers of WhatsAppShare keep working.
class WhatsAppShare {
  static Future<void> shareVideo(String videoPath) =>
      VideoShareService.shareVideo(videoPath);
}
