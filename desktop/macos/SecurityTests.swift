import Foundation

final class MemoryStore: SecretStore {
    var connection: AIConnection?
    func read() throws -> AIConnection? { connection }
    func save(_ connection: AIConnection) throws { self.connection = connection }
    func delete() throws { connection = nil }
}

final class StubProtocol: URLProtocol {
    static let mutex = NSLock()
    static var observed: [URLRequest] = []
    static var responseCode = 200
    static var hold = false
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(buffer, count: count) }
            captured.httpBody = data
        }
        Self.mutex.lock(); Self.observed.append(captured); let code=Self.responseCode, hold=Self.hold; Self.mutex.unlock()
        if hold { return }
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json", "Location": "https://untrusted.example/steal"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"choices\":[{\"message\":{\"content\":\"测试回复\"}}]}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct SecurityTests {
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        if !value() { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    static func rejected(_ name: String, _ operation: () throws -> Void) {
        do { try operation(); check(false, name) } catch {}
    }
    static func main() throws {
        let fake = "test-only-native-key-not-real"
        let store = MemoryStore()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let service = SecureAIService(store: store, configuration: configuration)
        try service.save(AIConnection(provider: "openai", model: "test-model", baseUrl: "https://api.openai.com/v1", key: fake))
        let snapshot = try JSONSerialization.data(withJSONObject: service.snapshot())
        check(!String(decoding: snapshot, as: UTF8.self).contains(fake), "public state exposes secret")
        let endpoint = try SecureAIService.endpoint("https://api.openai.com/v1")
        check(endpoint.absoluteString == "https://api.openai.com/v1/chat/completions", "endpoint normalization")
        rejected("plain HTTP accepted") { _ = try SecureAIService.endpoint("http://api.openai.com/v1") }
        rejected("URL credentials accepted") { _ = try SecureAIService.endpoint("https://user:pass@api.openai.com/v1") }
        rejected("URL query accepted") { _ = try SecureAIService.endpoint("https://api.openai.com/v1?key=secret") }
        rejected("provider destination mismatch accepted") { try SecureAIService.validate(AIConnection(provider: "openai", model: "m", baseUrl: "https://untrusted.example", key: fake)) }
        rejected("header injection accepted") { try SecureAIService.validate(AIConnection(provider: "custom", model: "m", baseUrl: "https://test.example", key: "key\nInjected: header")) }
        let first = DispatchSemaphore(value: 0)
        service.request([["role": "user", "content": "test"]]) { result in
            if case let .success(content) = result { check(content == "测试回复", "invalid reply") } else { check(false, "native request failed") }
            first.signal()
        }
        check(first.wait(timeout: .now()+5) == .success, "native request timeout")
        let request = StubProtocol.observed[0]
        check(request.url?.host == "api.openai.com", "request left configured provider")
        check(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + fake, "native authorization missing")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        check(body["max_completion_tokens"] as? Int == 4096, "output limit missing")
        check(!String(decoding: request.httpBody!, as: UTF8.self).contains(fake), "secret in request body")
        let before = StubProtocol.observed.count
        let invalid = DispatchSemaphore(value: 0)
        service.request([["role": "user", "content": String(repeating: "x", count: 50001)]]) { result in
            if case .success = result { check(false, "oversized input accepted") }; invalid.signal()
        }
        check(invalid.wait(timeout: .now()+2) == .success && StubProtocol.observed.count == before, "invalid input sent to provider")
        StubProtocol.responseCode = 302
        let redirect = DispatchSemaphore(value: 0)
        service.request([["role": "user", "content": "redirect"]]) { result in
            if case .success = result { check(false, "redirect accepted") }; redirect.signal()
        }
        check(redirect.wait(timeout: .now()+5) == .success, "redirect test timeout")
        check(StubProtocol.observed.allSatisfy { $0.url?.host == "api.openai.com" }, "redirect leaked credentials")
        let delegate = NoRedirectDelegate(), task = URLSession.shared.dataTask(with: URL(string: "https://api.openai.com")!)
        var didRejectRedirect = false
        delegate.urlSession(URLSession.shared, task: task, willPerformHTTPRedirection: HTTPURLResponse(url: task.originalRequest!.url!, statusCode: 302, httpVersion: nil, headerFields: nil)!, newRequest: URLRequest(url: URL(string: "https://untrusted.example")!)) { didRejectRedirect = $0 == nil }
        check(didRejectRedirect, "redirect delegate permits redirection")
        StubProtocol.responseCode = 200; StubProtocol.hold = true
        let cancelled = DispatchSemaphore(value: 0)
        var cancelMessage = ""
        service.request([["role": "user", "content": "cancel"]]) { result in
            if case .success = result { check(false, "cancelled request completed") }
            if case let .failure(error) = result { cancelMessage = error.localizedDescription }
            cancelled.signal()
        }
        service.cancel()
        check(cancelled.wait(timeout: .now()+5) == .success, "cancel did not stop native task")
        check(cancelMessage.contains("取消"), "cancel returned misleading error")
        check(!service.locked, "cancel unexpectedly locked credentials")
        StubProtocol.hold = true
        let lockedRequest = DispatchSemaphore(value: 0)
        service.request([["role": "user", "content": "lock"]]) { result in
            if case .success = result { check(false, "locked request completed") }; lockedRequest.signal()
        }
        service.lock()
        check(lockedRequest.wait(timeout: .now()+5) == .success, "lock did not cancel native task")
        check(service.locked, "service remains unlocked")
        _ = try service.unlock()
        check(!service.locked, "unlock failed")
        let deleted = try service.delete()
        check(deleted["hasKey"] as? Bool == false && store.connection == nil, "delete did not remove key")
        print("PASS native security: public-state isolation, HTTPS and provider binding, input/output limits, redirect refusal, cancellation, lock and deletion (no real Keychain writes)")
    }
}
