// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'netease_music_user_playlist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPlaylist _$UserPlaylistFromJson(Map<String, dynamic> json) => UserPlaylist(
  id: UserPlaylist._parseId(json['id']),
  name: json['name'] as String? ?? '未知歌单',
  coverImgUrl: UserPlaylist._parseCoverUrl(json['coverImgUrl']),
  trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
  playCount: (json['playCount'] as num?)?.toInt() ?? 0,
  creator: UserPlaylist._parseCreatorName(json['creator']),
  subscribed: json['subscribed'] as bool? ?? false,
);

Map<String, dynamic> _$UserPlaylistToJson(UserPlaylist instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'coverImgUrl': instance.coverImgUrl,
      'trackCount': instance.trackCount,
      'playCount': instance.playCount,
      'creator': instance.creator,
      'subscribed': instance.subscribed,
    };
