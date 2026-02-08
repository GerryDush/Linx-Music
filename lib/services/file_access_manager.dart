import 'package:flutter/services.dart';
import 'package:lzf_music/utils/platform_utils.dart';
import 'package:lzf_music/services/http_service.dart';

/// 原生选择返回的对象
class IOSNativePickedFile {
  final String? path; // 真实路径（如果系统提供）
  final bool isDirectory;
  final String? name;

  IOSNativePickedFile({this.path,  this.isDirectory = false, this.name});

  factory IOSNativePickedFile.fromMap(Map<dynamic, dynamic> map) {
    return IOSNativePickedFile(
      path: map['path'] as String?,
      isDirectory: (map['isDirectory'] as bool?) ?? false,
      name: map['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'path': path,
        'isDirectory': isDirectory,
        'name': name,
      };
}

class FileAccessManager {
  static const MethodChannel _channel =
      MethodChannel('com.lzf_music/secure_bookmarks');
      

  /// 为文件路径创建持久化访问书签 (支持 iOS & macOS)
  /// [filePath] 原始文件路径
  /// 返回: Base64 编码的书签字符串
  static Future<String?> createBookmark(String filePath) async {
    if (!PlatformUtils.isMacOS && !PlatformUtils.isIOS) return null;

    try {
      final String? bookmark =
          await _channel.invokeMethod('createBookmark', {'path': filePath});
      return bookmark;
    } catch (e) {
      print('[FileAccessManager] 创建书签失败: $e');
      return null;
    }
  }

  /// 解析并开始访问 (支持 iOS & macOS)
  /// [bookmark] Base64 编码的书签
  /// 返回: 解析后的真实文件路径
  static Future<String?> startAccessing(String bookmark) async {
    if (!PlatformUtils.isMacOS && !PlatformUtils.isIOS) return null;

    try {
      final String? resolvedPath =
          await _channel.invokeMethod('startAccessing', {'bookmark': bookmark});
      return resolvedPath;
    } catch (e) {
      await HttpService.instance.postLog(body: 'originalFilePath: ${e.toString()}');
      print('[FileAccessManager] 解析书签失败: $e');
      return null;
    }
  }

  /// 停止访问 (释放资源)
  static Future<void> stopAccessing(String bookmark) async {
    if (!PlatformUtils.isMacOS && !PlatformUtils.isIOS) return;

    try {
      await _channel.invokeMethod('stopAccessing', {'bookmark': bookmark});
    } catch (e) {
      print('[FileAccessManager] 停止访问失败: $e');
    }
  }


  /// 仅 iOS: 调用原生文件选择器，返回原生提供的路径
  /// [extensions] 可选，按文件后缀过滤（例如 ['mp3','flac']）
  /// [allowFolders] 是否允许选择文件夹
  /// 仅 iOS: 调用原生文件选择器，返回 `IOSNativePickedFile` 对象列表
  /// [extensions] 可选，按文件后缀过滤（例如 ['mp3','flac']）
  /// [allowFolders] 是否允许选择文件夹
  static Future<List<IOSNativePickedFile>> pickMusicNative({
    List<String>? extensions,
    bool allowFolders = false,
  }) async {
    if (!PlatformUtils.isIOS) return [];

    try {
      final Map<String, dynamic> args = {
        'extensions': extensions ?? [],
        'allowFolders': allowFolders,
      };
      final List<dynamic>? result = await _channel.invokeMethod('pickFile', args);
      if (result == null) return [];
      return result.map((e) => IOSNativePickedFile.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      print('Native picker failed: $e');
      return [];
    }
  }

  /// 仅 iOS: 选择单个文件夹并返回该对象（若用户取消返回 null）
  static Future<IOSNativePickedFile?> pickFolderNative({
    List<String>? extensions,
  }) async {
    final results = await pickMusicNative(extensions: extensions, allowFolders: true);
    if (results.isEmpty) return null;
    // 只取第一个（原生会限制为单选）
    return results.first;
  }
}
