import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grassmusicv2/models/netease_music_user_playlist.dart';
import 'package:grassmusicv2/providers/player_provider.dart' as player_provider;
import 'package:media_kit/media_kit.dart' as media_kit;

import 'package:grassmusicv2/services/netease_api.dart';
import 'package:grassmusicv2/providers/providers.dart';
import 'package:grassmusicv2/locator/service_locator.dart';
import 'package:grassmusicv2/models/netease_music.dart';
import 'package:grassmusicv2/models/playlist_detail.dart';
import 'package:grassmusicv2/providers/pixel_converter.dart'; // Import PixelConverter
import 'package:grassmusicv2/utils/song_utils.dart' as songtools;
import 'common/list_song_item_widget.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

SharedPreferences get pref => getIt<SharedPreferences>();

class UserPlaylistWidget extends ConsumerWidget {
  NeteaseMusicApi get api => getIt<NeteaseMusicApi>();
  final List<UserPlaylist> playlists;
  final bool isLoading;
  final double? maxHeight;
  const UserPlaylistWidget({
    super.key,
    required this.playlists,
    this.isLoading = false,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRefreshing = StateProvider<bool>((ref) => false);
    // Get logical screen size for responsive layout
    final screenSize = PixelConverter.windowLogicalSize(context);
    // Calculate crossAxisCount based on screen width (e.g., 2 for smaller screens, 3 for larger)
    final crossAxisCount = (screenSize.width / 200).floor().clamp(2, 4);

    if (isLoading || playlists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(isRefreshing.notifier).state = true;
        try {
          final newPlaylists = await api.getUserPlaylists(uid: 10934775);
          ref.read(playlistsProvider.notifier).state = newPlaylists;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('刷新失败: ${e.toString()}')));
          }
        } finally {
          ref.read(isRefreshing.notifier).state = false;
        }
      },
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6 - 56,
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(
            PixelConverter.physicalToLogical(context, 16),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: PixelConverter.physicalToLogical(context, 16),
            mainAxisSpacing: PixelConverter.physicalToLogical(context, 16),
            childAspectRatio: 0.75, // Adjust based on content
          ),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            final playerState = ref.watch(player_provider.playerProvider);
            final isPlaying =
                playerState.playlist.isNotEmpty &&
                playerState.currentIndex >= 0 &&
                playerState.currentIndex < playerState.playlist.length &&
                playerState
                        .playlist[playerState.currentIndex]
                        .extras?['playlistId'] ==
                    playlist.id;

            return _PlaylistCard(
              playlist: playlist,
              isPlaying: isPlaying,
              api: api,
            );
          },
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final UserPlaylist playlist;
  final bool isPlaying;
  final NeteaseMusicApi api;

  const _PlaylistCard({
    required this.playlist,
    required this.isPlaying,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          PixelConverter.physicalToLogical(context, 12),
        ),
      ),
      color:
          isPlaying
              ? Theme.of(
                context,
              ).colorScheme.primary.withAlpha((0.1 * 255).toInt())
              : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(
          PixelConverter.physicalToLogical(context, 12),
        ),
        onTap: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => PlaylistDetailScreen(
                        playlistId: int.parse(playlist.id),
                      ),
                ),
              );
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(
                        PixelConverter.physicalToLogical(context, 12),
                      ),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: playlist.coverImgUrl,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                      errorWidget:
                          (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.music_note,
                              size: PixelConverter.physicalToLogical(
                                context,
                                50,
                              ),
                            ),
                          ),
                    ),
                  ),
                  Positioned(
                    bottom: PixelConverter.physicalToLogical(context, 8),
                    right: PixelConverter.physicalToLogical(context, 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: PixelConverter.physicalToLogical(
                          context,
                          8,
                        ),
                        vertical: PixelConverter.physicalToLogical(context, 4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(
                          PixelConverter.physicalToLogical(context, 12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow,
                            size: PixelConverter.physicalToLogical(context, 16),
                            color: Colors.white,
                          ),
                          SizedBox(
                            width: PixelConverter.physicalToLogical(context, 4),
                          ),
                          Text(
                            _formatPlayCount(playlist.playCount),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: PixelConverter.physicalToLogical(
                                context,
                                12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isPlaying)
                    Positioned(
                      top: PixelConverter.physicalToLogical(context, 8),
                      right: PixelConverter.physicalToLogical(context, 8),
                      child: Container(
                        padding: EdgeInsets.all(
                          PixelConverter.physicalToLogical(context, 6),
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.music_note,
                          size: PixelConverter.physicalToLogical(context, 18),
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(
                PixelConverter.physicalToLogical(context, 12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: PixelConverter.physicalToLogical(context, 16),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(
                    height: PixelConverter.physicalToLogical(context, 4),
                  ),
                  Text(
                    '${playlist.trackCount}首 · ${playlist.creator}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: PixelConverter.physicalToLogical(context, 12),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPlayCount(int count) {
    if (count >= 100000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }
}

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final int playlistId;
  NeteaseMusicApi get api => getIt<NeteaseMusicApi>();

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  PlaylistDetailScreenState createState() => PlaylistDetailScreenState();
}

class PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  PlaylistDetail? _playlistDetail;
  final List<Song> _songs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  Timer? _autoLoadMoreTimer;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);

    _autoLoadMoreTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _autoLoadMoreAndAddToPlaylist();
    });
  }

  @override
  void dispose() {
    _autoLoadMoreTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _autoLoadMoreAndAddToPlaylist() async {
    if (_isLoadingMore || !_hasMore || _playlistDetail == null) return;
    setState(() {
      _isLoadingMore = true;
    });
    final moreSongs = await widget.api.loadMoreSongs(_playlistDetail!);
    setState(() {
      _songs.addAll(moreSongs);
      _playlistDetail!.loadedTrackIds.addAll(
        moreSongs.map((s) => s.id.toString()),
      );
      _hasMore =
          _playlistDetail!.loadedTrackIds.length <
          _playlistDetail!.allTrackIds.length;
      _isLoadingMore = false;
    });

    final player = ref.read(player_provider.playerProvider.notifier);
    final List<media_kit.Media> mediaList = await Future.wait(
      moreSongs.map((song) async => song.toMedia()),
    );
    player.addMultipleToPlaylist(mediaList);
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _songs.clear();
    });
    final detail = await widget.api.getPlaylistDetailFull(
      widget.playlistId.toString(),
    );
    setState(() {
      _playlistDetail = detail;
      _songs.addAll(detail.songs);
      _hasMore = detail.loadedTrackIds.length < detail.allTrackIds.length;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _playlistDetail == null) return;
    setState(() {
      _isLoadingMore = true;
    });
    final moreSongs = await widget.api.loadMoreSongs(_playlistDetail!);
    setState(() {
      _songs.addAll(moreSongs);
      _playlistDetail!.loadedTrackIds.addAll(
        moreSongs.map((s) => s.id.toString()),
      );
      _hasMore =
          _playlistDetail!.loadedTrackIds.length <
          _playlistDetail!.allTrackIds.length;
      _isLoadingMore = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _playlistDetail;
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放列表详情'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.playlist_add,
              size: PixelConverter.physicalToLogical(context, 36),
            ),
            tooltip: '全部添加到播放列表',
            onPressed:
                _songs.isEmpty ? null : () => _addAllinitialSongs(context),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadInitial,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount:
                      _songs.length +
                      (_hasMore ? 1 : 0) +
                      (detail != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (detail != null && index == 0) {
                      return Padding(
                        padding: EdgeInsets.all(
                          PixelConverter.physicalToLogical(context, 16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                PixelConverter.physicalToLogical(context, 8),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: detail.coverImgUrl,
                                width: PixelConverter.physicalToLogical(
                                  context,
                                  80,
                                ),
                                height: PixelConverter.physicalToLogical(
                                  context,
                                  80,
                                ),
                                fit: BoxFit.cover,
                                errorWidget:
                                    (context, url, error) => Icon(
                                      Icons.music_note,
                                      size: PixelConverter.physicalToLogical(
                                        context,
                                        80,
                                      ),
                                    ),
                              ),
                            ),
                            SizedBox(
                              width: PixelConverter.physicalToLogical(
                                context,
                                16,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    detail.name,
                                    style: TextStyle(
                                      fontSize:
                                          PixelConverter.physicalToLogical(
                                            context,
                                            20,
                                          ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(
                                    height: PixelConverter.physicalToLogical(
                                      context,
                                      8,
                                    ),
                                  ),
                                  Text(
                                    'by ${detail.creator.nickname}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize:
                                          PixelConverter.physicalToLogical(
                                            context,
                                            14,
                                          ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: PixelConverter.physicalToLogical(
                                      context,
                                      8,
                                    ),
                                  ),
                                  Text(
                                    detail.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize:
                                          PixelConverter.physicalToLogical(
                                            context,
                                            12,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final songIndex = detail != null ? index - 1 : index;
                    if (songIndex < _songs.length && songIndex >= 0) {
                      final song = _songs[songIndex];
                      return SongItem(
                        song: song,
                        ref: ref,
                        showDownload: true,
                        showAddToPlaylist: true,
                      );
                    } else {
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: PixelConverter.physicalToLogical(
                            context,
                            16,
                          ),
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }
                  },
                ),
              ),
    );
  }

  Future<void> _addAllinitialSongs(BuildContext context) async {
    songtools.SongUtils.addSongsToPlaylist(
      context: context,
      ref: ref,
      songs: _songs,
    );
  }
}
