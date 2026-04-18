import Testing
@testable import StoreKitClient

@Suite("StoreKitClient smoke")
struct StoreKitClientTests {
    @Test("Pro product id is namespaced")
    func proProductId() {
        #expect(StoreKitClient.proProductID.hasPrefix("app.workspaceterminal"))
    }

    @Test("Purchased status is entitled")
    func purchasedIsEntitled() {
        #expect(PurchaseStatus.purchased(transactionID: 1).isEntitled)
        #expect(!PurchaseStatus.notPurchased.isEntitled)
        #expect(!PurchaseStatus.unknown.isEntitled)
    }
}
