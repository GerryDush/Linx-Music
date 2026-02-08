import 'package:flutter/material.dart';
import 'package:lzf_music/services/audio_player_service.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';

import 'views/home_page_mobile.dart';
import 'views/home_page_desktop.dart';
import 'services/player_provider.dart';
import 'database/database.dart';
import './services/theme_provider.dart';
import 'platform/desktop_manager.dart';
import 'platform/mobile_manager.dart';
import 'widgets/keyboard_handler.dart';
import './utils/platform_utils.dart';
import '../utils/native_tab_bar_utils.dart';
import 'package:flutter_localization/flutter_localization.dart';
import './i18n/i18n.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

class GlobalRouteObserver extends NavigatorObserver {
  void _printRoute(Route<dynamic> route, String action) {
    print('$action: ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == 'NowPlayingScreen') {
      if (PlatformUtils.isIOS) {
        NativeTabBarController.hide();
      }
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route.settings.name == 'NowPlayingScreen') {
      if (PlatformUtils.isIOS) {
        NativeTabBarController.show();
      }
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _printRoute(newRoute, 'REPLACE');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterLocalization.instance.ensureInitialized();

  try {
    if (PlatformUtils.isDesktop) {
      await DesktopManager.initialize();
    } else if (PlatformUtils.isMobile) {
      await MobileManager.initialize();
    }

    MediaKit.ensureInitialized();

    final themeProvider = AppThemeProvider();
    await themeProvider.init();
    final musicDatabase = MusicDatabase.initialize();
    await AudioPlayerService.init();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider(create: (_) => PlayerProvider()),
          Provider<MusicDatabase>.value(value: musicDatabase),
        ],
        child: const MainApp(),
      ),
    );

    if (PlatformUtils.isDesktop) {
      await DesktopManager.postInitialize();
    }
  } catch (e) {
    debugPrint('应用初始化失败: $e');
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with DesktopWindowMixin {
  final FlutterLocalization _localization = FlutterLocalization.instance;
  @override
  void initState() {
    _localization.init(
      mapLocales: [
        const MapLocale(
          'en',
          AppLocale.EN,
          countryCode: 'US',
        ),
        const MapLocale(
          'zh',
          AppLocale.ZH,
          countryCode: 'ZH',
        ),
      ],
      initLanguageCode: 'en',
    );
    _localization.onTranslatedLanguage = _onTranslatedLanguage;
    super.initState();
    if (PlatformUtils.isDesktop) {
      DesktopManager.initializeListeners(this);
    }
  }

  @override
  void dispose() {
    if (PlatformUtils.isDesktop) {
      DesktopManager.disposeListeners();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeProvider>(
      builder: (context, themeProvider, child) {
        return MyKeyboardHandler(
          child: MaterialApp(
            supportedLocales: _localization.supportedLocales,
            localizationsDelegates: _localization.localizationsDelegates,
            color: Colors.transparent,
            title: 'Linx Music',
            theme: themeProvider.buildLightTheme(),
            darkTheme: themeProvider.buildDarkTheme(),
            themeMode: themeProvider.themeMode,
            home: HomePageWrapper(),
            navigatorObservers: [GlobalRouteObserver()],
            builder: (context, child) {
              if (PlatformUtils.isDesktopNotMac) {
                return DesktopManager.buildWithTitleBar(child);
              }
              return child ?? const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  void _onTranslatedLanguage(Locale? locale) async {
     DisplayMode m = await FlutterDisplayMode.active;
    print('默认：$m');
    final modes = await FlutterDisplayMode.supported;
    modes.forEach(print);
    await FlutterDisplayMode.setHighRefreshRate();
    print('语言已切换至: ${locale?.languageCode}');
    m = await FlutterDisplayMode.active;
    print('切换至： $m');
    setState(() {});
  }
}

class HomePageWrapper extends StatelessWidget {
  const HomePageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isMobileWidth(context)) {
      // 小屏幕（手机）
      return const HomePageMobile();
    } else {
      // 大屏幕（平板/桌面）
      return const HomePageDesktop();
    }
  }
}
