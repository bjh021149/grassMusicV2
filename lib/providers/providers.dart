import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grassmusicv2/models/netease_music_user_playlist.dart';
import 'package:grassmusicv2/models/netease_music.dart';
import 'package:grassmusicv2/models/playlist_detail.dart';
import 'package:grassmusicv2/providers/music_box.dart';
import 'package:grassmusicv2/providers/playlist_box.dart';
import 'package:grassmusicv2/services/objectbox_service.dart';

// Provider for login state
final loginStateProvider = StateProvider<bool>((ref) => false);

// Provider for daily recommended songs
final dailySongsProvider = StateProvider<List<Song>>((ref) => []);

// Provider for user playlists
final playlistsProvider = StateProvider<List<UserPlaylist>>((ref) => []);

// Provider for list detail
final userPlaylistDetailsProvider = StateProvider<PlaylistDetail?>(
  (ref) => null,
);

// 1. First create a non-nullable ObjectBoxService provider
final objectBoxServiceProvider = Provider<ObjectBoxService>((ref) {
  throw UnimplementedError('Should be overridden in main.dart');
});

// 2. Create non-nullable MusicBox provider
final musicBoxProvider = Provider<MusicBox>((ref) {
  return MusicBox(ref.read(objectBoxServiceProvider));
});

// 3. Create non-nullable PlaylistBox provider
final playlistBoxProvider = Provider<PlaylistBox>((ref) {
  return PlaylistBox(ref.read(objectBoxServiceProvider));
});
