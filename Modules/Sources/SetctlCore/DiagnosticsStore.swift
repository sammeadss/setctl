//
//  DiagnosticsStore.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/30/26.
//

import Foundation

/// Keeps the newest few MetricKit reports as JSON files in one folder.
public struct DiagnosticsStore: Sendable {
    public let directory: URL
    private let limit: Int

    public init(directory: URL, limit: Int = 10) {
        self.directory = directory
        self.limit = limit
    }

    /// The store in Application Support, which the system keeps and never purges.
    public static func standard() throws -> DiagnosticsStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return DiagnosticsStore(directory: base.appendingPathComponent("Diagnostics", isDirectory: true))
    }

    /// Writes `data` as a new report, then deletes all but the newest `limit` reports.
    public func save(_ data: Data, kind: String, date: Date = Date()) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: date).replacingOccurrences(of: ":", with: "-")
        try data.write(to: directory.appendingPathComponent("\(stamp)-\(kind).json"), options: .atomic)
        try prune()
    }

    /// Saved reports, newest first.
    public func files() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func prune() throws {
        for url in files().dropFirst(limit) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
