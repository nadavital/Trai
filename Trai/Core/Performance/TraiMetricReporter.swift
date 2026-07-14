//
//  TraiMetricReporter.swift
//  Trai
//
//  Async MetricKit report collection introduced in iOS 27.
//

import Foundation
import MetricKit
import os

@available(iOS 27.0, *)
@MainActor
final class TraiMetricReporter {
    static let shared = TraiMetricReporter()

    private let manager = MetricManager()
    private let archive = MetricReportArchive()
    private var tasks: [Task<Void, Never>] = []

    private init() {}

    func start() {
        guard tasks.isEmpty else { return }

        tasks = [
            Task { [manager, archive] in
                for await report in manager.metricReports {
                    guard !Task.isCancelled else { return }
                    await archive.persist(report, kind: "metric")
                }
            },
            Task { [manager, archive] in
                for await report in manager.diagnosticReports {
                    guard !Task.isCancelled else { return }
                    await archive.persist(report, kind: "diagnostic")
                }
            }
        ]
    }
}

@available(iOS 27.0, *)
private actor MetricReportArchive {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Trai", category: "MetricKit")
    private let maximumFiles = 8

    func persist<Report: Encodable & Sendable>(_ report: Report, kind: String) {
        do {
            let fileManager = FileManager.default
            let baseURL = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = baseURL.appendingPathComponent("MetricReports", isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let timestamp = Int(Date().timeIntervalSince1970)
            let destination = directory.appendingPathComponent("\(kind)-\(timestamp)-\(UUID().uuidString).json")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(report).write(to: destination, options: .atomic)
            try? fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destination.path)
            prune(directory: directory, fileManager: fileManager)
            logger.info("Archived an iOS 27 \(kind, privacy: .public) report")
        } catch {
            logger.error("Could not archive an iOS 27 \(kind, privacy: .public) report: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func prune(directory: URL, fileManager: FileManager) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ), files.count > maximumFiles else { return }

        let sorted = files.sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhs < rhs
        }
        for file in sorted.prefix(files.count - maximumFiles) {
            try? fileManager.removeItem(at: file)
        }
    }
}
