import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'locator/service_locator.dart';
import 'services/alist_api.dart';
import 'services/netease_api.dart';
import 'services/objectbox_service.dart';
import 'widgets/play_controls.dart';
import 'widgets/cookie_login.dart';
import 'widgets/user_playlist_widget.dart';
import 'providers/providers.dart';
import 'utils/setting.dart';

import './providers/pixel_converter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // 初始化服务定位器（自动注册 SharedPreferences/API 等）
  await setupServiceLocator();

  // 从 get_it 获取已注册的服务
  final objectBoxService = await ObjectBoxService.init();
  getIt.registerSingleton<ObjectBoxService>(objectBoxService); // 注册 ObjectBox

  // 初始化 API 服务
  try {
    final prefs = getIt<SharedPreferences>();
    final api = getIt<NeteaseMusicApi>();
    final aApi = getIt<AlistUtils>();

    // 检查是否设置了自动登录
    final autoLogin = prefs.getBool('auto_login') ?? false;
    if (autoLogin) {
      String cookie = prefs.getString('netease_cookie') ?? '';
      if (cookie.isNotEmpty) {
        debugPrint('自动登录中...');
        await api.init(cookie);
      }
    }

    // AList 初始化
    await aApi.newServer('http://localhost:5244');
    await aApi.login('listening', 'music');
  } catch (e) {
    debugPrint('Initialization failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        objectBoxServiceProvider.overrideWithValue(objectBoxService),
        // Make sure musicBoxProvider is declared as non-nullable in its definition
      ],
      child: const MusicApp(),
    ),
  );
}

class MusicApp extends StatelessWidget {
  const MusicApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const AppService(),
    );
  }
}

class AppService extends ConsumerStatefulWidget {
  const AppService({super.key});

  @override
  ConsumerState<AppService> createState() => _AppServiceState();
}

class _AppServiceState extends ConsumerState<AppService> {
  AlistUtils get aApi => getIt<AlistUtils>();
  NeteaseMusicApi get api => getIt<NeteaseMusicApi>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
  }

  Future<void> _initializeService() async {
    try {
      final isLoggedIn = api.isLoggedIn;
      ref.read(loginStateProvider.notifier).state = isLoggedIn;
      await ref
          .read(musicBoxProvider)
          .setCurrentUsername('listening@localhost');
      await ref.read(musicBoxProvider).checkTorefresh();
      if (isLoggedIn) {
        await _loadInitialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Initialization error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final dailySongs = await api.getDailyRecommendSongs();
      String uid = api.getuserid();
      uid = uid.isEmpty ? uid : '10934775';
      final playlists = await api.getUserPlaylists(uid: uid);

      ref.read(dailySongsProvider.notifier).state = dailySongs;
      ref.read(playlistsProvider.notifier).state = playlists;
    } catch (e) {
      debugPrint('Data load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data load error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: MainAppScreen());
  }
}

class MainAppScreen extends ConsumerWidget {
  NeteaseMusicApi get api => getIt<NeteaseMusicApi>();

  const MainAppScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appBarHeight = getAppBarHeight(context);
    final isLoggedIn = ref.watch(loginStateProvider);
    final dailySongs = ref.watch(dailySongsProvider);
    final playlists = ref.watch(playlistsProvider);

    debugPrint(
      'Current state: isLoggedIn=$isLoggedIn, dailySongs=${dailySongs.length}, playlists=${playlists.length}',
    );

    if (!isLoggedIn) {
      return _buildLoginPrompt(context, ref);
    }

    if (dailySongs.isEmpty || playlists.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player'),
        actions: [
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshData(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: PixelConverter.physicalToLogical(context, 80),
            child: HomeContentWidget(
              playlists: playlists,
              dailySongs: dailySongs,
            ),
          ),
          Positioned(
            bottom: 0,
            child: SizedBox(child: MiniPlayer(appbarheight: appBarHeight)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.music_note,
                  size: 64,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '欢迎使用音乐播放器',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '请登录网易云音乐账户以使用完整功能',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // 登录按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showLoginDialog(context, ref),
                  icon: const Icon(Icons.login),
                  label: const Text('Cookie登录'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 其他选项
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('登录说明'),
                              content: const Text(
                                'Cookie登录：\n'
                                '1. 登录网页版网易云音乐\n'
                                '2. 按F12打开开发者工具\n'
                                '3. 在Network标签中找到Cookie\n'
                                '4. 复制到应用中进行登录\n\n'
                                'Cookie会自动保存，下次可自动登录。',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('知道了'),
                                ),
                              ],
                            ),
                      );
                    },
                    icon: const Icon(Icons.help_outline),
                    label: const Text('登录帮助'),
                  ),
                  const SizedBox(width: 20),
                  TextButton.icon(
                    onPressed: () => _showSettingsDialog(context),
                    icon: const Icon(Icons.settings),
                    label: const Text('设置'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoginDialog(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CookieLoginPage(
              onLoginSuccess: () async {
                ref.read(loginStateProvider.notifier).state = true;
                await _loadInitialData(context, ref);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
      ),
    );
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    final prefs = getIt<SharedPreferences>();
    await showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
              child: SettingPage(),
            ),
          ),
    );
  }

  Future<void> _loadInitialData(BuildContext context, WidgetRef ref) async {
    try {
      final dailySongs = await api.getDailyRecommendSongs();
      String uid = api.getuserid();
      final playlists = await api.getUserPlaylists(uid: uid);

      ref.read(dailySongsProvider.notifier).state = dailySongs;
      ref.read(playlistsProvider.notifier).state = playlists;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data load error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _refreshData(BuildContext context, WidgetRef ref) async {
    await _loadInitialData(context, ref);
  }

  double getAppBarHeight(BuildContext context) {
    final defaultAppBarHeight = kToolbarHeight;
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final appBarHeight = appBarTheme.toolbarHeight ?? defaultAppBarHeight;
    return appBarHeight;
  }
}
