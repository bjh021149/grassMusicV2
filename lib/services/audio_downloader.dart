// audio_downloader.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
//import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/netease_music.dart';
import './netease_api.dart' as netease;

class AudioDownloader {
  final Dio _dio = Dio();

  // 修改下载方法，接受自定义路径参数
  Future<File?> downloadAudio(
    String audioUrl,
    String artist,
    String album,
    String fileName,
    String downloadPath,
  ) async {
    // 跳过权限检查（Windows 不需要）
    if (!Platform.isWindows) {
      final status = await Permission.storage.request();
      if (!status.isGranted) throw Exception('Permission denied');
    }

    String sanitizeFileName(String name) {
      return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    }

    artist = sanitizeFileName(artist);
    album = sanitizeFileName(album);
    fileName = sanitizeFileName(fileName);
    try {
      // 使用传入的downloadPath而不是固定路径
      final Directory dir = Directory(downloadPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final String savePath = path.join(downloadPath, artist, album, fileName);
      debugPrint('savePath: $savePath');
      if (!await File(savePath).exists()) {
        await _dio.download(
          audioUrl,
          savePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              debugPrint(
                'Download progress: ${(received / total * 100).toStringAsFixed(0)}%',
              );
            }
          },
        );
      }

      return File(savePath);
    } catch (e) {
      print('Download error: $e');
      return null;
    }
  }

  // 修改文件存在检查方法，使用自定义路径
  Future<File?> downloadCover(
    // ignore: non_constant_identifier_names
    String url,
    String artist,
    String album,

    String downloadPath,
  ) async {
    // 跳过权限检查（Windows 不需要）
    if (!Platform.isWindows) {
      final status = await Permission.storage.request();
      if (!status.isGranted) throw Exception('Permission denied');
    }

    String sanitizeFileName(String name) {
      return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    }

    artist = sanitizeFileName(artist);
    album = sanitizeFileName(album);
    String fileName = 'cover.jpg';
    try {
      // 使用传入的downloadPath而不是固定路径
      final Directory dir = Directory(downloadPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final String savePath = path.join(downloadPath, artist, album, fileName);
      debugPrint('savePath: $savePath');
      if (!await File(savePath).exists()) {
        await _dio.download(
          url,
          savePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              debugPrint(
                'Download progress: ${(received / total * 100).toStringAsFixed(0)}%',
              );
            }
          },
        );
      }

      return File(savePath);
    } catch (e) {
      print('Download error: $e');
      return null;
    }
  }

  Future<Map<String, File?>> downloadLrc(
    String songId,
    String songName,
    String artist,
    String album,
    String downloadPath,
  ) async {
    // 跳过权限检查（Windows 不需要）
    if (!Platform.isWindows) {
      final status = await Permission.storage.request();
      if (!status.isGranted) throw Exception('Permission denied');
    }

    String sanitizeFileName(String name, {bool removeAudioExtensions = false}) {
      String result = name;

      if (removeAudioExtensions) {
        // 移除常见的音频文件格式后缀（不区分大小写）
        result = result.replaceAll(
          RegExp(
            r'\.(flac|mp3|m4a|wav|aac|ogg|wma|ape|alac|dsf|dff|mqa)$',
            caseSensitive: false,
          ),
          '',
        );
      }

      // 替换非法字符为下划线
      result = result.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // 去除首尾空格和可能的多个下划线
      result = result.trim();
      result = result.replaceAll(RegExp(r'_+'), '_');

      return result;
    }

    artist = sanitizeFileName(artist);
    album = sanitizeFileName(album);
    songName = sanitizeFileName(songName);

    try {
      // 创建目录
      final String saveDirPath = path.join(downloadPath, artist, album);
      final Directory saveDir = Directory(saveDirPath);

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 获取歌词数据
      final neteaseApi = netease.NeteaseMusicApi(
        await SharedPreferences.getInstance(),
      );
      RawLyricResponse lrcData;

      try {
        lrcData = await neteaseApi.getLyricNew([songId]);
      } catch (e) {
        debugPrint('getLyricNew 失败，尝试使用 getLyric: $e');
        final Map<String, String> lyricMap = await neteaseApi.getLyric([
          songId,
        ]);

        lrcData = RawLyricResponse(
          sgc: false,
          sfy: false,
          qfy: false,
          lrc: lyricMap['lyric'] ?? '',
          tlyric: lyricMap['translatedLyric'] ?? '',
          klyric: lyricMap['klyric'] ?? '',
          yrc: '',
          romalrc: lyricMap['romalrc'] ?? '',
          code: 200,
        );
      }

      // 准备返回的文件映射
      final Map<String, File?> lyricFiles = {};

      // 1. 保存原始歌词 (LRC)
      if (lrcData.lrc.isNotEmpty) {
        final String originalLrcPath = path.join(saveDirPath, '$songName.lrc');
        final File originalLrcFile = File(originalLrcPath);

        if (!await originalLrcFile.exists()) {
          await originalLrcFile.writeAsString(lrcData.lrc, flush: true);
          debugPrint('原始歌词保存成功: $originalLrcPath');
        }
        lyricFiles['original'] = originalLrcFile;
      }

      // 2. 保存翻译歌词 (Translated LRC)
      if (lrcData.tlyric.isNotEmpty) {
        final String translatedLrcPath = path.join(
          saveDirPath,
          '${songName}_translated.lrc',
        );
        final File translatedLrcFile = File(translatedLrcPath);

        if (!await translatedLrcFile.exists()) {
          await translatedLrcFile.writeAsString(lrcData.tlyric, flush: true);
          debugPrint('翻译歌词保存成功: $translatedLrcPath');
        }
        lyricFiles['translated'] = translatedLrcFile;
      }

      // 3. 保存逐字歌词 (Karaoke LRC)
      if (lrcData.klyric.isNotEmpty) {
        final String karaokeLrcPath = path.join(
          saveDirPath,
          '${songName}_karaoke.lrc',
        );
        final File karaokeLrcFile = File(karaokeLrcPath);

        if (!await karaokeLrcFile.exists()) {
          await karaokeLrcFile.writeAsString(lrcData.klyric, flush: true);
          debugPrint('逐字歌词保存成功: $karaokeLrcPath');
        }
        lyricFiles['karaoke'] = karaokeLrcFile;
      }

      // 4. 保存罗马音歌词 (Romaji LRC)
      if (lrcData.romalrc.isNotEmpty) {
        final String romaLrcPath = path.join(
          saveDirPath,
          '${songName}_romaji.lrc',
        );
        final File romaLrcFile = File(romaLrcPath);

        if (!await romaLrcFile.exists()) {
          await romaLrcFile.writeAsString(lrcData.romalrc, flush: true);
          debugPrint('罗马音歌词保存成功: $romaLrcPath');
        }
        lyricFiles['romaji'] = romaLrcFile;
      }

      // 5. 保存YRC歌词 (网易云音乐特殊格式)
      if (lrcData.yrc.isNotEmpty) {
        final String yrcPath = path.join(saveDirPath, '${songName}.yrc');
        final File yrcFile = File(yrcPath);

        if (!await yrcFile.exists()) {
          await yrcFile.writeAsString(lrcData.yrc, flush: true);
          debugPrint('YRC歌词保存成功: $yrcPath');
        }
        lyricFiles['yrc'] = yrcFile;
      }

      // 6. 保存合并歌词 (原始+翻译，兼容大多数播放器)
      if (lrcData.lrc.isNotEmpty && lrcData.tlyric.isNotEmpty) {
        final String mergedLrcPath = path.join(
          saveDirPath,
          '${songName}_merged.lrc',
        );
        final File mergedLrcFile = File(mergedLrcPath);

        if (!await mergedLrcFile.exists()) {
          String mergedContent = lrcData.lrc;
          if (mergedContent.isNotEmpty && !mergedContent.endsWith('\n')) {
            mergedContent += '\n';
          }
          mergedContent += lrcData.tlyric;

          await mergedLrcFile.writeAsString(mergedContent, flush: true);
          debugPrint('合并歌词保存成功: $mergedLrcPath');
        }
        lyricFiles['merged'] = mergedLrcFile;
      }

      /*7. 保存所有歌词的JSON格式（包含元数据）
    final String jsonPath = path.join(saveDirPath, '${songName}_lyrics.json');
    final File jsonFile = File(jsonPath);
    
    final lyricJson = {
      'songId': songId,
      'songName': songName,
      'artist': artist,
      'album': album,
      'timestamp': DateTime.now().toIso8601String(),
      'lyrics': {
        'original': lrcData.lrc,
        'translated': lrcData.tlyric,
        'karaoke': lrcData.klyric,
        'romaji': lrcData.romalrc,
        'yrc': lrcData.yrc,
      },
      'metadata': {
        'sgc': lrcData.sgc,
        'sfy': lrcData.sfy,
        'qfy': lrcData.qfy,
        'hasOriginal': lrcData.lrc.isNotEmpty,
        'hasTranslated': lrcData.tlyric.isNotEmpty,
        'hasKaraoke': lrcData.klyric.isNotEmpty,
        'hasRomaji': lrcData.romalrc.isNotEmpty,
        'hasYrc': lrcData.yrc.isNotEmpty,
      }
    };
    
    await jsonFile.writeAsString(jsonEncode(lyricJson), flush: true);
    lyricFiles['json'] = jsonFile;
    debugPrint('JSON歌词信息保存成功: $jsonPath');*/

      // 8. 如果没有歌词，创建一个占位符文件
      if (lyricFiles.isEmpty || !lyricFiles.containsKey('original')) {
        final String placeholderPath = path.join(saveDirPath, '$songName.lrc');
        final File placeholderFile = File(placeholderPath);

        final placeholderContent = '''
[ti:$songName]
[ar:$artist]
[al:$album]
[by:网易云音乐]
[00:00.00]暂无歌词
''';

        await placeholderFile.writeAsString(placeholderContent, flush: true);
        lyricFiles['placeholder'] = placeholderFile;
        debugPrint('占位歌词文件创建成功: $placeholderPath');
      }

      return lyricFiles;
    } catch (e) {
      debugPrint('下载歌词失败: $e');
      return {};
    }
  }

  // 修改获取文件列表方法，使用自定义路径
  Future<List<File>> getDownloadedFiles(String downloadPath) async {
    try {
      final Directory dir = Directory(downloadPath);
      if (!await dir.exists()) {
        return [];
      }
      return dir.list().where((file) => file is File).cast<File>().toList();
    } catch (e) {
      print('Error getting downloaded files: $e');
      return [];
    }
  }
}
