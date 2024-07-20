import Flutter
import UIKit

public class ExternalDisplayPlugin: NSObject, FlutterPlugin {
    var externalWindow:UIWindow?
    var externalViewController:FlutterViewController!;
    public var externalViewEvents:FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let onDisplayChange = FlutterEventChannel(name: "monitorStateListener", binaryMessenger: registrar.messenger())
        onDisplayChange.setStreamHandler(MainViewHandler())
        
        let connect = FlutterMethodChannel(name: "displayController", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(ExternalDisplayPlugin(), channel: connect)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            if (UIScreen.screens.count > 1) {
                let args = call.arguments as? Dictionary<String, String>
                let routeName = args?["routeName"] ?? "externalView"
                let externalScreen = UIScreen.screens[1]
                let mode = externalScreen.availableModes.last
                externalScreen.currentMode = mode;
                var frame = CGRect.zero
                frame.size = mode!.size
                if (externalWindow == nil) {
                    let flutterEngine = FlutterEngine()
                    flutterEngine.run(withEntrypoint: "externalDisplayMain", initialRoute: routeName)
                    externalViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
                    
                    let receiveParameters = FlutterEventChannel(name: "receiveParametersListener", binaryMessenger: externalViewController.binaryMessenger)
                    receiveParameters.setStreamHandler(ExternalViewHandler(plugin: self))
                    
                    externalViewController.view.frame = frame
                    externalWindow = UIWindow(frame: frame)
                } else {
                    externalViewController.view.frame = frame
                    externalViewController.view.setNeedsLayout()
                    externalWindow?.frame = frame
                }
                externalWindow?.rootViewController = externalViewController
                externalWindow?.screen = externalScreen
                externalWindow?.makeKeyAndVisible()
                
                result(["height":mode!.size.height, "width":mode!.size.width])
            } else {
                result(false)
            }
        case "transferParameters":
            if (externalViewEvents != nil) {
                externalViewEvents?(call.arguments)
                result(true)
            } else {
                result(false)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

public class MainViewHandler: NSObject, FlutterStreamHandler {
    var didConnectObserver:NSObjectProtocol?
    var didDisconnectObserver:NSObjectProtocol?
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if (UIScreen.screens.count > 1) {
            let externalScreen = UIScreen.screens[1]
            let mode = externalScreen.availableModes.last
            events(["height":mode!.size.height, "width":mode!.size.width])
        }
        
        didConnectObserver = NotificationCenter.default.addObserver(forName:UIScreen.didConnectNotification, object:nil, queue:nil) {_ in
            if (UIScreen.screens.count > 1) {
                let externalScreen = UIScreen.screens[1]
                let mode = externalScreen.availableModes.last
                events(["height":mode!.size.height, "width":mode!.size.width])
            }
        }
        
        didDisconnectObserver = NotificationCenter.default.addObserver(forName:UIScreen.didDisconnectNotification, object:nil, queue: nil) {_ in
            events(false)
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(didConnectObserver)
        NotificationCenter.default.removeObserver(didDisconnectObserver)
        
        return nil
    }
}

public class ExternalViewHandler: NSObject, FlutterStreamHandler {
    var externalDisplayPlugin : ExternalDisplayPlugin
    
    init(plugin : ExternalDisplayPlugin) {
        externalDisplayPlugin = plugin
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        externalDisplayPlugin.externalViewEvents = events

        if (UIScreen.screens.count > 1) {
            let externalScreen = UIScreen.screens[1]
            let mode = externalScreen.availableModes.last
            events(["action": "Resolution", "value":["height":mode!.size.height, "width":mode!.size.width]])
        }
        
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        externalDisplayPlugin.externalViewEvents = nil
        return nil
    }
}
