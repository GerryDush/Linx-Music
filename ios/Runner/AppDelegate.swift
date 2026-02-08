import Flutter
import UIKit
import UniformTypeIdentifiers // 必须引入，用于 UTType
import MobileCoreServices // 用于 iOS < 14 时的 UTI 映射

// 统一管理常量
struct Channels {
    static let secureBookmarks = "com.lzf_music/secure_bookmarks"
    static let nativeTabBar = "native_tab_bar"
    static let audioRoute = "com.lzf.music/audio_route"
}

struct Methods {
    // 新增 pickFile 方法
    static let pickFile = "pickFile"
    // 原有的方法
    static let createBookmark = "createBookmark" // 仅作兼容保留
    static let startAccessing = "startAccessing"
    static let stopAccessing = "stopAccessing"
    
    static let selectTab = "selectTab"
    static let setTabBarHidden = "setTabBarHidden"
    static let onTabSelected = "onTabSelected"
    static let onTabBarVisibilityChanged = "onTabBarVisibilityChanged"
}

@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentPickerDelegate { // 添加 Delegate 协议
    
    // UI 引用
    var tabBarVC: UITabBarController?
    private var tabBarBottomConstraint: NSLayoutConstraint?
    
    // 数据引用
    var flutterEngine: FlutterEngine?
    var authorizedURLs = [String: URL]()
    
    // 临时保存 Flutter 的回调结果 (用于原生文件选择器)
    private var pickerResult: FlutterResult?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        guard let flutterVC = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
        self.flutterEngine = flutterVC.engine
        
        // 初始化功能模块
        setupNativeTabBar(on: flutterVC)
        setupBookmarkChannel(messenger: flutterVC.binaryMessenger)
        setupTabBarControlChannel(messenger: flutterVC.binaryMessenger)
        setupAudioRouteChannel(messenger: flutterVC.binaryMessenger)
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

// MARK: - Native TabBar Setup & Logic
extension AppDelegate {
    
    private func setupNativeTabBar(on flutterVC: UIViewController) {
        let tabBarController = UITabBarController()
        self.tabBarVC = tabBarController
        
        // 1. 容器背景透明
        tabBarController.view.backgroundColor = .clear
        
        // 2. 配置子控制器
        tabBarController.viewControllers = [
            createDummyVC(title: "库", icon: "music.note.list", tag: 0),
            createDummyVC(title: "喜欢", icon: "heart", tag: 1),
            createDummyVC(title: "最近播放", icon: "clock", tag: 2),
            createDummyVC(title: "系统设置", icon: "gear", tag: 3)
        ]
        
        tabBarController.delegate = self
        
        // 3. 配置外观 (支持透明悬浮 + 毛玻璃)
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground() // 透明基底
            appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial) // 毛玻璃
            appearance.backgroundColor = .clear
            
            // 去除分割线
            appearance.shadowImage = nil
            appearance.shadowColor = nil
            
            tabBarController.tabBar.standardAppearance = appearance
            tabBarController.tabBar.scrollEdgeAppearance = appearance
        } else {
            // iOS 14 兼容
            tabBarController.tabBar.backgroundImage = UIImage()
            tabBarController.tabBar.shadowImage = UIImage()
            tabBarController.tabBar.barTintColor = .clear
            tabBarController.tabBar.backgroundColor = .clear
            
            let blurEffect = UIBlurEffect(style: .systemChromeMaterial)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = tabBarController.tabBar.bounds
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView.isUserInteractionEnabled = false
            tabBarController.tabBar.insertSubview(blurView, at: 0)
        }
        
        // 4. 添加视图
        flutterVC.addChild(tabBarController)
        flutterVC.view.addSubview(tabBarController.view)
        tabBarController.didMove(toParent: flutterVC)
        
        // 5. 布局约束
        tabBarController.view.translatesAutoresizingMaskIntoConstraints = false
        
        let guide = flutterVC.view.safeAreaLayoutGuide
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        if isIPad {
            // iPad: 标签栏在顶部
            tabBarBottomConstraint = tabBarController.view.topAnchor.constraint(equalTo: flutterVC.view.topAnchor)
            NSLayoutConstraint.activate([
                tabBarController.view.leadingAnchor.constraint(equalTo: flutterVC.view.leadingAnchor),
                tabBarController.view.trailingAnchor.constraint(equalTo: flutterVC.view.trailingAnchor),
                tabBarBottomConstraint!,
                // 底部对齐 Safe Area 顶部，向下偏移 49pt (TabBar高度)
                tabBarController.view.bottomAnchor.constraint(equalTo: guide.topAnchor, constant: 49)
            ])
        } else {
            // iPhone: 标签栏在底部
            tabBarBottomConstraint = tabBarController.view.bottomAnchor.constraint(equalTo: flutterVC.view.bottomAnchor)
            NSLayoutConstraint.activate([
                tabBarController.view.leadingAnchor.constraint(equalTo: flutterVC.view.leadingAnchor),
                tabBarController.view.trailingAnchor.constraint(equalTo: flutterVC.view.trailingAnchor),
                tabBarBottomConstraint!,
                // 顶部对齐 Safe Area 底部，向上偏移 49pt (TabBar高度)
                tabBarController.view.topAnchor.constraint(equalTo: guide.bottomAnchor, constant: -49)
            ])
        }
    }
    
    private func createDummyVC(title: String, icon: String, tag: Int) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: icon), tag: tag)
        return vc
    }
    
    func setTabBar(hidden: Bool, animated: Bool = true) {
        guard let tabBar = tabBarVC?.view else { return }
        
        if tabBar.isHidden == hidden { return }
        
        if animated {
            UIView.animate(withDuration: 0.2) {
                tabBar.alpha = hidden ? 0 : 1
            } completion: { _ in
                tabBar.isHidden = hidden
            }
        } else {
            tabBar.alpha = hidden ? 0 : 1
            tabBar.isHidden = hidden
        }
        
        notifyFlutterTabBarVisibility(isHidden: hidden)
    }
}

// MARK: - Method Channels Setup
extension AppDelegate {
    
    private func setupTabBarControlChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: Channels.nativeTabBar, binaryMessenger: messenger)
        
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case Methods.selectTab:
                if let index = call.arguments as? Int {
                    self.tabBarVC?.selectedIndex = index
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Expected int", details: nil))
                }
            case Methods.setTabBarHidden:
                if let hidden = call.arguments as? Bool {
                    self.setTabBar(hidden: hidden, animated: true)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Expected bool", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func notifyFlutterTabBarVisibility(isHidden: Bool) {
        guard let engine = flutterEngine else { return }
        let channel = FlutterMethodChannel(name: Channels.nativeTabBar, binaryMessenger: engine.binaryMessenger)
        channel.invokeMethod(Methods.onTabBarVisibilityChanged, arguments: !isHidden)
    }
    
    private func setupBookmarkChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: Channels.secureBookmarks, binaryMessenger: messenger)
        
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleBookmarkCall(call: call, result: result)
        }
    }
}

// MARK: - Bookmark Logic & Document Picker
extension AppDelegate {
    
    private func handleBookmarkCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        
        switch call.method {
        // 新增：调用原生文件选择器
        case Methods.pickFile:
            let exts = args?["extensions"] as? [String] ?? []
            let allowFolders = args?["allowFolders"] as? Bool ?? false
            self.pickerResult = result
            openDocumentPicker(allowedExtensions: exts, allowFolders: allowFolders)
            
        case Methods.createBookmark:
            // 注意：如果使用 pickFile，这个方法通常不再被调用，但保留做兼容
            guard let path = args?["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Path required", details: nil))
                return
            }
            createBookmark(path: path, result: result)
            
        case Methods.startAccessing:
            guard let bookmark = args?["bookmark"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Bookmark required", details: nil))
                return
            }
            startAccessing(bookmarkBase64: bookmark, result: result)
            
        case Methods.stopAccessing:
            guard let bookmark = args?["bookmark"] as? String else {
                result(nil)
                return
            }
            stopAccessing(bookmarkBase64: bookmark)
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func openDocumentPicker(allowedExtensions: [String] = [], allowFolders: Bool = false) {
        let picker: UIDocumentPickerViewController

        if #available(iOS 14.0, *) {
            // iOS 14+ : 使用 UTType 和新构造函数
            var types: [UTType] = []

            if !allowedExtensions.isEmpty {
                for ext in allowedExtensions {
                    if let ut = UTType(filenameExtension: ext) {
                        types.append(ut)
                    } else if let ut = UTType.types(tag: ext, tagClass: .filenameExtension, conformingTo: nil).first {
                        types.append(ut)
                    }
                }
            }

            if allowFolders {
                types.append(.folder)
            }

            if types.isEmpty {
                types = [.audio]
                if allowFolders { types.append(.folder) }
            }

            picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        } else {
            // iOS 14 以下 : 使用字符串常量/UTI
            var types: [String] = []

            if !allowedExtensions.isEmpty {
                for ext in allowedExtensions {
                    if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil)?.takeRetainedValue() {
                        types.append(uti as String)
                    }
                }
            }

            if allowFolders && !types.contains("public.folder") {
                types.append("public.folder")
            }

            if types.isEmpty {
                types = ["public.audio"]
                if allowFolders { types.append("public.folder") }
            }

            // .open 模式等同于 asCopy: false (获取原始引用，不复制)
            picker = UIDocumentPickerViewController(documentTypes: types, in: .open)
        }

        picker.delegate = self
        // 如果选择的是文件夹，则只允许单选
        picker.allowsMultipleSelection = !allowFolders
        picker.modalPresentationStyle = .formSheet

        if let root = window?.rootViewController {
            root.present(picker, animated: true, completion: nil)
        } else {
            pickerResult?(FlutterError(code: "UI_ERROR", message: "Cannot find root VC", details: nil))
            pickerResult = nil
        }
    }
    
    // UIDocumentPickerDelegate 回调
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var results = [[String: Any]]()

        for url in urls {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
                let isDir = resourceValues.isDirectory ?? false
                let name = resourceValues.name ?? url.lastPathComponent

                results.append([
                    "path": url.path,
                    "isDirectory": isDir,
                    "name": name
                ])
                print("✅ [NativePicker] Selected: \(url.path) (dir: \(isDir))")
            } catch {
                print("❌ [NativePicker] Error reading resourceValues: \(error)")
                // 回退：仍然返回路径
                results.append([
                    "path": url.path,
                    "name": url.lastPathComponent
                ])
            }
        }

        pickerResult?(results)
        pickerResult = nil
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pickerResult?(nil)
        pickerResult = nil
    }
    
    
    private func createBookmark(path: String, result: FlutterResult) {
        let url = URL(fileURLWithPath: path)
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            result(data.base64EncodedString())
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
            // 解析时无需特殊参数，iOS 会自动识别 Security Scope
            let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("⚠️ [SecureBookmark] Data is stale but system recovered it.")
            }
            
            if url.startAccessingSecurityScopedResource() {
                authorizedURLs[bookmarkBase64] = url
                result(url.path)
            } else {
                result(FlutterError(code: "ACCESS_DENIED", message: "Failed to access", details: nil))
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

// MARK: - Audio Route Channel
extension AppDelegate {
    private func setupAudioRouteChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: Channels.audioRoute, binaryMessenger: messenger)
        
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard self != nil else {
                result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate unavailable", details: nil))
                return
            }
            
            switch call.method {
            case "showAirPlayPicker":
                // TODO: 实现 AirPlay 选择器
                result(FlutterMethodNotImplemented)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}

// MARK: - UITabBarControllerDelegate
extension AppDelegate: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let engine = flutterEngine else { return }
        let channel = FlutterMethodChannel(name: Channels.nativeTabBar, binaryMessenger: engine.binaryMessenger)
        channel.invokeMethod(Methods.onTabSelected, arguments: tabBarController.selectedIndex)
    }
}