import 'package:objectbox/objectbox.dart';

@Entity()
class CustomPlaylist {
  // 改为 CustomPlaylist 或其他有区分度的名称
  @Id()
  int id = 0;

  @Unique() // 确保列表名称唯一
  String name;

  @Property(type: PropertyType.byteVector) // 存储 int 列表
  List<int> mediaIdList; // 存储关联的 MediaItem.mediaId

  CustomPlaylist({required this.name, this.mediaIdList = const []});

  // 添加媒体到列表
  void addMediaId(int mediaId) {
    mediaIdList = [...mediaIdList, mediaId]; // 创建新列表保证触发 ObjectBox 更新
  }

  // 从列表移除媒体
  void removeMediaId(int mediaId) {
    mediaIdList = mediaIdList.where((id) => id != mediaId).toList();
  }
}
