//
//  DiagnosticsCollector.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/30/26.
//

#if os(iOS)
    import MetricKit
    import SetctlCore

    /// Saves the reports MetricKit delivers (metrics, crashes, hangs). Reports arrive on a background queue, about once
    /// a day, and only on real devices.
    public final class DiagnosticsCollector: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
        /// Safe to share across queues: `store` is an immutable value and every save is a self-contained file write.
        private let store: DiagnosticsStore

        init(store: DiagnosticsStore) {
            self.store = store
            super.init()
        }

        /// Starts collecting into the standard diagnostics folder. Returns nil, after logging, if the folder is
        /// unavailable; diagnostics are best-effort and never stop the app.
        public static func startStandard() -> DiagnosticsCollector? {
            do {
                let collector = try DiagnosticsCollector(store: .standard())
                MXMetricManager.shared.add(collector)
                return collector
            } catch {
                AppLog.diagnostics.error("Diagnostics unavailable: \(error)")
                return nil
            }
        }

        public func didReceive(_ payloads: [MXMetricPayload]) {
            for payload in payloads {
                save(payload.jsonRepresentation(), kind: "metrics")
            }
        }

        public func didReceive(_ payloads: [MXDiagnosticPayload]) {
            for payload in payloads {
                let crashes = payload.crashDiagnostics?.count ?? 0
                let hangs = payload.hangDiagnostics?.count ?? 0
                AppLog.diagnostics.info("Received diagnostics: \(crashes) crashes, \(hangs) hangs")
                save(payload.jsonRepresentation(), kind: "diagnostics")
            }
        }

        private func save(_ data: Data, kind: String) {
            do {
                try store.save(data, kind: kind)
            } catch {
                AppLog.diagnostics.error("Could not save the \(kind) report: \(error)")
            }
        }
    }
#endif
