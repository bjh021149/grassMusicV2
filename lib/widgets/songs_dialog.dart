import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grassmusicv2/models/netease_music.dart';
import 'package:grassmusicv2/widgets/common/list_song_item_widget.dart';
import 'package:grassmusicv2/utils/song_utils.dart' as songtools;
import 'package:grassmusicv2/providers/pixel_converter.dart';

/// A reusable dialog for displaying and playing songs
class SongsDialog extends StatelessWidget {
  final List<Song> songs;
  final WidgetRef ref;

  const SongsDialog({super.key, required this.songs, required this.ref});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('每日推荐'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return SongItem(
              song: song,
              ref: ref,
              showDownload: true,
              showAddToPlaylist: false,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            '关闭',
            style: TextStyle(
              fontSize: PixelConverter.physicalToLogical(context, 25),
            ),
          ),
        ),
        TextButton(
          onPressed: () => _addAllSongs(context),
          child: Text(
            '全部添加',
            style: TextStyle(
              fontSize: PixelConverter.physicalToLogical(context, 25),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addAllSongs(BuildContext context) async {
    songtools.SongUtils.addSongsToPlaylist(
      context: context,
      ref: ref,
      songs: songs,
    );
  }
}

/// Helper function to show the dialog
Future<void> showDailySongsDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<Song> songs,
}) async {
  await showDialog(
    context: context,
    builder: (context) => SongsDialog(songs: songs, ref: ref),
  );
}
