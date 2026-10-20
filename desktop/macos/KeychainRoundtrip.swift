import Foundation

@main struct KeychainRoundtrip {
    static func main() throws {
        let store = KeychainStore(service: "org.zhiti.learning.test." + UUID().uuidString, account: "disposable-test-item")
        guard try store.read() == nil else { fatalError("test target must not preexist") }
        defer { try? store.delete() }
        let first = AIConnection(provider: "openai", model: "test", baseUrl: "https://api.openai.com/v1", key: "FAKE-TEST-ONLY-NOT-A-REAL-KEY")
        try store.save(first)
        guard try store.read()?.key == first.key else { fatalError("Keychain roundtrip failed") }
        var changed = first; changed.key = "FAKE-UPDATED-NOT-A-REAL-KEY"
        try store.save(changed)
        guard try store.read()?.key == changed.key else { fatalError("Keychain update failed") }
        try store.delete()
        guard try store.read() == nil else { fatalError("Keychain delete failed") }
        print("PASS system Keychain: create, read, update, delete of a unique disposable fake test item; no user credentials accessed")
    }
}
