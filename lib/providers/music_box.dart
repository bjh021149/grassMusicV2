// music_box.dart
import 'package:flutter/rendering.dart';
import 'package:grassmusicv2/locator/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../services/alist_api.dart';
import '../services/netease_api.dart';
import '../services/objectbox_service.dart';
import '../models/media_item.dart';
import '../models/netease_music.dart';
import '../extensions/alist_song_extensions.dart';
import '../objectbox.g.dart';
import 'package:media_kit/media_kit.dart';
import 'package:grassmusicv2/extensions/remove_metadata_extention.dart';
import 'package:grassmusicv2/extensions/yrc_process.dart';

/// 文件类型枚举（音频、歌词、封面、背景图）
enum FileType { audio, lyric, cover, background }

/// 音乐来源枚举（AList或网易云）
enum MusicProvider { alist, netease }

/// 统一音乐数据仓库（管理AList和网易云音乐）
class MusicBox {
  final Box<MediaItem> _box; // ObjectBox 存储实例

  String? _currentUsername; // 当前AList用户名

  /// 构造函数
  /// [objectBoxService] 必须传入ObjectBox服务实例
  MusicBox(ObjectBoxService objectBoxService)
    : _box = objectBoxService.mediaBox;
  // 通过 getIt 直接获取 API 实例
  AlistUtils get _alistApi => getIt<AlistUtils>();
  NeteaseMusicApi get _neteaseApi => getIt<NeteaseMusicApi>();
  //================================================================
  // 通用音乐数据方法
  //================================================================

  /// 获取所有歌曲（可选按来源过滤）
  /// [provider] 可为null表示获取所有来源
  List<MediaItem> getAllSongs({MusicProvider? provider}) {
    final query =
        provider != null
            ? _box.query(MediaItem_.provider.equals(provider.name)).build()
            : _box.query().build();

    try {
      return query.find();
    } finally {
      query.close(); // 确保查询关闭
    }
  }

  /// 根据ID精确查询歌曲（自动处理资源释放）
  /// [id] 歌曲唯一标识（AList为路径，网易云为songId）
  /// [provider] 可选来源过滤
  MediaItem? getSongById(String id) {
    final query = _box.query(MediaItem_.url.equals(id)).build();

    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  /// 高级搜索（多条件组合查询）
  /// [keyword] 可选关键词（搜索标题/艺术家/专辑）
  /// [artist] 可选艺术家精确匹配
  /// [album] 可选专辑精确匹配
  /// [provider] 可选来源过滤
  List<MediaItem> search({
    String? keyword,
    String? artist,
    String? album,
    MusicProvider? provider,
  }) {
    Condition<MediaItem>? condition;

    // 关键词条件（OR组合）
    if (keyword != null) {
      condition = MediaItem_.title
          .contains(keyword, caseSensitive: false)
          .or(MediaItem_.artist.contains(keyword, caseSensitive: false))
          .or(MediaItem_.album.contains(keyword, caseSensitive: false));
    }

    // 艺术家条件（AND组合）
    if (artist != null) {
      condition =
          condition != null
              ? condition.and(MediaItem_.artist.equals(artist))
              : MediaItem_.artist.equals(artist);
    }

    // 来源条件（AND组合）
    if (provider != null) {
      condition =
          condition != null
              ? condition.and(MediaItem_.provider.equals(provider.name))
              : MediaItem_.provider.equals(provider.name);
    }

    // 构建最终查询
    final query =
        condition != null
            ? _box.query(condition).build()
            : _box.query().build();

    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  //================================================================
  // 网易云音乐专属方法
  //================================================================

  /// 添加单首网易云歌曲到本地存储
  Future<void> addNeteaseSongL(Song song) async {
    _box.put(song.toMediaItemL()); // 使用Song类自带的转换方法
  }

  Future<void> addNeteaseSongN(Song song) async {
    _box.put(song.toMediaItemN()); // 使用Song类自带的转换方法
  }

  /// 批量添加网易云歌曲
  Future<void> addNeteaseSongsL(List<Song> songs) async {
    _box.putMany(songs.map((s) => s.toMediaItemL()).toList());
  }

  /// 获取所有缓存的网易云歌曲（自动过滤来源）
  List<MediaItem> getAllNeteaseSongs() {
    final query = _box.query(MediaItem_.provider.equals('netease')).build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  //================================================================
  // AList音乐管理方法
  //================================================================

  /// 获取当前AList用户名
  String? get currentUsername => _currentUsername;

  /// 检查是否已加载用户名
  bool get isUsernameLoaded => _currentUsername != null;

  /// 尝试恢复上次登录的用户名
  Future<bool> tryRestoreUsername() async {
    if (_currentUsername != null) return true;

    final prefs = await SharedPreferences.getInstance();
    _currentUsername = prefs.getString('last_alist_user');

    if (_currentUsername != null) {
      await _checkAndScan();
      return true;
    }
    return false;
  }

  /// 设置当前AList用户名
  Future<void> setCurrentUsername(String username) async {
    _currentUsername = username;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_alist_user', username);
    await _checkAndScan();
  }

  /// 检查刷新AList音乐库
  Future<void> checkTorefresh() async {
    if (_currentUsername == null) {
      throw StateError('No current username loaded');
    }
    await _checkAndScan();
  }

  ///刷新
  Future<void> refresh() async {
    if (_alistApi.isLoggedIn) {
      await _scanMusicStructure();
    }
  }

  /// 检查并扫描音乐库（内部方法）
  Future<void> _checkAndScan() async {
    if (_currentUsername == null) return;
    if (!_alistApi.isLoggedIn) return;

    final query = _box.query().build();
    final count = query.count();
    query.close();
    final hasData = count > 0;
    if (!hasData) {
      await _scanMusicStructure();
    }
  }

  /// 扫描音乐目录结构（全量扫描）
  Future<void> _scanMusicStructure() async {
    try {
      _box.removeAll(); // 清空现有数据

      final rootContents = await _alistApi.listDirectory('/');
      for (final artistDir in rootContents.where((i) => i['is_dir'])) {
        final artistName = artistDir['name'];
        final artistPath = '/$artistName';
        final artistContents = await _alistApi.listDirectory(artistPath);

        for (final albumDir in artistContents.where(
          (i) => i['is_dir'] && i['name'] != '0',
        )) {
          await _processAlbum(
            artistName,
            albumDir['name'],
            '$artistPath/${albumDir['name']}',
          );
        }
      }
    } catch (e) {
      debugPrint('Music library scan failed: $e');
      rethrow;
    }
  }

  /// 处理单个专辑目录（内部方法）
  Future<void> _processAlbum(String artist, String album, String path) async {
    final files = await _alistApi.listDirectory(path);
    final songs =
        files
            .where((f) => !f['is_dir'] && _isAudioFile(f['name']))
            .map(
              (file) => MediaItem(
                title: file['name'].split('.').first,
                artist: artist,
                album: album,
                url: '$path/${file['name']}',
                provider: MusicProvider.alist.name,
                durationMs: 1, // 默认时长，实际使用时需解析
              ),
            )
            .toList();

    if (songs.isNotEmpty) {
      _box.putMany(songs);
    }
  }

  /// 判断是否为音频文件（内部方法）
  bool _isAudioFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['mp3', 'flac', 'wav'].contains(ext);
  }

  //================================================================
  // 高级功能方法
  //================================================================

  /// 批量删除歌曲（安全事务操作）
  /// [ids] 要删除的歌曲ID列表
  /// [provider] 可选来源过滤
  Future<void> removeSongs(List<String> ids, {MusicProvider? provider}) async {
    final condition =
        provider != null
            ? MediaItem_.url
                .oneOf(ids)
                .and(MediaItem_.provider.equals(provider.name))
            : MediaItem_.url.oneOf(ids);

    final query = _box.query(condition).build();
    try {
      final toRemove = query.findIds();
      if (toRemove.isNotEmpty) {
        _box.removeMany(toRemove);
      }
    } finally {
      query.close();
    }
  }

  /// 获取分页歌曲数据（支持排序）
  /// [page] 页码（从1开始）
  /// [pageSize] 每页数量
  /// [provider] 可选来源过滤

  List<MediaItem> getPagedSongs({
    required int page,
    required int pageSize,
    MusicProvider? provider,
  }) {
    final query =
        provider != null
            ? _box.query(MediaItem_.provider.equals(provider.name)).build()
            : _box.query().build();

    try {
      query
        ..offset = (page - 1) * pageSize
        ..limit = pageSize;
      return query.find();
    } finally {
      query.close();
    }
  }

  Future<String?> getAudioUrl(MediaItem song) async {
    try {
      //print('Attempting to convert URL for ${song.url}'); // Add this line
      if (song.provider.toLowerCase() == 'alist') {
        final url = await _alistApi.getFileUrlV2(song.url);

        //print('Converted ${song.url} to $url'); // Add this line
        return url;
      } else if (song.provider.toLowerCase() == 'netease') {
        final url = await _neteaseApi.getSongUrlV2Single(song.url.toString());
        print('Converted ${song.url} to $url'); // Add this line
        return url;
      }
    } catch (e) {
      print(
        'Get file URL error for ${song.url}: ${e.toString()}',
      ); // Add this line
      return null;
    }
    return null;
  }

  Future<String?> getAudioUrlV1(Media song) async {
    //debugPrint(StackTrace.current.toString());  打印调用堆栈

    try {
      final String provider = song.extras!['provider'];

      if (provider.toLowerCase() == 'alist') {
        final url = await _alistApi.getFileUrlV2(song.extras!['path']);
        debugPrint('Converted AList URL: ${song.uri} to $url');
        return url;
      } else if (provider.toLowerCase() == 'netease') {
        final songId = song.extras!['path'].toString();
        final checkresult = await _neteaseApi.checkMusic(songId);
        if (checkresult.message != 'ok') return 'no';

        final url = await _neteaseApi.getSongUrlV1([songId]);
        debugPrint('Converted Netease URL for ID $songId to $url');
        return url;
      }

      debugPrint('Unknown provider: $provider');
      return null;
    } catch (e) {
      debugPrint('Error getting audio URL: $e');
      return null;
    }
  }

  //========helper
  bool isNumeric(String str) {
    return RegExp(r'^[0-9]+$').hasMatch(str);
  }

  String getParentPath(String pathTag) {
    return p.dirname(pathTag);
  }

  String getFileName(String pathTag) {
    final filename = p.basename(pathTag);
    return filename;
  }

  SharedPreferences get pref => getIt<SharedPreferences>();

  Future<String?> getAudiourlFromPref(String pathTag) async {
    if (isNumeric(pathTag)) {
      print('Netease................................');
      return _neteaseApi.getSongUrlV2Single(pathTag);
    } else {
      return pref.getString('audio_$pathTag');
    }
  }

  Future<String?> getCoverUrlFromPref(String pathTag) async {
    if (isNumeric(pathTag)) {
      return pref.getString('cover_$pathTag');
    } else {
      final pPath = getParentPath(pathTag);
      return pref.getString('cover_$pPath');
    }
  }

  Future<String?> getLrcFromPref(String pathTag) async {
    if (isNumeric(pathTag)) {
      return pref.getString('lrc_$pathTag');
    } else {
      return 'no';
    }
  }

  Future<String?> getTlrcFromPref(String pathTag) async {
    if (isNumeric(pathTag)) {
      return pref.getString('tLrc_$pathTag');
    } else {
      return 'no';
    }
  }

  Future<String?> getYrcFromPref(String pathTag) async {
    if (isNumeric(pathTag)) {
      return pref.getString('yrc_$pathTag');
    } else {
      return 'no';
    }
  }

  Future<void> getSongInfo(String pathTag) async {
    if (isNumeric(pathTag)) {
      //==audiourl
      final checkresult = await _neteaseApi.checkMusic(pathTag);
      if (checkresult.message != 'ok') {
        await pref.setString('audio_$pathTag', 'no');
        return;
      } else {
        final audiourl = await _neteaseApi.getSongUrlV2Single(pathTag);
        await pref.setString('audio_$pathTag', audiourl);
        await pref.setString(
          'audioTimeStamp_$pathTag',
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }
      //==coverurl
      final coverurl = await _neteaseApi.getSongCoverUrl(
        pathTag,
        size: '600y600',
      );
      if (coverurl.isNotEmpty) {
        await pref.setString('cover_$pathTag', coverurl);
      } else {
        await pref.setString('cover_$pathTag', 'no');
      }
      //===lyricsTopref
      final lyricData = await _neteaseApi.getLyricNew([pathTag]);
      await _updateLyricsN(lyricData, pathTag);
    } else {
      final parentPath = getParentPath(pathTag);
      final title = getFileName(pathTag); //withExtension
      debugPrint('alist song title: $title');
      final audiourl = await _alistApi.getFileUrlV2(pathTag);
      if (audiourl.isNotEmpty) {
        await pref.setString('audio_$pathTag', audiourl);
      } else {
        await pref.setString('audio_$pathTag', 'no');
      }
      final coverurl = await _alistApi.getFileUrlV2('$parentPath/cover.jpg');
      if (coverurl.isNotEmpty) {
        await pref.setString('cover_$parentPath', coverurl);
      } else {
        await pref.setString('cover_$parentPath', 'no');
      }
      /*final lrcurl= await _alistApi.getFileUrlV2(
        '$parentPath/${p.basenameWithoutExtension(title)}.lrc',
      );
      if (lrcurl.isNotEmpty) {
        await pref.setString('audio_$pathTag', audiourl);
      }*/
    }
  }

  Future<String?> getCoverUrl(MediaItem song) async {
    if (song.provider == 'alist') {
      //
      //print(song.parentPath);
      final coverurl = await _alistApi.getFileUrlV2(
        '${song.parentPath}/cover.jpg',
      );
      return coverurl;
    } else if (song.provider == 'netease') {
      print('??????????????${song.url}');
      return await _neteaseApi.getSongCoverUrl(
        song.url.toString(),
        size: '600y600',
      );
    }
    return null; // Return actual null
  }

  ///Mediaitem get lyric
  Future<String> getLyricUrl(MediaItem song) async {
    if (song.provider == MusicProvider.alist.name) {
      final path =
          '${song.artist}/${song.album}/${song.nameWithoutExtension}.lrc';
      return await _alistApi.getFileUrlV2(path);
    } else {
      return 'no';
    }
  }

  Future<void> getLyricUrlV1(String pathTag) async {
    final lyricData = await _neteaseApi.getLyricNew([pathTag]);
    await _updateLyricsN(lyricData, pathTag);
  }

  _updateLyricsN(RawLyricResponse lyricData, String pathTag) async {
    final processedLyric = lyricData.hasLrc ? lyricData.lrc.parsedLyrics() : {};
    final processedTranslatedLyric =
        lyricData.hasTranslation ? lyricData.tlyric.parsedLyrics() : {};
    final processedYrcLyric =
        lyricData.hasWordByWord
            ? lyricData.yrc.convertYrcLines().parsedLyrics()
            : {};
    debugPrint(processedLyric['lyrics']);
    try {
      await pref.setString('lrc_$pathTag', processedLyric['lyrics'] ?? '');
      await pref.setString(
        'tLrc_$pathTag',
        processedTranslatedLyric['lyrics'] ?? '',
      );
      await pref.setString('yrc_$pathTag', processedYrcLyric['lyrics'] ?? '');
      print('geci updated...................');
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  /*
  Future<void> _getSongLyric(String id) async {
    _lyricData = await _api.getLyricNew([id]);
    _updateLyrics(lyricData);
  }
*/
}
