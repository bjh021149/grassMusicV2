import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grassmusicv2/locator/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grassmusicv2/providers/pixel_converter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grassmusicv2/utils/netease_image_cache_manager.dart';
import 'package:grassmusicv2/providers/player_provider.dart';

SharedPreferences get pref => getIt<SharedPreferences>();

class MediaItems extends ConsumerWidget {
  final Media song;
  final WidgetRef ref;
  final int? index;

  const MediaItems({
    super.key,
    required this.song,
    required this.ref,
    this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final extras = song.extras ?? {};

    final isCurrent = index != null && index == playerState.currentIndex;
    final height = isCurrent ? 200.0 : 120.0;

    return Column(
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                PixelConverter.physicalToLogical(context, 1),
              ),
              child: SizedBox(
                height: PixelConverter.physicalToLogical(context, height),
                width: PixelConverter.physicalToLogical(context, 200),
                child: CachedNetworkImage(
                  cacheManager: NeteaseImageCacheManager(),
                  imageUrl:
                      extras['thumbnail']?.toString().isNotEmpty == true
                          ? extras['thumbnail']
                          : 'https://via.placeholder.com/200',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: ListTile(
                title: Text(
                  extras['title']?.toString().isNotEmpty == true
                      ? extras['title']
                      : '未知标题',
                  style: TextStyle(
                    fontSize: PixelConverter.physicalToLogical(context, 22),
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color:
                        isCurrent
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  extras['artist']?.toString().isNotEmpty == true
                      ? extras['artist']
                      : '未知艺术家',
                  style: TextStyle(
                    fontSize: PixelConverter.physicalToLogical(context, 18),
                    color:
                        isCurrent
                            ? Theme.of(context).primaryColor.withAlpha(204)
                            : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Delete button - only shown if index is provided (in playlist)
                    if (index != null)
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          size: PixelConverter.physicalToLogical(context, 24),
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: () {
                          playerNotifier.removeFromPlaylistByIndex(index!);
                        },
                        tooltip: '从播放列表删除',
                      ),
                    // Play/Pause button
                    IconButton(
                      icon: Icon(
                        isCurrent && playerState.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: PixelConverter.physicalToLogical(context, 28),
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        if (index != null) {
                          playerNotifier.playIndex(index!);
                        } else {
                          playerNotifier.addToPlaylist(song);
                          playerNotifier.playIndex(
                            playerState.playlist.length - 1,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(
            bottom: PixelConverter.physicalToLogical(context, 4),
          ),
        ),
      ],
    );
  }
}
