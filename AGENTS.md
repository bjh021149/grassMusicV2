# grassmusicv2 — Agent 项目指南

> 本文件面向 AI Coding Agent 读者。假设你对本项目一无所知，阅读本文件即可快速理解项目架构、技术栈、构建方式和开发约定。

---

## 1. 项目概览

**grassmusicv2** 是一款使用 Flutter 构建的跨平台音乐播放器。它同时对接两个音乐来源：

1. **网易云音乐**（NetEase Cloud Music）—— 通过第三方开源 API（Node.js 版 NeteaseCloudMusicApi）获取歌曲、歌单、歌词、搜索等内容；支持 Cookie 登录与扫码登录。
2. **AList** —— 通过 AList 文件管理 API 访问用户自部署的存储服务，扫描本地音乐目录（`艺术家/专辑/歌曲` 层级）并播放。

应用将两类音源统一抽象为 `MediaItem`，存入本地 **ObjectBox** 数据库，并借助 **media_kit** 实现跨平台音频播放。UI 采用 **Material 3** 深色主题，并在部分组件中使用拟物风（Neumorphic）设计。

### 1.1 支持平台

- Android
- iOS
- Windows / Linux / macOS（Flutter 桌面支持）
- Web（有限支持，部分原生功能如 ObjectBox、CookieJar 在 Web 下不可用）

### 1.2 关键外部依赖

| 依赖 | 用途 |
|------|------|
| `flutter_riverpod` | 全局状态管理 |
| `media_kit` + `media_kit_libs_audio` | 跨平台音频播放 |
| `objectbox` + `objectbox_flutter_libs` | 本地 NoSQL 数据库 |
| `dio` + `dio_cookie_manager` / `cookie_jar` | HTTP 请求与 Cookie 管理 |
| `http` | AList API 请求（使用 `http` 包而非 Dio） |
| `shared_preferences` | 轻量级键值持久化（登录凭证、设置、URL 缓存） |
| `get_it` | 服务定位器（Service Locator），替代完整 DI 容器 |
| `cached_network_image` | 网络图片缓存（专辑封面） |
| `flutter_screenutil` / `flutter_neumorphic_plus` / `iconsax_plus` | UI 效果与图标 |
| `json_serializable` / `json_annotation` | JSON 模型代码生成 |
| `build_runner` | 运行代码生成器 |

---

## 2. 项目结构

```
lib/
├── main.dart                      # 应用入口：初始化 MediaKit、GetIt、ObjectBox、登录态
├── locator/
│   └── service_locator.dart       # get_it 注册：SharedPreferences → API Services
├── providers/
│   ├── providers.dart             # Riverpod Provider 定义（登录态、歌单、歌曲、ObjectBox/MusicBox/PlaylistBox）
│   ├── player_provider.dart       # 播放器状态与逻辑（PlayMode、PlayerNotifier、playerProvider）
│   ├── music_box.dart             # ObjectBox 音乐仓库封装（AList/网易云歌曲读写、扫描、URL 获取）
│   ├── playlist_box.dart          # ObjectBox 播放列表封装（创建、增删、查）
│   └── pixel_converter.dart       # 物理/逻辑像素转换工具（项目内 UI 大量使用）
├── services/
│   ├── netease_api.dart           # 网易云 API 封装（Dio、Cookie、缓存、QR 登录）
│   ├── alist_api.dart             # AList API 封装（http、登录、目录浏览、文件 URL）
│   ├── objectbox_service.dart     # ObjectBox Store 初始化、数据库诊断工具
│   ├── audio_downloader.dart      # 音频下载逻辑
│   └── cookie.dart                # Cookie 处理辅助
├── models/
│   ├── media_item.dart            # ObjectBox 实体：统一音源模型（title/artist/album/url/provider…）
│   ├── playlist_item.dart         # ObjectBox 实体：自定义播放列表（name + mediaIdList）
│   ├── netease_music.dart         # 网易云歌曲/艺人/专辑/歌词模型 + toMedia/toMediaItem 转换
│   ├── netease_music_user_playlist.dart  # 网易云用户歌单模型（JSON 序列化）
│   ├── netease_music_auth*.dart   # 登录认证相关模型
│   ├── netease_qr.dart            # QR 登录状态模型
│   └── playlist_detail.dart       # 歌单详情模型
├── widgets/
│   ├── play_controls.dart         # 迷你播放器 + 展开全屏播放器（含进度条、歌词、封面）
│   ├── user_playlist_widget.dart  # 首页内容：每日推荐卡片、音乐库卡片、歌单网格、歌单详情页
│   ├── cookie_login.dart          # Cookie 登录页
│   ├── search.dart                # 搜索页面
│   ├── setting.dart               # 设置页（服务器地址、Cookie、下载路径）
│   ├── songs_dialog.dart          # 歌曲列表弹窗
│   ├── private_music_dialog.dart  # 本地音乐库弹窗
│   ├── common/                    # 可复用列表项组件
│   └── lrc/                       # 歌词渲染组件（LRC / YRC 逐字歌词）
├── extensions/
│   ├── alist_song_extensions.dart # MediaItem 路径/文件名扩展
│   ├── yrc_process.dart           # YRC 歌词格式转换扩展
│   ├── remove_metadata_extention.dart # 歌词元数据清洗
│   └── xx.dart                    # 其他辅助扩展
├── utils/
│   ├── setting.dart               # 设置页 UI（StatefulWidget）
│   └── song_utils.dart            # 歌曲操作工具（如批量加入播放列表）
├── objectbox-model.json           # ObjectBox 实体模型元数据（必须纳入版本控制）
└── objectbox.g.dart               # ObjectBox 生成的代码（由 build_runner 产出）
```

### 2.1 关键配置

- **`pubspec.yaml`** —— Flutter 项目配置，定义依赖、资源、版本（`1.0.0+1`）。SDK 约束 `^3.7.2`。
- **`analysis_options.yaml`** —— 继承 `package:flutter_lints/flutter.yaml`，未额外启用严格规则。
- **`devtools_options.yaml`** —— 仅启用 `shared_preferences` DevTools 扩展。

---

## 3. 架构与状态管理

### 3.1 分层架构

项目采用近似 **三层架构** 的组织方式：

1. **表现层（UI）** —— `lib/widgets/` 内的 StatelessWidget / ConsumerStatefulWidget。
2. **状态层（Providers）** —— `lib/providers/` 使用 **Riverpod** 管理全局状态。
3. **数据层（Services）** —— `lib/services/` 封装远程 API 和本地数据库；通过 **GetIt** 做服务定位。

### 3.2 状态管理（Riverpod）

- 使用 `flutter_riverpod` 的 `StateProvider` 和 `StateNotifierProvider`。
- `PlayerNotifier`（`player_provider.dart`）是核心状态机，持有 `media_kit.Player` 实例，管理播放列表、播放模式（顺序/随机/单曲循环）、进度、预取下一首 URL 等。
- 全局状态：
  - `loginStateProvider` —— 网易云登录态
  - `dailySongsProvider` / `playlistsProvider` —— 首页数据
  - `playerProvider` —— 播放器状态
  - `musicBoxProvider` / `playlistBoxProvider` / `objectBoxServiceProvider` —— 数据访问层

### 3.3 服务定位器（GetIt）

`lib/locator/service_locator.dart` 按两层注册：

1. **核心服务**：`SharedPreferences`
2. **数据服务**：`AlistUtils`、`NeteaseMusicApi`

`ObjectBoxService` 由于需要异步初始化，在 `main.dart` 中手动 `await init()` 后再注册到 GetIt。

**注意**：项目中大量通过顶层的 `getIt< T >()` 直接获取服务，Riverpod 与 GetIt 混合使用。新增服务时应遵循 `service_locator.dart` 的分层注册约定。

---

## 4. 数据模型与数据库

### 4.1 ObjectBox 数据库

- **数据库文件路径**：`{appDocuments}/alist_music`
- **两个核心实体**：
  - `MediaItem` —— 统一歌曲实体（字段：`title`, `artist`, `album`, `url`, `thumbnail`, `provider`, `durationMs`, `association`）。`provider` 区分 `"alist"` / `"netease"`。
  - `CustomPlaylist` —— 自定义播放列表（字段：`name`, `mediaIdList`）。
- `objectbox-model.json` 和 `objectbox.g.dart` 由 `objectbox_generator` 维护。**切勿手动编辑 `objectbox-model.json`**；修改实体后运行代码生成。

### 4.2 网易云模型

- `netease_music.dart` 定义了 `Song`、`Artist`、`Album`、`LyricLine`、`RawLyricResponse` 等类。
- `Song` 提供三种转换方法：
  - `toMedia()` → `media_kit.Media`（用于直接播放）
  - `toMediaItemL()` → `MediaItem`，provider 标记为 `alist`（用于保存到本地库）
  - `toMediaItemN()` → `MediaItem`，provider 标记为 `netease`（用于保存到本地库）
- 部分模型使用 `json_serializable` 生成序列化代码（`.g.dart` 文件）。

---

## 5. 网络与 API

### 5.1 网易云 API（`NeteaseMusicApi`）

- 默认服务器地址硬编码为 `http://192.168.10.72:3000`，但可通过 `updateBaseUrl()` 和设置页修改，持久化到 `SharedPreferences`（键：`server_address`）。
- 使用 **Dio** 发送请求，自动附加 `X-CSRF-Token` 头。
- Cookie 管理：非 Web 平台使用 `CookieJar` + `DioCookieManager`；Web 平台依赖浏览器原生 Cookie。
- 内置 **SharedPreferences 缓存**（`_cachedRequest`）：默认缓存 10 分钟，键为 `endpoint + params.toString()`。
- 音频 URL 额外缓存 `_audioUrlCache`（内存，5 分钟），避免频繁请求 `/song/url/v1`。
- 登录方式：
  - **Cookie 登录**：直接传入包含 `MUSIC_U` 的 Cookie 字符串。
  - **QR 登录**：`startQRLogin()` → `checkQRStatus()`，轮询扫码状态。

### 5.2 AList API（`AlistUtils`）

- 使用 **`http`** 包（而非 Dio）与 AList 服务器通信。
- 默认在 `main.dart` 中自动初始化服务器 `http://localhost:5244` 并尝试登录（硬编码用户名/密码 `listening` / `music`）。
- 支持目录浏览、文件 URL 获取、上传、创建目录、搜索等操作。

### 5.3 安全与配置注意事项

- **硬编码凭据**：`main.dart` 中 AList 的默认服务器、用户名、密码是硬编码的；`NeteaseMusicApi` 中默认 API 地址也是硬编码的。这些仅供开发/个人局域网使用。
- **Cookie 持久化**：网易云 Cookie（含 `MUSIC_U`）以明文存储在 `SharedPreferences` 中。生产环境若需增强安全性，应考虑加密存储。
- **无环境变量实际使用**：`pubspec.yaml` 中依赖了 `flutter_dotenv`，但项目中未见 `.env` 文件或实际调用。

---

## 6. 播放器实现细节

- 底层播放器：`media_kit.Player`。
- 播放列表元素类型：`media_kit.Media`，其 `extras` Map 携带歌曲元数据（`title`, `artist`, `thumbnail`, `provider`, `path` 等）。
- 播放模式：顺序 (`sequence`)、随机 (`random`)、单曲循环 (`singleLoop`)。
- URL 刷新机制：播放时检查 URL 是否过期（默认 15 分钟），过期则通过 `MusicBox.getAudioUrlV1()` 重新获取。AList 的 URL 通常带时效性签名。
- 预取机制：播放当前歌曲时，后台预取下一首的音频 URL。
- 自然结束检测：使用 `Timer` 每秒检查播放位置，当 `position >= duration - 1` 秒时自动调用 `next()`。

---

## 7. UI 与交互约定

### 7.1 像素转换

项目中大量使用自定义的 `PixelConverter`（`lib/providers/pixel_converter.dart`）将**物理像素**转换为逻辑像素：

```dart
PixelConverter.physicalToLogical(context, 80)
```

这意味着很多尺寸常量是以**物理像素**为基准书写的（例如 `80` 表示 80 物理像素）。修改 UI 时应注意这一习惯，保持与现有代码一致，或在引入新组件时明确所用单位。

### 7.2 主题

- 应用主题在 `main.dart` 中定义为 **Material 3 Dark** 主题，`seedColor` 为 `Colors.blueAccent`。
- 部分 widget（如 `MiniPlayer` 展开页）内部会再包一层 `MaterialApp` 以隔离主题上下文。

### 7.3 歌词组件

- `lrc/` 目录下有两套歌词渲染：
  - **LRC** —— 标准逐行歌词 (`MiniLrcLyricsWidget` / `LrcLyricsWidget`)
  - **YRC** —— 网易云逐字歌词 (`MiniLyricsWidget` / `LyricsWidget`)
- YRC 歌词需先经过 `yrc_process.dart` 的格式转换，再交由通用歌词解析器。

---

## 8. 构建与开发命令

### 8.1 环境要求

- Flutter SDK `^3.7.2`（Dart 3）
- 对应的 Android SDK / Xcode（如需构建移动平台）
- 若使用桌面平台，需确保已启用对应平台的 Flutter 支持

### 8.2 依赖安装

```bash
flutter pub get
```

### 8.3 代码生成（必须执行）

本项目依赖代码生成来维护 ObjectBox 和 JSON 序列化：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

若频繁修改模型，可使用监视模式：

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

生成产物：
- `lib/objectbox.g.dart`
- `lib/models/*.g.dart`

**这些文件应纳入版本控制**，因为项目当前未在 CI 中运行代码生成。

### 8.4 运行与构建

```bash
# 开发运行（自动选择已连接设备）
flutter run

# 指定平台运行
flutter run -d windows
flutter run -d android
flutter run -d chrome

# 发布构建
flutter build apk          # Android
flutter build ios          # iOS（需在 macOS 上）
flutter build windows      # Windows
flutter build macos        # macOS
flutter build linux        # Linux
```

### 8.5 代码分析

```bash
flutter analyze
```

当前 `analysis_options.yaml` 仅启用 `flutter_lints`，无自定义严格规则。

---

## 9. 测试策略

**现状：本项目目前没有测试。** `test/` 目录不存在。

### 建议引入测试的方向

- **Unit Test**：`NeteaseMusicApi` 和 `AlistUtils` 的网络逻辑可通过 `mockito` 模拟 Dio/http 客户端；`PlayerNotifier` 可测试状态转换逻辑。
- **Widget Test**：登录页、设置页、播放器控件的交互验证。
- **Integration Test**：完整登录 → 获取歌单 → 播放一首歌曲的端到端流程。

已有 `mockito` 和 `flutter_test` 在 `dev_dependencies` 中，可直接开始编写。

---

## 10. 代码风格与开发约定

### 10.1 语言与注释

- 代码中变量、类名、方法名使用 **英文**；注释以 **中文** 为主，混合少量英文。
- 中文注释通常解释业务意图，适合快速理解模块职责。

### 10.2 命名习惯

- 类名：大驼峰（`NeteaseMusicApi`, `PlayerNotifier`）
- 文件名单词间下划线分隔（`music_box.dart`, `netease_api.dart`）
- 私有方法/变量以下划线开头（`_safeRequest`, `_dio`）
- Provider 命名以 `Provider` 结尾（`playerProvider`, `musicBoxProvider`）

### 10.3 异步与错误处理

- 服务层方法通常返回 `Future<T>`，并在内部捕获 `DioException` 后抛出带中文描述的 `Exception`。
- UI 层通过 `try/catch` 捕获并展示 `SnackBar`。
- 注意：部分 `async` 方法内部缺少 `await`（如 `_prefs.setString`），修改时应留意补上 `await` 避免竞态。

### 10.4 状态修改

- Riverpod 的 `StateNotifier` 通过创建新对象实现不可变更新（`copyWith`）。
- ObjectBox 实体修改后需调用 `box.put(entity)` 才能持久化。

### 10.5 URL 与路径处理

- AList 歌曲使用**文件路径**作为唯一标识（如 `/艺术家/专辑/歌曲.flac`）。
- 网易云歌曲使用**数字 songId** 作为唯一标识。
- `MusicBox` 中通过 `provider` 字段区分来源，并在获取音频 URL 时走不同分支。

---

## 11. 部署与发布注意事项

- **版本号**：维护在 `pubspec.yaml` 的 `version: 1.0.0+1`。Flutter 构建时可通过 `--build-name` 和 `--build-number` 覆盖。
- **平台权限**：
  - Android / iOS / 桌面：确保 `Internet` 权限已声明（用于访问网易云和 AList 服务器）。
  - 若未来加入本地音乐下载或扫描外部存储，需要额外存储权限（`permission_handler` 已加入依赖）。
- **ObjectBox 原生库**：ObjectBox 依赖平台特定的原生库，确保 `flutter build` 时未忽略相关 so/dylib/framework。
- **media_kit 平台库**：桌面构建时需确保对应平台的 media_kit 音频库正确链接。
- **未发布到应用商店**：`publish_to: 'none'`，当前为私有项目。

---

## 12. 常见问题与陷阱

1. **ObjectBox 模型不同步**
   - 如果修改了 `MediaItem` 或 `CustomPlaylist` 的字段，务必运行 `build_runner build`，否则运行时模型与数据库不匹配会崩溃。

2. **硬编码的服务器地址**
   - 首次运行若无法连接，检查 `NeteaseMusicApi._baseUrl` 或设置页中的服务器地址是否指向了可访问的 API 服务。

3. **Web 平台限制**
   - Web 下 `CookieJar` 为 `null`，网易云 API 的 Cookie 管理完全依赖浏览器；ObjectBox 在 Web 下可能不可用或需特殊配置。

4. **PixelConverter 与常规 Flutter 尺寸混用**
   - 项目中既有 `PixelConverter.physicalToLogical(context, x)` 也有直接使用逻辑像素的地方。修改布局时应观察周围代码的惯例，保持一致。

5. **播放器 URL 过期**
   - AList 的 `raw_url` 通常带时间戳签名，15 分钟后失效。`PlayerNotifier` 会在播放前自动刷新，但如果歌曲暂停过久后恢复，可能遇到 403/404，此时通常会自动跳到下一首。

---

## 13. 扩展建议

- 接入 `.env` 文件管理开发/生产环境的不同 API 地址（`flutter_dotenv` 已引入但未使用）。
- 将 `PixelConverter` 的调用逐步替换为 Flutter 标准的响应式布局方案（`LayoutBuilder`、`MediaQuery`、`Flex`），减少对物理像素的依赖。
- 为 `NeteaseMusicApi` 和 `AlistUtils` 抽象接口，便于单元测试 mock。
- 添加 `test/` 目录，从 `PlayerNotifier` 的状态转换和 `MusicBox` 的查询逻辑开始补测试。
