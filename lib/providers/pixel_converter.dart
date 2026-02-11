// providers/pixel_converter.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui';

class PixelConverter {
  // 安全获取主显示器信息
  static FlutterView get _primaryView {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isNotEmpty
        ? views.first
        : WidgetsBinding.instance.platformDispatcher.implicitView!;
  }

  // 获取设备像素密度比
  static double get devicePixelRatio => _primaryView.devicePixelRatio;

  // 获取屏幕物理尺寸
  static Size get screenPhysicalSize => _primaryView.physicalSize;

  // 获取应用窗口信息（需要BuildContext）
  static Size windowLogicalSize(BuildContext context) =>
      MediaQuery.sizeOf(context);
  static double windowDevicePixelRatio(BuildContext context) =>
      MediaQuery.devicePixelRatioOf(context);
  static Size windowPhysicalSize(BuildContext context) {
    final logicalSize = windowLogicalSize(context);
    final ratio = windowDevicePixelRatio(context);
    return Size(logicalSize.width * ratio, logicalSize.height * ratio);
  }

  // 计算DPI（基于窗口尺寸）
  static Map<String, double> calculateDPI(
    BuildContext context,
    double screenDiagonalInches,
  ) {
    if (screenDiagonalInches <= 0) throw ArgumentError('屏幕尺寸必须大于0');

    final physicalSize = windowPhysicalSize(context);
    final aspectRatio = physicalSize.width / physicalSize.height;
    final heightInches = screenDiagonalInches / sqrt(pow(aspectRatio, 2) + 1);
    final widthInches = heightInches * aspectRatio;

    return {
      'horizontalDPI': physicalSize.width / widthInches,
      'verticalDPI': physicalSize.height / heightInches,
      'diagonalDPI':
          sqrt(pow(physicalSize.width, 2) + pow(physicalSize.height, 2)) /
          screenDiagonalInches,
      'screenWidthInches': widthInches,
      'screenHeightInches': heightInches,
    };
  }

  // 像素转换工具
  static double physicalToLogical(
    BuildContext context,
    double physicalPixels,
  ) => physicalPixels / windowDevicePixelRatio(context);

  static double logicalToPhysical(BuildContext context, double logicalPixels) =>
      logicalPixels * windowDevicePixelRatio(context);
}
