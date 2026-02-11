import 'package:objectbox/objectbox.dart';
import 'package:media_kit/media_kit.dart';

@Entity()
class MediaItem {
  @Id()
  int id = 0;

  @Unique()
  String title;
  String artist;
  String album;
  String url;
  String? thumbnail;
  String? association;
  String provider;
  int durationMs;

  @Transient()
  Duration get duration => Duration(milliseconds: durationMs);

  @Transient()
  bool isFavorite = false;

  @Transient()
  Media? _media;

  MediaItem({
    required this.title,
    this.artist = 'Unknown',
    this.album = 'Unknown',
    required this.url,
    this.thumbnail,
    this.association,
    required this.provider,
    required this.durationMs,
  });

  /// Converts this MediaItem to a MediaKit Media object
  Media toMedia() {
    _media ??= Media(
      url,
      extras: {
        'id': id, // Use database ID for better consistency
        'title': title,
        'artist': artist,
        'album': album,
        'thumbnail': thumbnail,
        'association': association,
        'provider': provider,
        'durationMs': durationMs,
        'path': url,
      },
    );
    return _media!;
  }

  /// Creates a MediaItem from a MediaKit Media object
  factory MediaItem.fromMedia(Media media) {
    final extras = media.extras ?? {};
    return MediaItem(
      title: extras['title'] ?? media.uri.split('/').last.split('.').first,
      artist: extras['artist'] ?? 'Unknown',
      album: extras['album'] ?? 'Unknown',
      url: extras['path'],
      thumbnail: extras['thumbnail'],
      association: extras['association'] ?? 'none',
      provider: extras['provider'],
      durationMs: extras['durationMs'] ?? 0,
    );
  }

  /// Creates a MediaItem from JSON data
  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      title: json['title'] ?? 'Unknown',
      artist: json['artist'] ?? 'Unknown',
      album: json['album'] ?? 'Unknown',
      url: json['url'] ?? json['audio_url'],
      thumbnail: json['thumbnail'] ?? json['cover_url'],
      association: json['association'] ?? 'none',
      provider: json['provider'] ?? 'Unknown',
      durationMs: json['duration_ms'] ?? (json['duration'] ?? 0) * 1000,
    );
  }

  /// Creates a copy of this MediaItem with optional overrides
  MediaItem copyWith({
    String? title,
    String? artist,
    String? album,
    String? url,
    String? thumbnail,
    String? association,
    String? provider,
    int? durationMs,
  }) {
    return MediaItem(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      url: url ?? this.url,
      thumbnail: thumbnail ?? this.thumbnail,
      association: association ?? this.association,
      provider: provider ?? this.provider,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}
