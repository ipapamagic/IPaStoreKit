//
//  IPaStoreKit.swift
//  IPaStoreKit
//
//  Created by IPa Chen on 2015/8/11.
//  Copyright 2015年 A Magic Studio. All rights reserved.
//

import StoreKit
public typealias IPaSKCompleteHandler = (SKPaymentTransaction?,Error?) -> ()
public typealias IPaSKRestoreCompleteHandler = ([SKPaymentTransaction]?,Error?) -> ()
enum IPaSKError:Int {
    case isPurchasing = 0
    case PurchaseFail
    case isRestoring
}
public class IPaStoreKit : NSObject,SKPaymentTransactionObserver
{
    public static let shared = IPaStoreKit()
    var requestList = Set<IPaSKProductRequest>()
    var handlers = [String:IPaSKCompleteHandler]()
    var restoreHandler:IPaSKRestoreCompleteHandler?
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    /*!
    @abstract *Asynchronously* initiates the purchase for the product.
    
    @param productIdentifier the product identifier
    @param complete the completion block.
    */
    public func buyProduct(_ productIdentifier:String ,complete:@escaping IPaSKCompleteHandler) {
        if let _ = handlers[productIdentifier] {
            let error = NSError(domain: "com.IPaStoreKit", code: IPaSKError.isPurchasing.rawValue, userInfo: nil)
            complete(nil,error)
            return
        }
        handlers[productIdentifier] = complete
        _ = IPaStoreKit.shared.requestProductID(productIdentifier, complete: {
            request,response in
            if let product = response.products.first {
                SKPaymentQueue.default().add(SKPayment(product: product))
            }
        })
    }
    /*!
    @abstract *Asynchronously* restore the purchases for the product.
    @param complete the completion block.
    */
    public func restorePurcheses(complete:@escaping IPaSKRestoreCompleteHandler) {
        if restoreHandler != nil {
            let error = NSError(domain: "com.IPaStoreKit", code: IPaSKError.isRestoring.rawValue, userInfo: nil)
            complete(nil,error)
        }
        else {
            restoreHandler = complete
        }
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    //MARK: SKPaymentTransactionObserver
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        let transactions = transactions 
        for transaction in transactions {
            let productIdentifier = transaction.payment.productIdentifier
            if let handler = handlers[productIdentifier] {
               
                switch (transaction.transactionState) {
                case .purchased,.restored:
                    queue.finishTransaction(transaction)
                    handler(transaction,nil)
                    handlers.removeValue(forKey: productIdentifier)
                case .failed:
                    queue.finishTransaction(transaction)
                    let error = NSError(domain: "com.IPaStoreKit", code: IPaSKError.PurchaseFail.rawValue, userInfo: nil)
                    handler(transaction,error)
                    handlers.removeValue(forKey: productIdentifier)
                case .deferred:
                    handler(transaction,nil)
                case .purchasing:
                    handler(transaction,nil)

                    break
                }
                
            }
        };
    }
    
    // Sent when transactions are removed from the queue (via finishTransaction:).

    public func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
    // Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {

        restoreHandler?(nil,error)
    }
    
    // Sent when all transactions from the user's purchase history have successfully been added back to the queue.

    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        
        restoreHandler?(queue.transactions,nil)
    }
    
    // Sent when the download state has changed.

    public func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload])
    {
        
    }
    
    
    //MARK: Validator
    public func validate(_ iapHandler:@escaping IPaReceiptIAPValidatorHandler,complete:@escaping IPaReceiptValidatorHandler) {
        let validator = IPaReceiptValidator()
        validator.validate(iapHandler,completion:complete)
        
    }
    
}

extension IPaStoreKit:SKProductsRequestDelegate
{
    //MARK: SKRequest Product
    public func requestProductID(_ productID:String, complete:@escaping IPaSKProductRequestHandler)
    {
        let request = IPaSKProductRequest(productIdentifiers: Set([productID]),handler:complete)
        
        request.delegate = self
        requestList.insert(request)
        request.start()
        
    }
    //MARK: SKProductsRequestDelegate
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse)
    {
        guard let ipaSKRequest = request as? IPaSKProductRequest else
        {
            return
        }
        ipaSKRequest.handler?(request,response);
        requestList.remove(ipaSKRequest)
    }
}

