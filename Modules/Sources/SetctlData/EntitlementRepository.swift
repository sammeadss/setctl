//
//  EntitlementRepository.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/12/26.
//

import Foundation
import StoreKit

public struct EntitlementRepository: Sendable {
    public static let proMonthlyID = "com.stay.Setctl.pro.monthly"

    public init() {}

    public func fetchProProduct() async throws -> Product? {
        try await Product.products(for: [Self.proMonthlyID]).first
    }

    public func purchase(_ product: Product, accountToken: UUID) async throws -> Bool {
        let result = try await product.purchase(options: [.appAccountToken(accountToken)])

        switch result {
        case let .success(verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    public var entitlementUpdates: AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task {
                await continuation.yield(currentlyEntitled())

                for await result in Transaction.updates {
                    if let transaction = try? checkVerified(result) {
                        await transaction.finish()
                    }
                    await continuation.yield(currentlyEntitled())
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func currentlyEntitled() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result), transaction.productID == Self.proMonthlyID {
                return true
            }
        }
        return false
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw EntitlementError.failedVerification
        case let .verified(safe):
            return safe
        }
    }
}

public enum EntitlementError: Error {
    case failedVerification
}
