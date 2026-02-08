import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:lzf_music/utils/common_utils.dart';
import 'package:lzf_music/utils/platform_utils.dart';
import 'package:lzf_music/utils/theme_utils.dart';
import '../widgets/mini_player.dart';
import 'package:provider/provider.dart';
import '../../services/theme_provider.dart';
import '../contants/app_contants.dart' show PlayerPage;
import '../router/router.dart';
import 'dart:ui';
import '../utils/native_tab_bar_utils.dart';

class HomePageMobile extends StatefulWidget {
  const HomePageMobile({super.key});

  @override
  State<HomePageMobile> createState() => _HomePageMobileState();
}

class _HomePageMobileState extends State<HomePageMobile> {
  final menuManager = MenuManager();

  @override
  void initState() {
    super.initState();
    menuManager.init(navigatorKey: GlobalKey<NavigatorState>());
  }

  void _onTabChanged(int newIndex) {
    menuManager.setPage(PlayerPage.values[newIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Consumer<AppThemeProvider>(
      builder: (context, themeProvider, child) {
        final defaultTextColor = ThemeUtils.select(
          context,
          light: Colors.black,
          dark: Colors.white,
        );
        Color bodyBg = ThemeUtils.backgroundColor(context);

        NativeTabBarController.setEventHandler(onTabSelected: (index) {
          _onTabChanged(index);
        });

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              // 主内容区域
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      color: bodyBg,
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          padding: MediaQuery.of(context).padding.copyWith(
                                bottom: MediaQuery.of(context).padding.bottom +
                                    80, // 增加底部导航栏高度
                              ),
                        ),
                        child: ValueListenableBuilder<PlayerPage>(
                          valueListenable: menuManager.currentPage,
                          builder: (context, currentPage, _) {
                            return IndexedStack(
                              index: currentPage.index,
                              children: menuManager.pages,
                            );
                          },
                        ),
                      ),
                    ),

                    // 顶部标题栏
                    // Positioned(
                    //   top: 40,
                    //   left: 0,
                    //   right: 0,
                    //   child: Container(
                    //     padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    //     child: Row(
                    //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //       children: [ResolutionDisplay(isMinimized: true)],
                    //     ),
                    //   ),
                    // ),

                    // MiniPlayer
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: PlatformUtils.isIOS ? 80 : 0, // iOS 平台向上移动，避免和液态玻璃标签栏重合
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(66),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color:
                                            ThemeUtils.backgroundColor(context)
                                                .withValues(alpha: 0.8),
                                        border: Border.all(
                                          color: CommonUtils.select(
                                              ThemeUtils.isDark(context),
                                              t: const Color.fromRGBO(
                                                  255, 255, 255, 0.05),
                                              f: const Color.fromRGBO(
                                                  0, 0, 0, 0.05)),
                                          width: 1.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(65.5),
                                      ),
                                      child: MiniPlayer(
                                        containerWidth: constraints.maxWidth,
                                        isMobile: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 8,
                              ),
                              // 标签栏处理：
                              // - iOS (iPhone/iPad): 使用原生液态玻璃标签栏，不显示 Flutter 标签栏
                              // - 其他平台 (Android等): 使用 Flutter 标签栏，需要80px空间
                              SizedBox(
                                height: PlatformUtils.isIOS ? 0 : 80,
                                child: PlatformUtils.isIOS
                                    ? SizedBox()
                                    : ValueListenableBuilder<PlayerPage>(
                                        valueListenable:
                                            menuManager.currentPage,
                                        builder: (context, currentPage, _) {
                                          return ClipRect(
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                  sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                  decoration: BoxDecoration(
                                                    color: ThemeUtils
                                                        .backgroundColor(
                                                      context,
                                                    ).withValues(alpha: 0.8),
                                                    border: Border(
                                                      top: BorderSide(
                                                        color:
                                                            CommonUtils.select(
                                                                ThemeUtils
                                                                    .isDark(
                                                                        context),
                                                                t: const Color
                                                                    .fromRGBO(
                                                                    255,
                                                                    255,
                                                                    255,
                                                                    0.05),
                                                                f: const Color
                                                                    .fromRGBO(
                                                                    0,
                                                                    0,
                                                                    0,
                                                                    0.05)),
                                                        width: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: List.generate(
                                                        menuManager
                                                            .items.length, (
                                                      index,
                                                    ) {
                                                      final item = menuManager
                                                          .items[index];
                                                      final isSelected =
                                                          index ==
                                                              currentPage.index;

                                                      Color iconColor;
                                                      Color textColor;

                                                      if (isSelected) {
                                                        iconColor = primary;
                                                        textColor = primary;
                                                      } else {
                                                        iconColor =
                                                            defaultTextColor
                                                                .withValues(
                                                                    alpha: 0.6);
                                                        textColor =
                                                            defaultTextColor
                                                                .withValues(
                                                                    alpha: 0.6);
                                                      }

                                                      return Expanded(
                                                        child: InkWell(
                                                          onTap: () =>
                                                              _onTabChanged(
                                                                  index),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        8),
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(item.icon,
                                                                    color:
                                                                        iconColor,
                                                                    size: 24),
                                                                const SizedBox(
                                                                    height: 4),
                                                                Text(
                                                                  item.languageKey.getString(context),
                                                                  style:
                                                                      TextStyle(
                                                                    color:
                                                                        textColor,
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }),
                                                  )),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 底部导航栏
            ],
          ),
        );
      },
    );
  }
}
