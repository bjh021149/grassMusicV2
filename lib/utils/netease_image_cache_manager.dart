import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 网易云图片专用缓存管理器
/// 覆盖 User-Agent 为浏览器标识，避免被网易云图片服务器拦截
class NeteaseImageCacheManager extends CacheManager {
  static const key = 'neteaseImageCache';

  static final NeteaseImageCacheManager _instance =
      NeteaseImageCacheManager._internal();

  factory NeteaseImageCacheManager() => _instance;

  NeteaseImageCacheManager._internal()
    : super(
        Config(
          key,
          fileService: _NeteaseHttpFileService(),
        ),
      );
}

class _NeteaseHttpFileService extends HttpFileService {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final newHeaders = {
      ...?headers,
      'User-Agent': _userAgent,
    };
    return super.get(url, headers: newHeaders);
  }
}
