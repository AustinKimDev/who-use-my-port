import Foundation

struct PortRegistryStore {
    var fileURL: URL = Self.defaultFileURL

    static var defaultFileURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return baseURL
            .appendingPathComponent("WhoUseMyPort", isDirectory: true)
            .appendingPathComponent("registry.json")
    }

    func load() -> [PortRegistration] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        do {
            return try JSONDecoder.portRegistryDecoder.decode([PortRegistration].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ registrations: [PortRegistration]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try JSONEncoder.portRegistryEncoder.encode(registrations)
        try data.write(to: fileURL, options: .atomic)
    }
}

extension JSONDecoder {
    static var portRegistryDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

extension JSONEncoder {
    static var portRegistryEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
