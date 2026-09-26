import Foundation
import Security

struct Pairing: Codable, Equatable {
    let sessionId: String
    let secret: String
    let relayURL: URL
    var pushTopic: String = "bobc-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

    static func parse(_ url: URL) throws -> Pairing {
        guard let link = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw PairingError.invalid }
        var values: [String: String] = [:]
        let items: [URLQueryItem]
        let relay: URL?
        if link.scheme == "bobcompanion", link.host == "pair" {
            items = link.queryItems ?? []
            relay = nil
        } else if ["https", "http"].contains(link.scheme), let fragment = link.fragment {
            items = URLComponents(string: "?" + fragment)?.queryItems ?? []
            var base = link
            base.scheme = link.scheme == "https" ? "wss" : "ws"
            base.fragment = nil
            base.query = nil
            base.path = "/"
            relay = base.url
        } else { throw PairingError.invalid }
        for item in items {
            guard values[item.name] == nil else { throw PairingError.invalid }
            values[item.name] = item.value
        }
        guard let id = values["s"], id.range(of: "^[A-Za-z0-9_-]{4,64}$", options: .regularExpression) != nil,
              let secret = values["k"], secret.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil,
              let endpoint = relay ?? values["r"].flatMap(URL.init(string:)),
              let parts = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
              let host = parts.host, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil,
              parts.scheme == "wss" || (parts.scheme == "ws" && isLocal(host)) else { throw PairingError.invalid }
        return Pairing(sessionId: id, secret: secret, relayURL: endpoint)
    }

    static func isLocal(_ host: String) -> Bool {
        if host == "localhost" || host == "::1" || host.hasSuffix(".local") { return true }
        let octets = host.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return false }
        return octets[0] == 10 || octets[0] == 127 || (octets[0] == 192 && octets[1] == 168)
            || (octets[0] == 172 && (16...31).contains(octets[1]))
    }
}

enum PairingError: LocalizedError {
    case invalid, storage
    var errorDescription: String? {
        self == .invalid ? "This isn't a valid Bob pairing code. Ask Bob to pair your phone again."
            : "Alice couldn't securely save this connection. Please try again."
    }
}

enum PairingStorage {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.bobcompanion.app.pairing", kSecAttrAccount as String: "active"]
    }
    static func load() -> Pairing? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &value) == errSecSuccess, let data = value as? Data else { return nil }
        return try? JSONDecoder().decode(Pairing.self, from: data)
    }
    static func save(_ pairing: Pairing) throws {
        let data = try JSONEncoder().encode(pairing)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            guard SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else {
                throw PairingError.storage
            }
        } else if status != errSecSuccess { throw PairingError.storage }
    }
    static func clear() { SecItemDelete(query as CFDictionary) }
}
