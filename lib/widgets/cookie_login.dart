import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../locator/service_locator.dart';
import '../services/netease_api.dart';
import '../utils/setting.dart';

SharedPreferences get prefs => getIt<SharedPreferences>();
NeteaseMusicApi get api => getIt<NeteaseMusicApi>();

class CookieLoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const CookieLoginPage({Key? key, required this.onLoginSuccess})
    : super(key: key);

  @override
  _CookieLoginPageState createState() => _CookieLoginPageState();
}

class _CookieLoginPageState extends State<CookieLoginPage> {
  final TextEditingController _cookieController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  //bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    // 尝试加载之前保存的cookie
    _loadSavedCookie();
  }

  Future<void> _loadSavedCookie() async {
    final savedCookie = prefs.getString('netease_cookie');
    if (savedCookie != null && savedCookie.isNotEmpty) {
      _cookieController.text = savedCookie;
    }
  }

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  Future<void> _loginWithCookie() async {
    final cookie = _cookieController.text.trim();
    if (cookie.isEmpty) {
      setState(() => _errorMessage = '请输入Cookie');
      return;
    }

    if (!_validateCookie(cookie)) {
      setState(() => _errorMessage = 'Cookie格式不正确，请检查是否包含MUSIC_U字段');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await api.init(cookie);
      await prefs.setString('netease_cookie', cookie);
      await prefs.setBool('auto_login', false);

      widget.onLoginSuccess();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录成功')));
      }
    } catch (e) {
      setState(() => _errorMessage = '登录失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validateCookie(String cookie) {
    return cookie.contains('MUSIC_U=');
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('如何获取Cookie'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '1. 打开网页版网易云音乐 (music.163.com)\n'
                    '2. 登录您的账号\n'
                    '3. 按F12打开开发者工具\n'
                    '4. 切换到Network(网络)标签\n'
                    '5. 刷新页面，点击任意请求\n'
                    '6. 在Request Headers中找到Cookie字段\n'
                    '7. 复制整个Cookie值\n\n'
                    '提示：确保Cookie包含MUSIC_U字段',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '示例：MUSIC_U=xxx;__csrf=xxx;',
                      style: TextStyle(fontFamily: 'Monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cookie登录'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingPage()),
              );
            },
            tooltip: '设置',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和说明
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 32,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cookie登录',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '通过网页版网易云音乐的Cookie登录',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Cookie输入框
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cookie',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cookieController,
                  maxLines: 5,
                  minLines: 3,
                  decoration: InputDecoration(
                    hintText: '粘贴从网页版获取的Cookie...',
                    border: const OutlineInputBorder(),
                    errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 14, fontFamily: 'Monospace'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 帮助按钮
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _showHelpDialog,
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('如何获取Cookie'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _cookieController.clear();
                    setState(() => _errorMessage = '');
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('清空'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 记住登录状态
            Row(
              children: [
                Checkbox(
                  value: prefs.getBool('auto_login') ?? false,
                  onChanged: (value) {
                    prefs.setBool('auto_login', value ?? false);
                    setState(() {});
                  },
                ),
                const Text('记住登录状态'),
                const Spacer(),
                TextButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () {
                            prefs.remove('netease_cookie');
                            _cookieController.clear();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已清除保存的Cookie')),
                              );
                            }
                          },
                  child: const Text('清除保存的Cookie'),
                ),
              ],
            ),

            const Spacer(),

            // 登录按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _loginWithCookie,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child:
                    _isLoading
                        ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('登录中...'),
                          ],
                        )
                        : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login),
                            SizedBox(width: 8),
                            Text('登录', style: TextStyle(fontSize: 16)),
                          ],
                        ),
              ),
            ),

            const SizedBox(height: 20),

            // 其他选项
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingPage(),
                      ),
                    );
                  },
                  child: const Text('前往设置页面'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('返回首页'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 需要在 setting.dart 中导出的 SettingPage
// 如果 SettingPage 在单独的文件中，需要在这里导入
