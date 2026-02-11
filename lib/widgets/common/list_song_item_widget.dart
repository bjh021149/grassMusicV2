import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grassmusicv2/models/netease_music.dart';
import 'package:grassmusicv2/utils/song_utils.dart' as songtools;
import 'package:grassmusicv2/locator/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grassmusicv2/providers/pixel_converter.dart';
import 'package:grassmusicv2/providers/music_box.dart';
import 'package:grassmusicv2/providers/providers.dart';

SharedPreferences get pref => getIt<SharedPreferences>();

class SongItem extends StatelessWidget {
  final Song song;
  final WidgetRef ref;
  final bool showDownload;
  final bool showAddToPlaylist;

  const SongItem({
    super.key,
    required this.song,
    required this.ref,
    this.showDownload = true,
    this.showAddToPlaylist = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PixelConverter.physicalToLogical(context, 120),
      child: ListTile(
        leading: Image.network(
          song.album.picUrl,
          width: PixelConverter.physicalToLogical(context, 200),
          height: PixelConverter.physicalToLogical(context, 200),
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) => Icon(
                Icons.music_note,
                size: PixelConverter.physicalToLogical(context, 200),
              ),
        ),
        title: Text(
          song.name,
          style: TextStyle(
            fontSize: PixelConverter.physicalToLogical(context, 25),
          ),
        ),
        subtitle: Text(
          song.artistNames,
          style: TextStyle(
            fontSize: PixelConverter.physicalToLogical(context, 25),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDownload)
              IconButton(
                icon: Icon(
                  Icons.download,
                  size: PixelConverter.physicalToLogical(context, 40),
                ),
                onPressed: () => _downloadSong(context, song),
              ),
            if (showAddToPlaylist)
              IconButton(
                icon: Icon(
                  Icons.playlist_add,
                  size: PixelConverter.physicalToLogical(context, 40),
                ),
                onPressed: () => _addSongToPlaylist(context, song),
              ),
            IconButton(
              onPressed: () => _addNeteaseSong(context, song),
              icon: Icon(
                Icons.cloud,
                size: PixelConverter.physicalToLogical(context, 40),
              ),
            ),
          ],
        ),
        onTap: () => _playSong(context, song),
      ),
    );
  }

  Future<void> _playSong(BuildContext context, Song song) async {
    songtools.SongUtils.playSong(context: context, ref: ref, song: song);
  }

  Future<void> _downloadSong(BuildContext context, Song song) async {
    final MusicBox musicBox = ref.read(musicBoxProvider);
    songtools.SongUtils.downloadSong(context, musicBox, song, pref);
  }

  Future<void> _addSongToPlaylist(BuildContext context, Song song) async {
    songtools.SongUtils.addSongsToPlaylist(
      context: context,
      ref: ref,
      songs: [song],
    );
  }

  Future<void> _addNeteaseSong(BuildContext context, Song song) async {
    final MusicBox musicBox = ref.read(musicBoxProvider);
    songtools.SongUtils.addNeteaseSong(context, musicBox, song, pref);
  }
}
