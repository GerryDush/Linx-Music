import 'package:flutter/material.dart';
import 'package:lzf_music/utils/theme_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/platform_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'dart:ui';

class AppThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _seedColorKey = 'theme_seed_color';
  static const String _seedAlphaKey = 'theme_seed_alpha';
  static const String _opacityTargetKey = 'theme_opacity_target';
  static const _sidebarIsExtendedKey = 'theme_sidebar_is_extended';

  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = const Color(0xFF016B5B); // 默认主题色
  double _seedAlpha = 1.0;
  String _opacityTarget = "window"; // 默认值
  bool _sidebarIsExtended = true;

  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  double get seedAlpha => _seedAlpha;
  String get opacityTarget => _opacityTarget;
  bool get sidebarIsExtended => _sidebarIsExtended;

  bool get _useTransparentDesktopChrome => !PlatformUtils.isLinux;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final savedThemeIndex = _prefs?.getInt(_themeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[savedThemeIndex];

    final savedColorValue = _prefs?.getInt(_seedColorKey);
    final savedAlphaValue = _prefs?.getDouble(_seedAlphaKey);
    final savedOpacityTarget = _prefs?.getString(_opacityTargetKey);
    final savedSidebarIsExtended = _prefs?.getBool(_sidebarIsExtendedKey);
    if (savedSidebarIsExtended != null) {
      _sidebarIsExtended = savedSidebarIsExtended;
    }
    if (savedColorValue != null) {
      _seedColor = Color(savedColorValue);
    }
    if (savedAlphaValue != null) {
      _seedAlpha = savedAlphaValue;
    }
    if (savedOpacityTarget != null) {
      _opacityTarget = savedOpacityTarget;
    }
    _updateWindowEffect();
    notifyListeners();
  }

  // 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setInt(_themeKey, mode.index);
    _updateWindowEffect();
    notifyListeners();
  }

  void _updateWindowEffect() {
    final isDark =
        PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    if (isDark) {
      if (PlatformUtils.isMacOS) {
        Window.setEffect(effect: WindowEffect.hudWindow, dark: isDark);
        Window.setBlurViewState(MacOSBlurViewState.active);
      }
      if (PlatformUtils.isWindows) {
        Window.setEffect(effect: WindowEffect.mica, dark: isDark);
        Window.setBlurViewState(MacOSBlurViewState.active);
      }
    }
  }

  Future<void> setSeedColor(Color color) async {
    if (_seedColor != color) {
      _seedColor = color;
      await _prefs?.setInt(_seedColorKey, color.toARGB32());
    }
    if (_seedAlpha != color.a) {
      _seedAlpha = color.a;
      await _prefs?.setDouble(_seedAlphaKey, color.a);
    }
    notifyListeners();
  }

  Future<void> setOpacityTarget(String target) async {
    if (_opacityTarget != target) {
      _opacityTarget = target;
      await _prefs?.setString(_opacityTargetKey, target);
    }
    notifyListeners();
  }

  Future<void> toggleExtended() async {
    _sidebarIsExtended = !_sidebarIsExtended;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sidebarIsExtendedKey, _sidebarIsExtended);
    notifyListeners();
  }

  String getThemeName() {
    switch (_themeMode) {
      case ThemeMode.light:
        return '亮色模式';
      case ThemeMode.dark:
        return '深色模式';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  IconData getThemeIcon() {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  ThemeData buildLightTheme() {
    return ThemeData(
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xffe0e0e0),
        shadowColor: Color(0xffe0e0e0),
        position: PopupMenuPosition.under,
      ),
      dialogTheme: DialogThemeData(backgroundColor: ThemeUtils.lightBg),
      fontFamily: PlatformUtils.getFontFamily(),
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor:
          _useTransparentDesktopChrome ? Colors.transparent : ThemeUtils.lightBg,
      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor:
            _useTransparentDesktopChrome ? Colors.transparent : ThemeUtils.lightBg,
        elevation: 0,
        toolbarHeight: PlatformUtils.isDesktopNotMac ? 56 : null,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  ThemeData buildDarkTheme() {
    return ThemeData(
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xff151515),
        shadowColor: Color(0xff151515),
        position: PopupMenuPosition.under,
      ),
      dialogTheme: DialogThemeData(backgroundColor: ThemeUtils.darkBg),
      fontFamily: PlatformUtils.getFontFamily(),
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor:
          _useTransparentDesktopChrome ? Colors.transparent : ThemeUtils.darkBg,
      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor:
            _useTransparentDesktopChrome ? Colors.transparent : ThemeUtils.darkBg,
        elevation: 0,
        toolbarHeight: PlatformUtils.isDesktop ? 56 : null,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
