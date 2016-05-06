//
//  IPaStoreKit.swift
//  IPaStoreKit
//
//  Created by IPa Chen on 2015/8/11.
//  Copyright 2015年 A Magic Studio. All rights reserved.
//

import StoreKit
public typealias IPaSKCompleteHandler = (SKPaymentTransaction?,NSError?) -> ()
public typealias IPaSKRestoreCompleteHandler = ([SKPaymentTransaction]?,NSError?) -> ()
enum IPaSKError:Int {
    case isPurchasing = 0
    case PurchaseFail
    case isRestoring
}
public class IPaStoreKit : NSObject,SKPaymentTransactionObserver
{
    static func sharedInstance() -> IPaStoreKit {
        
        struct Static {
            static var onceToken : dispatch_once_t = 0
            static var instance : IPaStoreKit? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = IPaStoreKit()
            SKPaymentQueue.defaultQueue().addTransactionObserver(Static.instance!)
        }
        return Static.instance!
        
    }
    var handlers = [String:IPaSKCompleteHandler]()
    var restoreHandler:IPaSKRestoreCompleteHandler?
    /*!
    @abstract *Asynchronously* initiates the purchase for the product.
    
    @param productIdentifier the product identifier
    @param complete the completion block.
    */
    public func buyProduct(productIdentifier:String ,complete:IPaSKCompleteHandler) {
        if let _ = handlers[productIdentifier] {
            let error = NSError(domain: "com.IPaStoreKit", code: IPaSKError.isPurchasing.rawValue, userInfo: nil)
            complete(nil,error)
            return
        }
        handlers[productIdentifier] = complete
        IPaSKProductRequest.requestProductID(productIdentifier, complete: {
            request,response in
            if let product = response.products.first {
                SKPaymentQueue.defaultQueue().addPayment(SKPayment(product: product))
            }
        })
    }
    /*!
    @abstract *Asynchronously* restore the purchases for the product.
    @param complete the completion block.
    */
    public func restorePurcheses(complete:IPaSKRestoreCompleteHandler) {
        if restoreHandler != nil {
            let error = NSError(domain: "com.IPaStoreKit", code: IPaSKError.isRestoring.rawValue, userInfo: nil)
            complete(nil,error)
        }
        SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
    }
    
    //MARK: SKPaymentTransactionObserver
    public func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        let transactions = transactions 
        for transaction in transactions {
            let productIdentifier = transaction.payment.productIdentifier
            if let handler = handlers[productIdentifier] {
               
                switch (transaction.transactionState) {
                case .Purchased,.Restored:
                    queue.finishTransaction(transaction)
                    handler(transaction,nil)
                    handlers.removeValueForKey(productIdentifier)
                case .Failed:
                    queue.finishTransaction(transaction)
                    let error = NSError(domain: "com.IPaStoreKit", code: IPaSKError.PurchaseFail.rawValue, userInfo: nil)
                    handler(transaction,error)
                    handlers.removeValueForKey(productIdentifier)
                case .Deferred:
                    handler(transaction,nil)
                case .Purchasing:
                    handler(transaction,nil)

                    break
                }
                
            }
        };
    }
    
    // Sent when transactions are removed from the queue (via finishTransaction:).

    public func paymentQueue(queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
    // Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
    
    public func paymentQueue(queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: NSError) {

        restoreHandler?(nil,error)
    }
    
    // Sent when all transactions from the user's purchase history have successfully been added back to the queue.

    public func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue) {
        
        restoreHandler?(queue.transactions,nil)
    }
    
    // Sent when the download state has changed.

    public func paymentQueue(queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload])
    {
        
    }
}

