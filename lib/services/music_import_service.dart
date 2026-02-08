import 'dart:io';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:lzf_music/services/file_access_manager.dart';
import 'package:lzf_music/utils/common_utils.dart';
import 'package:lzf_music/utils/platform_utils.dart';
import '../database/database.dart';
import 'package:path/path.dart' as p;
import 'dart:async';
import '../widgets/lyric/lyrics_parser.dart';
import '../utils/cover_utils.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:lzf_music/services/http_service.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_stream/saf_stream.dart';

class CoverImage {
  final Uint8List bytes;
  final String type;

  CoverImage._(this.bytes, this.type);

  String get mime {
    switch (type.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpeg':
      case 'jpg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  static String? extensionFromDecoder(img.Decoder decoder) {
    if (decoder is img.PngDecoder) return 'png';
    if (decoder is img.JpegDecoder) return 'jpg';
    if (decoder is img.GifDecoder) return 'gif';
    if (decoder is img.WebPDecoder) return 'webp';
    if (decoder is img.BmpDecoder) return 'bmp';
    if (decoder is img.TiffDecoder) return 'tiff';
    if (decoder is img.IcoDecoder) return 'ico';
    if (decoder is img.TgaDecoder) return 'tga';
    return null;
  }

  static CoverImage? fromBytes(Uint8List data) {
    final decoder = img.findDecoderForData(data);
    if (decoder == null) return null;

    final ext = extensionFromDecoder(decoder);
    if (ext == null) return null;

    return CoverImage._(data, ext);
  }
}

abstract class ImportEvent {
  const ImportEvent();
}

class SelectedEvent extends ImportEvent {
  const SelectedEvent();
}

class ScaningEvent extends ImportEvent {
  final int count;
  const ScaningEvent(this.count);
}

class ScanCompletedEvent extends ImportEvent {
  final int count;
  final List<String> musicFiles;
  ScanCompletedEvent(this.count, [this.musicFiles = const []]);
}

class ProgressingEvent extends ImportEvent {
  final String currentFile;
  final int processed;
  final int total;

  const ProgressingEvent(this.currentFile, this.processed, this.total);

  double get progress => total > 0 ? processed / total : 0.0;
}

class CompletedEvent extends ImportEvent {
  const CompletedEvent();
}

class FailedEvent extends ImportEvent {
  final String error;
  final String? filePath;

  const FailedEvent(this.error, {this.filePath});
}

class CancelledEvent extends ImportEvent {
  const CancelledEvent();
}

class MusicImportService {
  final List<String> supportedExtensions = ['mp3', 'm4a', 'wav', 'flac'];

  MusicImportService();

  bool _isCancelled = false;

  /// 从文件夹导入音乐
  Stream<ImportEvent> importFromDirectory() async* {
    _isCancelled = false;

    try {
      String? dir = null;
      if (PlatformUtils.isIOS) {
        IOSNativePickedFile? pickedDir =
            await FileAccessManager.pickFolderNative();
        if (pickedDir == null) return;
        dir = pickedDir.path;
      } else {
        dir =
            await FilePicker.platform.getDirectoryPath(lockParentWindow: true);
      }
      if (dir == null) return;

      yield const SelectedEvent();

      if (_isCancelled) {
        yield const CancelledEvent();
        return;
      }

      List<String> filePaths = [];

      // 监听扫描事件并转发
      final scanStream = _listMusicFiles(Directory(dir));
      await for (final event in scanStream) {
        if (event is ScaningEvent) {
          yield event; // 转发扫描事件
        } else if (event is ScanCompletedEvent) {
          filePaths = event.musicFiles;
          yield event;
          break;
        } else if (event is FailedEvent) {
          yield event;
          return;
        }
      }

      if (filePaths.isEmpty) {
        yield const FailedEvent('未找到支持的音乐文件');
        yield const CompletedEvent();
        return;
      }

      yield* _processFiles(filePaths);
    } catch (e) {
      yield FailedEvent('选择文件夹时发生错误: ${e.toString()}');
      yield const CompletedEvent();
    }
  }

  Stream<ImportEvent> importFiles() async* {
    _isCancelled = false;

    List<String> filePaths = [];
    try {
      // ================= iOS 原生流程 =================
      if (PlatformUtils.isIOS) {
        List<IOSNativePickedFile> nativeFiles =
            await FileAccessManager.pickMusicNative(
                extensions: supportedExtensions);
        if (nativeFiles.isEmpty) return;
        filePaths = nativeFiles
            .where((file) => !file.isDirectory)
            .map((file) => file.path!)
            .toList();
      } else if (PlatformUtils.isAndroid) {
        // ================= Android SAF 流程 =================
        final safFiles = await SafUtil().pickFiles();
        if (safFiles == null || safFiles.isEmpty) return;
        filePaths = safFiles.map((file) => file.uri).toList();
      } else {
        final files = await FilePicker.platform.pickFiles(
          allowedExtensions: supportedExtensions,
          type: FileType.custom,
          allowMultiple: true,
          lockParentWindow: true,
          withData: false,
          withReadStream: false,
        );
        if (files == null || files.files.isEmpty) return;
        filePaths = files.files
            .where((file) => file.path != null)
            .map((file) => file.path!)
            .toList();
      }

      yield const SelectedEvent();

      if (_isCancelled) {
        yield const CancelledEvent();
        return;
      }

      yield ScanCompletedEvent(filePaths.length);

      if (filePaths.isEmpty) {
        yield const FailedEvent('未选择有效的音乐文件');
        yield const CompletedEvent();
        return;
      }

      // 通用处理流程
      yield* _processFiles(filePaths);
    } catch (e) {
      yield FailedEvent('选择文件时发生错误: ${e.toString()}');
      yield const CompletedEvent();
    }
  }

  static Future<bool> importLyrics(int songId) async {
    Song song = await MusicDatabase.database.getSongById(songId) as Song;
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['lrc', 'ttml'],
      type: FileType.custom,
      allowMultiple: false,
      lockParentWindow: false,
    );

    try {
      if (result != null) {
        for (final file in result.files) {
          final lyrics = File(file.path!).readAsStringSync();
          MusicDatabase.database.updateSong(
            song.copyWith(lyrics: Value(lyrics)),
          );
          updateMetadata(File(song.filePath), (metadata) {
            metadata.setLyrics(lyrics);
          });
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<String?> importAlbumArt(int songId) async {
    Song song = await MusicDatabase.database.getSongById(songId) as Song;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        type: FileType.custom,
        allowMultiple: false,
        lockParentWindow: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      if (file.path == null) return null;

      CoverImage? cover = CoverImage.fromBytes(
        await File(file.path!).readAsBytes(),
      );
      if (cover == null) {
        return null;
      }

      final basePath = await CommonUtils.getAppBaseDirectory();
      final albumArtDir = Directory(p.join(basePath, '.album_art'));
      await albumArtDir.create(recursive: true);

      // 删除旧封面
      if (song.albumArtPath != null && song.albumArtPath != null) {
        final oldFile = File(song.albumArtPath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      // 使用 MD5 命名新封面
      final md5Hash = md5.convert(cover.bytes).toString();
      final ext = p.extension(file.path!).replaceFirst('.', '');
      final albumArtFile = File(p.join(albumArtDir.path, '$md5Hash.$ext'));

      await albumArtFile.writeAsBytes(cover.bytes, flush: true);

      // 更新数据库
      MusicDatabase.database.updateSong(
        song.copyWith(albumArtPath: Value(albumArtFile.path)),
      );
      updateMetadata(File(song.filePath), (metadata) {
        metadata.setPictures([
          Picture(cover.bytes, cover.mime, PictureType.coverFront),
        ]);
      });

      return albumArtFile.path;
    } catch (e) {
      print('Failed to import album art: $e');
      return null;
    }
  }

  Stream<ImportEvent> _listMusicFiles(Directory dir) async* {
    final List<String> filePaths = [];

    try {
      await for (final entity in dir.list(recursive: true)) {
        if (_isCancelled) {
          yield const CancelledEvent();
          return;
        }

        if (entity is File) {
          final extension = p.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(extension.replaceFirst('.', ''))) {
            filePaths.add(entity.path);
          }
          yield ScaningEvent(filePaths.length);
        }
      }

      yield ScanCompletedEvent(filePaths.length, filePaths);
    } catch (e) {
      yield FailedEvent('扫描目录失败: ${e.toString()}');
    }
  }

  /// 处理文件列表的Stream
  Stream<ImportEvent> _processFiles(List<String> filePaths) async* {
    int processed = 0;

    for (final filePath in filePaths) {
      if (_isCancelled) {
        yield const CancelledEvent();
        return;
      }
      final fileName;
      if (Platform.isAndroid) {
        fileName = p.basename(Uri.decodeFull(filePath));
      } else {
        fileName = p.basename(filePath);
      }
      yield ProgressingEvent(fileName, processed, filePaths.length);

      try {
        await _processMusicFile(filePath);
        processed++;
        yield ProgressingEvent(fileName, processed, filePaths.length);
      } catch (e) {
        yield FailedEvent(e.toString(), filePath: filePath);
        continue;
      }
    }

    yield const CompletedEvent();
  }

  /// 取消导入
  void cancel() {
    _isCancelled = true;
  }

  Uint8List createThumbnail(Uint8List originalBytes,
      {int width = 200, int height = 200}) {
    final image = img.decodeImage(originalBytes);
    if (image == null) throw Exception('无法解码图片');

    final thumbnail = img.copyResize(image, width: width, height: height);

    final thumbnailBytes = img.encodeJpg(thumbnail);
    return Uint8List.fromList(thumbnailBytes);
  }

  CoverProcessOutput processCoverInIsolate(CoverProcessInput input) {
    // 判断图片格式
    final decoder = img.findDecoderForData(input.bytes);
    if (decoder == null) {
      throw Exception('Unsupported image format');
    }
    late final String ext;
    if (decoder is img.PngDecoder) ext = 'png';
    if (decoder is img.JpegDecoder) ext = 'jpg';
    if (decoder is img.GifDecoder) ext = 'gif';
    if (decoder is img.WebPDecoder) ext = 'webp';
    if (decoder is img.BmpDecoder) ext = 'bmp';
    if (decoder is img.TiffDecoder) ext = 'tiff';
    if (decoder is img.IcoDecoder) ext = 'ico';
    if (decoder is img.TgaDecoder) ext = 'tga';

    // 生成缩略图（CPU 密集）
    final thumbBytes = createThumbnail(input.bytes);

    // MD5（CPU）
    final hash = md5.convert(input.bytes).toString();

    return CoverProcessOutput(
      coverBytes: input.bytes,
      thumbBytes: thumbBytes,
      ext: ext,
      md5: hash,
      palette: null,
    );
  }

  Future<CoverProcessOutput?> _processCover(Uint8List bytes) async {
    try {
      return await compute(
        processCoverInIsolate,
        CoverProcessInput(bytes),
      );
    } catch (e) {
      debugPrint('Cover process failed: $e');
      return null;
    }
  }

  Future<void> _processMusicFile(String filePath) async {
    String originalFilePath = filePath;
    if (PlatformUtils.isMacOS || PlatformUtils.isIOS) {
      filePath = (await FileAccessManager.createBookmark(filePath))!;
      originalFilePath = (await FileAccessManager.startAccessing(filePath))!;
    }
    AudioMetadata metadata;
    if (Platform.isAndroid) {
      Stream<Uint8List> fileBytes =
          await SafStream().readFileStream(originalFilePath);
      metadata = await readMetadataUint8List(fileBytes, getImage: true);
    } else {
      metadata = await readMetadataFile(File(originalFilePath), getImage: true);
    }
    if (PlatformUtils.isMacOS || PlatformUtils.isIOS) {
      await FileAccessManager.stopAccessing(filePath);
    }
    final String title = metadata.title ?? p.basename(filePath);
    final String? artist = metadata.artist;
    final existingSongs = await (MusicDatabase.database.songs.select()
          ..where(
            (tbl) =>
                tbl.title.equals(title) &
                (artist != null
                    ? tbl.artist.equals(artist)
                    : tbl.artist.isNull()),
          ))
        .get();

    if (existingSongs.isNotEmpty) return;

    String? albumArtPath;
    String? albumArtThumbPath;
    List<Color>? palette;

    if (metadata.pictures.isNotEmpty) {
      final picture = metadata.pictures.first;

      final coverResult = await _processCover(picture.bytes);
      if (coverResult != null) {
        coverResult.palette =
            await PaletteUtils.fromBytes(coverResult.thumbBytes);
      }

      if (coverResult != null) {
        final basePath = await CommonUtils.getAppBaseDirectory();
        final fileName = '${coverResult.md5}.${coverResult.ext}';
        final coverFile = File(p.join(basePath, 'Cover', fileName));
        final thumbFile = File(p.join(basePath, 'Cover', 'thumb', fileName));

        await coverFile.parent.create(recursive: true);
        await thumbFile.parent.create(recursive: true);

        if (!await coverFile.exists()) {
          await coverFile.writeAsBytes(coverResult.coverBytes);
        }

        if (!await thumbFile.exists()) {
          await thumbFile.writeAsBytes(coverResult.thumbBytes);
        }

        albumArtPath = coverFile.path;
        albumArtThumbPath = thumbFile.path;
        palette = coverResult.palette;
      }
    }

    await MusicDatabase.database.insertSong(
      SongsCompanion.insert(
        title: title,
        artist: Value(artist),
        album: Value(metadata.album),
        filePath: filePath,
        lyrics: Value(metadata.lyrics),
        bitrate: Value(metadata.bitrate),
        sampleRate: Value(metadata.sampleRate),
        duration: Value(metadata.duration?.inSeconds),
        albumArtPath: Value(albumArtPath),
        albumArtThumbPath: Value(albumArtThumbPath),
        palette: Value(palette),
        dateAdded: Value(DateTime.now()),
        source: Value('local'),
        lyricsBlob: Value(
          metadata.lyrics != null
              ? await LyricsParser.parse(metadata.lyrics!)
              : null,
        ),
      ),
    );
  }
}

class CoverProcessInput {
  final Uint8List bytes;
  CoverProcessInput(this.bytes);
}

class CoverProcessOutput {
  final Uint8List coverBytes;
  final Uint8List thumbBytes;
  final String ext;
  final String md5;
  List<Color>? palette;

  CoverProcessOutput({
    required this.coverBytes,
    required this.thumbBytes,
    required this.ext,
    required this.md5,
    required this.palette,
  });
}
