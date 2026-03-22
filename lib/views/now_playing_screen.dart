import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lzf_music/utils/common_utils.dart';
import 'package:lzf_music/utils/platform_utils.dart';
import 'package:lzf_music/widgets/liquid_gradient_painter.dart';
import 'package:lzf_music/widgets/animated_album_cover.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../services/player_provider.dart';
import '../services/audio_route_service.dart';
import 'package:flutter/services.dart';
import 'package:lzf_music/widgets/karaoke_lyrics_view.dart';
import 'package:lzf_music/widgets/music_control_panel.dart';

class ImprovedNowPlayingScreen extends StatefulWidget {
  const ImprovedNowPlayingScreen({Key? key}) : super(key: key);

  @override
  State<ImprovedNowPlayingScreen> createState() =>
      _ImprovedNowPlayingScreenState();
}

class _ImprovedNowPlayingScreenState extends State<ImprovedNowPlayingScreen> {
  late ScrollController _scrollController;
  bool isHoveringLyrics = false;
  int lastCurrentIndex = -1;
  Map<int, double> lineHeights = {};
  double get placeholderHeight => 80;

  double _tempSliderValue = -1;
  bool _showLyrics = false;

  void _toggleLyrics() {
    setState(() {
      _showLyrics = !_showLyrics;
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  final FocusNode _focusNode = FocusNode();
  int? _currentSongId;
  @override
  Widget build(BuildContext context) {
    return Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(context);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Consumer<PlayerProvider>(
          builder: (context, playerProvider, child) {
            final currentSong = playerProvider.currentSong;
            final bool isPlaying = playerProvider.isPlaying;
            if (currentSong != null && currentSong.id != _currentSongId) {
              _currentSongId = currentSong.id;
            }

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LiquidGeneratorPage(
                          liquidColors: currentSong!.palette,
                          isPlaying: isPlaying,
                        )
                      ],
                    ),
                  ),
                  SafeArea(
                    child: LayoutBuilder(builder: (context, constraints) {
                      final isNarrow = PlatformUtils.isMobileWidth(context);

                      if (isNarrow) {
                        return MobileLayout(
                          currentSong: currentSong,
                          playerProvider: playerProvider,
                          isPlaying: isPlaying,
                          tempSliderValue: _tempSliderValue,
                          onSliderChanged: (value) =>
                              setState(() => _tempSliderValue = value),
                          onSliderChangeEnd: (value) {
                            setState(() => _tempSliderValue = -1);
                            playerProvider
                                .seekTo(Duration(seconds: value.toInt()));
                          },
                          showLyrics: _showLyrics,
                          onToggleLyrics: _toggleLyrics,
                        );
                      }

                      return DesktopLayout(
                        currentSong: currentSong,
                        playerProvider: playerProvider,
                        isPlaying: isPlaying,
                        tempSliderValue: _tempSliderValue,
                        onSliderChanged: (value) =>
                            setState(() => _tempSliderValue = value),
                        onSliderChangeEnd: (value) {
                          setState(() => _tempSliderValue = -1);
                          playerProvider
                              .seekTo(Duration(seconds: value.toInt()));
                        },
                      );
                    }),
                  ),
                  // 底部按钮 - 安全区外
                  if (PlatformUtils.isMobileWidth(context))
                    MobileBottomButtons(
                      showLyrics: _showLyrics,
                      onToggleLyrics: _toggleLyrics,
                    ),
                ],
              ),
            );
          },
        ));
  }


  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

// 移动端顶部歌曲信息栏

// 带渐变遮罩的歌词视图
class LyricsViewWithGradient extends StatelessWidget {
  final Widget lyricsView;
  final EdgeInsets padding;

  const LyricsViewWithGradient({
    Key? key,
    required this.lyricsView,
    this.padding = const EdgeInsets.only(top: 100.0, bottom: 210.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent
              ],
              stops: [0.0, 0.1, 0.9, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: lyricsView,
        ),
      ),
    );
  }
}

// 移动端无歌词布局（类似桌面端左侧样式）

// 移动端布局
class MobileLayout extends StatefulWidget {
  final dynamic currentSong;
  final PlayerProvider playerProvider;
  final bool isPlaying;
  final double tempSliderValue;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<double> onSliderChangeEnd;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;

  const MobileLayout({
    Key? key,
    required this.currentSong,
    required this.playerProvider,
    required this.isPlaying,
    required this.tempSliderValue,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    required this.showLyrics,
    required this.onToggleLyrics,
  }) : super(key: key);

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout>
    with SingleTickerProviderStateMixin {
  // Padding 常量配置
  static const double _topPaddingBase = 4.0; // 顶部基础增加值
  static const double _topPaddingMacOS = 20.0; // macOS 顶部额外增加值
  static const double _bottomPaddingBase = 20.0; // 底部基础增加值
  static const double _bottomPaddingMacOS = 32.0; // macOS 底部额外增加值

  bool _showControlPanel = true;
  bool get _showLyrics => widget.showLyrics;
  Timer? _hideTimer;
  late AnimationController _transitionController;
  bool _handledLyricsSwipeInCurrentGesture = false;

  // 缩小后的封面尺寸
  static const double _smallCoverSize = 66.0;
  static const double _smallCoverBorderRadius = 10.0;
  static const double _largeCoverBorderRadius = 20.0;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: widget.showLyrics ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(MobileLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 showLyrics 状态变化时触发动画
    if (widget.showLyrics != oldWidget.showLyrics) {
      if (widget.showLyrics) {
        _transitionController.forward();
        // 切换到歌词模式时，显示控件并启动3秒隐藏计时器
        setState(() => _showControlPanel = true);
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _showLyrics) {
            setState(() => _showControlPanel = false);
          }
        });
      } else {
        _transitionController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _transitionController.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => _showControlPanel = false);
      }
    });
  }

  void _showControls() {
    if (!_showControlPanel) {
      setState(() => _showControlPanel = true);
    }
    _startHideTimer();
  }

  void _hideControls() {
    _hideTimer?.cancel();
    if (_showLyrics && _showControlPanel) {
      setState(() => _showControlPanel = false);
    }
  }

  void _onLyricsVerticalDragStart() {
    _handledLyricsSwipeInCurrentGesture = false;
  }

  void _onLyricsVerticalDragUpdate(double deltaY) {
    if (!_showLyrics || _handledLyricsSwipeInCurrentGesture) {
      return;
    }

    if (deltaY.abs() < 8) {
      return;
    }

    _handledLyricsSwipeInCurrentGesture = true;
    if (deltaY < 0) {
      _showControls();
    } else {
      _hideControls();
    }
  }

  void _onLyricsVerticalDragEnd() {
    _handledLyricsSwipeInCurrentGesture = false;
  }

  @override
  Widget build(BuildContext context) {
    // 计算 Padding 值（安全区）
    final paddingLeft = 30.0;
    final paddingRight = 30.0;
    final paddingTop = MediaQuery.of(context).padding.top +
        _topPaddingBase +
        ((defaultTargetPlatform == TargetPlatform.macOS)
            ? _topPaddingMacOS
            : 0);
    final paddingBottom = MediaQuery.of(context).padding.bottom +
        _bottomPaddingBase +
        ((defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.windows)
            ? _bottomPaddingMacOS
            : 0);

    final lyricsView = Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
        ),
        child: KaraokeLyricsView(
          key: ValueKey('mobile_${widget.currentSong.id}'),
          lyricsData: widget.currentSong.lyricsBlob,
          currentPosition: widget.playerProvider.position,
          onTapLine: (time) {
            widget.playerProvider.seekTo(time);
            _showControls();
          },
          onVerticalDragStart: _onLyricsVerticalDragStart,
          onVerticalDragUpdate: _onLyricsVerticalDragUpdate,
          onVerticalDragEnd: _onLyricsVerticalDragEnd,
        ));

    return GestureDetector(
        onTap: _showLyrics ? () => _showControls() : null,
        child: DraggableCloseContainer(
        child: Stack(
          children: [
            // 主内容区域（带安全区 padding）
            Stack(
              children: [
                // 歌词层（在显示歌词时可见）
                AnimatedBuilder(
                  animation: _transitionController,
                  builder: (context, child) {
                    final t = Curves.easeInOutSine
                        .transform(_transitionController.value);
                    final blurAmount = 5.0 * (1.0 - t); // 从5到0的模糊

                    return _showLyrics
                        ? Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: 88,
                                bottom: _showControlPanel ? 244.0 : 8.0,
                              ),
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: blurAmount,
                                  sigmaY: blurAmount,
                                  tileMode: TileMode.decal,
                                ),
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black,
                                        Colors.black,
                                        Colors.transparent
                                      ],
                                      stops: [0.0, 0.1, 0.9, 1.0],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: lyricsView,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink();
                  },
                ),

                // 主内容层
                AnimatedBuilder(
                  animation: _transitionController,
                  builder: (context, child) {
                    final t = Curves.easeInOutSine
                        .transform(_transitionController.value);
                    // 上部 flex: 从 2 过渡到 0
                    final topFlex = ((1 - t) * 2).clamp(0.01, 2.0);
                    // 下部 flex: 从 3 过渡到 1
                    final bottomFlex = 3 - t * 2;

                    return Column(
                      children: [
                        // 顶部：把手
                        SizedBox(
                          width: 100,
                          height: 6,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(4),
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 上部空间 - 动画过渡 flex 值
                        Flexible(
                          flex: (topFlex * 100).round(),
                          child: const SizedBox.expand(),
                        ),

                        // 封面/歌曲信息

                        Column(
                          children: [
                            const SizedBox(height: 8),
                            Padding(
                              padding: EdgeInsets.only(
                                left: paddingLeft+10,
                                right: paddingRight+10,
                                top: paddingTop,
                                bottom: paddingBottom,
                              ),
                              child: AnimatedAlbumCover(
                                albumArtPath: widget.currentSong.albumArtPath,
                                title: widget.currentSong.title,
                                artist: widget.currentSong.artist,
                                isPlaying: widget.isPlaying,
                                animationProgress: t,
                                smallCoverSize: _smallCoverSize,
                                largeCoverBorderRadius: _largeCoverBorderRadius,
                                smallCoverBorderRadius: _smallCoverBorderRadius,
                                smallCoverLeft: -10.0,
                                smallCoverTop: 2.0,
                              ),
                            )
                          ],
                        ),

                        // 下部空间 - 动画过渡 flex 值
                        Flexible(
                          flex: (bottomFlex * 100).round(),
                          child: const SizedBox.expand(),
                        ),

                        Padding(
                          padding: EdgeInsets.only(
                            left: paddingLeft,
                            right: paddingRight,
                            top: paddingTop,
                            bottom: paddingBottom,
                          ),
                          child: Stack(
                            children: [
                              IgnorePointer(
                                ignoring: _showLyrics && !_showControlPanel,
                                child: AnimatedOpacity(
                                  opacity: _showLyrics
                                      ? (_showControlPanel ? 1.0 : 0.0)
                                      : 1.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SongInfoPanel(
                                        tempSliderValue: widget.tempSliderValue,
                                        onSliderChanged: widget.onSliderChanged,
                                        onSliderChangeEnd: widget.onSliderChangeEnd,
                                        playerProvider: widget.playerProvider,
                                        compactLayout: t > 0.5,
                                        animationProgress: t, // 传递动画进度，实现同步
                                      ),
                                      const SizedBox(height: 10),
                                      MusicControlButtons(
                                        playerProvider: widget.playerProvider,
                                        isPlaying: widget.isPlaying,
                                        compactLayout: true,
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 桌面端布局
class DesktopLayout extends StatelessWidget {
  final dynamic currentSong;
  final PlayerProvider playerProvider;
  final bool isPlaying;
  final double tempSliderValue;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<double> onSliderChangeEnd;

  const DesktopLayout({
    Key? key,
    required this.currentSong,
    required this.playerProvider,
    required this.isPlaying,
    required this.tempSliderValue,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lyricsView = KaraokeLyricsView(
      key: ValueKey('desktop_${currentSong.id}'),
      lyricsData: currentSong.lyricsBlob,
      currentPosition: playerProvider.position,
      onTapLine: (time) => playerProvider.seekTo(time),
    );

    return DraggableCloseContainer(
      child: Row(
        children: [
          Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: CommonUtils.select(
                    MediaQuery.of(context).size.width > 1300,
                    t: 380,
                    f: 336,
                  ),
                  height: 700,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          HoverIconButton(
                              onPressed: () => Navigator.pop(context)),
                          AnimatedScale(
                            scale: isPlaying ? 1.0 : 0.85,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: AnimatedOpacity(
                              opacity: isPlaying ? 1.0 : 0.8,
                              duration: const Duration(milliseconds: 300),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: currentSong.albumArtPath != null &&
                                        File(currentSong.albumArtPath!)
                                            .existsSync()
                                    ? Image.file(
                                        File(currentSong.albumArtPath!),
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: double.infinity,
                                        height: 300,
                                        color: Colors.grey[800],
                                        child: const Icon(
                                            Icons.music_note_rounded,
                                            color: Colors.white,
                                            size: 48),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SongInfoPanel(
                              tempSliderValue: tempSliderValue,
                              onSliderChanged: onSliderChanged,
                              onSliderChangeEnd: onSliderChangeEnd,
                              playerProvider: playerProvider,
                            ),
                            const SizedBox(height: 8),
                            MusicControlButtons(
                              playerProvider: playerProvider,
                              isPlaying: isPlaying,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            flex: 5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60.0),
                child: SizedBox(
                  width: 480,
                  child: LyricsViewWithGradient(
                    lyricsView: lyricsView,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MeasureSize extends StatefulWidget {
  final Widget child;
  final Function(Size) onChange;

  const MeasureSize({Key? key, required this.onChange, required this.child})
      : super(key: key);

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? oldSize;
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final contextSize = context.size;
      if (contextSize != null && oldSize != contextSize) {
        oldSize = contextSize;
        widget.onChange(contextSize);
      }
    });
    return widget.child;
  }
}

class DraggableCloseContainer extends StatefulWidget {
  final Widget child;
  final double topFraction;
  final double distanceThreshold;
  final double velocityThreshold;

  const DraggableCloseContainer({
    Key? key,
    required this.child,
    this.topFraction = 0.7,
    this.distanceThreshold = 140.0,
    this.velocityThreshold = 700.0,
  }) : super(key: key);

  @override
  _DraggableCloseContainerState createState() =>
      _DraggableCloseContainerState();
}

class _DraggableCloseContainerState extends State<DraggableCloseContainer> {
  double _dragOffsetX = 0.0;
  double _dragOffsetY = 0.0;
  bool _isDraggingForClose = false;
  String? _dragAxis;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        final startDy = details.globalPosition.dy;
        final screenH = MediaQuery.of(context).size.height;
        _isDraggingForClose = startDy <= screenH * widget.topFraction;
        _dragAxis = null; // reset axis lock
      },
      onPanUpdate: (details) {
        if (!_isDraggingForClose) return;

        if (_dragAxis == null) {
          final dx = details.delta.dx.abs();
          final dy = details.delta.dy.abs();
          const axisLockThreshold = 4.0;
          if (dx >= axisLockThreshold || dy >= axisLockThreshold) {
            _dragAxis = dx > dy ? 'x' : 'y';
          } else {
            return;
          }
        }

        setState(() {
          if (_dragAxis == 'x') {
            _dragOffsetX =
                (_dragOffsetX + details.delta.dx).clamp(-50.0, 500.0);
          } else if (_dragAxis == 'y') {
            _dragOffsetY =
                (_dragOffsetY + details.delta.dy).clamp(-50.0, 500.0);
          }
        });
      },
      onPanEnd: (details) {
        if (!_isDraggingForClose) return;
        _isDraggingForClose = false;

        final axis = _dragAxis;
        _dragAxis = null;

        final vx = details.velocity.pixelsPerSecond.dx;
        final vy = details.velocity.pixelsPerSecond.dy;

        bool shouldClose = false;
        if (axis == 'x') {
          shouldClose = _dragOffsetX > widget.distanceThreshold ||
              vx > widget.velocityThreshold;
        } else if (axis == 'y') {
          shouldClose = _dragOffsetY > widget.distanceThreshold ||
              vy > widget.velocityThreshold;
        } else {
          shouldClose = _dragOffsetX > widget.distanceThreshold ||
              _dragOffsetY > widget.distanceThreshold ||
              vx > widget.velocityThreshold ||
              vy > widget.velocityThreshold;
        }

        if (shouldClose) {
          Navigator.maybePop(context);
        } else {
          // 回弹
          setState(() {
            _dragOffsetX = 0.0;
            _dragOffsetY = 0.0;
          });
        }
      },
      child: Transform.translate(
        offset: Offset(_dragOffsetX > 0 ? _dragOffsetX : 0.0,
            _dragOffsetY > 0 ? _dragOffsetY : 0.0),
        child: widget.child,
      ),
    );
  }
}

// 移动端底部按钮组件
class MobileBottomButtons extends StatelessWidget {
  final bool showLyrics;
  final VoidCallback onToggleLyrics;

  const MobileBottomButtons({
    Key? key,
    required this.showLyrics,
    required this.onToggleLyrics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // AirPlay 按钮 - 左下角
        Positioned(
          left: 28,
          bottom: 28,
          child: GestureDetector(
            onTap: () {
              AudioRouteService.showAudioRoutePicker();
            },
            child: SvgPicture.asset(
              'assets/icons/airplay.audio.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                Colors.white.withOpacity(0.9),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        // 歌词切换按钮 - 右下角
        Positioned(
          right: 28,
          bottom: 28,
          child: GestureDetector(
            onTap: onToggleLyrics,
            child: SvgPicture.asset(
              showLyrics
                  ? 'assets/icons/quote.bubble.fill.svg'
                  : 'assets/icons/quote.bubble.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                Colors.white.withOpacity(0.9),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
