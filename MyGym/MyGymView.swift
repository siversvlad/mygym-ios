import SwiftUI
import WebKit

struct MyGymView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "mygymBluetooth")
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        let web = WKWebView(frame: .zero, configuration: config)
        context.coordinator.web = web
        context.coordinator.bluetooth = BluetoothManager { [weak web] event in
            guard let web, let data = try? JSONSerialization.data(withJSONObject: event),
                  let json = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { web.evaluateJavaScript("window.mygymNativeBLE(\(json));", completionHandler: nil) }
        }
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var web: WKWebView?
        var bluetooth: BluetoothManager?
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: String] else { return }
            switch body["action"] {
            case "scan": bluetooth?.scan()
            case "disconnect": bluetooth?.disconnect()
            default: break
            }
        }
    }
}
