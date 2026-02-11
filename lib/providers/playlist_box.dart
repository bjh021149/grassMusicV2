import 'package:objectbox/objectbox.dart';
import '../services/objectbox_service.dart';
import '../models/playlist_item.dart';
import '../objectbox.g.dart';

// First, let's update the PlaylistBox class to expose necessary methods
class PlaylistBox {
  final Box<CustomPlaylist> _playlistBox;

  PlaylistBox(ObjectBoxService objectBoxService)
    : _playlistBox = objectBoxService.playlistBox;

  Future<void> createPlaylist(String playlistName) async {
    try {
      final query =
          _playlistBox.query(CustomPlaylist_.name.equals(playlistName)).build();
      final existingPlaylist = query.findFirst();
      query.close();

      if (existingPlaylist == null) {
        final newPlaylist = CustomPlaylist(name: playlistName, mediaIdList: []);
        _playlistBox.put(newPlaylist);
        print('Playlist "$playlistName" created successfully');
      } else {
        print('Playlist "$playlistName" already exists');
      }
    } catch (e) {
      print('Error creating playlist: $e');
      rethrow;
    }
  }

  Future<void> addToPlaylist(String playlistName, int mediaId) async {
    try {
      // First ensure the playlist exists
      await createPlaylist(playlistName);

      final query =
          _playlistBox.query(CustomPlaylist_.name.equals(playlistName)).build();
      final playlist = query.findFirst();
      query.close();

      if (playlist == null) {
        throw Exception('Playlist "$playlistName" not found after creation');
      }

      if (!playlist.mediaIdList.contains(mediaId)) {
        playlist.addMediaId(mediaId);
        _playlistBox.put(playlist);
        print('Added media $mediaId to playlist "$playlistName"');
      } else {
        print('Media $mediaId already exists in playlist "$playlistName"');
      }
    } catch (e) {
      print('Error adding to playlist: $e');
      rethrow;
    }
  }

  List<CustomPlaylist> getAllPlaylists() {
    return _playlistBox.getAll();
  }

  List<int> getMediaIdsInPlaylist(String playlistName) {
    final query =
        _playlistBox.query(CustomPlaylist_.name.equals(playlistName)).build();
    final playlist = query.findFirst();
    query.close();
    return playlist?.mediaIdList ?? [];
  }

  Future<void> removeFromPlaylist(String playlistName, int mediaId) async {
    final query =
        _playlistBox.query(CustomPlaylist_.name.equals(playlistName)).build();
    final playlist = query.findFirst();
    query.close();

    if (playlist != null) {
      playlist.removeMediaId(mediaId);
      _playlistBox.put(playlist);
    }
  }

  Future<void> deletePlaylist(String playlistName) async {
    final query =
        _playlistBox.query(CustomPlaylist_.name.equals(playlistName)).build();
    final playlist = query.findFirst();
    query.close();

    if (playlist != null) {
      _playlistBox.remove(playlist.id);
    }
  }

  // Add this new method to get playlist by ID
  CustomPlaylist? getPlaylistById(int id) {
    return _playlistBox.get(id);
  }
}
