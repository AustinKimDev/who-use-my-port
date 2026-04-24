import Foundation

struct PortScanner {
    func scan(_ query: PortQuery) async throws -> [PortProcess] {
        try await Task.detached(priority: .userInitiated) {
            var processMap: [Int: PortProcess] = [:]

            for spec in query.lsofSpecs {
                let output = try Shell.run(
                    executable: "/usr/sbin/lsof",
                    arguments: ["-nP", "-F", "pcLnPT", "-iTCP:\(spec)", "-iUDP:\(spec)"],
                    allowNoResults: true
                )

                for process in Self.parseLsofOutput(output) {
                    var existing = processMap[process.pid] ?? process
                    let knownConnections = Set(existing.connections)
                    existing.connections.append(contentsOf: process.connections.filter { !knownConnections.contains($0) })
                    processMap[process.pid] = existing
                }
            }

            return try processMap.values
                .map { try Self.enrichProcess($0) }
                .sorted {
                    if $0.portSummary == $1.portSummary {
                        return $0.command.localizedCaseInsensitiveCompare($1.command) == .orderedAscending
                    }
                    return $0.portSummary.localizedStandardCompare($1.portSummary) == .orderedAscending
                }
        }.value
    }

    private static func parseLsofOutput(_ output: String) -> [PortProcess] {
        var results: [PortProcess] = []
        var currentPID: Int?
        var currentCommand = ""
        var currentUser = ""
        var currentProtocol = ""
        var currentState: String?
        var currentConnections: [PortConnection] = []

        func flushCurrentProcess() {
            guard let pid = currentPID else { return }
            results.append(
                PortProcess(
                    pid: pid,
                    command: currentCommand.isEmpty ? "PID \(pid)" : currentCommand,
                    user: currentUser,
                    executablePath: nil,
                    arguments: nil,
                    connections: currentConnections
                )
            )
        }

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())

            switch field {
            case "p":
                flushCurrentProcess()
                currentPID = Int(value)
                currentCommand = ""
                currentUser = ""
                currentProtocol = ""
                currentState = nil
                currentConnections = []
            case "c":
                currentCommand = value
            case "L":
                currentUser = value
            case "P":
                currentProtocol = value
            case "T":
                if let state = Self.parseTCPState(value) {
                    currentState = state

                    if let lastIndex = currentConnections.indices.last {
                        currentConnections[lastIndex].state = state
                    }
                }
            case "f":
                currentProtocol = ""
                currentState = nil
            case "n":
                currentConnections.append(
                    PortConnection(
                        protocolName: currentProtocol.isEmpty ? "UNKNOWN" : currentProtocol,
                        name: value,
                        state: currentState,
                        localPort: Self.parseLocalPort(from: value)
                    )
                )
            default:
                continue
            }
        }

        flushCurrentProcess()
        return results.filter { !$0.connections.isEmpty }
    }

    private static func enrichProcess(_ process: PortProcess) throws -> PortProcess {
        var enriched = process

        let pid = "\(process.pid)"
        let user = try Shell.run(executable: "/bin/ps", arguments: ["-p", pid, "-o", "user="], allowNoResults: true)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let executablePath = try Shell.run(executable: "/bin/ps", arguments: ["-p", pid, "-o", "comm="], allowNoResults: true)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let arguments = try Shell.run(executable: "/bin/ps", arguments: ["-p", pid, "-o", "args="], allowNoResults: true)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !user.isEmpty {
            enriched.user = user
        }

        enriched.executablePath = executablePath.isEmpty ? nil : executablePath
        enriched.arguments = arguments.isEmpty ? nil : arguments

        return enriched
    }

    private static func parseTCPState(_ value: String) -> String? {
        let markers = ["ST=", "TST="]

        for marker in markers {
            if value.hasPrefix(marker) {
                return String(value.dropFirst(marker.count))
            }
        }

        return nil
    }

    private static func parseLocalPort(from name: String) -> Int? {
        let localEndpoint = name.components(separatedBy: "->").first ?? name
        let pattern = #":(\d+)(?:\s|\)|$)"#

        guard let range = localEndpoint.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let match = String(localEndpoint[range])
        let digits = match.filter(\.isNumber)
        return Int(digits)
    }
}

struct ProcessController {
    func terminate(pid: Int, force: Bool) async throws {
        try await Task.detached(priority: .userInitiated) {
            _ = try Shell.run(
                executable: "/bin/kill",
                arguments: [force ? "-KILL" : "-TERM", "\(pid)"],
                allowNoResults: false
            )
        }.value
    }
}

enum ShellError: LocalizedError {
    case launchFailed(String)
    case failed(executable: String, status: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let executable):
            return "Could not launch \(executable)."
        case .failed(let executable, let status, let message):
            let suffix = message.isEmpty ? "" : " \(message)"
            return "\(executable) exited with status \(status).\(suffix)"
        }
    }
}

enum Shell {
    static func run(executable: String, arguments: [String], allowNoResults: Bool) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(executable)
        }

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let outputString = String(data: output, encoding: .utf8) ?? ""
        let errorString = String(data: errorOutput, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            if allowNoResults && outputString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ""
            }

            throw ShellError.failed(
                executable: URL(fileURLWithPath: executable).lastPathComponent,
                status: process.terminationStatus,
                message: errorString.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return outputString
    }
}
