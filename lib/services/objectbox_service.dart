import 'package:grassmusicv2/providers/music_box.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/media_item.dart';
import '../models/playlist_item.dart';
import '../objectbox.g.dart';

import 'package:media_kit/media_kit.dart';

class ObjectBoxService {
  static ObjectBoxService? _instance;
  late final Store store;
  late final Box<MediaItem> mediaBox;
  late final Box<CustomPlaylist> playlistBox;

  ObjectBoxService._create();

  static Future<ObjectBoxService> init() async {
    if (_instance == null) {
      _instance = ObjectBoxService._create();
      final docsDir = await getApplicationDocumentsDirectory();
      final storePath = p.join(docsDir.path, 'alist_music');
      _instance!.store = await openStore(directory: storePath);
      _instance!.mediaBox = _instance!.store.box<MediaItem>();
      _instance!.playlistBox = _instance!.store.box<CustomPlaylist>();
    }
    return _instance!;
  }

  Future<List<Media>> getMediaItemsInPlaylist(
    int playlistId,
    MusicBox musicbox,
  ) async {
    // 1. 获取播放列表
    //repairPlaylistReferences();
    //checkDataIntegrity();
    printDatabaseStats();
    final playlist = playlistBox.get(playlistId);
    if (playlist == null) {
      print('❌ 播放列表不存在，ID: $playlistId');
      return [];
    }

    print('🔄 正在处理播放列表: ${playlist.name}');
    print('📋 包含的媒体ID: ${playlist.mediaIdList}');

    // 2. 查询媒体项（优化后的查询方式）
    final mediaItems = <MediaItem>[];
    for (final mediaId in playlist.mediaIdList) {
      final item = mediaBox.get(mediaId);
      if (item != null) {
        mediaItems.add(item);
        print('✅ 找到媒体项 - ID: $mediaId, 标题: ${item.title}');
      } else {
        print('⚠️ 缺失的媒体项 - ID: $mediaId');
      }
    }

    print('🔍 实际找到的媒体项数量: ${mediaItems.length}/${playlist.mediaIdList.length}');

    // 3. 转换为可播放的Media对象
    final mediaList = <Media>[];
    for (final item in mediaItems) {
      try {
        print('⏳ 正在获取媒体URL - ${item.title} (ID: ${item.id})');
        final validUrl = await musicbox.getAudioUrl(item);
        final coverurl = await musicbox.getCoverUrl(item);
        if (validUrl == null) {
          print('❌ 获取URL失败 - ${item.title}');
          continue;
        }

        print('🔗 有效URL: $validUrl');
        final media = Media(
          validUrl,
          extras: {
            'id': item.id.toString(), // 使用真实ID而不是组合字符串
            'title': item.title,
            'artist': item.artist,
            'album': item.album,
            'coverUrl': coverurl,
          },
        );
        mediaList.add(media);
      } catch (e) {
        print('‼️ 处理媒体项时出错 - ${item.id}: $e');
      }
    }

    print('🎵 最终可播放的媒体数量: ${mediaList.length}');
    return mediaList;
  }

  Future<void> close() async {
    store.close();
  }

  // 添加到ObjectBoxService类中
  void printFirstTenMediaItems() {
    try {
      final query = mediaBox.query().build();

      final items = query.find();
      query.close();

      if (items.isEmpty) {
        print('📭 媒体数据库为空');
        return;
      }

      print('📋 前10个媒体项ID:');
      for (var item in items) {
        print(
          '│ ID: ${item.id.toString().padRight(5)} │ '
          '标题: ${item.title.padRight(20)} │ '
          '艺术家: ${item.artist}',
        );
      }
      print('└─────────────────────────────────────────');
    } catch (e) {
      print('‼️ 打印媒体项时出错: $e');
    }
  }

  Future<void> repairPlaylistReferences() async {
    final query = playlistBox.query().build();
    final lists = query.find();

    for (final playlist in lists) {
      final invalidRefs = playlist.mediaIdList.where(
        (id) => id <= 0 || mediaBox.get(id) == null,
      );

      if (invalidRefs.isNotEmpty) {
        print('修复播放列表 "${playlist.name}": 移除无效引用 $invalidRefs');
        playlist.mediaIdList.removeWhere((id) => invalidRefs.contains(id));
        playlistBox.put(playlist);
      }
    }
  }

  void checkDataIntegrity() {
    final allMediaIds = mediaBox.getAll().map((e) => e.id).toSet();
    final query = playlistBox.query().build();
    final lists = query.find();
    for (var playlist in lists) {
      for (var mediaId in playlist.mediaIdList) {
        if (!allMediaIds.contains(mediaId)) {
          print('⚠️ 孤立引用: 播放列表 "${playlist.name}" 引用了不存在的媒体ID $mediaId');
        }
      }
    }
  }

  void printDatabaseStats() {
    final items = mediaBox.getAll();

    print('📊 数据库统计:');
    print('│ 总记录数: ${items.length}');
    print('│ 最小ID: ${items.isNotEmpty ? items.first.id : "N/A"}');
    print('│ 最大ID: ${items.isNotEmpty ? items.last.id : "N/A"}');
    print(
      '│ 缺失ID数: ${items.isNotEmpty ? items.last.id - items.length : "N/A"}',
    );
  }
}
