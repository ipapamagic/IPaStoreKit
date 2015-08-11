//
//  IPaStoreKit.swift
//  IPaStoreKit
//
//  Created by IPa Chen on 2015/8/11.
//  Copyright 2015年 A Magic Studio. All rights reserved.
//

import StoreKit
typealias IPaSKCompleteHandler = (SKPaymentTransaction?,NSError?) -> ()
typealias IPaSKRestoreCompleteHandler = ([SKPaymentTransaction]?,NSError?) -> ()
enum IPaSKError:Int {
    case isPurchasing = 0
    case PurchaseFail
    case isRestoring
}
class IPaStoreKit : NSObject,SKPaymentTransactionObserver
{
    class var sharedInstance : IPaStoreKit {
        struct Static {
            static var onceToken : dispatch_once_t = 0
            static var instance : IPaStoreKit? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = IPaStoreKit()
            SKPaymentQueue.defaultQueue().addTransactionObserver(Static.instance)
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
    func buyProduct(productIdentifier:String ,complete:IPaSKCompleteHandler) {
        if let handler = handlers[productIdentifier] {
            let error = NSError(domain: "com.IPaStoreKit", code: IPaSKError.isPurchasing.rawValue, userInfo: nil)
            complete(nil,error)
            return
        }
        handlers[productIdentifier] = complete
        IPaSKProductRequest.requestProductID(productIdentifier, complete: {
            request,response in
            if let product = response.products.first as? SKProduct {
                SKPaymentQueue.defaultQueue().addPayment(SKPayment(product: product))
            }
        })
    }
    /*!
    @abstract *Asynchronously* restore the purchases for the product.
    @param complete the completion block.
    */
    func restorePurcheses(complete:IPaSKRestoreCompleteHandler) {
        if restoreHandler != nil {
            let error = NSError(domain: "com.IPaStoreKit", code: IPaSKError.isRestoring.rawValue, userInfo: nil)
            complete(nil,error)
        }
        SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
    }
    
    //MARK: SKPaymentTransactionObserver
    func paymentQueue(queue: SKPaymentQueue!, updatedTransactions transactions: [AnyObject]!) {
        let transactions = transactions as! [SKPaymentTransaction]
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
                    
                default:
                    handler(transaction,nil)
                    break
                }

            }
        };
    }
    
    // Sent when transactions are removed from the queue (via finishTransaction:).

    func paymentQueue(queue: SKPaymentQueue!, removedTransactions transactions: [AnyObject]!) {
        
    }
    
    // Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
    
    func paymentQueue(queue: SKPaymentQueue!, restoreCompletedTransactionsFailedWithError error: NSError!) {

        restoreHandler?(nil,error)
    }
    
    // Sent when all transactions from the user's purchase history have successfully been added back to the queue.

    func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue!) {
        if let transactions = queue.transactions as? [SKPaymentTransaction] {
            restoreHandler?(transactions,nil)
        }
    }
    
    // Sent when the download state has changed.

    func paymentQueue(queue: SKPaymentQueue!, updatedDownloads downloads: [AnyObject]!)
    {
        
    }
}

