import 'package:cached_network_image/cached_network_image.dart';
import 'package:grassmusicv2/utils/netease_image_cache_manager.dart';
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
import 'package:grassmusicv2/providers/pixel_converter.dart';
import 'package:grassmusicv2/utils/song_utils.dart' as songtools;
import 'common/list_song_item_widget.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grassmusicv2/providers/music_box.dart';
import 'songs_dialog.dart';
import 'private_music_dialog.dart';

SharedPreferences get pref => getIt<SharedPreferences>();

class HomeContentWidget extends ConsumerStatefulWidget {
  final List<UserPlaylist> playlists;
  final List<Song> dailySongs;
  final bool isLoading;
  final double? maxHeight;

  const HomeContentWidget({
    super.key,
    required this.playlists,
    required this.dailySongs,
    this.isLoading = false,
    this.maxHeight,
  });

  @override
  HomeContentWidgetState createState() => HomeContentWidgetState();
}

class HomeContentWidgetState extends ConsumerState<HomeContentWidget>
    with SingleTickerProviderStateMixin {
  NeteaseMusicApi get api => getIt<NeteaseMusicApi>();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _cardHeightAnimation;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _cardHeightAnimation = Tween<double>(begin: 0.2, end: 0.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent > 0) {
      _animationController.value = (offset / maxExtent).clamp(0.0, 1.0);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    try {
      final newPlaylists = await api.getUserPlaylists(uid: 10934775);
      final newDailySongs = await api.getDailyRecommendSongs();
      ref.read(playlistsProvider.notifier).state = newPlaylists;
      ref.read(dailySongsProvider.notifier).state = newDailySongs;
    } catch (e) {
      print(e.toString());
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = screenSize.height > screenSize.width;
    final cardWidth =
        isPortrait ? screenSize.width - 32 : (screenSize.width / 2) - 25;

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 顶部卡片部分
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, _) {
                final cardHeight =
                    screenSize.height * _cardHeightAnimation.value;
                return isPortrait
                    ? _buildPortraitTopCards(cardHeight, cardWidth)
                    : _buildLandscapeTopCards(cardHeight, cardWidth);
              },
            ),
          ),

          // 播放列表标题
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                '我的歌单',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // 播放列表网格
          _buildPlaylistGrid(isPortrait, screenSize),

          // 加载更多指示器
          if (_isRefreshing)
            const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildPortraitTopCards(double cardHeight, double cardWidth) {
    return Column(
      children: [
        _buildDailySongsCard(cardHeight, cardWidth),
        const SizedBox(height: 16),
        _buildMusicLibraryCard(cardHeight, cardWidth),
      ],
    );
  }

  Widget _buildLandscapeTopCards(double cardHeight, double cardWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildDailySongsCard(cardHeight, cardWidth)),
        const SizedBox(width: 16),
        Expanded(child: _buildMusicLibraryCard(cardHeight, cardWidth)),
      ],
    );
  }

  Widget _buildDailySongsCard(double height, double width) {
    return Hero(
      tag: 'daily_songs_card',
      child: Material(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
              () => showDailySongsDialog(
                context: context,
                ref: ref,
                songs: widget.dailySongs,
              ),
          child: Container(
            height: height,
            width: width,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple.shade700, Colors.purple.shade900],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (widget.dailySongs.isNotEmpty)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        cacheManager: NeteaseImageCacheManager(),
                        imageUrl: widget.dailySongs.first.album.picUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '每日推荐',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.dailySongs.length}首歌曲',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: _PlayButton(
                    onPressed: () => _playDailySongs(),
                    iconSize: 36,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMusicLibraryCard(double height, double width) {
    final musicBox = ref.read(musicBoxProvider);
    final alistSongs = musicBox.getAllSongs(provider: MusicProvider.alist);
    final neteaseSongs = musicBox.getAllSongs(provider: MusicProvider.netease);
    final totalSongs = alistSongs.length + neteaseSongs.length;

    return Hero(
      tag: 'music_library_card',
      child: Material(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showMusicLibraryDialog(context),
          child: Container(
            height: height,
            width: width,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade600, Colors.blue.shade800],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '音乐库',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$totalSongs首歌曲',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Row(
                    children: [
                      _buildProviderBadge('AList', alistSongs.length),
                      const SizedBox(width: 8),
                      _buildProviderBadge('网易云', neteaseSongs.length),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    color: Colors.white,
                    onPressed: () => showMusicLibraryDialog(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistGrid(bool isPortrait, Size screenSize) {
    final crossAxisCount =
        isPortrait
            ? (screenSize.width ~/ 200).clamp(2, 5)
            : (screenSize.width ~/ 180).clamp(3, 6);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final playlist = widget.playlists[index];
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
        }, childCount: widget.playlists.length),
      ),
    );
  }

  Future<void> _playDailySongs() async {
    try {
      final player = ref.read(player_provider.playerProvider.notifier);
      final List<media_kit.Media> mediaList = await Future.wait(
        widget.dailySongs.map((song) async => song.toMedia()),
      );
      player.addMultipleToPlaylist(mediaList);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已添加到播放列表')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败: ${e.toString()}')));
      }
    }
  }

  Widget _buildProviderBadge(String provider, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(56),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            provider,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double iconSize;

  const _PlayButton({required this.onPressed, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: Colors.white.withAlpha(50),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(Icons.play_arrow, color: Colors.white, size: iconSize),
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
    return Hero(
      tag: 'playlist_${playlist.id}',
      child: Material(
        color:
            isPlaying
                ? Theme.of(context).colorScheme.primary.withAlpha(25)
                : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToPlaylistDetail(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面图片
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        cacheManager: NeteaseImageCacheManager(),
                        imageUrl: playlist.coverImgUrl,
                        fit: BoxFit.cover,
                        placeholder:
                            (_, __) => Container(
                              color: Colors.grey.shade800,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        errorWidget:
                            (_, __, ___) => Container(
                              color: Colors.grey.shade800,
                              child: const Icon(Icons.music_note, size: 48),
                            ),
                      ),

                      // 播放次数
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_arrow,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatPlayCount(playlist.playCount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 正在播放指示器
                      if (isPlaying)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.music_note,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 播放列表信息
              Padding(
                padding: const EdgeInsets.all(1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.trackCount}首 · ${playlist.creator}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
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
      ),
    );
  }

  void _navigateToPlaylistDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                PlaylistDetailScreen(playlistId: int.parse(playlist.id)),
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

// PlaylistDetailScreen 保持不变...
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
                                cacheManager: NeteaseImageCacheManager(),
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
