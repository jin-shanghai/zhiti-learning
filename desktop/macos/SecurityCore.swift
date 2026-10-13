import Foundation
import Security

struct AIConnection: Codable {
    var provider: String
    var model: String
    var baseUrl: String
    var key: String
    var publicConfig: [String: String] { ["provider": provider, "model": model, "baseUrl": baseUrl] }
}

enum SecureAIError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}

protocol SecretStore {
    func read() throws -> AIConnection?
    func save(_ connection: AIConnection) throws
    func delete() throws
}

final class KeychainStore: SecretStore {
    private let query: [String: Any]
    init(service: String = "org.zhiti.learning.ai", account: String = "personal-provider") {
        query = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    func read() throws -> AIConnection? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let bytes = item as? Data,
              let connection = try? JSONDecoder().decode(AIConnection.self, from: bytes) else {
            throw SecureAIError.invalid("无法读取系统钥匙串，请解锁电脑或允许知题访问。")
        }
        return connection
    }
    func save(_ connection: AIConnection) throws {
        let encoded = try JSONEncoder().encode(connection)
        let updates = [kSecValueData as String: encoded]
        var status = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = encoded
            item[kSecAttrLabel as String] = "知题 AI 服务密钥"
            // 默认由创建此条目的应用访问；不设置允许任意应用读取的 ACL。
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw SecureAIError.invalid("无法保存到系统钥匙串，原配置未被替换。") }
    }
    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureAIError.invalid("系统钥匙串未允许删除，请检查系统权限。")
        }
    }
}

final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

final class SecureAIService {
    let store: SecretStore
    private let queue = DispatchQueue(label: "org.zhiti.learning.ai.requests")
    private let redirectDelegate = NoRedirectDelegate()
    private var session: URLSession!
    private var tasks: [UUID: URLSessionDataTask] = [:]
    private var requestTimes: [Date] = []
    private(set) var locked = false
    private var generation = 0

    init(store: SecretStore, configuration: URLSessionConfiguration = .ephemeral) {
        self.store = store
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration, delegate: redirectDelegate, delegateQueue: nil)
    }

    static func endpoint(_ raw: String) throws -> URL {
        guard raw.count <= 500, var parts = URLComponents(string: raw),
              parts.scheme == "https", let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil else {
            throw SecureAIError.invalid("接口必须为 HTTPS 地址，不能含账号、参数或片段。")
        }
        let path = parts.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        parts.path = "/" + (path.hasSuffix("chat/completions") ? path : (path.isEmpty ? "" : path + "/") + "chat/completions")
        guard let url = parts.url else { throw SecureAIError.invalid("接口地址无效") }
        return url
    }

    static func validate(_ connection: AIConnection) throws {
        let url = try endpoint(connection.baseUrl)
        guard !connection.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              connection.key.count <= 8192, !connection.key.contains("\n"), !connection.key.contains("\r"),
              !connection.model.isEmpty, connection.model.count <= 120 else {
            throw SecureAIError.invalid("请检查模型名称和密钥。")
        }
        let hosts = ["openai": ["api.openai.com"], "deepseek": ["api.deepseek.com"],
                     "qwen": ["dashscope.aliyuncs.com", "dashscope-intl.aliyuncs.com", "dashscope-us.aliyuncs.com"]]
        if connection.provider != "custom" {
            guard let permitted = hosts[connection.provider], permitted.contains(url.host ?? ""), url.port == nil || url.port == 443 else {
                throw SecureAIError.invalid("服务商与接口地址不匹配；自建接口请明确选择其他兼容接口。")
            }
        }
    }

    func snapshot() throws -> [String: Any] {
        guard let connection = try store.read() else { return ["hasKey": false, "locked": true] }
        return ["hasKey": true, "locked": locked, "config": connection.publicConfig]
    }
    func save(_ connection: AIConnection) throws {
        try Self.validate(connection)
        lock()
        try store.save(connection)
        locked = false
    }
    func unlock() throws -> [String: Any] {
        guard try store.read() != nil else { throw SecureAIError.invalid("请先配置密钥") }
        locked = false
        return try snapshot()
    }
    func lock() {
        queue.sync {
            generation += 1
            locked = true
            for task in tasks.values { task.cancel() }
            tasks.removeAll()
        }
    }
    func delete() throws -> [String: Any] {
        lock()
        try store.delete()
        return ["hasKey": false, "locked": true]
    }

    func request(_ raw: Any, completion: @escaping (Result<String, Error>) -> Void) {
        do {
            guard !locked, let connection = try store.read() else { throw SecureAIError.invalid("密钥已锁定或未配置") }
            try Self.validate(connection)
            guard let messages = raw as? [[String: Any]], !messages.isEmpty, messages.count <= 25 else {
                throw SecureAIError.invalid("对话数量超过限制，请开始新的追问。")
            }
            var safeMessages: [[String: String]] = []
            var characters = 0
            for message in messages {
                guard let role = message["role"] as? String, ["system", "user", "assistant"].contains(role),
                      let content = message["content"] as? String, content.count <= 50000 else {
                    throw SecureAIError.invalid("对话内容无效或过长")
                }
                characters += content.utf8.count
                safeMessages.append(["role": role, "content": content])
            }
            guard characters <= 120000 else { throw SecureAIError.invalid("本次对话过长，请缩短后重试。") }
            var request = URLRequest(url: try Self.endpoint(connection.baseUrl))
            request.httpMethod = "POST"
            request.setValue("Bearer " + connection.key, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var body: [String: Any] = ["model": connection.model, "messages": safeMessages, "stream": false]
            body[connection.provider == "openai" ? "max_completion_tokens" : "max_tokens"] = 4096
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let id = UUID(), epoch = generation
            let task = session.dataTask(with: request) { [weak self] bytes, response, error in
                guard let self = self else { return }
                let cancelled = self.queue.sync { () -> Bool in
                    self.tasks.removeValue(forKey: id)
                    return self.generation != epoch
                }
                if cancelled || error != nil {
                    completion(.failure(SecureAIError.invalid(cancelled ? "密钥已锁定，请重新解锁。" : "请求失败或超时，请检查网络。"))); return
                }
                guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    completion(.failure(SecureAIError.invalid("服务商返回错误（\(code)）；请检查权限、额度和接口。"))); return
                }
                guard let bytes = bytes, bytes.count <= 2_000_000,
                      let payload = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                      let choices = payload["choices"] as? [[String: Any]], let message = choices.first?["message"] as? [String: Any],
                      let content = message["content"] as? String, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    completion(.failure(SecureAIError.invalid("服务商未返回有效文字"))); return
                }
                completion(.success(content))
            }
            let accepted = queue.sync { () -> Bool in
                let now = Date()
                requestTimes.removeAll { now.timeIntervalSince($0) > 300 }
                guard !locked, tasks.count < 2, requestTimes.count < 20 else { return false }
                requestTimes.append(now); tasks[id] = task; return true
            }
            guard accepted else { throw SecureAIError.invalid("请求过于频繁或密钥已锁定，请稍后重试。") }
            task.resume()
        } catch { completion(.failure(error)) }
    }
}
