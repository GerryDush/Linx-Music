import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  var authorizedURLs = [String: URL]()
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let toolbar = NSToolbar(identifier: "MainToolbar")
    toolbar.showsBaselineSeparator = false
    self.toolbar = toolbar

    let bookmarkChannel = FlutterMethodChannel(name: "com.lzf_music/secure_bookmarks",
                                                   binaryMessenger: flutterViewController.engine.binaryMessenger)
        
        bookmarkChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleBookmarkCall(call: call, result: result)
        }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleEnterFullScreen),
        name: NSWindow.willEnterFullScreenNotification,
        object: self
    )
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleExitFullScreen),
        name: NSWindow.willExitFullScreenNotification,
        object: self
    )
  }
  @objc func handleEnterFullScreen() {
        self.toolbar = nil
 }

    @objc func handleExitFullScreen() {
    DispatchQueue.main.async {
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.showsBaselineSeparator = false
        self.toolbar = toolbar
    }
}

  
    private func handleBookmarkCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        
        if call.method == "createBookmark" {
            guard let path = args?["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Path is required", details: nil))
                return
            }
            createBookmark(path: path, result: result)
            
        } else if call.method == "startAccessing" {
            guard let bookmarkStr = args?["bookmark"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Bookmark is required", details: nil))
                return
            }
            startAccessing(bookmarkBase64: bookmarkStr, result: result)
            
        } else if call.method == "stopAccessing" {
            guard let bookmarkStr = args?["bookmark"] as? String else {
                result(nil)
                return
            }
            stopAccessing(bookmarkBase64: bookmarkStr)
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    // --- 核心逻辑 ---

    private func createBookmark(path: String, result: FlutterResult) {
        let url = URL(fileURLWithPath: path)
        
        // macOS 需要 .withSecurityScope 选项
        // 注意：在创建书签时，如果是从 FilePicker 刚拿到的，通常不需要 startAccessing，
        // 但为了保险起见，或者如果是二次授权，我们可以尝试 startAccessing。
        // 对于只读访问，使用 .securityScopeAllowOnlyReadAccess
        
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            let base64 = data.base64EncodedString()
            result(base64)
        } catch {
            result(FlutterError(code: "CREATE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func startAccessing(bookmarkBase64: String, result: FlutterResult) {
        guard let data = Data(base64Encoded: bookmarkBase64) else {
            result(FlutterError(code: "DECODE_ERROR", message: "Invalid Base64", details: nil))
            return
        }
        
        var isStale = false
        do {
            // 解析书签
            let url = try URL(resolvingBookmarkData: data,
                              options: .withSecurityScope, // 必须指定
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("Warning: Bookmark is stale")
                // 实际应用中可能需要重新创建书签，但通常还能用
            }
            
            if url.startAccessingSecurityScopedResource() {
                authorizedURLs[bookmarkBase64] = url
                result(url.path)
            } else {
                result(FlutterError(code: "ACCESS_DENIED", message: "Failed to access resource", details: nil))
            }
        } catch {
            result(FlutterError(code: "RESOLVE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func stopAccessing(bookmarkBase64: String) {
        if let url = authorizedURLs[bookmarkBase64] {
            url.stopAccessingSecurityScopedResource()
            authorizedURLs.removeValue(forKey: bookmarkBase64)
        }
    }
}
