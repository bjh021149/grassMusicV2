import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grassmusicv2/locator/service_locator.dart';
import 'package:grassmusicv2/models/media_item.dart';
import 'package:grassmusicv2/providers/providers.dart';
import 'package:grassmusicv2/providers/music_box.dart';
import 'package:grassmusicv2/services/alist_api.dart';

import 'package:grassmusicv2/widgets/common/list_media_item_widget.dart';

import 'package:media_kit/media_kit.dart';

class MusicLibraryDialog extends ConsumerStatefulWidget {
  const MusicLibraryDialog({super.key});

  @override
  ConsumerState<MusicLibraryDialog> createState() => _MusicLibraryDialogState();
}

class _MusicLibraryDialogState extends ConsumerState<MusicLibraryDialog> {
  late final MusicBox _musicBox;
  List<MediaItem> _songs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedProvider;

  @override
  void initState() {
    super.initState();
    _musicBox = ref.read(musicBoxProvider);
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      _songs = _musicBox.getAllSongs();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<MediaItem> get _filteredSongs {
    var filtered = _songs;

    // 按来源过滤
    if (_selectedProvider != null) {
      filtered =
          filtered.where((song) => song.provider == _selectedProvider).toList();
    }

    // 按搜索词过滤
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where(
                (song) =>
                    song.title.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    song.artist.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    song.album.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          children: [
            // 顶部工具栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 搜索框
                  TextField(
                    decoration: InputDecoration(
                      labelText: '搜索歌曲',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 12),
                  // 来源筛选
                  Row(
                    children: [
                      const Text('来源:'),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('全部'),
                        selected: _selectedProvider == null,
                        onSelected:
                            (_) => setState(() => _selectedProvider = null),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('AList'),
                        selected: _selectedProvider == 'alist',
                        onSelected:
                            (_) => setState(() => _selectedProvider = 'alist'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('网易云'),
                        selected: _selectedProvider == 'netease',
                        onSelected:
                            (_) =>
                                setState(() => _selectedProvider = 'netease'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 歌曲列表
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredSongs.isEmpty
                      ? const Center(child: Text('没有找到歌曲'))
                      : ListView.builder(
                        itemCount: _filteredSongs.length,
                        itemBuilder: (context, index) {
                          final song = _filteredSongs[index];
                          return FutureBuilder(
                            future: _buildSongItem(song, index),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 56,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                debugPrint(
                                  'Error building song item: ${snapshot.error}',
                                );
                                return const ListTile(
                                  title: Text('Error loading song'),
                                );
                              }
                              return snapshot.data ?? const SizedBox.shrink();
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Widget?> _buildSongItem(MediaItem song, int index) async {
    // Convert MediaItem to Media object
    Media media = song.toMedia();

    // Get the music box provider - consider using ref.watch if this needs to react to changes
    final musicBox = ref.read(musicBoxProvider);

    try {
      // Fetch the cover URL asynchronously
      final picurl = await musicBox.getCoverUrl(song);
      //Fetch lrc
      //final lrc = await musicBox.getLyricUrl(song);
      // Update the Media object with additional information
      final updatedMedia = media.copyWith(
        extras: {...?media.extras, 'thumbnail': picurl},
      );

      return MediaItems(song: updatedMedia, ref: ref);
    } catch (e) {
      // Handle error case, perhaps return a placeholder widget
      debugPrint('Error loading song item: $e');
      return MediaItems(
        song: media,
        ref: ref,
      ); // Return original media without thumbnail
    }
  }
}

// 使用示例
Future<Media?> showMusicLibraryDialog(BuildContext context) async {
  return await showDialog<Media>(
    context: context,
    builder: (context) => const MusicLibraryDialog(),
  );
}
