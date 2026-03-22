import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lzf_music/utils/platform_utils.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:tray_manager/tray_manager.dart';
import '../utils/theme_utils.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'dart:ui';

class DesktopManager {
  static State? _currentState;
  static const Color _linuxWindowBackground = ThemeUtils.darkBg;

  static Future<void> initialize() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      await windowManager.ensureInitialized();
      await Window.initialize();

      final windowOptions = WindowOptions(
        size: Size(1080, 720),
        minimumSize: Size(360, 660),
        center: true,
        backgroundColor:
            PlatformUtils.isLinux ? _linuxWindowBackground : Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setBackgroundColor(
          PlatformUtils.isLinux ? _linuxWindowBackground : Colors.transparent,
        );
        await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();

        await windowManager.setBackgroundColor(
          PlatformUtils.isLinux ? _linuxWindowBackground : Colors.transparent,
        );
        if (Platform.isMacOS) {
          await Window.setEffect(
            effect: WindowEffect.hudWindow,
            dark:
                PlatformDispatcher.instance.platformBrightness ==
                Brightness.dark,
          );
          Window.setBlurViewState(MacOSBlurViewState.active);
        }
      });

      await _initTray();
    } catch (e) {
      debugPrint('桌面端初始化失败: $e');
    }
  }

  static Future<void> postInitialize() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      if (PlatformUtils.isWindows) {
        doWhenWindowReady(() {
          final win = appWindow;
          win.minSize = const Size(360, 660);
          win.size = const Size(1080, 720);
          win.alignment = Alignment.center;
          win.show();
          if (Platform.isWindows) {
            Window.setEffect(
              effect: WindowEffect.mica,
              dark:
                  PlatformDispatcher.instance.platformBrightness ==
                  Brightness.dark,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('桌面端后初始化失败: $e');
    }
  }

  static void initializeListeners(State state) {
    if (!PlatformUtils.isDesktop) return;

    _currentState = state;
    if (state is WindowListener) {
      windowManager.addListener(state as WindowListener);
    }
    if (state is TrayListener) {
      trayManager.addListener(state as TrayListener);
    }
  }

  static void disposeListeners() {
    if (!PlatformUtils.isDesktop || _currentState == null) return;

    if (_currentState is WindowListener) {
      windowManager.removeListener(_currentState as WindowListener);
    }
    if (_currentState is TrayListener) {
      trayManager.removeListener(_currentState as TrayListener);
    }
    _currentState = null;
  }

  static Widget buildWithTitleBar(Widget? child) {
    if (!PlatformUtils.isWindows) {
      return child ?? const SizedBox.shrink();
    }
    return Stack(
      children: [
        if (child != null) Positioned.fill(child: child),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 30,
          child: CustomTitleBar(),
        ),
      ],
    );
  }

  static Future<void> _initTray() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/windows/icons/tray_icon.ico'
            : 'assets/icons/tray_icon.svg',
            isTemplate: PlatformUtils.isMacOS
      );
    } catch (e) {
      debugPrint('系统托盘初始化失败: $e');
    }
  }

  static Future<void> updateTray() async {
    if (!PlatformUtils.isDesktop) return;
    try {
      bool isWindowVisible = await windowManager.isVisible();
      Menu menu = Menu(
        items: [
          MenuItem(
            key: isWindowVisible ? 'hide_window' : 'show_window',
            label: isWindowVisible ? '隐藏窗口' : '显示窗口',
          ),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: '退出应用'),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('系统托盘更新失败: $e');
    }
  }

  static Future<void> handleTrayMenuClick(MenuItem menuItem) async {
    if (!PlatformUtils.isDesktop) return;

    try {
      switch (menuItem.key) {
        case 'show_window':
          await windowManager.show();
          break;
        case 'hide_window':
          await windowManager.hide();
          break;
        case 'exit_app':
          await trayManager.destroy();
          await windowManager.setPreventClose(false);
          await windowManager.close();
          break;
      }
    } catch (e) {
      debugPrint('托盘菜单处理失败: $e');
    }
  }

  static Future<void> handleWindowClose() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      if (await windowManager.isPreventClose()) {
        await windowManager.hide();
      } else {
        await windowManager.close();
        exit(0);
      }
    } catch (e) {
      debugPrint('窗口关闭处理失败: $e');
    }
  }

  static Future<void> handleTrayIconClick() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      if (!await windowManager.isVisible()) {
        await windowManager.show();
      }
    } catch (e) {
      debugPrint('托盘图标点击处理失败: $e');
    }
  }

  static Future<void> handleTrayRightClick() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      await updateTray();
      await trayManager.popUpContextMenu();
    } catch (e) {
      debugPrint('托盘右键点击处理失败: $e');
    }
  }

  static Future<void> hideWindow() async {
    if (!PlatformUtils.isDesktop) return;
    try {
      await windowManager.hide();
    } catch (e) {
      debugPrint('隐藏窗口失败: $e');
    }
  }

  static Future<void> showWindow() async {
    if (!PlatformUtils.isDesktop) return;

    try {
      await windowManager.show();
    } catch (e) {
      debugPrint('显示窗口失败: $e');
    }
  }
}

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: ThemeUtils.select(
        context,
        light: Colors.black54,
        dark: Colors.white70,
      ),
      mouseOver: ThemeUtils.select(
        context,
        light: Colors.grey.shade300,
        dark: Colors.grey.shade700,
      ),
      mouseDown: ThemeUtils.select(
        context,
        light: Colors.grey.shade400,
        dark: Colors.grey.shade800,
      ),
      iconMouseOver: ThemeUtils.select(
        context,
        light: Colors.black,
        dark: Colors.white,
      ),
      iconMouseDown: ThemeUtils.select(
        context,
        light: Colors.black,
        dark: Colors.white,
      ),
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: ThemeUtils.select(
        context,
        light: Colors.black54,
        dark: Colors.white70,
      ),
      mouseOver: Colors.red.shade700,
      mouseDown: Colors.red.shade900,
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );

    return Container(
      color: Colors.transparent,
      child: WindowTitleBarBox(
        child: Row(
          children: [
            Expanded(child: MoveWindow()),
            Row(
              children: [
                MinimizeWindowButton(
                  colors: buttonColors,
                  onPressed: () => windowManager.minimize(),
                ),
                MaximizeWindowButton(
                  colors: buttonColors,
                  onPressed: () async {
                    bool maximized = await windowManager.isMaximized();
                    if (maximized) {
                      windowManager.restore();
                    } else {
                      windowManager.maximize();
                    }
                  },
                ),
                CloseWindowButton(
                  colors: closeButtonColors,
                  onPressed: () => windowManager.close(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

mixin DesktopWindowMixin<T extends StatefulWidget> on State<T>
    implements WindowListener, TrayListener {
  @override
  void onWindowClose() => DesktopManager.handleWindowClose();

  @override
  void onTrayIconMouseDown() => DesktopManager.handleTrayIconClick();

  @override
  void onTrayIconRightMouseDown() => DesktopManager.handleTrayRightClick();

  @override
  void onTrayIconRightMouseUp() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) =>
      DesktopManager.handleTrayMenuClick(menuItem);

  @override
  void onWindowFocus() {}
  @override
  void onWindowBlur() {}
  @override
  void onWindowMaximize() {}
  @override
  void onWindowUnmaximize() {}
  @override
  void onWindowMinimize() {}
  @override
  void onWindowRestore() {}
  @override
  void onWindowResize() {}
  @override
  void onWindowResized() {}
  @override
  void onWindowMove() {}
  @override
  void onWindowMoved() {}
  @override
  void onWindowEnterFullScreen() {}
  @override
  void onWindowLeaveFullScreen() {}
  @override
  void onWindowDocked() {}
  @override
  void onWindowUndocked() {}
  @override
  void onWindowEvent(String eventName) {}
  @override
  void onTrayIconMouseUp() {}
}
