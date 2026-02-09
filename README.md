# IPaStoreKit

[![Version](https://img.shields.io/badge/version-5.0.0-blue.svg)](https://github.com/ipapamagic/IPaStoreKit)
[![Platform](https://img.shields.io/badge/platform-iOS%2015.0%2B%20%7C%20macOS%2012.0%2B-lightgrey.svg)](https://github.com/ipapamagic/IPaStoreKit)
[![Swift](https://img.shields.io/badge/Swift-5.6-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Modern Swift wrapper for StoreKit 2 with async/await support.

## 🎯 Features

- ✅ **StoreKit 2 Native**: Built on modern StoreKit 2 APIs
- ✅ **Async/Await**: Clean Swift concurrency support
- ✅ **Auto Verification**: Automatic transaction verification
- ✅ **Product Caching**: Built-in product caching for performance
- ✅ **Auto Transaction Handling**: Background transaction monitoring
- ✅ **Subscription Support**: Automatic expiration checking
- ✅ **Unified Logging**: Integration with IPaLog
- ✅ **Type Safe**: Full Swift type safety

## 📋 Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.6+
- Xcode 13.0+

## 📦 Installation

### Swift Package Manager

Add IPaStoreKit to your project using Xcode:

1. Go to **File** → **Add Packages...**
2. Enter the repository URL: `https://github.com/ipapamagic/IPaStoreKit.git`
3. Select **Up to Next Major Version** with `5.0.0`

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ipapamagic/IPaStoreKit.git", from: "5.0.0")
]
```

## 🚀 Quick Start

### 1. Request Products

```swift
import IPaStoreKit

// Request multiple products
let products = try await IPaStoreKit.shared.requestProducts(for: [
    "com.yourapp.premium",
    "com.yourapp.pro"
])

// Request a single product
let product = try await IPaStoreKit.shared.requestProduct(for: "com.yourapp.premium")
```

### 2. Purchase Product

```swift
// Purchase by product ID
do {
    let transaction = try await IPaStoreKit.shared.purchaseProduct("com.yourapp.premium")
    print("Purchase successful: \(transaction.productID)")
} catch IPaStoreKitError.userCancelled {
    print("User cancelled")
} catch IPaStoreKitError.pending {
    print("Purchase pending approval")
} catch {
    print("Purchase failed: \(error)")
}

// Or purchase with Product object
let transaction = try await IPaStoreKit.shared.purchaseProduct(product)
```

### 3. Check Purchase Status

```swift
// Check if a product is purchased
if await IPaStoreKit.shared.isPurchased("com.yourapp.premium") {
    // Enable premium features
}

// Get all purchased products
let purchasedIDs = await IPaStoreKit.shared.getPurchasedProducts()
```

### 4. Restore Purchases

```swift
do {
    let transactions = try await IPaStoreKit.shared.restorePurchases()
    print("Restored \(transactions.count) purchases")
} catch {
    print("Restore failed: \(error)")
}
```

### 5. Listen for Transaction Updates

```swift
// Add a handler for transaction updates (optional)
await IPaStoreKit.shared.addTransactionUpdateHandler { transaction in
    print("Transaction updated: \(transaction.productID)")
    // Update UI or sync with your backend
}
```

## 💡 Usage Examples

### SwiftUI Integration

```swift
import SwiftUI
import IPaStoreKit
import StoreKit

struct StoreView: View {
    @State private var products: [Product] = []
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(products, id: \.id) { product in
                ProductRow(product: product)
            }

            Button("Restore Purchases") {
                Task {
                    try? await IPaStoreKit.shared.restorePurchases()
                }
            }
        }
        .task {
            await loadProducts()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    func loadProducts() async {
        do {
            products = try await IPaStoreKit.shared.requestProducts(for: [
                "com.yourapp.premium",
                "com.yourapp.pro"
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProductRow: View {
    let product: Product
    @State private var isPurchased = false

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(product.displayName)
                    .font(.headline)
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button(product.displayPrice) {
                    Task {
                        await purchase()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .task {
            isPurchased = await IPaStoreKit.shared.isPurchased(product.id)
        }
    }

    func purchase() async {
        do {
            _ = try await IPaStoreKit.shared.purchaseProduct(product)
            isPurchased = true
        } catch IPaStoreKitError.userCancelled {
            // User cancelled, do nothing
        } catch {
            print("Purchase failed: \(error)")
        }
    }
}
```

### App Launch Setup

```swift
import SwiftUI
import IPaStoreKit

@main
struct YourApp: App {
    init() {
        // IPaStoreKit automatically starts monitoring transactions
        // No additional setup needed!
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## 🔒 Transaction Verification

IPaStoreKit automatically verifies all transactions using StoreKit 2's built-in verification:

- ✅ Cryptographic signature validation
- ✅ Automatic fraud detection
- ✅ No server-side validation required (optional)

All transactions returned by IPaStoreKit are already verified and safe to trust.

## 📝 Error Handling

```swift
public enum IPaStoreKitError: LocalizedError {
    case productNotFound        // Product ID not found in App Store
    case verificationFailed     // Transaction verification failed
    case userCancelled         // User cancelled the purchase
    case pending               // Purchase pending approval (Ask to Buy)
    case purchaseFailed(String) // Purchase failed with message
    case restoreFailed(String)  // Restore failed with message
    case unknown               // Unknown error
}
```

## 🔄 Migration from 4.x

### Key Changes

| StoreKit 1 (4.x) | StoreKit 2 (5.x) | Notes |
|------------------|------------------|-------|
| Callback-based | async/await | Modern Swift concurrency |
| `SKProduct` | `Product` | Native StoreKit 2 types |
| `SKPaymentTransaction` | `Transaction` | Auto-verified transactions |
| Manual queue management | Automatic | No more `SKPaymentQueue` |
| Delegate pattern | Async sequence | Cleaner code |

### Migration Example

**Old (4.x):**
```swift
IPaStoreKit.shared.purchaseProduct("premium") { result in
    switch result {
    case .success(let transaction):
        // Handle success
    case .failure(let error):
        // Handle error
    }
}
```

**New (5.x):**
```swift
do {
    let transaction = try await IPaStoreKit.shared.purchaseProduct("premium")
    // Handle success
} catch {
    // Handle error
}
```

## 🐛 Debugging

IPaStoreKit integrates with [IPaLog](https://github.com/ipapamagic/IPaLog) for comprehensive logging:

```
[IPaStoreKit] Initializing StoreKit 2 manager
[IPaStoreKit] Requesting products: ["com.yourapp.premium"]
[IPaStoreKit] Loaded 1 new products
[IPaStoreKit] Starting purchase for: com.yourapp.premium
[IPaStoreKit] Purchase successful: com.yourapp.premium
[IPaStoreKit] Updated purchased products: ["com.yourapp.premium"]
```

## 📄 License

IPaStoreKit is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## 👨‍💻 Author

**IPa Chen** - [@ipapamagic](https://github.com/ipapamagic)

Email: ipapamagic@gmail.com

## 🙏 Acknowledgments

- Built with [StoreKit 2](https://developer.apple.com/storekit/)
- Logging powered by [IPaLog](https://github.com/ipapamagic/IPaLog)

---

Made with ❤️ by A Magic Studio
