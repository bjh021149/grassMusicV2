//import 'package:flutter/widgets.dart';

import './media_item.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;
//import 'package:grassmusicv2/extensions/alist_song_extensions.dart';

class Song {
  final String id;
  final String name;
  final List<Artist> artists;
  final Album album;
  final int duration; // 毫秒
  late String? audioUrl;
  final bool available;
  final String? size;

  Song({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.duration,
    this.audioUrl,
    this.available = true,
    this.size,
  });

  // 添加 copyWith 方法
  Song copyWith({
    String? id,
    String? name,
    List<Artist>? artists,
    Album? album,
    int? duration,
    String? audioUrl,
    bool? available,
    String? size,
  }) {
    return Song(
      id: id ?? this.id,
      name: name ?? this.name,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      audioUrl: audioUrl ?? this.audioUrl,
      available: available ?? this.available,
      size: size ?? this.size,
    );
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      artists:
          (json['ar'] as List? ?? []).map((e) => Artist.fromJson(e)).toList(),
      album: Album.fromJson(json['al'] ?? {}),
      duration: json['dt'] ?? 0,
      audioUrl: json['audioUrl'],
      available: json['available'] ?? true,
      size: json['size'],
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ar': artists.map((e) => e.toJson()).toList(),
    'al': album.toJson(),
    'dt': duration,
    'audioUrl': audioUrl,
    'available': available,
    'size': size,
  };
  String get artistNames => artists.map((e) => e.name).join(' / ');

  // 格式化持续时间 (mm:ss)
  String get formattedDuration {
    final duration = Duration(milliseconds: this.duration);
    return '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  String sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  MediaItem toMediaItemL() {
    // Use the first artist as main artist, others as associations
    final mainArtist = artists.isNotEmpty ? artists.first.name : 'Unknown';
    final otherArtists =
        artists.length > 1
            ? artists.sublist(1).map((a) => a.name).join(', ')
            : null;
    final pathTag = path.join(
      sanitizeFileName(mainArtist),
      sanitizeFileName(album.name),
      sanitizeFileName(name),
    );

    return MediaItem(
      title: path.basenameWithoutExtension(name),
      artist: mainArtist,
      album: album.name,
      url: pathTag, //localpathtag
      thumbnail: album.picUrl,
      provider: 'alist',
      durationMs: duration,
      association: otherArtists,
    ); // for save to musicbox;
  }

  MediaItem toMediaItemN() {
    // Use the first artist as main artist, others as associations
    final mainArtist = artists.isNotEmpty ? artists.first.name : 'Unknown';
    final otherArtists =
        artists.length > 1
            ? artists.sublist(1).map((a) => a.name).join(', ')
            : null;

    return MediaItem(
      title: name,
      artist: mainArtist,
      album: album.name,
      url: id, //networkpaathtag
      thumbnail: album.picUrl,
      provider: 'netease',
      durationMs: duration,
      association: otherArtists,
    ); // for save to musicbox;
  }

  Media toMedia() {
    // Use the first artist as main artist, others as associations
    final mainArtist = artists.isNotEmpty ? artists.first.name : 'Unknown';
    final otherArtists =
        artists.length > 1
            ? artists.sublist(1).map((a) => a.name).join(', ')
            : null;

    return Media(
      id, // 使用歌曲ID作为URL初始值
      extras: {
        'path': id, // 保留原始ID
        'title': name,
        'artist': mainArtist,
        'album': album.name,
        'thumbnail': album.picUrl,
        'coverUrl': album.picUrl, // 添加coverUrl以保持一致性
        'provider': 'Netease',
        'durationMs': duration,
        'association': otherArtists,
      },
    );
  }
}

class Artist {
  final String id;
  final String name;

  Artist({required this.id, required this.name});

  Artist copyWith({String? id, String? name}) {
    return Artist(id: id ?? this.id, name: name ?? this.name);
  }

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(id: json['id']?.toString() ?? '', name: json['name'] ?? '');
  }
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  @override
  String toString() => name;
}

class Album {
  final String id;
  final String name;
  final String picUrl;

  Album({required this.id, required this.name, required this.picUrl});

  Album copyWith({String? id, String? name, String? picUrl}) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      picUrl: picUrl ?? this.picUrl,
    );
  }

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      picUrl: json['picUrl'] ?? json['picUrl'] ?? json['coverImgUrl'] ?? '',
    );
  }
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'picUrl': picUrl};
  @override
  String toString() => name;
}

class LyricResponse {
  final bool sgc;
  final bool sfy;
  final bool qfy;
  final Lrc lrc;
  final Yrc yrc;
  final int code;

  LyricResponse({
    required this.sgc,
    required this.sfy,
    required this.qfy,
    required this.lrc,
    required this.yrc,
    required this.code,
  });

  factory LyricResponse.fromJson(Map<String, dynamic> json) {
    return LyricResponse(
      sgc: json['sgc'] ?? false,
      sfy: json['sfy'] ?? false,
      qfy: json['qfy'] ?? false,
      lrc: Lrc.fromJson(json['lrc'] ?? {}),
      yrc: Yrc.fromJson(json['yrc'] ?? {}),
      code: json['code'] ?? 0,
    );
  }
}

class Lrc {
  final int version;
  final String lyric;

  Lrc({required this.version, required this.lyric});

  factory Lrc.fromJson(Map<String, dynamic> json) {
    return Lrc(version: json['version'] ?? 0, lyric: json['lyric'] ?? '');
  }
}

class Yrc {
  final int version;
  final String lyric;

  Yrc({required this.version, required this.lyric});

  factory Yrc.fromJson(Map<String, dynamic> json) {
    return Yrc(version: json['version'] ?? 0, lyric: json['lyric'] ?? '');
  }
}

class LyricLine {
  final Duration startTime;
  final Duration endTime;
  final String text;
  final List<LyricWord>? words; // 仅YRC使用

  LyricLine({
    required this.startTime,
    required this.endTime,
    required this.text,
    this.words,
  });

  @override
  String toString() {
    return '${startTime.inMilliseconds}-${endTime.inMilliseconds}: $text';
  }
}

class LyricWord {
  final Duration startTime;
  final Duration duration;
  final String word;

  LyricWord({
    required this.startTime,
    required this.duration,
    required this.word,
  });

  @override
  String toString() {
    return '${startTime.inMilliseconds} (${duration.inMilliseconds}): $word';
  }
}

class RawLyricResponse {
  final bool sgc;
  final bool sfy;
  final bool qfy;
  final String lrc;
  final String tlyric;
  final String klyric;
  final String yrc;
  final String romalrc;
  final int code;

  RawLyricResponse({
    required this.sgc,
    required this.sfy,
    required this.qfy,
    required this.lrc,
    required this.tlyric,
    required this.klyric,
    required this.yrc,
    required this.romalrc,
    required this.code,
  });

  factory RawLyricResponse.fromJson(Map<String, dynamic> json) {
    return RawLyricResponse(
      sgc: json['sgc'] ?? false,
      sfy: json['sfy'] ?? false,
      qfy: json['qfy'] ?? false,
      lrc: json['lrc']?.toString() ?? '',
      tlyric: json['tlyric']?.toString() ?? '',
      klyric: json['klyric']?.toString() ?? '',
      yrc: json['yrc']?.toString() ?? '',
      romalrc: json['romalrc']?.toString() ?? '',
      code: json['code'] ?? 0,
    );
  }

  bool get hasLrc => lrc.isNotEmpty;
  bool get hasTranslation => tlyric.isNotEmpty;
  bool get hasKaraoke => klyric.isNotEmpty;
  bool get hasWordByWord => yrc.isNotEmpty;
  bool get hasRomaji => romalrc.isNotEmpty;
}
