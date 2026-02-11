import 'package:get_it/get_it.dart';
import 'package:grassmusicv2/services/alist_api.dart';
import 'package:grassmusicv2/services/netease_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

// service_locator.dart
Future<void> setupServiceLocator() async {
  // 第一层：基础服务
  await _registerCoreServices();

  // 第二层：数据服务
  await _registerDataServices();

  /* 第三层：业务服务
  _registerBusinessServices();*/
}

Future<void> _registerCoreServices() async {
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
}

Future<void> _registerDataServices() async {
  getIt.registerSingleton<AlistUtils>(AlistUtils(getIt()));
  getIt.registerSingleton<NeteaseMusicApi>(NeteaseMusicApi(getIt()));
}

/*void _registerBusinessServices() {
  // 注册其他业务相关服务...
}*/
