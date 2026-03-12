import 'dart:io' show Platform;
import 'package:flutter/material.dart';

class PlatformUtils {
  PlatformUtils._();
  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static bool get isDesktopNotMac =>
      (Platform.isWindows || Platform.isLinux) && !Platform.isMacOS;

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool isMobileWidth(BuildContext context) {
    return MediaQuery.of(context).size.width < 880;
  }

  static bool get isWindows => Platform.isWindows;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isLinux => Platform.isLinux;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  
  // 通过屏幕尺寸判断是否为iPad
  // iPad最小宽度是768pt（iPad mini），iPhone最大是430pt
  static bool isIPad(BuildContext context) {
    if (!Platform.isIOS) return false;
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600; // iPad的最短边通常>=768，这里用600作为安全阈值
  }

  static String? getFontFamily() {
    if (Platform.isWindows) {
      return 'Microsoft YaHei';
    }
    return null; // fallback
  }

  static T select<T>({required T desktop, required T mobile}) {
    return isDesktop ? desktop : mobile;
  }
}
