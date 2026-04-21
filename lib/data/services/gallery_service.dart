import 'dart:io';
import 'package:photo_manager/photo_manager.dart';

class GalleryAsset {
  const GalleryAsset({
    required this.id,
    required this.type,
    required this.createDateTime,
    this.file,
    this.thumbnailData,
  });

  final String id;
  final AssetType type;
  final DateTime createDateTime;
  final File? file;
  final Future<List<int>?>? thumbnailData;

  bool get isVideo => type == AssetType.video;
}

class GalleryService {
  Future<PermissionState> requestPermission() async {
    return PhotoManager.requestPermissionExtend();
  }

  Future<List<AssetEntity>> loadAssets({int page = 0, int pageSize = 80}) async {
    final filter = FilterOptionGroup(
      orders: [
        const OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
      filterOption: filter,
    );
    if (albums.isEmpty) return [];
    return albums[0].getAssetListPaged(page: page, size: pageSize);
  }

  Future<File?> getFile(AssetEntity asset) async {
    return asset.file;
  }

  Future<List<int>?> getThumbnail(AssetEntity asset) async {
    final data = await asset.thumbnailDataWithSize(
      const ThumbnailSize(300, 300),
      quality: 80,
    );
    return data;
  }
}
