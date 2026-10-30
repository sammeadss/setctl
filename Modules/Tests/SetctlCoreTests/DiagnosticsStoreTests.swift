//
//  DiagnosticsStoreTests.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/30/26.
//

import Foundation
@testable import SetctlCore
import Testing

@Test func savedReportsAreListedNewestFirst() throws {
    let store = makeStore()
    try store.save(Data("a".utf8), kind: "metrics", date: day(1))
    try store.save(Data("b".utf8), kind: "diagnostics", date: day(2))

    let names = store.files().map(\.lastPathComponent)

    #expect(names == ["1970-01-03T00-00-00Z-diagnostics.json", "1970-01-02T00-00-00Z-metrics.json"])
}

@Test func onlyTheNewestReportsAreKept() throws {
    let store = makeStore(limit: 3)
    for number in 1 ... 5 {
        try store.save(Data("x".utf8), kind: "metrics", date: day(Double(number)))
    }

    let names = store.files().map(\.lastPathComponent)

    #expect(names.count == 3)
    #expect(names.first == "1970-01-06T00-00-00Z-metrics.json")
    #expect(names.last == "1970-01-04T00-00-00Z-metrics.json")
}

@Test func anEmptyStoreHasNoFiles() {
    #expect(makeStore().files().isEmpty)
}

private func makeStore(limit: Int = 10) -> DiagnosticsStore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("diagnostics-\(UUID().uuidString)", isDirectory: true)
    return DiagnosticsStore(directory: directory, limit: limit)
}

private func day(_ number: Double) -> Date {
    Date(timeIntervalSince1970: number * 86400)
}
