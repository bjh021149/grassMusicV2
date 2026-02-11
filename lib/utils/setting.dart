import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:grassmusicv2/services/netease_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grassmusicv2/locator/service_locator.dart';

SharedPreferences get prefs => getIt<SharedPreferences>();
NeteaseMusicApi get api => getIt<NeteaseMusicApi>();

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  String? _storagePath;
  String? _serverAddress;
  String? _cookieValue;
  final TextEditingController _serverAddressController =
      TextEditingController();
  final TextEditingController _cookieController = TextEditingController();

  static const String _storagePathKey = 'download_path';
  static const String _serverAddressKey = 'server_address';
  static const String _cookieKey = 'netease_cookie';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _storagePath = prefs.getString(_storagePathKey);
      _serverAddress = prefs.getString(_serverAddressKey);
      _cookieValue = prefs.getString(_cookieKey);
      _serverAddressController.text = _serverAddress ?? '';
      _cookieController.text = _cookieValue ?? '';
    });
  }

  Future<void> _chooseDirectory() async {
    final String? directoryPath = await getDirectoryPath();
    if (directoryPath != null) {
      await prefs.setString(_storagePathKey, directoryPath);
      setState(() {
        _storagePath = directoryPath;
      });
    }
  }

  Future<void> _saveServerAddress() async {
    if (_serverAddressController.text.isNotEmpty) {
      final newAddress = _serverAddressController.text;

      // Update the API client's base URL&&save it to SharedPreferences
      final result = await api.updateBaseUrl(_serverAddressKey, newAddress);
      if (result == 'success') {
        setState(() {
          _serverAddress = newAddress;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('服务器地址已保存')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $result')));
      }
    }
  }

  Future<void> _saveCookie() async {
    if (_cookieController.text.isNotEmpty) {
      final cookie = _cookieController.text.trim();

      // 验证cookie格式
      if (!_validateCookie(cookie)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cookie格式不正确，请检查')));
        return;
      }

      try {
        // 使用cookie登录
        await api.init(cookie);

        // 保存cookie到SharedPreferences
        await prefs.setString(_cookieKey, cookie);

        setState(() {
          _cookieValue = cookie;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cookie登录成功')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登录失败: $e')));
      }
    }
  }

  bool _validateCookie(String cookie) {
    // 检查是否包含MUSIC_U字段
    final hasMusicU = cookie.contains('MUSIC_U=');
    // 检查cookie格式（至少有一个key=value对）
    final hasKeyValuePair = cookie.contains('=') && !cookie.endsWith('=');

    return hasMusicU && hasKeyValuePair;
  }

  Future<void> _clearCookie() async {
    await prefs.remove(_cookieKey);
    setState(() {
      _cookieValue = null;
      _cookieController.clear();
    });

    try {
      await api.logout();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cookie已清除')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('清除失败: $e')));
    }
  }

  Future<void> _testLogin() async {
    if (_cookieValue == null || _cookieValue!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先输入或保存Cookie')));
      return;
    }

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正在测试登录...')));

      // 获取用户信息测试登录状态
      final userProfile = await api.getuseraccount();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登录测试成功！用户: ${userProfile.nickname}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登录测试失败: $e')));
    }
  }

  @override
  void dispose() {
    _serverAddressController.dispose();
    _cookieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 存储路径设置
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('选择存储路径'),
            subtitle: Text(_storagePath ?? '尚未选择路径'),
            trailing: ElevatedButton(
              onPressed: _chooseDirectory,
              child: const Text('选择'),
            ),
          ),
          const Divider(),

          // 服务器地址设置
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('服务器地址'),
            subtitle: TextField(
              controller: _serverAddressController,
              decoration: const InputDecoration(
                hintText: '输入服务器地址 (如: 192.168.1.100:3000)',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _saveServerAddress(),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveServerAddress,
            ),
          ),
          const Divider(),

          // Cookie登录设置
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Cookie登录'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '从浏览器开发者工具获取网易云音乐Cookie',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cookieController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: '粘贴Cookie (需包含MUSIC_U字段)',
                    border: const OutlineInputBorder(),
                    suffixIcon:
                        _cookieValue != null
                            ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: _clearCookie,
                            )
                            : null,
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _saveCookie, child: const Text('保存')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _testLogin, child: const Text('测试')),
              ],
            ),
          ),

          // 说明文本
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '如何获取Cookie:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '1. 登录网页版网易云音乐 (music.163.com)\n'
                  '2. 按F12打开开发者工具\n'
                  '3. 切换到Network(网络)标签\n'
                  '4. 刷新页面，点击任意请求\n'
                  '5. 在Request Headers中找到Cookie字段\n'
                  '6. 复制整个Cookie值到这里',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),

          // 登录状态显示
          if (_cookieValue != null && api.isLoggedIn)
            Card(
              margin: const EdgeInsets.all(16),
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '已登录',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            '用户ID: ${api.getuserid()}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      onPressed: _clearCookie,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
