import 'package:cached_network_image/cached_network_image.dart';
import 'package:grassmusicv2/utils/netease_image_cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grassmusicv2/services/netease_api.dart';
import 'package:grassmusicv2/services/alist_api.dart';
import '../providers/player_provider.dart' as player_provider;
import '../providers/pixel_converter.dart';
import 'common/list_media_item_widget.dart';
import 'lrc/mini_lyrics_plugin.dart';
import 'lrc/mini_lrc_lyrics_plugin.dart';
import 'lrc/lrc_lyrics_plugin.dart';
import 'lrc/lyrics_plugin.dart';
import '../extensions/remove_metadata_extention.dart';
import '../extensions/yrc_process.dart';
import '../locator/service_locator.dart';

// 自定义进度条绘制器，用于绘制音乐播放的进度条
class _ProgressBarPainter extends CustomPainter {
  // 播放进度（0.0到1.0）
  final double playProgress;
  // 缓冲进度（0.0到1.0）
  final double bufferProgress;
  // 主题数据，用于获取颜色
  final ThemeData theme;
  // 缩放因子，用于适配不同屏幕尺寸

  _ProgressBarPainter({
    required this.playProgress,
    required this.bufferProgress,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height;
    final width = size.width;

    // 绘制背景条（整个进度条的底色）
    final bgPaint =
        Paint()
          ..color = theme.dividerColor
          ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        Radius.circular(height / 2),
      ),
      bgPaint,
    );

    // 绘制缓冲进度条（表示已缓冲的部分）
    if (bufferProgress > 0) {
      final bufferPaint =
          Paint()
            ..color = theme.primaryColor.withAlpha(125)
            ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, width * bufferProgress, height),
          Radius.circular(height * 0.3),
        ),
        bufferPaint,
      );
    }

    // 绘制播放进度条（表示已播放的部分）
    if (playProgress > 0) {
      final progressPaint =
          Paint()
            ..color = theme.primaryColor
            ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, width * playProgress, height),
          Radius.circular(height * 0.3),
        ),
        progressPaint,
      );
    }

    // 绘制进度指示器（滑块）
    if (playProgress > 0) {
      final thumbPaint =
          Paint()
            ..color = theme.dividerColor
            ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(width * playProgress, height / 2),
        height,
        thumbPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return oldDelegate.playProgress != playProgress ||
        oldDelegate.bufferProgress != bufferProgress ||
        oldDelegate.theme != theme;
  }
}

class MiniPlayer extends ConsumerStatefulWidget {
  final double appbarheight;
  const MiniPlayer({super.key, required this.appbarheight});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  bool _isExpanded = false;
  bool _showLyrics = false;
  final FocusNode _focusNode = FocusNode();
  final Map<String, Future<List<String>>> _lyricsCache = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(player_provider.playerProvider);
    final playerNotifier = ref.read(player_provider.playerProvider.notifier);

    if (playerState.playlist.isEmpty ||
        playerState.currentIndex >= playerState.playlist.length) {
      return const SizedBox.shrink(); //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    }

    final currentMedia = playerState.playlist[playerState.currentIndex];
    final extras = currentMedia.extras;
    final screenSize = PixelConverter.windowPhysicalSize(context); // 使用应用窗口物理像素
    final isPortrait = screenSize.height > screenSize.width;
    //devdebugPrint(widget.appbarheight.toString());
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _isExpanded) {
          debugPrint('ESC key pressed, collapsing MiniPlayer');
          setState(() {
            _isExpanded = false;
          });
        } else {
          debugPrint('Key event: ${event.logicalKey}');
        }
      },
      child: SizedBox(
        width: PixelConverter.physicalToLogical(context, screenSize.width),
        child: GestureDetector(
          onTap: () {
            if (!_isExpanded) {
              debugPrint('Album cover tapped, expanding MiniPlayer');
              setState(() {
                _isExpanded = true;
                _focusNode.requestFocus();
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height:
                _isExpanded
                    ? PixelConverter.physicalToLogical(
                          context,
                          screenSize.height,
                        ) -
                        widget.appbarheight
                    : PixelConverter.physicalToLogical(context, 80) + 47,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                if (!_isExpanded)
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: PixelConverter.physicalToLogical(context, 4),
                    offset: Offset(
                      0,
                      PixelConverter.physicalToLogical(context, -3),
                    ),
                  ),
              ],
            ),

            child:
                _isExpanded
                    ? _buildExpandedView(
                      context,
                      playerState,
                      playerNotifier,
                      extras,
                      screenSize,
                      isPortrait,
                    )
                    : _buildMiniView(
                      context,
                      playerState,
                      playerNotifier,
                      extras,
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniView(
    BuildContext context,
    player_provider.PlayerState playerState,
    player_provider.PlayerNotifier playerNotifier,
    Map<String, dynamic>? extras,
  ) {
    final currentMedia = playerState.playlist[playerState.currentIndex];
    final currentPathTag = currentMedia.extras!['path'] ?? '-1';

    // 3. 预加载歌词
    if (!_lyricsCache.containsKey(currentPathTag)) {
      _lyricsCache[currentPathTag] = _fetchLyrics(currentPathTag);
    }
    return SizedBox(
      height: PixelConverter.physicalToLogical(context, 150) - 16,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildProgressBar(context, playerState, playerNotifier),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  debugPrint(
                    'Album cover tapped in mini view, expanding MiniPlayer',
                  );
                  setState(() {
                    _isExpanded = true;
                    _focusNode.requestFocus();
                  });
                },
                child: CachedNetworkImage(
                  cacheManager: NeteaseImageCacheManager(),
                  imageUrl:
                      extras?['thumbnail']?.isNotEmpty == true
                          ? extras!['thumbnail']
                          : 'https://via.placeholder.com/56',
                  width: PixelConverter.physicalToLogical(context, 150) - 16,
                  height: PixelConverter.physicalToLogical(context, 150) - 16,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => const CircularProgressIndicator(),
                  errorWidget:
                      (context, url, error) => const Icon(Icons.music_note),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: PixelConverter.physicalToLogical(context, 8),
                  ),
                  child:
                      _showLyrics
                          ? FutureBuilder<List<String>>(
                            future: _lyricsCache[currentPathTag],
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text('加载失败: ${snapshot.error}'),
                                );
                              }
                              final lrc = snapshot.data?[0] ?? '暂无歌词';
                              final yrc = snapshot.data?[1] ?? '';
                              return yrc.isNotEmpty
                                  ? MiniLyricsWidget(
                                    lyrics: yrc,
                                    position: playerState.position,
                                    duration: playerState.duration,
                                    isLyricChanged: true,
                                  )
                                  : MiniLrcLyricsWidget(
                                    lrcText: lrc,
                                    position: playerState.position,
                                    duration: playerState.duration,
                                    isLyricChanged: true,
                                  );
                            },
                          ) //歌词
                          : Column(
                            children: [
                              Text(
                                extras?['title']?.isNotEmpty == true
                                    ? extras!['title']
                                    : '未知标题',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).dividerColor,
                                  fontSize: PixelConverter.physicalToLogical(
                                    context,
                                    36,
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                extras?['artist']?.isNotEmpty == true
                                    ? extras!['artist']
                                    : '未知艺术家',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: PixelConverter.physicalToLogical(
                                    context,
                                    20,
                                  ),
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                ),
              ),
              _buildControlButtons(playerState, playerNotifier),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView(
    BuildContext context,
    player_provider.PlayerState playerState,
    player_provider.PlayerNotifier playerNotifier,
    Map<String, dynamic>? extras,
    Size screenSize,
    bool isPortrait,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final themeData = isDarkMode ? ThemeData.dark(useMaterial3: true) : theme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeData,
      home: LayoutBuilder(
        builder: (context, constraints) {
          final currentMedia = playerState.playlist[playerState.currentIndex];
          final currentPathTag = currentMedia.extras!['path'] ?? '-1';

          // 3. 预加载歌词
          if (!_lyricsCache.containsKey(currentPathTag)) {
            _lyricsCache[currentPathTag] = _fetchLyrics(currentPathTag);
          }
          return Column(
            children: [
              // 头部控制栏（8% 高度）
              SizedBox(
                height: constraints.maxHeight * 0.08,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: PixelConverter.physicalToLogical(context, 16),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_downward,
                          color: themeData.iconTheme.color,
                          size: PixelConverter.physicalToLogical(context, 24),
                        ),
                        onPressed: () => setState(() => _isExpanded = false),
                      ),
                      const Spacer(),
                      Text(
                        '正在播放',
                        style: themeData.textTheme.titleLarge?.copyWith(
                          fontSize: PixelConverter.physicalToLogical(
                            context,
                            20,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: PixelConverter.physicalToLogical(context, 48),
                      ),
                    ],
                  ),
                ),
              ),

              // 主内容区域（占用剩余空间）
              Expanded(
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: LayoutBuilder(
                    builder: (context, innerConstraints) {
                      return isPortrait
                          ? Column(
                            children: [
                              // 专辑封面区域（55% 内层高度）
                              SizedBox(
                                height: innerConstraints.maxHeight * 0.55,
                                width: innerConstraints.maxWidth,
                                child: Container(
                                  margin: EdgeInsets.all(
                                    PixelConverter.physicalToLogical(
                                      context,
                                      24,
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      PixelConverter.physicalToLogical(
                                        context,
                                        12,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(76),
                                        blurRadius:
                                            PixelConverter.physicalToLogical(
                                              context,
                                              20,
                                            ),
                                        spreadRadius:
                                            PixelConverter.physicalToLogical(
                                              context,
                                              2,
                                            ),
                                        offset: Offset(
                                          0,
                                          PixelConverter.physicalToLogical(
                                            context,
                                            10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      PixelConverter.physicalToLogical(
                                        context,
                                        12,
                                      ),
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: CachedNetworkImage(
                                        cacheManager: NeteaseImageCacheManager(),
                                        imageUrl:
                                            extras?['thumbnail'] ??
                                            'https://via.placeholder.com/500',
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) => const Center(
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      Colors.blueAccent,
                                                    ),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, url, error) => Center(
                                              child: Icon(
                                                Icons.music_note,
                                                size:
                                                    PixelConverter.physicalToLogical(
                                                      context,
                                                      80,
                                                    ),
                                                color: themeData.disabledColor,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // 歌曲信息区域（20% 内层高度）=====================================================================================================================
                              SizedBox(
                                height: innerConstraints.maxHeight * 0.20,
                                width: innerConstraints.maxWidth,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        PixelConverter.physicalToLogical(
                                          context,
                                          16,
                                        ),
                                  ),
                                  child:
                                      _showLyrics
                                          ? FutureBuilder<List<String>>(
                                            future:
                                                _lyricsCache[currentPathTag],
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              }
                                              if (snapshot.hasError) {
                                                return Center(
                                                  child: Text(
                                                    '加载失败: ${snapshot.error}',
                                                  ),
                                                );
                                              }
                                              final lrc =
                                                  snapshot.data?[0] ?? '暂无歌词';
                                              final yrc =
                                                  snapshot.data?[1] ?? '';
                                              return yrc.isNotEmpty
                                                  ? MiniLyricsWidget(
                                                    lyrics: yrc,
                                                    position:
                                                        playerState.position,
                                                    duration:
                                                        playerState.duration,
                                                    isLyricChanged: true,
                                                  )
                                                  : MiniLrcLyricsWidget(
                                                    lrcText: lrc,
                                                    position:
                                                        playerState.position,
                                                    duration:
                                                        playerState.duration,
                                                    isLyricChanged: true,
                                                  );
                                            },
                                          ) //歌词
                                          : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                extras?['title'] ?? '未知标题',
                                                style: themeData
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          PixelConverter.physicalToLogical(
                                                            context,
                                                            24,
                                                          ),
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                              SizedBox(
                                                height:
                                                    PixelConverter.physicalToLogical(
                                                      context,
                                                      8,
                                                    ),
                                              ),
                                              Text(
                                                extras?['artist'] ?? '未知艺术家',
                                                style: themeData
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      color: themeData
                                                          .textTheme
                                                          .bodyLarge
                                                          ?.color
                                                          ?.withAlpha(170),
                                                      fontSize:
                                                          PixelConverter.physicalToLogical(
                                                            context,
                                                            18,
                                                          ),
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                ),
                              ),
                            ],
                          )
                          : Row(
                            children: [
                              // 专辑封面区域（72% 内层高度，50% 内层宽度）
                              SizedBox(
                                height: innerConstraints.maxHeight * 0.72,
                                width: innerConstraints.maxWidth * 0.5,
                                child: Container(
                                  margin: EdgeInsets.all(
                                    PixelConverter.physicalToLogical(
                                      context,
                                      24,
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      PixelConverter.physicalToLogical(
                                        context,
                                        12,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(76),
                                        blurRadius:
                                            PixelConverter.physicalToLogical(
                                              context,
                                              20,
                                            ),
                                        spreadRadius:
                                            PixelConverter.physicalToLogical(
                                              context,
                                              2,
                                            ),
                                        offset: Offset(
                                          0,
                                          PixelConverter.physicalToLogical(
                                            context,
                                            10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      PixelConverter.physicalToLogical(
                                        context,
                                        12,
                                      ),
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: CachedNetworkImage(
                                        cacheManager: NeteaseImageCacheManager(),
                                        imageUrl:
                                            extras?['thumbnail'] ??
                                            'https://via.placeholder.com/500',
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) => const Center(
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      Colors.blueAccent,
                                                    ),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, url, error) => Center(
                                              child: Icon(
                                                Icons.music_note,
                                                size:
                                                    PixelConverter.physicalToLogical(
                                                      context,
                                                      80,
                                                    ),
                                                color: themeData.disabledColor,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // 歌曲信息区域（75% 内层高度，50% 内层宽度）===========================================================================================================================================
                              SizedBox(
                                height: innerConstraints.maxHeight * 0.75,
                                width: innerConstraints.maxWidth * 0.5,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        PixelConverter.physicalToLogical(
                                          context,
                                          16,
                                        ),
                                  ),
                                  child:
                                      _showLyrics
                                          ? FutureBuilder<List<String>>(
                                            future:
                                                _lyricsCache[currentPathTag],
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              }
                                              if (snapshot.hasError) {
                                                return Center(
                                                  child: Text(
                                                    '加载失败: ${snapshot.error}',
                                                  ),
                                                );
                                              }
                                              final lrc =
                                                  snapshot.data?[0] ?? '暂无歌词';
                                              final yrc =
                                                  snapshot.data?[1] ?? '';
                                              return yrc.isNotEmpty
                                                  ? LyricsWidget(
                                                    lyrics: yrc,
                                                    position:
                                                        playerState.position,
                                                    duration:
                                                        playerState.duration,
                                                    isLyricChanged: true,
                                                  )
                                                  : LrcLyricsWidget(
                                                    lrcText: lrc,
                                                    position:
                                                        playerState.position,
                                                    duration:
                                                        playerState.duration,
                                                    isLyricChanged: true,
                                                  );
                                            },
                                          ) //歌词
                                          : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                extras?['title'] ?? '未知标题',
                                                style: themeData
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          PixelConverter.physicalToLogical(
                                                            context,
                                                            24,
                                                          ),
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                              SizedBox(
                                                height:
                                                    PixelConverter.physicalToLogical(
                                                      context,
                                                      8,
                                                    ),
                                              ),
                                              Text(
                                                extras?['artist'] ?? '未知艺术家',
                                                style: themeData
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      color: themeData
                                                          .textTheme
                                                          .bodyLarge
                                                          ?.color
                                                          ?.withAlpha(170),
                                                      fontSize:
                                                          PixelConverter.physicalToLogical(
                                                            context,
                                                            18,
                                                          ),
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                ),
                              ),
                            ],
                          );
                    },
                  ),
                ),
              ),

              // 底部控制区域（20% 高度）
              SizedBox(
                height: constraints.maxHeight * 0.20,
                child: Column(
                  children: [
                    // 进度条（8% 高度）
                    SizedBox(
                      height: constraints.maxHeight * 0.1,
                      child: _buildEnhancedProgressBar(
                        context,
                        playerState,
                        playerNotifier,
                      ),
                    ),

                    // 控制按钮（12% 高度）
                    SizedBox(
                      height: constraints.maxHeight * 0.1,
                      child: _buildControlButtons(playerState, playerNotifier),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 4. 修改 _fetchLyrics 方法
  Future<List<String>> _fetchLyrics(String pathTag) async {
    debugPrint('Fetched lyrics for pathTag $pathTag');
    if (pathTag == '-1') return ['暂无歌词', ''];

    NeteaseMusicApi api = getIt<NeteaseMusicApi>();
    try {
      final data = await api.getLyricNew([pathTag]);

      final processedLyric = data.hasLrc ? data.lrc.parsedLyrics() : {};
      final processedYrcLyric =
          data.hasWordByWord ? data.yrc.convertYrcLines().parsedLyrics() : {};
      return [
        processedLyric['lyrics'] ?? '暂无歌词',
        processedYrcLyric['lyrics'] ?? '',
      ];
    } catch (e) {
      // 从API获取失败，尝试从本地获取
      AlistUtils alistUtils = getIt<AlistUtils>();
      pathTag = _convertAudioPathToLyricsPath(pathTag);

      final lrcurl = await alistUtils.getFileUrlV2(pathTag);
      debugPrint('alist lyrics content: $lrcurl');
      final lyric = await _fetchLyricsFromUrl(lrcurl);
      final processedLyric = lyric.parsedLyrics();
      debugPrint(processedLyric['lyrics']);
      return processedLyric.isNotEmpty
          ? [processedLyric['lyrics'] ?? '暂无歌词', '']
          : ['暂无歌词', ''];
    }
  }

  // 将音频文件路径转换为歌词文件路径
  String _convertAudioPathToLyricsPath(String audioPath) {
    // 定义音频文件扩展名
    final audioExtensions = [
      '.flac',
      '.mp3',
      '.m4a',
      '.wav',
      '.aac',
      '.ogg',
      '.wma',
      '.ape',
      '.alac',
      '.dsf',
      '.dff',
      '.mqa',
    ];

    String lyricsPath = audioPath;

    // 移除音频文件扩展名
    for (final ext in audioExtensions) {
      if (lyricsPath.toLowerCase().endsWith(ext)) {
        lyricsPath = lyricsPath.substring(0, lyricsPath.length - ext.length);
        break;
      }
    }

    // 添加歌词文件扩展名
    return '$lyricsPath.lrc';
  }

  // 从URL获取歌词内容
  Future<String> _fetchLyricsFromUrl(String url) async {
    try {
      final response = await Dio().get(
        url,
        options: Options(
          responseType: ResponseType.plain, // 纯文本响应
          headers: {'Accept': 'text/plain, application/json'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data.toString();
      } else {
        debugPrint('获取歌词内容失败，状态码: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      debugPrint('从URL获取歌词失败: $e');
      return '';
    }
  }

  /*---------------------------------------------------------------------------------------------------------------------*/
  Widget _buildEnhancedProgressBar(
    BuildContext context,
    player_provider.PlayerState state,
    player_provider.PlayerNotifier notifier,
  ) {
    final duration = state.duration;
    final position = state.position;
    final buffer = state.buffer;
    final theme = Theme.of(context);

    final playProgress =
        (duration.inMilliseconds > 0)
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(
              0.0,
              1.0,
            )
            : 0.0;
    final bufferProgress =
        (duration.inMilliseconds > 0)
            ? (buffer.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

    return SizedBox(
      height: PixelConverter.physicalToLogical(context, 44),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatDuration(position),
            style: TextStyle(
              decoration: TextDecoration.none, // 明确取消下划线
              color: Theme.of(context).dividerColor,
              fontSize: PixelConverter.physicalToLogical(context, 24),
            ),
          ),
          SizedBox(
            height: PixelConverter.physicalToLogical(context, 44),
            width:
                PixelConverter.windowLogicalSize(context).width -
                PixelConverter.physicalToLogical(context, 240),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox;
                final x = details.localPosition.dx;
                final newProgress = x / box.size.width;
                notifier.seek(duration * newProgress);
              },
              onHorizontalDragUpdate: (details) {
                final box = context.findRenderObject() as RenderBox;
                final x = details.localPosition.dx.clamp(0.0, box.size.width);
                final newProgress = x / box.size.width;
                notifier.seek(duration * newProgress);
              },
              child: CustomPaint(
                painter: _ProgressBarPainter(
                  playProgress: playProgress,
                  bufferProgress: bufferProgress,
                  theme: theme,
                ),
              ),
            ),
          ),
          Text(
            _formatDuration(duration),
            style: TextStyle(
              decoration: TextDecoration.none, // 明确取消下划线
              color: Theme.of(context).dividerColor,
              fontSize: PixelConverter.physicalToLogical(context, 24),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildProgressBar(
    BuildContext context,
    player_provider.PlayerState state,
    player_provider.PlayerNotifier notifier,
  ) {
    final duration = state.duration;
    final position = state.position;
    final double progress =
        duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0;

    return SizedBox(
      height: PixelConverter.physicalToLogical(context, 24),
      width: double.infinity,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: PixelConverter.physicalToLogical(context, 2),
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: PixelConverter.physicalToLogical(context, 6),
          ),
          overlayShape: RoundSliderOverlayShape(
            overlayRadius: PixelConverter.physicalToLogical(context, 12),
          ),
        ),
        child: Slider(
          value: progress.clamp(0.0, 1.0),
          onChanged: (value) {
            final newPosition = duration * value;
            notifier.seek(newPosition);
          },
        ),
      ),
    );
  }

  Widget _buildControlButtons(
    player_provider.PlayerState state,
    player_provider.PlayerNotifier notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.lyrics,
            size: PixelConverter.physicalToLogical(context, 40),
            color: const Color.fromARGB(96, 168, 206, 232),
          ),
          onPressed: () => _showLyrics = !_showLyrics,
          padding: EdgeInsets.all(PixelConverter.physicalToLogical(context, 4)),
          tooltip: '显示歌词',
        ),
        IconButton(
          icon: Icon(
            Icons.queue_music,
            size: PixelConverter.physicalToLogical(context, 40),
            color: const Color.fromARGB(96, 168, 206, 232),
          ),
          onPressed: () => _showPlaylistQueueDialog(context: context),
          padding: EdgeInsets.all(PixelConverter.physicalToLogical(context, 4)),
          tooltip: '显示播放队列',
        ),
        IconButton(
          icon: Icon(
            state.playMode.icon,
            size: PixelConverter.physicalToLogical(context, 40),
            color:
                state.playMode != player_provider.PlayMode.sequence
                    ? Colors.blueAccent
                    : null,
          ),
          onPressed: notifier.switchPlayMode,
          padding: EdgeInsets.all(PixelConverter.physicalToLogical(context, 4)),
          tooltip: state.playMode.displayName,
        ),
        IconButton(
          icon: Icon(
            Icons.skip_previous,
            size: PixelConverter.physicalToLogical(context, 40),
          ),
          onPressed: notifier.previous,
          padding: EdgeInsets.all(PixelConverter.physicalToLogical(context, 4)),
          tooltip: '上一首',
        ),
        IconButton(
          icon: Icon(
            state.isPlaying ? Icons.pause : Icons.play_arrow,
            size: PixelConverter.physicalToLogical(context, 40),
            color: Colors.blueAccent,
          ),
          onPressed: notifier.togglePlayPause,
          padding: EdgeInsets.all(PixelConverter.physicalToLogical(context, 4)),
          tooltip: state.isPlaying ? '暂停' : '播放',
        ),
        IconButton(
          icon: Icon(
            Icons.skip_next,
            size: PixelConverter.physicalToLogical(context, 40),
          ),
          onPressed: notifier.next,
          padding: EdgeInsets.all(PixelConverter.physicalToLogical(context, 4)),
          tooltip: '下一首',
        ),
        IconButton(
          icon: Icon(
            Icons.shuffle,
            size: PixelConverter.physicalToLogical(context, 40),
            color: state.isShuffled ? Colors.blueAccent : null,
          ),
          onPressed: notifier.toggleShuffle,
          padding: EdgeInsets.all(PixelConverter.physicalToLogical(context, 4)),
          tooltip: '随机播放',
        ),
      ],
    );
  }

  void _showPlaylistQueueDialog({required BuildContext context}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SizedBox(
            width: PixelConverter.windowLogicalSize(context).width * 0.9,
            height: PixelConverter.windowLogicalSize(context).height * 0.8,
            child: const PlaylistQueue(),
          ),
        );
      },
    );
  }
}

class PlaylistQueue extends ConsumerWidget {
  const PlaylistQueue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(player_provider.playerProvider);
    final playerNotifier = ref.read(player_provider.playerProvider.notifier);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '播放列表',
            style: TextStyle(
              fontSize: PixelConverter.physicalToLogical(context, 40),
            ),
          ),
          if (playerState.playlist.isNotEmpty)
            TextButton.icon(
              icon: Icon(
                Icons.clear_all,
                size: PixelConverter.physicalToLogical(context, 24),
              ),
              label: Text(
                '清空歌单',
                style: TextStyle(
                  fontSize: PixelConverter.physicalToLogical(context, 24),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed:
                  () => _showClearPlaylistConfirmation(context, playerNotifier),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: PixelConverter.windowLogicalSize(context).height,
        child:
            playerState.playlist.isEmpty
                ? Center(
                  child: Text(
                    '播放列表为空',
                    style: TextStyle(
                      fontSize: PixelConverter.physicalToLogical(context, 28),
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                )
                : ListView.builder(
                  itemCount: playerState.playlist.length,
                  itemBuilder: (context, index) {
                    final media = playerState.playlist[index];
                    return Dismissible(
                      key: Key('${media.uri}_$index'),
                      direction: DismissDirection.endToStart,
                      background: _buildSwipeBackground(context, false),
                      secondaryBackground: _buildSwipeBackground(context, true),
                      onDismissed: (direction) {
                        playerNotifier.removeFromPlaylistByIndex(index);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '已删除: ${media.extras?['title'] ?? '未知歌曲'}',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: MediaItems(song: media, index: index, ref: ref),
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
      ],
    );
  }

  Widget _buildSwipeBackground(BuildContext context, bool isConfirming) {
    return Container(
      color:
          isConfirming ? Colors.red[700] : Theme.of(context).colorScheme.error,
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(
        right: PixelConverter.physicalToLogical(context, 20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete,
            size: PixelConverter.physicalToLogical(context, 30),
            color: Colors.white,
          ),
          if (isConfirming)
            Text(
              '松开删除',
              style: TextStyle(
                color: Colors.white,
                fontSize: PixelConverter.physicalToLogical(context, 16),
              ),
            ),
        ],
      ),
    );
  }

  void _showClearPlaylistConfirmation(
    BuildContext context,
    player_provider.PlayerNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('清空歌单'),
            content: Text('确定要清空整个播放列表吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  notifier.setPlaylist([]);
                  Navigator.pop(context); // Close confirmation dialog
                  Navigator.pop(context); // Close playlist dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已清空播放列表'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
                  '清空',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
    );
  }
}
