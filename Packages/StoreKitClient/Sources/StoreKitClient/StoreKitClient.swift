import Foundation
import StoreKit

/// Receipt validation + purchase gating via StoreKit 2.
public enum StoreKitClient {
    public static let proProductID = "app.workspaceterminal.ios.pro"
}

public enum PurchaseStatus: Sendable, Equatable {
    case unknown
    case notPurchased
    case purchased(transactionID: UInt64)

    public var isEntitled: Bool {
        if case .purchased = self { return true }
        return false
    }
}
