import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
//import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:tuple/tuple.dart';

// Models
import '../models/netease_music_auth.dart';
//import '../models/netease_music_auth_model.dart';
import '../models/netease_music.dart';
import '../models/netease_music_user_playlist.dart';
import '../models/playlist_detail.dart';
import '../models/netease_qr.dart';

class MusicAvailability {
  final bool success;
  final String message;

  MusicAvailability({required this.success, required this.message});

  factory MusicAvailability.fromJson(Map<String, dynamic> json) {
    return MusicAvailability(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

class NeteaseMusicApi {
  String _baseUrl = 'http://192.168.10.72:3000';
  final Dio _dio;

  final Map<String, Tuple2<String, DateTime>> _audioUrlCache = {};
  final Duration _urlCacheDuration = Duration(minutes: 5);
  late final SharedPreferences _prefs;
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;
  late final CookieJar? _cookieJar = !kIsWeb ? CookieJar() : null;

  NeteaseMusicApi(this._prefs)
    : _dio = Dio(
        BaseOptions(contentType: 'application/x-www-form-urlencoded'),
      ) {
    _baseUrl = _prefs.getString('server_address') ?? _baseUrl;
    _dio.options.baseUrl = _baseUrl;

    if (!kIsWeb) {
      _dio.interceptors.add(CookieManager(_cookieJar!));
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _clearAuthInfo();
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<String> updateBaseUrl(String serverKey, String newUrl) async {
    try {
      // Ensure the URL has http:// or https:// prefix
      if (!newUrl.startsWith('http://') && !newUrl.startsWith('https://')) {
        newUrl = 'http://$newUrl';
      }

      // Remove any trailing slashes
      newUrl = newUrl.replaceAll(RegExp(r'/$'), '');

      await _prefs.setString(serverKey, newUrl);
      _baseUrl = newUrl;
      _dio.options.baseUrl = _baseUrl;
      return 'success';
    } catch (e) {
      debugPrint('Error updating base URL: $e');
      return 'fail';
    }
    // Validate the URL format
  }
  // QR Login Methods ======================================================

  Future<void> init(String cookie) async {
    await _handleLoginSuccess(cookie);
    try {
      await getuseraccount();
      _isLoggedIn = true;
    } catch (e) {
      _isLoggedIn = false;
      throw Exception('Failed to initialize: $e');
    }
  }

  Future<UserProfile> getuseraccount() async {
    final response = await _safeRequest('/user/account');
    if (response['code'] == 200) {
      final user = response['profile'];
      print(UserProfile.fromJson(user).userId);
      await _prefs.setString('netease_userId', user['userId'].toString());
      return UserProfile.fromJson(user);
    }
    throw Exception(response['msg'] ?? 'Failed to get user account');
  }

  String getuserid() {
    final userId = _prefs.getString('netease_userId');
    if (userId != null) {
      debugPrint('User ID: $userId');
    } else {
      debugPrint('User ID not found in preferences');
    }
    return userId ?? '';
  }

  Future<QRLoginResult> startQRLogin() async {
    final key = await generateQRKey();
    final qrData = await generateQRCode(key);
    return QRLoginResult(key: key, qrImage: qrData['qrimg']);
  }

  Future<String> generateQRKey() async {
    final response = await _dio.get(
      '/login/qr/key',
      queryParameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
    return response.data['data']['unikey'].toString();
  }

  Future<Map<String, dynamic>> generateQRCode(String key) async {
    final response = await _dio.get(
      '/login/qr/create',
      queryParameters: {
        'key': key,
        'qrimg': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    return {
      'qrimg': response.data['data']['qrimg'],
      'qrurl': response.data['data']['qrurl'],
    };
  }

  Future<QRLoginStatus> checkQRStatus(String key) async {
    final response = await _dio.get(
      '/login/qr/check',
      queryParameters: {
        'key': key,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );

    switch (response.data['code']) {
      case 800:
        return QRLoginStatus.expired(message: '二维码已过期');
      case 801:
        return QRLoginStatus.waiting();
      case 802:
        return QRLoginStatus.scanned(
          nickname: response.data['nickname'],
          avatar: response.data['avatar'],
        );
      case 803:
        final cookie = response.data['cookie'].toString();
        await _handleLoginSuccess(cookie);
        return QRLoginStatus.success(
          cookie: cookie,
          accountId: response.data['accountId']?.toString(),
        );
      default:
        throw Exception(response.data['message'] ?? '未知状态');
    }
  }

  Future<void> _handleLoginSuccess(String cookie) async {
    _prefs.setString('Cookie', cookie);
    final musicU = _extractCookie(cookie, 'MUSIC_U');
    final csrf = _extractCookie(cookie, '__csrf');

    if (musicU == null) throw Exception('Invalid cookie');

    await _prefs.setString('netease_token', musicU);
    if (csrf != null) {
      await _prefs.setString('netease_csrf', csrf);
    }

    if (!kIsWeb) {
      final uri = Uri.parse(_baseUrl);
      await _cookieJar!.saveFromResponse(uri, [
        Cookie('MUSIC_U', musicU),
        if (csrf != null) Cookie('__csrf', csrf),
      ]);
    }

    _isLoggedIn = true;
  }

  // Auth Methods ==========================================================

  Future<bool> logout() async {
    try {
      final response = await _dio.get('/logout');
      await clearLoginInfo();
      return response.data['code'] == 200;
    } catch (e) {
      await clearLoginInfo();
      debugPrint('Logout failed: $e');
      return false;
    }
  }

  Future<void> clearLoginInfo() async {
    await _prefs.remove('netease_token');
    await _prefs.remove('netease_csrf');
    await _prefs.remove('netease_userId');

    if (!kIsWeb) {
      await _cookieJar!.deleteAll();
    }

    _isLoggedIn = false;
  }

  Future<bool> checkLoginStatus() async {
    return _prefs.getString('netease_token') != null;
  }

  Future<Map<String, String>> getCredentials() async {
    return {
      'MUSIC_U': _prefs.getString('netease_token') ?? '',
      'csrf_token': _prefs.getString('netease_csrf') ?? '',
    };
  }

  // Music API Methods =====================================================

  Future<List<Song>> getDailyRecommendSongs() async {
    final result = await _safeRequest('/recommend/songs');

    if (result['code'] == 200) {
      final dailySongs = result['data']['dailySongs'];
      if (dailySongs is List) {
        return dailySongs.map((e) => Song.fromJson(e)).toList();
      }
      throw Exception('Unexpected data format for daily songs');
    }
    throw Exception(result['msg'] ?? 'Failed to get recommendations');
  }

  Future<Map<String, String>> getLyric(List<String> songId) async {
    final result = await _safeRequest('/lyric', params: {'id': songId});

    if (result['code'] == 200) {
      return {
        'lyric': result['lrc']?['lyric'] ?? '',
        'translatedLyric': result['tlyric']?['lyric'] ?? '',
        'klyric': result['klyric']?['lyric'] ?? '',
        'romalrc': result['romalrc']?['lyric'] ?? '',
      };
    }
    throw Exception(result['msg'] ?? 'Failed to fetch lyrics');
  }

  Future<RawLyricResponse> getLyricNew(List<String> songId) async {
    final result = await _safeRequest('/lyric/new', params: {'id': songId});
    //debugPrint('Lyric response: $result');
    if (result['code'] == 200) {
      debugPrint(result['lrc']?['lyric'] ?? '');
      return RawLyricResponse(
        sgc: result['sgc'] ?? false,
        sfy: result['sfy'] ?? false,
        qfy: result['qfy'] ?? false,
        lrc: result['lrc']?['lyric'] ?? '',
        tlyric: result['tlyric']?['lyric'] ?? '',
        klyric: result['klyric']?['lyric'] ?? '',
        yrc: result['yrc']?['lyric'] ?? '',
        romalrc: result['romalrc']?['lyric'] ?? '',
        code: 200,
      );
    }

    throw Exception(result['msg'] ?? 'Failed to fetch lyrics');
  }

  Future<List<UserPlaylist>> getUserPlaylists({
    required dynamic uid,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final result = await _safeRequest(
        '/user/playlist',
        params: {'uid': uid, 'limit': limit, 'offset': offset},
      );

      if (result['code'] == 200) {
        final playlists =
            (result['playlist'] ?? result['data']['playlist']) as List?;
        if (playlists != null) {
          return playlists.map((e) => UserPlaylist.fromJson(e)).toList();
        }
      }
      throw Exception(result['msg'] ?? 'Invalid playlist data format');
    } on DioException catch (e) {
      throw Exception('网络请求失败: ${e.message}');
    }
  }

  Future<List<String>> getPlaylistDetail(
    String playlistId, {
    int subscribersCount = 8,
  }) async {
    final result = await _safeRequest(
      '/playlist/detail',
      params: {'id': playlistId, 's': subscribersCount},
    );

    if (result['code'] == 200) {
      final playlist = result['playlist'];
      final trackIds =
          (playlist['trackIds'] as List)
              .map((e) => e['id'].toString())
              .toList();
      debugPrint(trackIds.toString());
      return trackIds;
    }
    throw Exception(result['msg'] ?? 'Failed to get playlist details');
  }

  Future<List<Song>> getSongsDetail(List<String> songIds) async {
    final result = await _safeRequest(
      '/song/detail',
      params: {'ids': songIds.join(',')},
    );

    if (result['code'] == 200) {
      return (result['songs'] as List).map((e) => Song.fromJson(e)).toList();
    }
    throw Exception(result['msg'] ?? 'Failed to get songs detail');
  }

  Future<String?> getSongUrlV1(
    List<String> ids, {
    String level = 'hires',
  }) async {
    debugPrint('getSongUrlV1 called for ids: $ids');
    final result1 = await Future.wait(ids.map((id) => checkMusic(id)));
    final avaibialIds = <String>[];
    for (int i = 0; i < ids.length; i++) {
      if (result1[i].success) {
        avaibialIds.add(ids[i]);
      }
    }

    final now = DateTime.now();
    final uncachedIds =
        avaibialIds.where((id) {
          return !_audioUrlCache.containsKey(id) ||
              now.difference(_audioUrlCache[id]!.item2) > _urlCacheDuration;
        }).toList();

    if (uncachedIds.isNotEmpty) {
      debugPrint('Fetching URL for uncached ids: $uncachedIds');
      final result = await _safeRequest(
        '/song/url/v1',
        params: {'id': uncachedIds.join(','), 'level': level},
      );

      if (result['code'] == 200) {
        for (final item in result['data'] as List) {
          _audioUrlCache[item['id'].toString()] = Tuple2(
            item['url']?.toString() ?? '',
            now,
          );
        }
      }
    }

    final urls = ids.map((id) => _audioUrlCache[id]?.item1).toList();
    return urls.firstWhere((url) => url != null, orElse: () => null);
  }

  Future<List<String>> getSongUrlV2(
    List<String> ids, {
    String level = 'hires',
  }) async {
    final result1 = await Future.wait(ids.map((id) => checkMusic(id)));
    final avaibialIds = <String>[];
    for (int i = 0; i < ids.length; i++) {
      if (result1[i].success) {
        avaibialIds.add(ids[i]);
      }
    }

    final result = await _safeRequest(
      '/song/url/v1',
      params: {'id': avaibialIds.join(','), 'level': level},
    );

    if (result['code'] == 200) {
      return (result['data'] as List)
          .map(
            (e) =>
                Song(
                  id: e['id'].toString(),
                  name: '',
                  artists: [],
                  album: Album(id: '', name: '', picUrl: ''),
                  duration: 0,
                  audioUrl: e['url'],
                  size: e['size'].toString(),
                ).audioUrl.toString(),
          )
          .toList();
    }
    throw Exception(result['msg'] ?? 'Failed to get song URLs');
  }

  Future<String> getSongUrlV2Single(String id, {String level = 'hires'}) async {
    final availability = await checkMusic(id);
    if (!availability.success) {
      return 'No';
    }

    final result = await _safeRequest(
      '/song/url/v1',
      params: {'id': id, 'level': level},
    );

    if (result['code'] == 200) {
      final data = result['data'] as List;
      if (data.isEmpty) throw Exception('No URL found for song $id');

      return data.first['url']?.toString() ?? 'none';
    }

    throw Exception(result['msg'] ?? 'Failed to get song URL');
  }

  Future<String> getSongCoverUrl(String id, {String size = '300y300'}) async {
    final result = await _safeRequest('/song/detail', params: {'ids': id});

    if (result['code'] != 200) {
      throw Exception(result['msg'] ?? 'Failed to get song details');
    }

    final songs = result['songs'] as List?;
    if (songs == null || songs.isEmpty) {
      throw Exception('No song found for ID: $id');
    }

    final album = songs.first['al'] as Map?;
    final picUrl = album?['picUrl']?.toString();

    if (picUrl == null) {
      throw Exception('No cover available for song: $id');
    }

    return picUrl.replaceAll(RegExp(r'\?param=\d+y\d+'), '?param=$size');
  }

  Future<List<PlaylistDetail>> getPlaylistsDetails(
    List<String> playlistIds, {
    int initialLoadCount = 5,
  }) async {
    // Only process a subset of playlists initially for performance
    final initialPlaylistIds = playlistIds.take(initialLoadCount).toList();

    final results = await Future.wait(
      initialPlaylistIds.map((id) => _getSinglePlaylistDetail(id)),
    );

    return results.whereType<PlaylistDetail>().toList();
  }

  Future<PlaylistDetail?> _getSinglePlaylistDetail(String playlistId) async {
    try {
      final result = await _safeRequest(
        '/playlist/detail',
        params: {'id': playlistId},
      );

      if (result['code'] == 200) {
        final playlist = result['playlist'];
        final allTrackIds =
            (playlist['trackIds'] as List)
                .map((e) => e['id'].toString())
                .toList();

        // Only load initial batch of songs
        final initialTrackIds = allTrackIds.take(20).toList();
        final initialSongs =
            initialTrackIds.isNotEmpty
                ? await getSongsDetail(initialTrackIds)
                : <Song>[];

        return PlaylistDetail(
          id: playlist['id'].toString(),
          name: playlist['name'].toString(),
          coverImgUrl: playlist['coverImgUrl'].toString(),
          creator: UserProfile.fromJson(playlist['creator']),
          description: playlist['description']?.toString() ?? '',
          subscribed: playlist['subscribed'] ?? false,
          trackCount: playlist['trackCount'] ?? 0,
          playCount: playlist['playCount'] ?? 0,
          songs: initialSongs,
          allTrackIds: allTrackIds,
          loadedTrackIds: initialTrackIds,
          createTime: DateTime.fromMillisecondsSinceEpoch(
            playlist['createTime'],
          ),
          updateTime: DateTime.fromMillisecondsSinceEpoch(
            playlist['updateTime'],
          ),
        );
      }
      return null;
    } catch (e) {
      debugPrint('Failed to load playlist $playlistId: $e');
      return null;
    }
  }

  Future<List<PlaylistDetail>> loadMorePlaylists(
    List<String> allPlaylistIds,
    List<PlaylistDetail> currentlyLoaded, {
    int loadCount = 5,
  }) async {
    final loadedIds = currentlyLoaded.map((p) => p.id).toList();
    final unloadedIds =
        allPlaylistIds
            .where((id) => !loadedIds.contains(id))
            .take(loadCount)
            .toList();

    if (unloadedIds.isEmpty) return [];

    final results = await Future.wait(
      unloadedIds.map((id) => _getSinglePlaylistDetail(id)),
    );

    return results.whereType<PlaylistDetail>().toList();
  }

  Future<PlaylistDetail> getPlaylistDetailFull(
    String playlistId, {
    int initialLoadCount = 20,
  }) async {
    final result = await _safeRequest(
      '/playlist/detail',
      params: {'id': playlistId},
    );

    if (result['code'] == 200) {
      final playlist = result['playlist'];
      final allTrackIds =
          (playlist['trackIds'] as List)
              .map((e) => e['id'].toString())
              .toList();
      final initialTrackIds = allTrackIds.take(initialLoadCount).toList();
      final initialSongs = await getSongsDetail(initialTrackIds);

      final mergedInitialSongs = initialSongs.toList();

      return PlaylistDetail(
        id: playlist['id'].toString(),
        name: playlist['name'].toString(),
        coverImgUrl: playlist['coverImgUrl'].toString(),
        creator: UserProfile.fromJson(playlist['creator']),
        description: playlist['description']?.toString() ?? '',
        subscribed: playlist['subscribed'] ?? false,
        trackCount: playlist['trackCount'] ?? 0,
        playCount: playlist['playCount'] ?? 0,
        songs: mergedInitialSongs,
        allTrackIds: allTrackIds,
        loadedTrackIds: initialTrackIds,
        createTime: DateTime.fromMillisecondsSinceEpoch(playlist['createTime']),
        updateTime: DateTime.fromMillisecondsSinceEpoch(playlist['updateTime']),
      );
    }
    throw Exception(result['msg'] ?? 'Failed to get playlist details');
  }

  Future<List<Song>> loadMoreSongs(
    PlaylistDetail playlistDetail, {
    int loadCount = 20,
  }) async {
    final unloadedIds =
        playlistDetail.allTrackIds
            .where((id) => !playlistDetail.loadedTrackIds.contains(id))
            .take(loadCount)
            .toList();

    if (unloadedIds.isEmpty) return [];

    final songs = await getSongsDetail(unloadedIds);
    return songs.toList();
  }
  //Search=======================================================
  // Add this to the NeteaseMusicApi class (around line 700, before the closing brace)

  /// Search for music/album/artist/playlist/user
  ///
  /// [keywords] - Search keywords (multiple keywords should be separated by spaces)
  /// [type] - Search type:
  ///   1: song, 10: album, 100: artist, 1000: playlist,
  ///   1002: user, 1004: MV, 1006: lyric, 1009: radio,
  ///   1014: video, 1018: comprehensive, 2000: voice
  /// [limit] - Number of results to return (default: 30)
  /// [offset] - Offset for pagination (default: 0)
  /// [useCloudSearch] - Whether to use the more comprehensive cloudsearch API
  Future<Map<String, dynamic>> search({
    required String keywords,
    int type = 1,
    int limit = 30,
    int offset = 0,
    bool useCloudSearch = false,
  }) async {
    final endpoint = useCloudSearch ? '/cloudsearch' : '/search';

    final result = await _safeRequest(
      endpoint,
      params: {
        'keywords': keywords,
        'type': type,
        'limit': limit,
        'offset': offset,
      },
    );

    if (result['code'] == 200) {
      return result;
    }
    throw Exception(result['msg'] ?? 'Failed to perform search');
  }

  /// Convenience method to search for songs
  Future<List<Song>> searchSongs({
    required String keywords,
    int limit = 30,
    int offset = 0,
    bool useCloudSearch = false,
  }) async {
    final result = await search(
      keywords: keywords,
      type: 1,
      limit: limit,
      offset: offset,
      useCloudSearch: useCloudSearch,
    );

    if (result['code'] == 200) {
      final songs = result['result']['songs'] as List?;
      if (songs != null) {
        return songs.map((e) => Song.fromJson(e)).toList();
      }
    }
    throw Exception(result['msg'] ?? 'Failed to search songs');
  }

  /// Convenience method to search for playlists
  Future<List<UserPlaylist>> searchPlaylists({
    required String keywords,
    int limit = 30,
    int offset = 0,
    bool useCloudSearch = false,
  }) async {
    final result = await search(
      keywords: keywords,
      type: 1000,
      limit: limit,
      offset: offset,
      useCloudSearch: useCloudSearch,
    );

    if (result['code'] == 200) {
      final playlists = result['result']['playlists'] as List?;
      if (playlists != null) {
        return playlists.map((e) => UserPlaylist.fromJson(e)).toList();
      }
    }
    throw Exception(result['msg'] ?? 'Failed to search playlists');
  }
  // Helper Methods ========================================================

  Future<dynamic> _safeRequest(
    String endpoint, {
    Map<String, dynamic>? params,
    String method = 'GET',
    bool withCredentials = true,
  }) async {
    final cParams = params?.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );
    final rawData = await _cachedRequest(
      endpoint,
      params: cParams,
      method: method,
      withCredentials: withCredentials,
    );
    return rawData;
  }

  Future<dynamic> _request(
    String endpoint, {
    Map<String, dynamic>? params,
    String method = 'GET',
    bool withCredentials = true,
  }) async {
    try {
      if (method == 'POST') {
        params ??= {};
        params['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
      }

      Options options = Options(
        method: method,
        headers: await _createHeaders(),
        extra: {'withCredentials': withCredentials},
      );

      if (endpoint == '/song/url/v1') {
        options = Options(
          method: method,
          headers: await _createHeadersv1(),
          extra: {'withCredentials': withCredentials},
        );
      }

      final response = await _dio.request(
        endpoint,
        data: method == 'POST' ? params : null,
        queryParameters: method == 'GET' ? params : null,
        options: options,
      );

      _handleResponseCookies(response.headers);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          'Request failed: ${e.response?.statusCode} - ${e.response?.data}',
        );
      } else {
        throw Exception('Request failed: ${e.message}');
      }
    }
  }

  Future<Map<String, dynamic>> _cachedRequest(
    String endpoint, {
    Duration cacheDuration = const Duration(minutes: 10),
    Map<String, dynamic>? params,
    String method = 'GET',
    bool withCredentials = true,
  }) async {
    final cacheKey = '$endpoint${params?.toString() ?? ''}';
    final now = DateTime.now();

    final cached = _prefs.getString(cacheKey);
    if (cached != null) {
      final data = jsonDecode(cached);
      final timestamp = DateTime.parse(data['timestamp']);
      if (now.difference(timestamp) < cacheDuration) {
        return data['response'];
      }
    }

    final rawData = await _request(
      endpoint,
      params: params,
      method: method,
      withCredentials: withCredentials,
    );

    await _prefs.setString(
      cacheKey,
      jsonEncode({'timestamp': now.toIso8601String(), 'response': rawData}),
    );

    return rawData;
  }

  Future<Map<String, String>> _createHeaders() async {
    final authInfo = _getAuthInfo();
    final headers = <String, String>{};

    if (authInfo.csrf.isNotEmpty) {
      headers['X-CSRF-Token'] = authInfo.csrf;
    }

    return headers;
  }

  Future<Map<String, String>> _createHeadersv1() async {
    debugPrint('Ding');
    final authInfo = _getAuthInfo();
    final headers = <String, String>{};

    if (authInfo.csrf.isNotEmpty) {
      headers['X-CSRF-Token'] = authInfo.csrf;
    }

    if (authInfo.musicU.isNotEmpty && !kIsWeb) {
      final uri = Uri.parse(_baseUrl);
      final cookies = await _cookieJar!.loadForRequest(uri);
      cookies.add(Cookie('os', 'pc'));
      await _cookieJar.saveFromResponse(uri, cookies);
    }

    return headers;
  }

  void _handleResponseCookies(Headers headers) {
    final cookies = headers['set-cookie'];
    if (cookies != null) {
      final csrf = _extractCookie(cookies.join('; '), '__csrf');
      if (csrf != null) {
        _prefs.setString('netease_csrf', csrf);
      }
    }
  }

  AuthInfo _getAuthInfo() {
    return AuthInfo(
      musicU: _prefs.getString('netease_token') ?? '',
      csrf: _prefs.getString('netease_csrf') ?? '',
    );
  }

  Future<void> _clearAuthInfo() async {
    await _prefs.remove('netease_token');
    await _prefs.remove('netease_userId');
    await _prefs.remove('netease_csrf');
    if (!kIsWeb) {
      await _cookieJar!.deleteAll();
    }
    _isLoggedIn = false;
  }

  Future<MusicAvailability> checkMusic(String songId, {int br = 999000}) async {
    debugPrint('Checking music availability for id: $songId');
    final result = await _safeRequest(
      '/check/music',
      params: {'id': songId, 'br': br},
    );
    return MusicAvailability.fromJson(result);
  }

  String? _extractCookie(String? cookieStr, String key) {
    if (cookieStr == null || cookieStr.isEmpty) return null;
    final match = RegExp('$key=([^;]+)').firstMatch(cookieStr);
    return match?.group(1);
  }
}
