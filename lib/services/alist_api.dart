import 'dart:convert';
//import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

/// AList API 工具类
class AlistUtils {
  final SharedPreferences prefs;
  AlistUtils(this.prefs);

  String _basePath = '/nas';
  String _baseUrl = '';
  String _server = '';
  String _authToken = '';
  bool _isLoggedIn = false;
  //getter
  String get basePath => _basePath;
  String get authToken => _authToken;
  String get server => _server;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> _loadPreferences() async {
    _basePath = prefs.getString('basePath') ?? '/nas';
    _baseUrl = prefs.getString('serverApi') ?? '';
    _server = prefs.getString('server') ?? '';
    _authToken = prefs.getString('alist_token') ?? '';
  }

  /// 设定挂载目录
  Future<void> newBasePath(String basePath) async {
    await prefs.setString('basePath', basePath);
    _basePath = basePath;
  }

  /// 设置服务器接口地址
  Future<void> newServer(String serverAddress) async {
    final serverApi = '$serverAddress/api';
    await prefs.setString('serverApi', serverApi);
    await prefs.setString('server', serverAddress);
    _baseUrl = serverApi;
    _server = serverAddress;
  }

  /// 设置认证token
  Future<void> getToken(String token) async {
    await prefs.setString('alist_token', token);
    _authToken = token;
  }

  /// 获取用户信息
  Future<void> getUserInfo() async {
    await _loadPreferences();
    if (_authToken.isEmpty) {
      throw Exception('未登录，请先调用login方法');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/me'),
      headers: {'Authorization': _authToken},
    );

    if (!response.statusCode.toString().startsWith('2')) {
      print('false');
      throw Exception('获取用户信息失败');
    }

    final data = jsonDecode(response.body);
    await newBasePath(data['data']['base_path']);
    _basePath = data['data']['base_path'];
  }

  /// 登录获取token
  Future<Map<String, dynamic>> login(
    String username,
    String password, [
    String otp = '',
  ]) async {
    await _loadPreferences();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          if (otp.isNotEmpty) 'otp_code': otp,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['code'] == 200) {
        await getToken(data['data']['token']);
        await getUserInfo();
        await SharedPreferences.getInstance().then(
          (prefs) => prefs.setString('userId', username),
        );
        _isLoggedIn = true;
        return {
          'token': data['data']['token'],
          'expire': DateTime.now().millisecondsSinceEpoch + 3600000,
        };
      } else {
        throw Exception(data['message'] ?? '登录失败');
      }
    } catch (error) {
      print('AList登录失败: $error');
      rethrow;
    }
  }

  /// 列出目录内容
  Future<List<Map<String, dynamic>>> listDirectory(String path) async {
    await _loadPreferences();
    if (_authToken.isEmpty) {
      throw Exception('未登录，请先调用login方法');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fs/list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authToken,
        },
        body: jsonEncode({'path': path}),
      );

      if (!response.statusCode.toString().startsWith('2')) {
        return [];
      }

      final data = jsonDecode(response.body);
      if (data['data'] == null || data['data']['content'] == null) {
        return [];
      }

      if (data['data']['content'] is! List) {
        print('返回的content不是数组: ${data['data']['content']}');
        return [];
      }

      final content =
          (data['data']['content'] as List)
              .map(
                (item) => {
                  'name': item['name'],
                  'path': '$path/${item['name']}'.replaceAll(
                    RegExp(r'/+'),
                    '/',
                  ),
                  'is_dir': item['is_dir'] ?? false,
                },
              )
              .toList();

      return content;
    } catch (error) {
      print('获取目录内容失败: $error');
      if (error.toString().contains('404') ||
          error.toString().contains('not found')) {
        return [];
      }
      rethrow;
    }
  }

  /// 获取文件信息
  Future<dynamic> getFileInfo(String filePath) async {
    await _loadPreferences();
    if (_authToken.isEmpty) {
      throw Exception('未登录，请先调用login方法');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fs/get'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authToken,
        },
        body: jsonEncode({'path': filePath.replaceAll(r'\', '/')}),
      );

      final data = jsonDecode(response.body);
      print(data['data']);
      if (data['code'] != 200) {
        print(data['message']);
      }

      print(data['data']);
      return data['data'];
    } catch (error) {
      print('获取文件URL失败: $error');
      rethrow;
    }
  }

  /// 获取文件URL v2
  Future<String> getFileUrlV2(String filePath) async {
    filePath = filePath.replaceAll(r'\', '/');
    print(filePath);
    final data = await getFileInfo(filePath);
    //print(data['raw_url']);
    return data['raw_url'];
  }

  /// 获取文件下载/访问URL
  Future<String> getFileUrl(
    String filePath,
    String baseName,
    String type,
  ) async {
    print('====================');
    print(filePath);
    await _loadPreferences();
    if (_authToken.isEmpty) {
      throw Exception('未登录，请先调用login方法');
    }

    final wholePath = '$filePath$baseName.$type';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fs/get'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authToken,
        },
        body: jsonEncode({'path': wholePath}),
      );

      final data = jsonDecode(response.body);
      if (data['code'] != 200) {
        print(data['message']);
      }

      print(data['data']['raw_url']);
      return data['data']['raw_url'];
    } catch (error) {
      print('获取文件URL失败: $error');
      rethrow;
    }
  }

  /// 上传文件
  Future<Map<String, dynamic>> uploadFile(
    String dirPath,
    http.MultipartFile file,
  ) async {
    await _loadPreferences();
    if (_authToken.isEmpty) {
      throw Exception('未登录，请先调用login方法');
    }

    try {
      final request =
          http.MultipartRequest('PUT', Uri.parse('$_baseUrl/fs/put'))
            ..headers['Authorization'] = _authToken
            ..headers['File-Path'] = Uri.encodeComponent(
              '$dirPath/${file.filename}',
            )
            ..files.add(file);

      final response = await request.send();
      final responseData = await http.Response.fromStream(response);
      final data = jsonDecode(responseData.body);

      if (data['code'] != 200) {
        throw Exception(data['message'] ?? '文件上传失败');
      }

      return data;
    } catch (error) {
      print('文件上传失败: $error');
      rethrow;
    }
  }

  /// 创建目录
  Future<Map<String, dynamic>> createDirectory(String path) async {
    await _loadPreferences();
    if (_authToken.isEmpty) {
      throw Exception('未登录，请先调用login方法');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fs/mkdir'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authToken,
        },
        body: jsonEncode({'path': path}),
      );

      final data = jsonDecode(response.body);
      if (data['code'] != 200) {
        throw Exception(data['message'] ?? '创建目录失败');
      }

      return data;
    } catch (error) {
      print('创建目录失败: $error');
      rethrow;
    }
  }

  /// 重命名文件或目录
  Future<Map<String, dynamic>> rename(String path, String newName) async {
    await _loadPreferences();
    if (_authToken.isEmpty) {
      throw Exception('未登录，请先调用login方法');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fs/rename'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authToken,
        },
        body: jsonEncode({'path': path, 'name': newName}),
      );

      final data = jsonDecode(response.body);
      if (data['code'] != 200) {
        throw Exception(data['message'] ?? '重命名失败');
      }

      return data;
    } catch (error) {
      print('重命名失败: $error');
      rethrow;
    }
  }

  /// 删除文件或目录
  Future<Map<String, dynamic>> remove(String dir, List<String> names) async {
    await _loadPreferences();
    if (_authToken.isEmpty) {
      throw Exception('未登录，请先调用login方法');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fs/remove'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authToken,
        },
        body: jsonEncode({'dir': dir, 'names': names}),
      );

      final data = jsonDecode(response.body);
      if (data['code'] != 200) {
        throw Exception(data['message'] ?? '删除失败');
      }

      return data;
    } catch (error) {
      print('删除失败: $error');
      rethrow;
    }
  }

  /// 保存并上传文件
  Future<void> saveAndUploadFile(
    String baseName,
    String fileContent,
    String type,
    String parentPath,
  ) async {
    try {
      final filename = '$baseName.$type';

      final bytes = utf8.encode(fileContent);
      final file = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      );

      await uploadFile(parentPath, file);
    } catch (error) {
      print('文件保存失败: $error');
      rethrow;
    }
  }

  /// 匹配内容类型
  String matchContentType(String type) {
    switch (type.toLowerCase()) {
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      case 'aac':
        return 'audio/aac';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      default:
        return 'application/octet-stream';
    }
  }

  /// 搜索文件或目录
  Future<List<dynamic>> search(String keywords, String type) async {
    await _loadPreferences();
    int scope;
    switch (type) {
      case 'ALL':
        scope = 0;
        break;
      case 'FOLDER':
        scope = 1;
        break;
      case 'FILE':
        scope = 2;
        break;
      default:
        scope = 0;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/fs/search'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': _authToken,
      },
      body: jsonEncode({
        'parent': '/local',
        'keywords': keywords,
        'scope': scope,
        'page': 1,
        'per_page': 100,
        'password': '',
      }),
    );

    final data = jsonDecode(response.body);
    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '搜索失败');
    }

    print(data['data']['content'][0]);
    return data['data']['content'];
  }
}
