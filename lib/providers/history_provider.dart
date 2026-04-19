import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/video_history_service.dart';

class VideoHistoryState {
  const VideoHistoryState({required this.videos, required this.todayCount});
  final List<VideoRecord> videos;
  final int todayCount;
}

final videoHistoryProvider = FutureProvider<VideoHistoryState>((ref) async {
  final svc = VideoHistoryService();
  final all   = await svc.getAll();
  final today = await svc.countToday();
  return VideoHistoryState(videos: all, todayCount: today);
});
