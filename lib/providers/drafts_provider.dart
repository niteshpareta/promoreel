import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/video_project.dart';
import '../data/services/draft_service.dart';

final _draftService = DraftService();

final draftsProvider =
    AsyncNotifierProvider<DraftsNotifier, List<DraftRecord>>(
        DraftsNotifier.new);

class DraftsNotifier extends AsyncNotifier<List<DraftRecord>> {
  @override
  Future<List<DraftRecord>> build() => _draftService.getDrafts();

  Future<void> save(VideoProject project, {String? thumbnailPath}) async {
    await _draftService.saveDraft(project, thumbnailPath: thumbnailPath);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await _draftService.deleteDraft(id);
    ref.invalidateSelf();
  }
}

/// Drafts whose `is_rendering` flag is still set — i.e. the app was killed
/// mid-export and no success/failure callback ever ran. The home screen
/// shows a "Resume export" chip for these so the user can re-kick the render
/// without rebuilding the project from scratch.
final orphanedRendersProvider =
    FutureProvider<List<DraftRecord>>((ref) => _draftService.getOrphanedRenders());
