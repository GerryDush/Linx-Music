import 'package:flutter/material.dart';
import 'package:lzf_music/ui/lzf_select.dart';
import 'package:lzf_music/utils/platform_utils.dart';
import 'package:lzf_music/widgets/lzf_dialog.dart';
import 'package:lzf_music/widgets/show_aware_page.dart';
import 'package:provider/provider.dart';
import '../../services/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../widgets/lzf_toast.dart';
import '../../router/router.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lzf_music/widgets/frosted_container.dart';
import 'package:lzf_music/widgets/themed_background.dart';
import '../../widgets/page_header.dart';
import 'package:lzf_music/utils/common_utils.dart';
import '../../i18n/i18n.dart';
import 'package:flutter_localization/flutter_localization.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> with ShowAwarePage {
  final localization = FlutterLocalization.instance;
  @override
  void onPageShow() {
    print('settings ...');
  }

  @override
  Widget build(BuildContext context) {
    final topSafeArea = MediaQuery.of(context).padding.top;
    return Consumer<AppThemeProvider>(
      builder: (context, themeProvider, child) {
        return ThemedBackground(
          builder: (context, theme) {
            return Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    4,
                    CommonUtils.select(theme.isFloat,
                        t: CommonUtils.select(PlatformUtils.isMobile,
                            t: topSafeArea + 44, f: 70),
                        f: 80),
                    4,
                    CommonUtils.select(theme.isFloat, t: 0, f: 90),
                  ),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      8.0,
                      CommonUtils.select(theme.isFloat, t: 18, f: 8),
                      8.0,
                      8.0,
                    ),
                    children: [
                      _buildSectionHeader('基本设置'),
                      _buildThemeSettingCard(),
                      const SizedBox(height: 18),
                      _buildSectionHeader('存储设置'),
                      _buildStorageSettingCard(),
                      const SizedBox(height: 18),
                      _buildSectionHeader('播放设置'),
                      _buildPlaybackSettingCard(),
                      const SizedBox(height: 18),
                      _buildSectionHeader('其他设置'),
                      _buildOtherSettingsCard(),
                      if (theme.isFloat)
                        const SizedBox(
                          height: 80,
                        )
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: FrostedContainer(
                    enabled: theme.isFloat,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16.0,
                          PlatformUtils.isDesktop ? 18 : 0,
                          16.0,
                          10,
                        ),
                        child: PageHeader(
                          showImport: false,
                          showSearch: false,
                          title: AppLocale.settings.getString(context),
                          children: [],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 构建分组标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  final List<Map<String, dynamic>> languages = [
    {
      'name': 'English',
      'code': 'en',
      'locale': AppLocale.EN,
    },
    {
      'name': '简体中文',
      'code': 'zh',
      'locale': AppLocale.ZH,
    }
  ];

  Widget _buildThemeSettingCard() {
    return Consumer<AppThemeProvider>(
      builder: (context, themeProvider, child) {
        void onColorChanged(Color color) {
          themeProvider.setSeedColor(color);
        }

        final colorPicker = SizedBox(
          height: 260,
          width: 260,
          child: Consumer<AppThemeProvider>(
              builder: (context, themeProvider, child) {
            return ColorPickerArea(
              HSVColor.fromColor(themeProvider.seedColor),
              (v) {
                onColorChanged(v.toColor());
              },
              PaletteType.rgbWithBlue,
            );
          }),
        );

        final rightColumn = Column(
          children: [
            SizedBox(
              width: 280,
              child: Center(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    ...[
                      Color(0xFF016B5B),
                      Colors.red,
                      Colors.green,
                      Colors.blue,
                      Colors.orange,
                      Colors.purple,
                      Colors.pink,
                      Colors.amber,
                    ].map((e) => MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            onColorChanged(e);
                          },
                          child: CircleAvatar(
                            backgroundColor: e,
                            radius: 14,
                          ),
                        )))
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40.0,
              width: 280,
              child: Consumer<AppThemeProvider>(
                  builder: (context, themeProvider, child) {
                return ColorPickerSlider(
                  TrackType.blue,
                  HSVColor.fromColor(themeProvider.seedColor),
                  (v) {
                    onColorChanged(v.toColor());
                  },
                  displayThumbColor: true,
                );
              }),
            ),
            if (!PlatformUtils.isMobileWidth(context)) ...[
              SizedBox(
                height: 40.0,
                width: 280,
                child: Consumer<AppThemeProvider>(
                    builder: (context, themeProvider, child) {
                  return ColorPickerSlider(
                    TrackType.alpha,
                    HSVColor.fromColor(themeProvider.seedColor),
                    (v) {
                      onColorChanged(v.toColor());
                    },
                    displayThumbColor: true,
                  );
                }),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 280,
                child: Consumer<AppThemeProvider>(
                    builder: (context, themeProvider, child) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 12),
                      ColorIndicator(
                        HSVColor.fromColor(themeProvider.seedColor)
                            .withAlpha(1),
                        width: 30,
                        height: 30,
                      ),
                      const SizedBox(width: 40),
                      ColorPickerInput(
                        themeProvider.seedColor,
                        (Color color) {},
                        enableAlpha: true,
                        embeddedText: false,
                      )
                    ],
                  );
                }),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 260,
                child: Row(
                  children: [
                    const Text(
                      "透明区域",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Consumer<AppThemeProvider>(
                          builder: (context, themeProvider, child) {
                        final map = {
                          '窗口': 'window',
                          '仅侧边栏': 'sidebar',
                          '仅主体': 'body'
                        };
                        return RadixSelect(
                          value: map.entries
                              .firstWhere(
                                  (e) => e.value == themeProvider.opacityTarget)
                              .key,
                          items: ['窗口', '仅侧边栏', '仅主体'],
                          onChanged: (v) {
                            themeProvider.setOpacityTarget(map.entries
                                .firstWhere((e) => e.key == v)
                                .value);
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

        return _buildSettingCard(
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Icon(
                    themeProvider.getThemeIcon(),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text(
                  '主题模式',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(themeProvider.getThemeName()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(themeProvider),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.brush_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  '主题色&背景透明度(高斯模糊)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  '通过调色盘调整主题色和背景透明度',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  LZFDialog.show(
                    context,
                    width: 596,
                    titleText: '选择主题色和背景透明度',
                    content: Builder(
                      builder: (innerContext) {
                        bool isMobile =
                            PlatformUtils.isMobileWidth(innerContext);
                        if (isMobile) {
                          return SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                colorPicker,
                                const SizedBox(height: 20),
                                rightColumn,
                              ],
                            ),
                          );
                        } else {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              colorPicker,
                              const SizedBox(width: 20),
                              rightColumn,
                            ],
                          );
                        }
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.language_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text(
                  '语言设置',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  languages.firstWhere(
                      (e) =>
                          e['code'] == localization.currentLocale?.languageCode,
                      orElse: () => languages[0])['name'],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await LZFDialog.show(
                    context,
                    width: 400,
                    titleText: '选择语言',
                    content: SizedBox(
                      width: 400,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: languages.map((lang) {
                          return ListTile(
                            title: Text(
                              lang['name'],
                              style: localization.currentLocale?.languageCode ==
                                      lang['code']
                                  ? TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary)
                                  : null,
                            ),
                            trailing: localization
                                        .currentLocale?.languageCode ==
                                    lang['code']
                                ? Icon(
                                    Icons.check_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                            onTap: () {
                              localization.translate(lang['code']);
                              LZFDialog.close(context);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildStorageSettingCard() {
    return Consumer<AppThemeProvider>(
      builder: (context, themeProvider, child) {
        return _buildSettingCard(
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.storage,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text(
                  '存储设置',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('添加存储本地/WebDav/More...'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  NestedNavigationHelper.push(context, "/settings/storage");
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.folder,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text(
                  '音乐源',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('添加的音乐源'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  NestedNavigationHelper.push(context, "/webdav/browser");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaybackSettingCard() {
    return _buildSettingCard(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(Icons.volume_up, color: Colors.green),
            ),
            title: const Text(
              '音量设置',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('调整默认音量'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              LZFToast.show(context, '音量设置功能尚未实现');
            },
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.1),
              child: const Icon(Icons.equalizer, color: Colors.orange),
            ),
            title: const Text(
              '音效设置',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('均衡器和音效'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              LZFToast.show(context, '音效设置功能尚未实现');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOtherSettingsCard() {
    return _buildSettingCard(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(Icons.description_outlined, color: Colors.blue),
            ),
            title: const Text(
              '许可证 Apache 2.0',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('查看软件许可证信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showLicenseDialog();
            },
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.1),
              child: const Icon(Icons.info_outline, color: Colors.purple),
            ),
            title: const Text(
              '关于应用',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('版本信息和开发者'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.grey.withOpacity(isDark ? 0.1 : 0.15),

      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias, // 裁剪水波纹
      child: child,
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeMode mode,
    String title,
    IconData icon,
    String subtitle,
    AppThemeProvider themeProvider,
  ) {
    final isSelected = themeProvider.themeMode == mode;

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? Icon(
              Icons.check_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: () {
        themeProvider.setThemeMode(mode);
        LZFDialog.close(context);
      },
      splashColor: Theme.of(
        context,
      ).colorScheme.primary.withOpacity(0.2),
    );
  }

  void _showThemeDialog(AppThemeProvider themeProvider) {
    LZFDialog.show(context,
        titleText: '主题模式',
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                context,
                ThemeMode.light,
                '亮色模式',
                Icons.light_mode,
                '始终使用亮色主题',
                themeProvider,
              ),
              _buildThemeOption(
                context,
                ThemeMode.dark,
                '深色模式',
                Icons.dark_mode,
                '始终使用深色主题',
                themeProvider,
              ),
              _buildThemeOption(
                context,
                ThemeMode.system,
                '跟随系统',
                Icons.brightness_auto,
                '跟随系统设置自动切换',
                themeProvider,
              ),
            ],
          ),
        ));
  }

  void _showAboutDialog() {
    _buildCopyRow(context, 'QQ群', '709053803');
    LZFDialog.show(
      context,
      titleText: 'Linx Music',
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: 0.3.3'),
            SizedBox(height: 8),
            Text('基于 Flutter 开发'),
            Text('开源软件，采用 Apache 2.0 许可证'),
            SizedBox(height: 12),
            Text('软件优点：', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              '1. 简洁、好看，拥有类似 Apple Music 的歌词页面，支持多种格式（mp3, m4a, wav, flac, aac）无损格式。',
            ),
            SizedBox(height: 6),
            Text('2. 能从音乐文件中读取 LRC 歌词。未来将支持歌词编辑、MV 导入与播放、WebDav 协议等功能，'),
            SizedBox(height: 6),
            Text('3. 提供本地和私有云音乐解决方案。'),
            SizedBox(height: 16),
            const Text(
              '反馈建议及联系方式',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildCopyRow(context, 'QQ群', '709053803'),
            const SizedBox(height: 6),
            _buildLinkRow(context, 'GitHub', 'https://github.com/GerryDush'),
          ],
        ),
      ),
      confirmText: '确定',
    );
  }

  void _showLicenseDialog() {
    rootBundle.loadString('assets/LICENSE').then((licence) {
      LZFDialog.show(context,
          titleText: '许可证 Apache 2.0',
          content: Text(licence),
          width: 500,
          confirmText: '确定',
          height: MediaQuery.of(context).size.height * 0.8);
    });
  }

  Widget _buildCopyRow(BuildContext context, String label, String content) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: content));
            LZFToast.show(context, '$label 已复制到剪贴板');
          },
          child: Text(
            content,
            style: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkRow(BuildContext context, String label, String url) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('无法打开链接: $url')));
              }
            },
            child: Text(
              url,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
