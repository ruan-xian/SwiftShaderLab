import Foundation
import Observation

@MainActor
@Observable
final class ShaderLabStore {
    private static let storageKey = "ShaderLabDocument.v1"
    private let persistsChanges: Bool

    var document: ShaderLabDocument {
        didSet {
            guard persistsChanges, let data = try? document.jsonData(prettyPrinted: false) else {
                return
            }
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    init() {
        persistsChanges = true
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let restored = try? ShaderLabDocument.decodeJSON(data)
        {
            document = restored
        } else {
            document = .defaults
        }
    }

    init(document: ShaderLabDocument, persistsChanges: Bool) {
        self.document = document
        self.persistsChanges = persistsChanges
    }

    func reset() {
        document = .defaults
    }

    func importData(_ data: Data) throws {
        let imported = try ShaderLabDocument.decodeJSON(data)
        document = imported
    }

    func exportData() throws -> Data {
        try document.jsonData()
    }
}
