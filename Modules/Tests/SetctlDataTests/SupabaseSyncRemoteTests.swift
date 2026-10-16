//
//  SupabaseSyncRemoteTests.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/16/26.
//

import Foundation
@testable import SetctlData
import Supabase
import Testing

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var bodies: [Data] = []
    nonisolated(unsafe) static var responseStatus = 200
    nonisolated(unsafe) static var responseBody = Data()

    static func reset(status: Int = 200, body: String = "") {
        requests = []
        bodies = []
        responseStatus = status
        responseBody = Data(body.utf8)
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)
        Self.bodies.append(Self.readBody(of: request))
        let url = request.url ?? URL(fileURLWithPath: "/")
        let response = HTTPURLResponse(
            url: url, statusCode: Self.responseStatus, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

@Suite(.serialized)
struct SupabaseSyncRemoteTests {
    @Test func pullDecodesServerRowsAndAsksForTheNextPage() async throws {
        StubURLProtocol.reset(body: """
        [{"id":"aaaaaaaa-1111-1111-1111-111111111111",
          "user_id":"7cd2758b-b159-47e0-b623-fd9d89440662",
          "started_at":"2026-10-16T12:00:00+00:00","ended_at":null,"note":"fresh",
          "created_at":"2026-10-16T12:00:00.5+00:00","updated_at":"2026-10-16T13:00:00.12+00:00",
          "deleted_at":null,"server_updated_at":"2026-10-16T15:08:12.498312+00:00"}]
        """)
        let remote = try makeRemote()

        let rows = try await remote.pull(
            RemoteWorkout.self, since: Date(timeIntervalSince1970: 1_000_000), limit: 500
        )

        let row = try #require(rows.first)
        #expect(row.id == "aaaaaaaa-1111-1111-1111-111111111111")
        #expect(row.local.id == "AAAAAAAA-1111-1111-1111-111111111111")
        #expect(row.note == "fresh")
        #expect(row.endedAt == nil)
        let base = try #require(ISO8601DateFormatter().date(from: "2026-10-16T15:08:12Z"))
        let serverStamp = try #require(row.serverUpdatedAt)
        #expect(abs(serverStamp.timeIntervalSince(base) - 0.498312) < 0.0001)

        let request = try #require(StubURLProtocol.requests.first)
        let items = try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(request.url?.path == "/rest/v1/workouts")
        #expect(items.contains { $0.name == "order" && $0.value == "server_updated_at.asc.nullslast" })
        #expect(items.contains { $0.name == "limit" && $0.value == "500" })
        #expect(items.contains { $0.name == "server_updated_at" && ($0.value ?? "").hasPrefix("gte.") })
    }

    @Test func pushSendsAnUpsertWithExplicitNulls() async throws {
        StubURLProtocol.reset(status: 201)
        let remote = try makeRemote()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let row = RemoteWorkout(Workout(startedAt: date, createdAt: date, updatedAt: date), userId: UUID().uuidString)

        try await remote.push([row])

        let request = try #require(StubURLProtocol.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/rest/v1/workouts")
        let prefer = request.value(forHTTPHeaderField: "Prefer") ?? ""
        #expect(prefer.contains("resolution=merge-duplicates"))
        #expect(prefer.contains("return=minimal"))
        let items = try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        let columns = items.first { $0.name == "columns" }?.value ?? ""
        #expect(columns.contains("\"ended_at\""))
        #expect(columns.contains("\"note\""))
        #expect(!columns.contains("server_updated_at"))
        let body = try #require(JSONSerialization.jsonObject(with: StubURLProtocol.bodies[0]) as? [[String: Any]])
        #expect(body.count == 1)
        #expect(body[0]["ended_at"] is NSNull)
    }

    @Test func pushOfNoRowsSendsNothing() async throws {
        StubURLProtocol.reset()
        let remote = try makeRemote()

        try await remote.push([RemoteWorkout]())

        #expect(StubURLProtocol.requests.isEmpty)
    }

    private func makeRemote() throws -> SupabaseSyncRemote {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let url = try #require(URL(string: "https://example.supabase.co"))
        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: "test-key",
            options: SupabaseClientOptions(
                auth: .init(accessToken: { "test-token" }),
                global: .init(session: URLSession(configuration: configuration))
            )
        )
        return SupabaseSyncRemote(client: client)
    }
}
