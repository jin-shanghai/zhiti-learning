import AppKit
import WebKit

final class ZhitiApp: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    private let service = SecureAIService(store: KeychainStore())
    private var window: NSWindow!
    private var webView: WKWebView!
    private var indexURL: URL!
    private var awayLock: DispatchWorkItem?
    private var sleepObserver: NSObjectProtocol?
    private var configurationFields: (model: NSTextField, address: NSTextField)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let resourceURL = Bundle.main.resourceURL else { return }
        indexURL = resourceURL.appendingPathComponent("index.html")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "zhitiSecure")
        let bridge = """
        (() => {
          let next=0; const pending=new Map();
          const epoch=Array.from(crypto.getRandomValues(new Uint8Array(16)),x=>x.toString(16).padStart(2,'0')).join('');
          Object.defineProperty(window,'__zhitiNativeReply',{value:(id,result,error)=>{
            const p=pending.get(id);if(!p)return;pending.delete(id);clearTimeout(p.timer);
            error?p.reject(new Error(error)):p.resolve(result);
          }});
          Object.defineProperty(window,'zhitiNative',{value:Object.freeze({request:(op,args={})=>new Promise((resolve,reject)=>{
            const id=epoch+'-'+(++next);const timer=setTimeout(()=>{pending.delete(id);reject(new Error('本机操作超时，请重试'))},70000);
            pending.set(id,{resolve,reject,timer});window.webkit.messageHandlers.zhitiSecure.postMessage({id,op,args});
          })})});
        })();
        """
        configuration.userContentController.addUserScript(WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 850),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "知题 · 本机安全版"
        window.minSize = NSSize(width: 800, height: 650)
        window.contentView = webView
        window.center(); window.makeKeyAndOrderFront(nil)
        installMenu()
        webView.loadFileURL(indexURL, allowingReadAccessTo: resourceURL)
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.service.lock(); self?.webView.evaluateJavaScript("void lockAIKey();", completionHandler: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {
        service.lock(); awayLock?.cancel()
        if let observer = sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
    func applicationDidResignActive(_ notification: Notification) {
        awayLock?.cancel()
        let action = DispatchWorkItem { [weak self] in
            self?.service.lock()
            self?.webView.evaluateJavaScript("void lockAIKey();", completionHandler: nil)
        }
        awayLock = action
        DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: action)
    }
    func applicationDidBecomeActive(_ notification: Notification) { awayLock?.cancel(); awayLock = nil }
    private func installMenu() {
        let menu = NSMenu(), appMenu = NSMenu(), appItem = NSMenuItem()
        appItem.submenu = appMenu; menu.addItem(appItem)
        appMenu.addItem(withTitle: "退出知题", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editMenu = NSMenu(title: "编辑"), edit = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        edit.submenu = editMenu; menu.addItem(edit)
        for (title, action, key) in [("复制", #selector(NSText.copy(_:)), "c"), ("粘贴", #selector(NSText.paste(_:)), "v"),
                                   ("剪切", #selector(NSText.cut(_:)), "x"), ("全选", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        NSApp.mainMenu = menu
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.standardizedFileURL == indexURL.standardizedFileURL,
              let body = message.body as? [String: Any], let id = body["id"] as? String,
              id.range(of: "^[0-9a-f]{32}-[0-9]{1,7}$", options: .regularExpression) != nil,
              let operation = body["op"] as? String else { return }
        do {
            switch operation {
            case "status": reply(id, result: try service.snapshot())
            case "configure":
                guard let connection = try configurationDialog() else { reply(id, error: "设置已取消"); return }
                try service.save(connection); reply(id, result: try service.snapshot())
            case "unlock": reply(id, result: try service.unlock())
            case "lock": service.lock(); reply(id, result: ["locked": true])
            case "cancel": service.cancel(); reply(id, result: ["cancelled": true])
            case "delete":
                let alert = NSAlert(); alert.messageText = "删除已保存的 AI 密钥？"
                alert.informativeText = "将从系统钥匙串删除。学习记录和 AI 解析会保留；服务商后台的 Key 不会自动撤销。"
                alert.addButton(withTitle: "删除密钥"); alert.addButton(withTitle: "取消")
                guard alert.runModal() == .alertFirstButtonReturn else { reply(id, error: "删除已取消"); return }
                reply(id, result: try service.delete())
            case "request":
                let args = body["args"] as? [String: Any] ?? [:]
                service.request(args["messages"] as Any) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let content): self?.reply(id, result: ["content": content])
                        case .failure(let error): self?.reply(id, error: error.localizedDescription)
                        }
                    }
                }
            default: reply(id, error: "不允许此操作")
            }
        } catch { reply(id, error: error.localizedDescription) }
    }
    private func reply(_ id: String, result: [String: Any] = [:], error: String? = nil) {
        guard let bytes = try? JSONSerialization.data(withJSONObject: [id, result, (error as Any?) ?? NSNull()]),
              let json = String(data: bytes, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.__zhitiNativeReply(...\(json));", completionHandler: nil)
    }
    private func configurationDialog() throws -> AIConnection? {
        let old = try service.store.read()
        let form = NSView(frame: NSRect(x: 0, y: 0, width: 470, height: 245))
        let provider = NSPopUpButton(frame: NSRect(x: 115, y: 200, width: 345, height: 28))
        provider.addItems(withTitles: ["OpenAI", "DeepSeek", "通义千问", "其他兼容接口"])
        let providers = ["openai", "deepseek", "qwen", "custom"]
        provider.selectItem(at: providers.firstIndex(of: old?.provider ?? "openai") ?? 0)
        let model = NSTextField(frame: NSRect(x: 115, y: 150, width: 345, height: 28))
        model.stringValue = old?.model ?? "gpt-4o-mini"
        let address = NSTextField(frame: NSRect(x: 115, y: 100, width: 345, height: 28))
        address.stringValue = old?.baseUrl ?? "https://api.openai.com/v1"
        configurationFields = (model, address)
        defer { configurationFields = nil }
        provider.target = self; provider.action = #selector(providerChanged(_:))
        let key = NSSecureTextField(frame: NSRect(x: 115, y: 50, width: 345, height: 28))
        key.placeholderString = old == nil ? "粘贴你的 API Key" : "留空使用已有密钥（接口不变时）"
        for (title, y) in [("服务商", 200), ("模型", 150), ("接口地址", 100), ("API Key", 50)] {
            let label = NSTextField(labelWithString: title); label.frame = NSRect(x: 0, y: y+3, width: 105, height: 23)
            form.addSubview(label)
        }
        for control in [provider as NSView, model, address, key] { form.addSubview(control) }
        let alert = NSAlert(); alert.messageText = "配置本机 AI 服务"
        alert.informativeText = "密钥只存入 Mac 系统钥匙串。选择其他服务商时请核对其模型和官方接口；改接口后必须重新填写密钥。"
        alert.accessoryView = form; alert.addButton(withTitle: "保存到系统钥匙串"); alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { key.stringValue = ""; return nil }
        let entered = key.stringValue.trimmingCharacters(in: .whitespacesAndNewlines); key.stringValue = ""
        let base = address.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if entered.isEmpty, let old = old, try Self.sameEndpoint(old.baseUrl, base) == false {
            throw SecureAIError.invalid("接口已改变，请重新填写对应服务商的密钥。")
        }
        let connection = AIConnection(provider: providers[provider.indexOfSelectedItem],
            model: model.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), baseUrl: base, key: entered.isEmpty ? old?.key ?? "" : entered)
        try SecureAIService.validate(connection)
        if connection.provider == "custom" {
            let confirm = NSAlert(); confirm.messageText = "确认信任这个接口？"
            confirm.informativeText = "你的密钥和题目将发送到：\(try SecureAIService.endpoint(base).absoluteString)\n只继续连接你明确信任的服务。"
            confirm.addButton(withTitle: "信任并保存"); confirm.addButton(withTitle: "取消")
            if confirm.runModal() != .alertFirstButtonReturn { return nil }
        }
        return connection
    }
    private static func sameEndpoint(_ first: String, _ second: String) throws -> Bool {
        try SecureAIService.endpoint(first) == SecureAIService.endpoint(second)
    }
    @objc private func providerChanged(_ sender: NSPopUpButton) {
        let presets = [("gpt-4o-mini", "https://api.openai.com/v1"), ("deepseek-flash", "https://api.deepseek.com"),
                       ("qwen-plus", "https://dashscope.aliyuncs.com/compatible-mode/v1"), ("", "")]
        let preset = presets[sender.indexOfSelectedItem]
        configurationFields?.model.stringValue = preset.0; configurationFields?.address.stringValue = preset.1
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.shouldPerformDownload { decisionHandler(.download); return }
        if url.standardizedFileURL == indexURL.standardizedFileURL { decisionHandler(.allow); return }
        if navigationAction.navigationType == .linkActivated, ["http", "https"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
        decisionHandler(.cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, ["http", "https"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
        return nil
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert(); alert.messageText = message; alert.addButton(withTitle: "确定"); alert.addButton(withTitle: "取消")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = NSAlert(); alert.messageText = message; alert.addButton(withTitle: "确定"); alert.runModal(); completionHandler()
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = suggestedFilename
        completionHandler(panel.runModal() == .OK ? panel.url : nil)
    }
}

@main struct ZhitiMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = ZhitiApp()
        app.delegate = delegate
        app.run()
    }
}
