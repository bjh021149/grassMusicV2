import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grassmusicv2/models/netease_music.dart';
import 'package:grassmusicv2/providers/music_box.dart';
import 'package:grassmusicv2/providers/player_provider.dart' as player_provider;

import 'package:grassmusicv2/services/audio_downloader.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SongUtils {
  /// 播放单首歌曲（带重复检查）
  static Future<void> playSong({
    required BuildContext context,
    required WidgetRef ref,
    required Song song,
  }) async {
    final player = ref.read(player_provider.playerProvider.notifier);
    final currentState = ref.read(player_provider.playerProvider);

    try {
      // 使用 MusicBox 获取音频 URL
      final media = song.toMedia();
      final existingIndex = currentState.playlist.indexWhere(
        (m) => m.extras?['id'] == song.id,
      );

      if (existingIndex == -1) {
        player.addToPlaylist(media);
        player.playIndex(currentState.playlist.length);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('正在播放: ${song.name}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('播放失败: ${e.toString()}')));
      }
    }
  }

  /// 将 Song 转换为 Media（使用 MusicBox 获取 URL）

  /// 批量添加到播放列表
  static Future<void> addSongsToPlaylist({
    required BuildContext context,
    required WidgetRef ref,
    required List<Song> songs,
  }) async {
    try {
      final player = ref.read(player_provider.playerProvider.notifier);
      final mediaList = await Future.wait(songs.map((s) async => s.toMedia()));

      player.addMultipleToPlaylist(mediaList);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已添加到播放列表')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败: ${e.toString()}')));
      }
    }
  }

  static Future<void> downloadSong(
    BuildContext context,
    MusicBox musicBox,
    Song song,
    SharedPreferences pref,
  ) async {
    final downloader = AudioDownloader();

    final audioUrl = await musicBox.getAudioUrlV1(song.toMedia());
    if (audioUrl == null || audioUrl == 'no') return;
    String filename = Uri.parse(audioUrl).pathSegments.last;
    debugPrint(filename);
    String fileExtension = filename.split('.').last;
    String songName = song.name;
    String fileName = '$songName.$fileExtension';
    //final downloadPath = r'c:\Users\bjh02\Music\musiclibrary';
    final downloadPath =
        pref.getString('download_path') ?? r'c:\Users\bjh02\Music\musiclibrary';

    await downloader.downloadAudio(
      audioUrl,
      song.artists.first.name,
      song.album.name,
      fileName,
      downloadPath,
    );
    await Future.delayed(const Duration(seconds: 1));
    await downloader.downloadCover(
      song.album.picUrl,
      song.artists.first.name,
      song.album.name,
      downloadPath,
    );
    await Future.delayed(const Duration(seconds: 1));
    await downloader.downloadLrc(
      song.id,
      song.name,
      song.artists.first.name,
      song.album.name,
      downloadPath,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已下载: $fileName')));
    }
    final newSong = song.copyWith(name: fileName);
    print(newSong.name);
    await musicBox.addNeteaseSongL(newSong);
  }

  static Future<void> addNeteaseSong(
    BuildContext context,
    MusicBox musicBox,
    Song song,
    SharedPreferences pref,
  ) async {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加: ${song.name}')));
      debugPrint(song as String?);
    }

    await musicBox.addNeteaseSongN(song);
  }
}
