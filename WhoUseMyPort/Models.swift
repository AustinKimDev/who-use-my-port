import Foundation

struct PortQuery: Equatable {
    let rawValue: String
    let segments: [ClosedRange<Int>]

    var lsofSpecs: [String] {
        segments.map { range in
            range.lowerBound == range.upperBound ? "\(range.lowerBound)" : "\(range.lowerBound)-\(range.upperBound)"
        }
    }

    func contains(port: Int) -> Bool {
        segments.contains { $0.contains(port) }
    }

    func expandedPorts(limit: Int = 240) -> [Int]? {
        var ports: [Int] = []

        for segment in segments {
            for port in segment {
                guard ports.count < limit else { return nil }
                ports.append(port)
            }
        }

        return ports
    }

    static func parse(_ input: String) throws -> PortQuery {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw PortQueryError.empty
        }

        let segments = try trimmedInput
            .split(separator: ",")
            .map { part -> ClosedRange<Int> in
                let trimmedPart = part.trimmingCharacters(in: .whitespacesAndNewlines)
                let bounds = trimmedPart.split(separator: "-", maxSplits: 1).map(String.init)

                guard bounds.count == 1 || bounds.count == 2 else {
                    throw PortQueryError.invalidSegment(trimmedPart)
                }

                guard let lower = Int(bounds[0]), (1...65535).contains(lower) else {
                    throw PortQueryError.invalidSegment(trimmedPart)
                }

                if bounds.count == 1 {
                    return lower...lower
                }

                guard let upper = Int(bounds[1]), (1...65535).contains(upper), lower <= upper else {
                    throw PortQueryError.invalidSegment(trimmedPart)
                }

                return lower...upper
            }

        guard !segments.isEmpty else {
            throw PortQueryError.empty
        }

        return PortQuery(rawValue: trimmedInput, segments: segments)
    }
}

struct PortPreset: Identifiable, Hashable {
    var id: String { name }

    var name: String
    var systemImage: String
    var query: String
    var description: String

    static let defaults: [PortPreset] = [
        PortPreset(
            name: "Web",
            systemImage: "globe",
            query: "80, 443, 8000, 8080, 8443",
            description: "HTTP, HTTPS, common local web servers"
        ),
        PortPreset(
            name: "JS Apps",
            systemImage: "curlybraces",
            query: "3000-3005, 5173-5175",
            description: "Next.js, React, Vite, fallback dev ports"
        ),
        PortPreset(
            name: "Node API",
            systemImage: "server.rack",
            query: "3000-3005, 4000-4005, 5000-5005",
            description: "Node, Express, GraphQL, API fallback ports"
        ),
        PortPreset(
            name: "Python",
            systemImage: "terminal",
            query: "5000-5005, 8000-8005, 8501",
            description: "Flask, Django, FastAPI, Streamlit"
        ),
        PortPreset(
            name: "Backend",
            systemImage: "gearshape.2",
            query: "8080-8085, 9000-9005, 9090",
            description: "Spring, JVM, admin and metrics ports"
        ),
        PortPreset(
            name: "Data",
            systemImage: "externaldrive.connected.to.line.below",
            query: "5432, 3306, 6379, 27017, 9200",
            description: "Postgres, MySQL, Redis, MongoDB, Elasticsearch"
        )
    ]
}

enum PortQueryError: LocalizedError {
    case empty
    case invalidSegment(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Enter a port, range, or comma-separated list."
        case .invalidSegment(let segment):
            return "Invalid port segment: \(segment). Use values from 1 to 65535."
        }
    }
}

struct PortConnection: Identifiable, Hashable {
    var id: String {
        [protocolName, displayState, name].joined(separator: "|")
    }

    var protocolName: String
    var name: String
    var state: String?
    var localPort: Int?

    var displayState: String {
        state?.isEmpty == false ? state! : "UNKNOWN"
    }
}

struct PortProcess: Identifiable, Hashable {
    var id: Int { pid }

    var pid: Int
    var command: String
    var user: String
    var executablePath: String?
    var arguments: String?
    var connections: [PortConnection]

    var portSummary: String {
        let ports = Set(connections.compactMap(\.localPort)).sorted()
        guard !ports.isEmpty else { return "No parsed port" }
        return ports.map(String.init).joined(separator: ", ")
    }

    var protocolsSummary: String {
        let protocols = Set(connections.map(\.protocolName)).sorted()
        return protocols.isEmpty ? "UNKNOWN" : protocols.joined(separator: ", ")
    }
}

struct PortRegistration: Codable, Identifiable, Hashable {
    var port: Int
    var tool: String
    var projectPath: String
    var command: String?
    var purpose: String?
    var pid: Int?
    var startedAt: Date
    var updatedAt: Date

    var id: String {
        "\(port)|\(tool)|\(projectPath)"
    }

    var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }

    var isStale: Bool {
        Date().timeIntervalSince(updatedAt) > 120
    }
}

struct MonitoredPort: Identifiable, Hashable {
    var id: Int { port }

    var port: Int
    var processes: [PortProcess]
    var registrations: [PortRegistration]

    var primaryProcess: PortProcess? {
        processes.first
    }

    var primaryRegistration: PortRegistration? {
        registrations.first
    }

    var isOccupied: Bool {
        !processes.isEmpty
    }

    var isReserved: Bool {
        !registrations.isEmpty
    }

    var statusTitle: String {
        if isOccupied {
            return "Occupied"
        }

        if isReserved {
            return primaryRegistration?.isStale == true ? "Stale" : "Reserved"
        }

        return "Available"
    }

    var statusSystemImage: String {
        if isOccupied {
            return "lock.fill"
        }

        if isReserved {
            return primaryRegistration?.isStale == true ? "clock.badge.exclamationmark" : "person.crop.circle.badge.checkmark"
        }

        return "checkmark.circle"
    }

    var ownerSummary: String {
        if let registration = primaryRegistration {
            return "\(registration.tool) · \(registration.projectName)"
        }

        return "Unregistered"
    }

    var processSummary: String {
        guard let process = primaryProcess else {
            return isReserved ? "Waiting for process" : "No listener"
        }

        return "\(process.command) · PID \(process.pid)"
    }
}
