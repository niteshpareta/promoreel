import 'package:flutter/services.dart';

/// Bridge to Android's incoming share-intent handler.
///
/// When another app sends photos/videos to PromoReel via the share sheet,
/// Android routes them to [MainActivity], which copies the URIs into app
/// cache and queues their paths. Flutter polls that queue via
/// [getPendingSharedMedia] on app start and on resume.
class SharedMediaService {
  static const _channel = MethodChannel('com.binaryscript.promoreel/shared_media');

  /// Returns paths to any media Android has delivered since the last call
  /// (the native queue is cleared on each invocation). Returns an empty list
  /// on non-Android platforms or when nothing is pending.
  static Future<List<String>> getPendingSharedMedia() async {
    try {
      final paths = await _channel.invokeListMethod<String>('getSharedMedia');
      return paths ?? const [];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }
}
