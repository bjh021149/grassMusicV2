import 'dart:math';
import 'package:grassmusicv2/providers/music_box.dart';
import 'package:grassmusicv2/providers/providers.dart';
import 'package:grassmusicv2/widgets/user_playlist_widget%20copy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:path/path.dart';

// Enhanced play mode enum with proper string representation
enum PlayMode {
  sequence('Sequence', Icons.repeat),
  random('Random', Icons.shuffle),
  singleLoop('Single Loop', Icons.repeat_one);

  final String displayName;
  final IconData icon;

  const PlayMode(this.displayName, this.icon);
}

// Player state with additional useful fields
class PlayerState {
  final List<Media> playlist;
  final int currentIndex;
  final bool buffering;
  final Duration buffer;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final PlayMode playMode;
  final bool isShuffled; // Track if playlist is currently shuffled
  final List<int> originalOrder; // Store original playlist order for shuffle
  final String currentPathTag;
  PlayerState({
    this.playlist = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.buffering = false,
    this.buffer = Duration.zero,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playMode = PlayMode.sequence,
    this.isShuffled = false,
    this.originalOrder = const [],
    this.currentPathTag = '-1',
  });

  PlayerState copyWith({
    List<Media>? playlist,
    int? currentIndex,
    bool? isPlaying,
    bool? buffering,
    Duration? buffer,
    Duration? position,
    Duration? duration,
    PlayMode? playMode,
    bool? isShuffled,
    List<int>? originalOrder,
    String? currentPathTag,
  }) {
    return PlayerState(
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      buffering: buffering ?? this.buffering,
      buffer: buffer ?? this.buffer,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playMode: playMode ?? this.playMode,
      isShuffled: isShuffled ?? this.isShuffled,
      originalOrder: originalOrder ?? this.originalOrder,
      currentPathTag: currentPathTag ?? this.currentPathTag,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Player _player = Player();
  final Random _random = Random();
  final Map<String, String> _urlCache = {};
  final MusicBox musicBox;
  String? _lastPathTag;
  Timer? _playbackMonitor; // 进度检查定时器
  bool _isNaturalEnd = false; // 标记是否自然结束

  void clearCache() {
    _urlCache.clear();
  }

  PlayerNotifier(this.musicBox) : super(PlayerState()) {
    _setupPlayerListeners();
  }

  void _setupPlayerListeners() {
    _player.stream.playing.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });

    _player.stream.buffering.listen((buffering) {
      state = state.copyWith(buffering: buffering);
    });

    _player.stream.buffer.listen((buffer) {
      state = state.copyWith(buffer: buffer);
    });

    _player.stream.position.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _player.stream.duration.listen((dur) async {
      state = state.copyWith(duration: dur);
    });
  }

  //通过index删除歌曲
  // Add this method to the PlayerNotifier class
  void removeFromPlaylist(Media media) {
    if (state.playlist.isEmpty) return;

    final index = state.playlist.indexOf(media);
    if (index == -1) return; // Media not found in playlist

    // Create updated lists
    final updatedPlaylist = [...state.playlist]..removeAt(index);
    final updatedOriginalOrder = [...state.originalOrder];

    // Adjust original order indices
    for (int i = 0; i < updatedOriginalOrder.length; i++) {
      if (updatedOriginalOrder[i] > index) {
        updatedOriginalOrder[i]--;
      }
    }
    updatedOriginalOrder.removeWhere((i) => i == index);

    // Determine new current index
    int newCurrentIndex = state.currentIndex;
    if (index == state.currentIndex) {
      // If removing currently playing item, move to next or previous
      newCurrentIndex =
          (state.currentIndex < updatedPlaylist.length)
              ? state.currentIndex
              : (updatedPlaylist.isNotEmpty ? state.currentIndex - 1 : 0);
    } else if (index < state.currentIndex) {
      // If removing item before current, adjust current index
      newCurrentIndex--;
    }

    // Update state
    state = state.copyWith(
      playlist: updatedPlaylist,
      originalOrder: updatedOriginalOrder,
      currentIndex: newCurrentIndex.clamp(0, updatedPlaylist.length - 1),
    );

    // If we removed the currently playing item and there are items left, play the new current
    if (index == state.currentIndex && updatedPlaylist.isNotEmpty) {
      playIndex(newCurrentIndex);
    } else if (updatedPlaylist.isEmpty) {
      // If playlist is now empty, stop playback
      _player.stop();
      state = state.copyWith(isPlaying: false);
    }
  }

  // Add this method to remove by index if needed
  void removeFromPlaylistByIndex(int index) {
    if (index < 0 || index >= state.playlist.length) return;
    removeFromPlaylist(state.playlist[index]);
    if (0 != state.playlist.length - 1) {
      _prefetchNextAudioUrl(state.currentIndex);
    }
  }

  // 新增：增量添加歌曲到播放列表
  void addToPlaylist(Media media) {
    final updatedPlaylist = [...state.playlist, media];

    state = state.copyWith(
      playlist: updatedPlaylist,
      originalOrder: List.generate(updatedPlaylist.length, (i) => i),
    );

    // 如果是第一次添加，自动开始播放
    if (updatedPlaylist.length == 1) {
      playIndex(0);
    }
  }

  void setPlaylistclear() {
    setPlaylist([]);
  }

  // 批量删除播放列表歌曲
  void removeFromPlaylistByIndexes(List<int> indexes) {
    if (state.playlist.isEmpty || indexes.isEmpty) return;

    // Sort and deduplicate indexes in descending order for safe removal
    final sortedIndexes =
        indexes.toSet().toList()..sort((a, b) => b.compareTo(a));

    // Create copies of current state
    var updatedPlaylist = [...state.playlist];
    var updatedOriginalOrder = [...state.originalOrder];
    var currentIndex = state.currentIndex;
    var wasPlayingCurrent = false;

    // Remove items from playlist and adjust original order
    for (final index in sortedIndexes) {
      if (index < 0 || index >= updatedPlaylist.length) continue;

      // Check if we're removing the currently playing item
      if (index == currentIndex) {
        wasPlayingCurrent = true;
      }

      // Remove from playlist
      updatedPlaylist.removeAt(index);

      // Adjust original order indices
      for (int i = 0; i < updatedOriginalOrder.length; i++) {
        if (updatedOriginalOrder[i] > index) {
          updatedOriginalOrder[i]--;
        }
      }
      updatedOriginalOrder.removeWhere((i) => i == index);

      // Adjust current index if needed
      if (index < currentIndex) {
        currentIndex--;
      }
    }

    // Handle case where current item was removed
    if (wasPlayingCurrent) {
      if (updatedPlaylist.isNotEmpty) {
        // Try to play next song or previous if at end
        currentIndex = currentIndex.clamp(0, updatedPlaylist.length - 1);
      } else {
        // Playlist is now empty
        _player.stop();
      }
    }

    // Update state
    state = state.copyWith(
      playlist: updatedPlaylist,
      originalOrder: updatedOriginalOrder,
      currentIndex: currentIndex.clamp(0, updatedPlaylist.length - 1),
      isPlaying:
          wasPlayingCurrent ? updatedPlaylist.isNotEmpty : state.isPlaying,
    );

    // If we removed the currently playing item and there are items left, play the new current
    if (wasPlayingCurrent && updatedPlaylist.isNotEmpty) {
      playIndex(currentIndex);
    }
  }

  // 新增：批量添加歌曲
  void addMultipleToPlaylist(List<Media> mediaList) {
    final updatedPlaylist = [...state.playlist, ...mediaList];

    state = state.copyWith(
      playlist: updatedPlaylist,
      originalOrder: List.generate(updatedPlaylist.length, (i) => i),
    );

    ///*/* 如果当前没有在播放，自动开始播放第一首
    if (!state.isPlaying && updatedPlaylist.isNotEmpty) {
      //print(updatedPlaylist.first.extras!['title']);
      playIndex(0);
    }
  }

  void setPlaylist(List<Media> media) {
    final originalOrder = List.generate(media.length, (i) => i);

    state = state.copyWith(
      playlist: media,
      currentIndex: 0,
      originalOrder: originalOrder,
      isShuffled: false,
    );
  }

  //==========playindexenhancehelper==========
  bool isValidUrl(String url, Duration outDatedTime) {
    debugPrint('Validating URL: $url'); // Better logging

    // Check URL format first
    final pattern = r'^https?://'; // http:// or https:// (optional)
    //r'(([a-zA-Z0-9\-_]+\.)+[a-zA-Z]{2,}|localhost)' // domain or localhost
    //r'(:\d+)?' // port (optional)
    //r'(\/[^\s?#]*)?' // path (optional)
    //r'(\?[^\s#]*)?' // query (optional)
    //r'(#.*)?$'; // fragment (optional)

    final regExp = RegExp(pattern);
    if (!regExp.hasMatch(url)) {
      debugPrint('Invalid URL format');
      return false;
    }

    // Check timestamp if exists
    try {
      final media = state.playlist.firstWhere((m) => m.uri == url);
      if (media.extras?['timestamp'] != null) {
        final timestamp = media.extras!['timestamp'] as int;
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        final isExpired = age >= outDatedTime.inMilliseconds;
        debugPrint(outDatedTime.inMilliseconds.toString());
        debugPrint('URL age: $age ms, expired: $isExpired');
        return !isExpired;
      }
    } catch (e) {
      debugPrint('Error checking media timestamp: $e');
    }

    return true;
  }

  Future<void> _prefetchNextAudioUrl(int currentIndex) async {
    final nextIndex = (state.currentIndex + 1) % state.playlist.length;
    // 检查下一首是否存在
    if (nextIndex < state.playlist.length) {
      final nextMedia = state.playlist[nextIndex];
      try {
        final isvaild = isValidUrl(nextMedia.uri, Duration(minutes: 15));

        if (isvaild) return;
        final audioUrl = await musicBox.getAudioUrlV1(nextMedia);

        if (audioUrl != null && audioUrl != 'no') {
          // 更新播放列表中的 URL
          final updatedPlaylist = [...state.playlist];
          updatedPlaylist[nextIndex] = Media(
            audioUrl,
            extras: {
              ...?nextMedia.extras,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
          );
          state = state.copyWith(playlist: updatedPlaylist);
          debugPrint('预取成功: 下一首歌曲 (Index=$nextIndex)');
        }
      } catch (e) {
        debugPrint('预取失败 (Index=$nextIndex): $e');
      }
    }
  }

  void _startPlaybackMonitor() {
    _playbackMonitor?.cancel(); // 取消之前的定时器
    _playbackMonitor = Timer.periodic(const Duration(seconds: 1), (timer) {
      final position = state.position.inSeconds;
      final duration = state.duration.inSeconds;

      // 避免除零错误（未获取到 duration 时）
      if (duration <= 0) return;

      // 当播放进度接近结束时（剩余 1 秒内），触发 next()
      if (position >= duration - 1 && !_isNaturalEnd) {
        _isNaturalEnd = true;
        debugPrint('歌曲自然结束，切换到下一首');
        next();
      }
    });
  }

  Future<void> playIndex(int index) async {
    _isNaturalEnd = false;
    _playbackMonitor?.cancel();

    try {
      final currentMedia = state.playlist[index];
      final newPathTag = currentMedia.extras!['path'] ?? '-1';

      // 更新 pathTag 状态
      state = state.copyWith(currentIndex: index, currentPathTag: newPathTag);

      // 只有当 pathTag 变化时才通知
      if (_lastPathTag != newPathTag) {
        _lastPathTag = newPathTag;
        // 这里会自动通过 Riverpod 通知监听者
      }
      String audioUrl = currentMedia.uri;

      // 1. 检查并刷新当前歌曲的 URL
      if (!(currentMedia.extras?.containsKey('timestamp') ?? true) ||
          !isValidUrl(audioUrl, Duration(minutes: 15))) {
        if (currentMedia.extras!['providers'] == 'alist') return;

        final currentAudioUrl = await musicBox.getAudioUrlV1(currentMedia);

        if (currentAudioUrl == null || currentAudioUrl == 'no') {
          debugPrint('当前歌曲 URL 无效，跳过');
          next();
          return;
        }

        // 2. 更新当前歌曲的 Media 对象
        final updatedMedia = Media(
          currentAudioUrl.isEmpty ? audioUrl : currentAudioUrl,
          extras: {
            ...?currentMedia.extras,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );
        final updatedPlaylist = [...state.playlist];
        updatedPlaylist[index] = updatedMedia;
        state = state.copyWith(playlist: updatedPlaylist);

        audioUrl = currentAudioUrl;
      }

      // 3. 播放当前歌曲
      await _player.open(state.playlist[index], play: false);
      await _player.play();

      // 4. 更新状态
      state = state.copyWith(
        currentIndex: index,
        isPlaying: true,
        position: Duration.zero,
      );

      // 5. 预取下一首歌曲的 URL
      if (state.playlist.length > 1) {
        await _prefetchNextAudioUrl(index);
      }

      // 6. 启动播放进度监听
      _startPlaybackMonitor();
    } catch (e) {
      debugPrint('播放失败: $e');
      next();
    }
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      _player.pause();
      _playbackMonitor?.cancel(); // 暂停时取消监听
    } else {
      _player.play();
      _startPlaybackMonitor(); // 恢复播放时重新监听
    }
  }

  void next() {
    if (state.playlist.isEmpty) return;

    int nextIndex;
    switch (state.playMode) {
      case PlayMode.random:
        nextIndex = _random.nextInt(state.playlist.length);
        break;
      case PlayMode.singleLoop:
        nextIndex = state.currentIndex;
        break;
      case PlayMode.sequence:
        nextIndex = (state.currentIndex + 1) % state.playlist.length;
        break;
    }
    playIndex(nextIndex);
  }

  void previous() {
    if (state.playlist.isEmpty) return;

    int prevIndex;
    if (state.position.inSeconds > 3) {
      prevIndex = state.currentIndex;
    } else {
      prevIndex = (state.currentIndex - 1) % state.playlist.length;
      if (prevIndex < 0) prevIndex = state.playlist.length - 1;
    }
    playIndex(prevIndex);
  }

  void switchPlayMode() {
    final nextMode =
        PlayMode.values[(PlayMode.values.indexOf(state.playMode) + 1) %
            PlayMode.values.length];

    state = state.copyWith(playMode: nextMode);
  }

  void toggleShuffle() {
    if (state.playlist.isEmpty) return;

    if (state.isShuffled) {
      // Restore original order
      final originalPlaylist =
          state.originalOrder.map((i) => state.playlist[i]).toList();

      // Find current track in original order
      final currentMedia = state.playlist[state.currentIndex];
      final newIndex = originalPlaylist.indexOf(currentMedia);

      state = state.copyWith(
        playlist: originalPlaylist,
        currentIndex: newIndex,
        isShuffled: false,
      );
    } else {
      // Create shuffled playlist
      final shuffledIndices = List.of(state.originalOrder)..shuffle(_random);
      final shuffledPlaylist =
          shuffledIndices.map((i) => state.playlist[i]).toList();

      // Find current track in shuffled order
      final currentMedia = state.playlist[state.currentIndex];
      final newIndex = shuffledPlaylist.indexOf(currentMedia);

      state = state.copyWith(
        playlist: shuffledPlaylist,
        currentIndex: newIndex,
        isShuffled: true,
      );
    }
  }

  void seek(Duration position) {
    _isNaturalEnd = false;
    _playbackMonitor?.cancel(); // 取消当前检查

    // 如果跳转到歌曲结尾，直接触发播放完成逻辑
    if (position >= state.duration) {
      _isNaturalEnd = true;
      next(); // 切换到下一首
      return;
    }

    _player.seek(position);
    state = state.copyWith(position: position);
    _startPlaybackMonitor(); // 重新启动监听
  }

  @override
  void dispose() {
    _playbackMonitor?.cancel(); // 销毁定时器
    _player.dispose();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  final musicBox = ref.read(musicBoxProvider);
  return PlayerNotifier(musicBox);
});
final currentPathTagProvider = Provider<String>((ref) {
  final playerState = ref.watch(playerProvider);
  return playerState.currentPathTag;
});
