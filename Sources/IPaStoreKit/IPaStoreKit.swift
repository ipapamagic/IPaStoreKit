//
//  IPaStoreKit.swift
//  IPaStoreKit
//
//  Created by IPa Chen on 2015/8/11.
//  Updated for StoreKit 2 in 2026/1/8
//  Copyright 2015年 A Magic Studio. All rights reserved.
//

import StoreKit
import IPaLog

/// Errors that can occur during StoreKit operations
public enum IPaStoreKitError: LocalizedError {
    case productNotFound
    case verificationFailed
    case userCancelled
    case pending
    case purchaseFailed(String)
    case restoreFailed(String)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .verificationFailed:
            return "Transaction verification failed"
        case .userCancelled:
            return "User cancelled the purchase"
        case .pending:
            return "Purchase is pending approval"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

/// Main StoreKit 2 manager using modern async/await APIs
@available(iOS 15.0, macOS 12.0, *)
public actor IPaStoreKit {
    /// Shared singleton instance
    public static let shared = IPaStoreKit()

    // MARK: - Private Properties

    /// Cache for loaded products
    private var productsCache: [String: Product] = [:]

    /// Set of purchased product identifiers
    private var purchasedProductIDs: Set<String> = []

    /// Task for observing transaction updates
    private var transactionUpdateTask: Task<Void, Never>?

    /// Handlers for transaction updates
    private var transactionUpdateHandlers: [(Transaction) -> Void] = []

    /// UserDefaults key for caching purchased products
    private let purchasedProductsCacheKey = "IPaStoreKit.PurchasedProducts"

    // MARK: - Initialization

    private init() {
        IPaLog("[IPaStoreKit] Initializing StoreKit 2 manager")

        // Load from cache first for immediate availability
        loadCachedPurchasedProducts()

        // Start observing transaction updates
        transactionUpdateTask = observeTransactionUpdates()

        // Update purchased products from StoreKit (ensures latest state)
        Task {
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionUpdateTask?.cancel()
    }

    // MARK: - Product Requests

    /// Request multiple products by their identifiers
    /// - Parameter productIDs: Array of product identifiers
    /// - Returns: Array of available products
    public func requestProducts(for productIDs: [String]) async throws -> [Product] {
        IPaLog("[IPaStoreKit] Requesting products: \(productIDs)")

        // Check cache first
        let uncachedIDs = productIDs.filter { productsCache[$0] == nil }

        // Load uncached products
        if !uncachedIDs.isEmpty {
            let products = try await Product.products(for: uncachedIDs)

            // Cache the loaded products
            for product in products {
                productsCache[product.id] = product
            }

            IPaLog("[IPaStoreKit] Loaded \(products.count) new products")
        }

        // Return all requested products from cache
        let result = productIDs.compactMap { productsCache[$0] }

        if result.isEmpty {
            IPaLog("[IPaStoreKit] No products found for IDs: \(productIDs)")
        }

        return result
    }

    /// Request a single product by its identifier
    /// - Parameter productID: Product identifier
    /// - Returns: The requested product
    public func requestProduct(for productID: String) async throws -> Product {
        let products = try await requestProducts(for: [productID])

        guard let product = products.first else {
            IPaLog("[IPaStoreKit] Product not found: \(productID)")
            throw IPaStoreKitError.productNotFound
        }

        return product
    }

    // MARK: - Purchase

    /// Purchase a product by its identifier
    /// - Parameter productID: Product identifier to purchase
    /// - Returns: Verified transaction
    @discardableResult
    public func purchaseProduct(_ productID: String) async throws -> Transaction {
        IPaLog("[IPaStoreKit] Starting purchase for: \(productID)")

        let product = try await requestProduct(for: productID)
        return try await purchaseProduct(product)
    }

    /// Purchase a product
    /// - Parameter product: Product to purchase
    /// - Returns: Verified transaction
    @discardableResult
    public func purchaseProduct(_ product: Product) async throws -> Transaction {
        IPaLog("[IPaStoreKit] Purchasing product: \(product.id)")

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerification(verification)

            // Finish the transaction
            await transaction.finish()

            // Update purchased products
            await updatePurchasedProducts()

            IPaLog("[IPaStoreKit] Purchase successful: \(product.id)")
            return transaction

        case .userCancelled:
            IPaLog("[IPaStoreKit] Purchase cancelled by user: \(product.id)")
            throw IPaStoreKitError.userCancelled

        case .pending:
            IPaLog("[IPaStoreKit] Purchase pending approval: \(product.id)")
            throw IPaStoreKitError.pending

        @unknown default:
            IPaLog("[IPaStoreKit] Unknown purchase result")
            throw IPaStoreKitError.unknown
        }
    }

    // MARK: - Restore Purchases

    /// Restore all completed transactions
    /// - Returns: Array of restored transactions
    public func restorePurchases() async throws -> [Transaction] {
        IPaLog("[IPaStoreKit] Starting restore purchases")

        var restoredTransactions: [Transaction] = []

        do {
            // Sync with App Store
            try await AppStore.sync()

            // Iterate through all current entitlements
            for await result in Transaction.currentEntitlements {
                do {
                    let transaction = try checkVerification(result)
                    restoredTransactions.append(transaction)
                    IPaLog("[IPaStoreKit] Restored: \(transaction.productID)")
                } catch {
                    IPaLog("[IPaStoreKit] Failed to verify restored transaction: \(error)")
                }
            }

            // Update purchased products
            await updatePurchasedProducts()

            IPaLog("[IPaStoreKit] Restore completed: \(restoredTransactions.count) transactions")
            return restoredTransactions

        } catch {
            IPaLog("[IPaStoreKit] Restore failed: \(error)")
            throw IPaStoreKitError.restoreFailed(error.localizedDescription)
        }
    }

    // MARK: - Transaction Verification

    /// Verify a transaction result
    /// - Parameter result: Verification result to check
    /// - Returns: Verified transaction
    private func checkVerification<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe

        case .unverified(_, let error):
            IPaLog("[IPaStoreKit] Verification failed: \(error)")
            throw IPaStoreKitError.verificationFailed
        }
    }

    // MARK: - Transaction Updates

    /// Observe transaction updates in the background
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerification(result)

                    IPaLog("[IPaStoreKit] Transaction update: \(transaction.productID)")

                    // Finish the transaction
                    await transaction.finish()

                    // Update purchased products
                    await self.updatePurchasedProducts()

                    // Notify handlers
                    await self.notifyTransactionUpdate(transaction)

                } catch {
                    IPaLog("[IPaStoreKit] Failed to verify transaction update: \(error)")
                }
            }
        }
    }

    /// Add a transaction update handler
    /// - Parameter handler: Closure to handle transaction updates
    public func addTransactionUpdateHandler(_ handler: @escaping (Transaction) -> Void) {
        transactionUpdateHandlers.append(handler)
    }

    /// Remove all transaction update handlers
    public func removeAllTransactionUpdateHandlers() {
        transactionUpdateHandlers.removeAll()
    }

    /// Notify all handlers about a transaction update
    private func notifyTransactionUpdate(_ transaction: Transaction) {
        for handler in transactionUpdateHandlers {
            handler(transaction)
        }
    }

    // MARK: - Purchase Status

    /// Check if a product has been purchased
    /// - Parameter productID: Product identifier to check
    /// - Returns: True if purchased
    public func isPurchased(_ productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
    }

    /// Get all purchased product IDs
    /// - Returns: Set of purchased product identifiers
    public func getPurchasedProducts() -> Set<String> {
        return purchasedProductIDs
    }

    /// Load purchased products from UserDefaults cache
    private func loadCachedPurchasedProducts() {
        if let cachedArray = UserDefaults.standard.array(forKey: purchasedProductsCacheKey) as? [String] {
            purchasedProductIDs = Set(cachedArray)
            IPaLog("[IPaStoreKit] Loaded \(purchasedProductIDs.count) products from cache")
        } else {
            IPaLog("[IPaStoreKit] No cached purchased products found")
        }
    }

    /// Save purchased products to UserDefaults cache
    private func saveCachedPurchasedProducts() {
        let array = Array(purchasedProductIDs)
        UserDefaults.standard.set(array, forKey: purchasedProductsCacheKey)
    }

    /// Update the list of purchased products from current entitlements
    private func updatePurchasedProducts() async {
        var productIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // Check if subscription has expired
                if let expirationDate = transaction.expirationDate,
                   expirationDate < Date() {
                    continue
                }

                productIDs.insert(transaction.productID)
            }
        }

        purchasedProductIDs = productIDs

        // Save to cache for next app launch
        saveCachedPurchasedProducts()

        IPaLog("[IPaStoreKit] Updated purchased products: \(productIDs)")
    }

    // MARK: - App Receipt (for backwards compatibility)

    /// Check if app receipt exists
    public var hasAppReceipt: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return FileManager.default.fileExists(atPath: receiptURL.path)
    }

    /// Get base64 encoded app receipt string
    public var appReceiptString: String? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path) else {
            return nil
        }

        do {
            let receiptData = try Data(contentsOf: receiptURL)
            return receiptData.base64EncodedString()
        } catch {
            IPaLog("[IPaStoreKit] Failed to read receipt: \(error)")
            return nil
        }
    }

    /// Refresh the app receipt (for debugging or if receipt is missing)
    public func refreshReceipt() async throws {
        IPaLog("[IPaStoreKit] Refreshing app receipt")
        try await AppStore.sync()
    }
}
