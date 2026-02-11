// Extensions
import '../models/media_item.dart';
import 'package:path/path.dart' as p;

extension SafeFirstWhere<T> on Iterable<T> {
  T? safeFirstWhere(bool Function(T) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}

extension SongNameExtension on MediaItem {
  String get nameWithoutExtension => title.split('.').first;
  String? get fileExtension {
    final parts = title.split('.');
    return parts.length > 1 ? parts.last : null;
  }
}

extension SongPathExtension on MediaItem {
  String get parentPath {
    try {
      print(p.dirname(url));

      return p.dirname(url);
    } catch (e) {
      print('error${e.toString()}');
      return '';
    }
  }
}
