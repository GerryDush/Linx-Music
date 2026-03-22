import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lzf_music/utils/platform_utils.dart';
import '../services/player_provider.dart';
import '../widgets/slider_custom.dart';
import '../contants/app_contants.dart' show PlayMode;
import 'package:cupertino_icons/cupertino_icons.dart';

class SongInfoPanel extends StatelessWidget {
  final double tempSliderValue;
  final Function(double) onSliderChanged;
  final Function(double) onSliderChangeEnd;
  final PlayerProvider playerProvider;
  final bool compactLayout;
  final double animationProgress; // 0.0 = 完整显示, 1.0 = 紧凑模式

  const SongInfoPanel({
    super.key,
    required this.tempSliderValue,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    required this.playerProvider,
    this.compactLayout = false,
    this.animationProgress = 0.0,
  });

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // 只做透明度变化，高度保持固定，避免上下浮动
    final titleOpacity = (1.0 - animationProgress).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRect(
          child: SizedBox(
            height: 80,
            child: Opacity(
              opacity: titleOpacity,
              child: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playerProvider.currentSong?.title ?? "未知歌曲",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      playerProvider.currentSong?.artist ?? "未知歌手",
                      style: const TextStyle(color: Colors.white70, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder<Duration>(
            valueListenable: playerProvider.position,
            builder: (context, position, child) {
              return AnimatedTrackHeightSlider(
                value: tempSliderValue >= 0
                    ? tempSliderValue
                    : position.inSeconds.toDouble(),
                max: playerProvider.duration.inSeconds.toDouble(),
                min: 0,
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
                onChanged: onSliderChanged,
                onChangeEnd: onSliderChangeEnd,
              );
            }),
        SizedBox(height: 4), // 增加底部间距
        Row(
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: playerProvider.position,
              builder: (context, position, child) {
                return SizedBox(
                  width: 60,
                  child: Text(
                    formatDuration(position),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                );
              },
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      "${playerProvider.currentSong?.bitrate != null ? (playerProvider.currentSong!.bitrate! / 1000).toStringAsFixed(0) : '未知'} kbps",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatDuration(playerProvider.duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            )
          ],
        ),
      ],
    );
  }
}

class MusicControlButtons extends StatelessWidget {
  final PlayerProvider playerProvider;
  final bool isPlaying;
  final bool compactLayout;

  const MusicControlButtons({
    super.key,
    required this.playerProvider,
    required this.isPlaying,
    this.compactLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showPlayModeButtons = constraints.maxWidth >= 320;
        final isMobile = PlatformUtils.isMobileWidth(context);
        return Column(
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                if (showPlayModeButtons)
                  IconButton(
                    iconSize: 18,
                    padding: compactLayout ? const EdgeInsets.all(4) : null,
                    constraints: compactLayout ? const BoxConstraints() : null,
                    color: Colors.white70,
                    icon: Icon(
                      CupertinoIcons.shuffle,
                      color: playerProvider.playMode == PlayMode.shuffle
                          ? Colors.white
                          : null,
                    ),
                    onPressed: () {
                      if (playerProvider.playMode == PlayMode.shuffle) {
                        playerProvider.setPlayMode(PlayMode.sequence);
                        return;
                      }
                      playerProvider.setPlayMode(PlayMode.shuffle);
                    },
                  ),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        padding: compactLayout ? const EdgeInsets.all(4) : null,
                        constraints: compactLayout ? const BoxConstraints() : null,
                        color: (playerProvider.hasPrevious ||
                                playerProvider.playMode == PlayMode.loop)
                            ? Colors.white
                            : Colors.white70,
                        icon: const Icon(CupertinoIcons.backward_fill),
                        onPressed: () => playerProvider.previous(),
                      ),
                      SizedBox(width: compactLayout ? 8 : 16),
                      IconButton(
                        iconSize: 52,
                        padding: compactLayout ? const EdgeInsets.all(4) : null,
                        constraints: compactLayout ? const BoxConstraints() : null,
                        color: Colors.white,
                        icon: Icon(
                          isPlaying
                              ? CupertinoIcons.pause_fill
                              : CupertinoIcons.play_fill,
                        ),
                        onPressed: () => playerProvider.togglePlay(),
                      ),
                      SizedBox(width: compactLayout ? 8 : 16),
                      IconButton(
                        iconSize: 36,
                        padding: compactLayout ? const EdgeInsets.all(4) : null,
                        constraints: compactLayout ? const BoxConstraints() : null,
                        color: (playerProvider.hasNext ||
                                playerProvider.playMode == PlayMode.loop)
                            ? Colors.white
                            : Colors.white70,
                        icon: const Icon(CupertinoIcons.forward_fill),
                        onPressed: () => playerProvider.next(),
                      ),
                    ],
                  ),
                ),
                if (showPlayModeButtons)
                  IconButton(
                    iconSize: 18,
                    padding: compactLayout ? const EdgeInsets.all(4) : null,
                    constraints: compactLayout ? const BoxConstraints() : null,
                    color: Colors.white70,
                    icon: Icon(
                      playerProvider.playMode == PlayMode.singleLoop
                          ? CupertinoIcons.repeat_1
                          : CupertinoIcons.repeat,
                      color: playerProvider.playMode == PlayMode.loop ||
                              playerProvider.playMode == PlayMode.singleLoop
                          ? Colors.white
                          : null,
                    ),
                    onPressed: () {
                      if (playerProvider.playMode == PlayMode.singleLoop) {
                        playerProvider.setPlayMode(PlayMode.sequence);
                        return;
                      }
                      playerProvider.setPlayMode(
                        playerProvider.playMode == PlayMode.loop
                            ? PlayMode.singleLoop
                            : PlayMode.loop,
                      );
                    },
                  ),
              ],
            ),
            if (compactLayout) ...[
              const SizedBox(height: 20),
            ] else ...[
              const SizedBox(height: 10),
            ],
            Row(
          children: [
            IconButton(
              iconSize: 20,
              padding: compactLayout ? const EdgeInsets.all(4) : null,
              constraints: compactLayout ? const BoxConstraints() : null,
              icon: const Icon(
                CupertinoIcons.volume_down,
                color: Colors.white70,
              ),
              onPressed: () {
                playerProvider.setVolume(playerProvider.volume - 0.1);
              },
            ),
            Expanded(
              child: AnimatedTrackHeightSlider(
                trackHeight: 4,
                value: playerProvider.volume,
                max: 1.0,
                min: 0,
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
                onChanged: (value) {
                  playerProvider.setVolume(value);
                },
              ),
            ),
            IconButton(
              iconSize: 20,
              padding: compactLayout ? const EdgeInsets.all(4) : null,
              constraints: compactLayout ? const BoxConstraints() : null,
              icon: const Icon(CupertinoIcons.volume_up, color: Colors.white70),
              onPressed: () {
                playerProvider.setVolume(playerProvider.volume + 0.1);
              },
              ),
            ],
          ),
          if (compactLayout) ...[
              const SizedBox(height: 20),
            ] 
        ],
      );
    },
    );
  }
}

class HoverIconButton extends StatefulWidget {
  final VoidCallback onPressed;

  const HoverIconButton({super.key, required this.onPressed});

  @override
  State<HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<HoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onPressed,
      borderRadius: BorderRadius.circular(4), // 圆角大小
      onHover: (v) {
        setState(() {
          _isHovered = !_isHovered;
        });
      },
      child: Icon(
        _isHovered ? Icons.keyboard_arrow_down_rounded : Icons.remove_rounded,
        color: Colors.white,
        size: 50,
      ),
    );
  }
}
