extension FileNameExtension on String {
  String ensureFileExtension([String? fallbackExtension = 'mp3']) {
    if (contains('.')) return this;
    return '$this.$fallbackExtension';
  }

  String? get fileExtension {
    final dotIndex = lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < length - 1) {
      return substring(dotIndex + 1).toLowerCase();
    }
    return null;
  }
}
