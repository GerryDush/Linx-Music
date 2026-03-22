import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:lzf_music/utils/platform_utils.dart';
import './lyric/lyrics_models.dart';

class KaraokeLyricsView extends StatefulWidget {
  final LyricsData? lyricsData;
  final ValueNotifier<Duration> currentPosition;
  final Function(Duration) onTapLine;
  final VoidCallback? onVerticalDragStart;
  final ValueChanged<double>? onVerticalDragUpdate;
  final VoidCallback? onVerticalDragEnd;

  const KaraokeLyricsView({
    Key? key,
    required this.lyricsData,
    required this.currentPosition,
    required this.onTapLine,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
  }) : super(key: key);

  @override
  State<KaraokeLyricsView> createState() => _KaraokeLyricsViewState();
}

class _KaraokeLyricsViewState extends State<KaraokeLyricsView>
    with TickerProviderStateMixin {
  List<LyricLine> _lyricLines = [];
  int _currentLineIndex = 0;

  double _targetScrollY = 0.0;
  final Map<int, double> _lineHeights = {};
  final Map<_LyricLayoutCacheKey, _LyricLineLayout> _lyricLayoutCache = {};

  bool _isDragging = false;
  bool _isMomentumScrolling = false;
  bool _isMouseHovering = false;

  Timer? _resumeAutoScrollTimer;
  late AnimationController _momentumController;
  late final Ticker _positionTicker;
  final ValueNotifier<Duration> _displayPosition = ValueNotifier(Duration.zero);
  Duration _lastKnownPosition = Duration.zero;
  DateTime _lastPositionUpdateTime = DateTime.now();

  Timer? _wheelDebounceTimer;
  double _lastWheelDelta = 0.0;

  bool get _isInteracting =>
      _isDragging || _isMomentumScrolling || _isMouseHovering;

  @override
  void initState() {
    super.initState();
    _momentumController = AnimationController.unbounded(vsync: this);
    _lastKnownPosition = widget.currentPosition.value;
    _displayPosition.value = _lastKnownPosition;
    _positionTicker = createTicker(_tickDisplayPosition)..start();
    _updateLyricsData();
    widget.currentPosition.addListener(_onPositionChanged);
  }

  @override
  void didUpdateWidget(KaraokeLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyricsData != oldWidget.lyricsData) {
      _updateLyricsData();
    }
    if (widget.currentPosition != oldWidget.currentPosition) {
      oldWidget.currentPosition.removeListener(_onPositionChanged);
      widget.currentPosition.addListener(_onPositionChanged);
      _lastKnownPosition = widget.currentPosition.value;
      _lastPositionUpdateTime = DateTime.now();
      _displayPosition.value = _lastKnownPosition;
    }
  }

  void _updateLyricsData() {
    setState(() {
      _lyricLines = widget.lyricsData?.lines ?? [];
      _currentLineIndex = 0;
      _targetScrollY = 0.0;
      _lineHeights.clear();
      _lyricLayoutCache.clear();
      _forceResetState();
    });
  }

  void _forceResetState() {
    _resumeAutoScrollTimer?.cancel();
    _wheelDebounceTimer?.cancel();
    if (_momentumController.isAnimating) _momentumController.stop();
    _isDragging = false;
    _isMomentumScrolling = false;
  }

  void _onPositionChanged() {
    _lastKnownPosition = widget.currentPosition.value;
    _lastPositionUpdateTime = DateTime.now();

    if (_lyricLines.isEmpty) return;
    if (_isInteracting) return;

    final pos = widget.currentPosition.value;
    final newIndex = _lyricLines.lastIndexWhere(
      (line) => (pos + const Duration(milliseconds: 400)) >= line.startTime,
    );

    if (newIndex != -1 && newIndex != _currentLineIndex) {
      setState(() {
        _currentLineIndex = newIndex;
        _recalculateAutoScrollTarget();
      });
    }
  }

  void _tickDisplayPosition(Duration _) {
    final now = DateTime.now();
    final timeSinceUpdate = now.difference(_lastPositionUpdateTime);
    final nextPosition = timeSinceUpdate.inMilliseconds > 500
        ? _lastKnownPosition
        : _lastKnownPosition + timeSinceUpdate;

    if (_displayPosition.value != nextPosition) {
      _displayPosition.value = nextPosition;
    }
  }

  double _selectTopPadding() {
    return PlatformUtils.isMobileWidth(context) ? 120 : 160;
  }

  double _bottomSpacerHeight(BuildContext context) =>
      MediaQuery.of(context).size.height /1.5;

  void _recalculateAutoScrollTarget() {
    if (_lineHeights.isEmpty) return;

    final topPadding = _selectTopPadding();
    double offset = 0.0;
    for (int i = 0; i < _currentLineIndex; i++) {
      offset += (_lineHeights[i] ?? 80.0);
    }
    offset += topPadding;

    final screenHeight = MediaQuery.of(context).size.height;
    final currentLineHeight = _lineHeights[_currentLineIndex] ?? 80.0;

    double target = 0;
    if (topPadding == 160.0) {
      target = offset + (currentLineHeight / 2) - (screenHeight * 0.30);
    } else {
      target = offset + (currentLineHeight / 2) - (screenHeight * 0.2);
    }

    target = _clampScrollTarget(target);

    setState(() {
      _targetScrollY = target;
    });
  }

  double _clampScrollTarget(double target) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = _selectTopPadding();
    double totalContentHeight = topPadding +  _bottomSpacerHeight(context);
    for (var h in _lineHeights.values) totalContentHeight += h;

    if (totalContentHeight < screenHeight) return 0;
    final maxScroll = totalContentHeight - screenHeight;

    if (target < 0) return 0;
    if (target > maxScroll) return maxScroll;
    return target;
  }

  void _performRestore() {
    if (!mounted) return;
    setState(() {
      _isDragging = false;
      _isMomentumScrolling = false;
      _recalculateAutoScrollTarget();
    });
  }

  void _scheduleResumeAutoScroll() {
    _resumeAutoScrollTimer?.cancel();

    if (PlatformUtils.isDesktop) {
      if (_isMouseHovering) return;
      _resumeAutoScrollTimer = Timer(const Duration(milliseconds: 50), () {
        _performRestore();
      });
    } else {
      if (!_isDragging && !_isMomentumScrolling) {
        _resumeAutoScrollTimer = Timer(const Duration(milliseconds: 500), () {
          _performRestore();
        });
      }
    }
  }

  void _handleMouseWheel(PointerScrollEvent event) {
    if (!_isMomentumScrolling && !_isDragging) {
      _momentumController.stop();
      _resumeAutoScrollTimer?.cancel();
      setState(() => _isMomentumScrolling = true);
    }

    final double delta = -event.scrollDelta.dy * 1.5;
    _handleDragUpdate(delta);
    _lastWheelDelta = delta;

    _wheelDebounceTimer?.cancel();
    _wheelDebounceTimer = Timer(const Duration(milliseconds: 60), () {
      final double simulatedVelocity = _lastWheelDelta * 20;
      _handleDragEnd(simulatedVelocity);
    });
  }

  void _handleDragUpdate(double delta) {
    setState(() {
      double newTarget = _targetScrollY - delta;
      final maxScroll = _getMaxScrollExtent();
      if (newTarget < 0 || newTarget > maxScroll) {
        newTarget = _targetScrollY - (delta * 0.5);
      }
      _targetScrollY = _clampScrollTarget(newTarget);
    });
  }

  double _getMaxScrollExtent() {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = _selectTopPadding();
    final bottomSpacerHeight = _bottomSpacerHeight(context);
    double total = topPadding + bottomSpacerHeight;
    for (var h in _lineHeights.values) total += h;
    return (total - screenHeight).clamp(0.0, double.infinity);
  }

  void _handleDragEnd(double velocity) {
    setState(() {
      _isDragging = false;
      _isMomentumScrolling = true;
    });

    final simulation = FrictionSimulation(0.135, _targetScrollY, -velocity);
    _momentumController.animateWith(simulation);

    void tick() {
      if (!mounted) return;
      final double newVal = _momentumController.value;
      final double clamped = _clampScrollTarget(newVal);
      setState(() {
        _targetScrollY = clamped;
      });
      if ((newVal < 0 && velocity > 0) ||
          (newVal > _getMaxScrollExtent() && velocity < 0)) {
        _momentumController.stop();
      }
    }

    _momentumController.addListener(tick);
    _momentumController.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _momentumController.removeListener(tick);
        if (mounted) {
          setState(() {
            _isMomentumScrolling = false;
          });
          _scheduleResumeAutoScroll();
        }
      }
    });
  }

  @override
  void dispose() {
    widget.currentPosition.removeListener(_onPositionChanged);
    _momentumController.dispose();
    _positionTicker.dispose();
    _displayPosition.dispose();
    _resumeAutoScrollTimer?.cancel();
    _wheelDebounceTimer?.cancel();
    super.dispose();
  }

  // --- 全局交互逻辑 ---
  void _onGlobalPointerEnter() {
    // 只有当状态确实改变时才调用 setState，避免频繁重建
    if (!_isMouseHovering) {
      setState(() => _isMouseHovering = true);
    }
    _resumeAutoScrollTimer?.cancel();
    _wheelDebounceTimer?.cancel();
    if (_momentumController.isAnimating) _momentumController.stop();
    if (_isMomentumScrolling || _isDragging) {
      setState(() {
        _isMomentumScrolling = false;
        _isDragging = false;
      });
    }
  }

  void _onGlobalPointerExit() {
    setState(() => _isMouseHovering = false);
    _scheduleResumeAutoScroll();
  }

  @override
  Widget build(BuildContext context) {
    if (_lyricLines.isEmpty) {
      return const Center(
          child: Text("暂无歌词",
              style: TextStyle(color: Colors.white54, fontSize: 24)));
    }

    final double activeScrollY = _targetScrollY;
    final double topPadding = _selectTopPadding();
    final double bottomSpacerHeight = _bottomSpacerHeight(context);

    final bool interacting = _isInteracting;
    final bool isUserMoving = _isDragging || _isMomentumScrolling;

    // 修复点：外层 Listener 监听滚轮，内部包裹 MouseRegion 监听进出
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _handleMouseWheel(event);
        }
      },
      child: MouseRegion(
        // 关键：监听进入和离开
        onEnter: (_) => _onGlobalPointerEnter(),
        onExit: (_) => _onGlobalPointerExit(),
        // 双重保险：只要鼠标在区域内移动，就强制确认为 Hovering 状态
        // 解决有时快速移动导致 onExit 触发后 _isMouseHovering 没变回来的问题
        onHover: (_) => _onGlobalPointerEnter(),

        // 确保 MouseRegion 不会遮挡点击，同时允许事件穿透到空白处
        opaque: false,

        child: GestureDetector(
          behavior: HitTestBehavior.translucent, // 确保空白区域也能响应拖拽
          onVerticalDragStart: (_) {
            _momentumController.stop();
            _resumeAutoScrollTimer?.cancel();
            _wheelDebounceTimer?.cancel();
            widget.onVerticalDragStart?.call();
            setState(() => _isDragging = true);
          },
          onVerticalDragUpdate: (details) {
            widget.onVerticalDragUpdate?.call(details.delta.dy);
            _handleDragUpdate(details.delta.dy);
          },
          onVerticalDragEnd: (details) {
            widget.onVerticalDragEnd?.call();
            _handleDragEnd(details.velocity.pixelsPerSecond.dy);
          },
          onVerticalDragCancel: () {
            widget.onVerticalDragEnd?.call();
          },
          onTap: () {
            if (_isMomentumScrolling) {
              _momentumController.stop();
              _wheelDebounceTimer?.cancel();
              setState(() => _isMomentumScrolling = false);
              _scheduleResumeAutoScroll();
            }
          },
          child: Container(
            color: Colors.transparent, // 必须透明色，确保 HitTestBehavior 生效
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                ScrollConfiguration(
                  behavior:
                      ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: topPadding),
                        ..._lyricLines.asMap().entries.map((entry) {
                          final index = entry.key;
                          final line = entry.value;
                          final isCurrent = index == _currentLineIndex;
                          final isPastLine = index < _currentLineIndex;
                          final shouldTrackPlayback =
                              isCurrent || index == _currentLineIndex - 1;

                          return MeasureSize(
                            key: ValueKey('lyric_$index'),
                            onChange: (size) {
                              if (_lineHeights[index] != size.height) {
                                _lineHeights[index] = size.height;
                                if (isCurrent && !interacting) {
                                  Future.microtask(_recalculateAutoScrollTarget);
                                }
                              }
                            },
                            child: IndependentLyricLine(
                              index: index,
                              currentIndex: _currentLineIndex,
                              targetScrollY: activeScrollY,
                              isUserDragging: isUserMoving,
                              isInteracting: interacting,
                              onTap: () {
                                widget.onTapLine(line.startTime);
                                setState(() {
                                  _currentLineIndex = index;
                                  _forceResetState();
                                  _recalculateAutoScrollTarget();
                                });
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (shouldTrackPlayback)
                                    ValueListenableBuilder<Duration>(
                                      valueListenable: _displayPosition,
                                      builder: (context, position, child) {
                                        final isCompletedPastLine =
                                            isPastLine &&
                                            position >= line.endTime;
                                        return RepaintBoundary(
                                          child: _buildKaraokeText(
                                            line,
                                            position,
                                            isCurrent,
                                            isPastLine: isCompletedPastLine,
                                            showPlaybackProgress: true,
                                          ),
                                        );
                                      },
                                    )
                                  else
                                    RepaintBoundary(
                                      child: _buildKaraokeText(
                                        line,
                                        _displayPosition.value,
                                        false,
                                        isPastLine: isPastLine,
                                        showPlaybackProgress: false,
                                      ),
                                    ),
                                  if (line.translations != null &&
                                      line.translations!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: AnimatedOpacity(
                                        duration:
                                            const Duration(milliseconds: 500),
                                        opacity: isCurrent ? 0.8 : 0.4,
                                        child: Text(
                                          line.translations!.values.first,
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            fontSize: 20,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                        SizedBox(
                          height: bottomSpacerHeight,
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKaraokeText(
    LyricLine line,
    Duration position,
    bool isCurrent, {
    required bool isPastLine,
    required bool showPlaybackProgress,
  }) {
    final textStyle = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final layout = _getLyricLineLayout(
          line: line,
          textStyle: textStyle,
          textDirection: textDirection,
          maxWidth: maxWidth,
        );

        return SizedBox(
          width: double.infinity,
          height: layout.height,
          child: CustomPaint(
            painter: _KaraokeLinePainter(
              layout: layout,
              line: line,
              position: position,
              isCurrent: isCurrent,
              isPastLine: isPastLine,
              showPlaybackProgress: showPlaybackProgress,
            ),
            isComplex: isCurrent,
            willChange: isCurrent,
          ),
        );
      },
    );
  }

  _LyricLineLayout _getLyricLineLayout({
    required LyricLine line,
    required TextStyle textStyle,
    required TextDirection textDirection,
    required double maxWidth,
  }) {
    final cacheKey = _LyricLayoutCacheKey(
      line: line,
      widthKey: maxWidth.round(),
      textDirection: textDirection,
    );

    return _lyricLayoutCache.putIfAbsent(cacheKey, () {
      final inactiveStyle = textStyle.copyWith(color: Colors.white54);
      final activeStyle = textStyle.copyWith(color: Colors.white);
      final completedStyle = textStyle.copyWith(
        color: Colors.white,
      );

      final tokens = <_LyricTokenLayout>[];
      double x = 0.0;
      double y = 0.0;
      double lineHeight = 0.0;

      for (final span in line.spans) {
        final inactivePainter = TextPainter(
          text: TextSpan(text: span.text, style: inactiveStyle),
          textDirection: textDirection,
        )..layout();
        final activePainter = TextPainter(
          text: TextSpan(text: span.text, style: activeStyle),
          textDirection: textDirection,
        )..layout();
        final completedPainter = TextPainter(
          text: TextSpan(text: span.text, style: completedStyle),
          textDirection: textDirection,
        )..layout();

        final tokenWidth = inactivePainter.width;
        final tokenHeight = inactivePainter.height;

        if (x > 0 && x + tokenWidth > maxWidth) {
          y += lineHeight;
          x = 0.0;
          lineHeight = 0.0;
        }

        tokens.add(
          _LyricTokenLayout(
            span: span,
            offset: Offset(x, y),
            width: tokenWidth,
            height: tokenHeight,
            inactivePainter: inactivePainter,
            activePainter: activePainter,
            completedPainter: completedPainter,
          ),
        );

        x += tokenWidth;
        if (tokenHeight > lineHeight) {
          lineHeight = tokenHeight;
        }
      }

      final totalHeight = tokens.isEmpty ? 0.0 : y + lineHeight;
      return _LyricLineLayout(
        tokens: tokens,
        height: totalHeight,
      );
    });
  }
}

class _LyricLayoutCacheKey {
  final LyricLine line;
  final int widthKey;
  final TextDirection textDirection;

  const _LyricLayoutCacheKey({
    required this.line,
    required this.widthKey,
    required this.textDirection,
  });

  @override
  bool operator ==(Object other) {
    return other is _LyricLayoutCacheKey &&
        identical(other.line, line) &&
        other.widthKey == widthKey &&
        other.textDirection == textDirection;
  }

  @override
  int get hashCode => Object.hash(identityHashCode(line), widthKey, textDirection);
}

class _LyricLineLayout {
  final List<_LyricTokenLayout> tokens;
  final double height;

  const _LyricLineLayout({
    required this.tokens,
    required this.height,
  });
}

class _LyricTokenLayout {
  final LyricSpan span;
  final Offset offset;
  final double width;
  final double height;
  final TextPainter inactivePainter;
  final TextPainter activePainter;
  final TextPainter completedPainter;

  const _LyricTokenLayout({
    required this.span,
    required this.offset,
    required this.width,
    required this.height,
    required this.inactivePainter,
    required this.activePainter,
    required this.completedPainter,
  });
}

class _KaraokeLinePainter extends CustomPainter {
  static const double _colorSoftEdgeWidth = 14.0;

  final _LyricLineLayout layout;
  final LyricLine line;
  final Duration position;
  final bool isCurrent;
  final bool isPastLine;
  final bool showPlaybackProgress;

  const _KaraokeLinePainter({
    required this.layout,
    required this.line,
    required this.position,
    required this.isCurrent,
    required this.isPastLine,
    required this.showPlaybackProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isLineCompleted = position > line.endTime;
    final currentTokenIndex =
        layout.tokens.lastIndexWhere((token) => position >= token.span.start);

    double currentColorProgress = 0.0;
    if (currentTokenIndex != -1) {
      currentColorProgress = _progressFor(
        position: position,
        start: layout.tokens[currentTokenIndex].span.start,
        end: layout.tokens[currentTokenIndex].span.end,
      );
    }

    for (int i = 0; i < layout.tokens.length; i++) {
      final token = layout.tokens[i];
      final offset = token.offset;

      if (isLineCompleted || isPastLine) {
        token.completedPainter.paint(canvas, offset);
        continue;
      }

      if (!showPlaybackProgress || position < line.startTime) {
        token.inactivePainter.paint(canvas, offset);
        continue;
      }

      if (currentTokenIndex == -1 || i > currentTokenIndex) {
        token.inactivePainter.paint(canvas, offset);
        continue;
      }

      if (i < currentTokenIndex) {
        token.activePainter.paint(canvas, offset);
        continue;
      }

      _paintActiveToken(
        canvas: canvas,
        token: token,
        offset: offset,
        colorProgress: currentColorProgress,
      );
    }
  }

  void _paintActiveToken({
    required Canvas canvas,
    required _LyricTokenLayout token,
    required Offset offset,
    required double colorProgress,
  }) {
    if (colorProgress <= 0) {
      token.inactivePainter.paint(canvas, offset);
      return;
    }

    if (colorProgress >= 1) {
      token.activePainter.paint(canvas, offset);
      return;
    }

    final filledWidth = token.width * colorProgress;
    final softEdgeWidth =
        _colorSoftEdgeWidth.clamp(0.0, token.width).toDouble();
    final solidWidth =
        (filledWidth - softEdgeWidth).clamp(0.0, token.width).toDouble();
    final fadeWidth = (filledWidth - solidWidth).clamp(0.0, token.width).toDouble();

    token.inactivePainter.paint(canvas, offset);

    if (solidWidth > 0) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          offset.dx,
          offset.dy,
          solidWidth,
          token.height,
        ),
      );
      token.activePainter.paint(canvas, offset);
      canvas.restore();
    }

    if (fadeWidth <= 0) {
      return;
    }

    final fadeRect = Rect.fromLTWH(
      offset.dx + solidWidth,
      offset.dy,
      fadeWidth,
      token.height,
    );

    canvas.saveLayer(fadeRect, Paint());
    canvas.save();
    canvas.clipRect(fadeRect);
    token.activePainter.paint(canvas, offset);
    canvas.restore();
    canvas.drawRect(
      fadeRect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white,
            Colors.transparent,
          ],
        ).createShader(fadeRect),
    );
    canvas.restore();
  }

  double _progressFor({
    required Duration position,
    required Duration start,
    required Duration end,
  }) {
    final durationMs = (end - start).inMilliseconds;
    if (durationMs <= 0) {
      return position >= end ? 1.0 : 0.0;
    }

    return ((position.inMilliseconds - start.inMilliseconds) / durationMs)
        .clamp(0.0, 1.0);
  }

  @override
  bool shouldRepaint(covariant _KaraokeLinePainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.line != line ||
        oldDelegate.position != position ||
        oldDelegate.isCurrent != isCurrent ||
        oldDelegate.isPastLine != isPastLine ||
        oldDelegate.showPlaybackProgress != showPlaybackProgress;
  }
}

class IndependentLyricLine extends StatefulWidget {
  final int index;
  final int currentIndex;
  final double targetScrollY;
  final bool isUserDragging;
  final bool isInteracting;
  final Widget child;
  final VoidCallback onTap;

  const IndependentLyricLine({
    Key? key,
    required this.index,
    required this.currentIndex,
    required this.targetScrollY,
    required this.isUserDragging,
    required this.isInteracting,
    required this.child,
    required this.onTap,
  }) : super(key: key);

  @override
  State<IndependentLyricLine> createState() => _IndependentLyricLineState();
}

class _IndependentLyricLineState extends State<IndependentLyricLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _yAnimation;
  double _currentTranslateY = 0.0;
  bool _isHovered = false;
  Timer? _delayedStartTimer;
  int _animationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(() {
        setState(() {
          _currentTranslateY = _yAnimation.value;
        });
      });

    _currentTranslateY = widget.targetScrollY;
    _yAnimation = AlwaysStoppedAnimation(widget.targetScrollY);
  }

  @override
  void didUpdateWidget(IndependentLyricLine oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isUserDragging) {
      _cancelPendingAnimation();
      if (_animController.isAnimating) _animController.stop();
      if (_currentTranslateY != widget.targetScrollY) {
        setState(() {
          _currentTranslateY = widget.targetScrollY;
        });
      }
      _yAnimation = AlwaysStoppedAnimation(widget.targetScrollY);
      return;
    }

    if (widget.targetScrollY != oldWidget.targetScrollY) {
      _startSpringAnimation(from: _currentTranslateY, to: widget.targetScrollY);
    }
  }

  void _startSpringAnimation({required double from, required double to}) {
    _cancelPendingAnimation();

    if ((from - to).abs() < 0.1) {
      _currentTranslateY = to;
      _yAnimation = AlwaysStoppedAnimation(to);
      return;
    }

    _animationGeneration += 1;
    final generation = _animationGeneration;
    int distance = (widget.index - widget.currentIndex) + 1;
    Duration animDuration = const Duration(milliseconds: 600);
    _animController.duration = animDuration;

    bool isScrollingBackwards = to < from;

    int delayMs = 0;
    int step = isScrollingBackwards ? 20 : 50;
    if (distance >= 0 && distance <= 12) {
      delayMs = (distance * step).clamp(0, 1600);
    }

    _yAnimation = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutQuart,
      ),
    );

    _animController.reset();
    _delayedStartTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted ||
          widget.isUserDragging ||
          generation != _animationGeneration) {
        return;
      }
      _animController.forward();
    });
  }

  void _cancelPendingAnimation() {
    _delayedStartTimer?.cancel();
    _delayedStartTimer = null;
  }

  @override
  void dispose() {
    _cancelPendingAnimation();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrent = widget.index == widget.currentIndex;
    final int dist = (widget.index - widget.currentIndex).abs();

    double targetOpacity;
    double targetBlur;

    if (widget.isInteracting || _isHovered) {
      targetOpacity = 1.0;
      targetBlur = 0.0;
    } else {
      if (isCurrent) {
        targetOpacity = 1.0;
        targetBlur = 0.0;
      } else {
        targetOpacity = (1.0 - (dist * 0.15)).clamp(0.2, 0.6);
        targetBlur = (dist * 0.8).clamp(0.0, 4.0);
      }
    }

    return Transform.translate(
      offset: Offset(0, -_currentTranslateY),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: targetOpacity,
              child: ImageFiltered(
                imageFilter:
                    ImageFilter.blur(sigmaX: targetBlur, sigmaY: targetBlur),
                child: widget.child,
              ),
            ),
          ),
        ),
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
  Size? _oldSize;
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = context.size;
      if (size != null &&
          (_oldSize == null || (_oldSize!.height - size.height).abs() > 0.5)) {
        _oldSize = size;
        widget.onChange(size);
      }
    });
    return widget.child;
  }
}
