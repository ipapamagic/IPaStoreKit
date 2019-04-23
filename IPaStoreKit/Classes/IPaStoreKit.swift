//
//  IPaStoreKit.swift
//  IPaStoreKit
//
//  Created by IPa Chen on 2015/8/11.
//  Copyright 2015年 A Magic Studio. All rights reserved.
//

import StoreKit
import IPaReachability
public typealias IPaSKCompleteHandler = (SKPaymentTransaction?,Error?) -> ()
public typealias IPaSKRestoreCompleteHandler = ([SKPaymentTransaction]?,Error?) -> ()
public typealias IPaSKProductRequestHandler = (SKProductsRequest,SKProductsResponse?,Error?) -> ()
public enum IPaStoreKitError:Error {
    case isPurchasing
    case PurchaseFail
    case isRestoring
}
open class IPaStoreKit : NSObject,SKPaymentTransactionObserver
{
    public static let shared = IPaStoreKit()
    var requestList = Set<IPaSKRequest>()
    var handlers = [String:IPaSKCompleteHandler]()
    var restoreHandler:IPaSKRestoreCompleteHandler?
    open var hasAppReceipt:Bool {
        get {
            let receiptUrl = Bundle.main.appStoreReceiptURL!
            return FileManager.default.fileExists(atPath: receiptUrl.path)
        }
    }
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    open func refreshReceipts(_ complete: @escaping IPaSKRequestHandler) {
        let request = SKReceiptRefreshRequest(receiptProperties: [SKReceiptPropertyIsRevoked:NSNumber(value :true)])
        let ipaSKRequest = IPaSKRequest(request:request,handler:{
            _ipaSKRequest,error in
            complete(_ipaSKRequest.request,error)
            self.requestList.remove(_ipaSKRequest)
        })
        requestList.insert(ipaSKRequest)
        request.start()
    }
    open func getAppReceipt(_ handler:@escaping (Bool?,IPaAppReceipt?) -> ())
    {
        do {
            guard let receiptUrl = Bundle.main.appStoreReceiptURL ,let receiptData = try? Data(contentsOf: receiptUrl) else {
                handler(nil,nil)
                return
            }
            let appReceipt = try IPaAppReceipt(receiptData:receiptData)
            
            handler(nil,appReceipt)
            let reachability = IPaReachability.sharedInternetReachability
            
            if reachability.currentStatus == .reachableByWWan {
                appReceipt.validate(completion: { receipt in
                    if let receipt = receipt {
                        handler(true,receipt)
                    }
                    else {
                        handler(false,nil)
                    }
                })
            }
            else {
                reachability.addNotificationReceiver(for: "IPaStoreKit.validateReceipt", handler: { reachability in
                    if reachability.currentStatus == .reachableByWWan {
                        appReceipt.validate(completion: { receipt in
                            if let receipt = receipt {
                                handler(true,receipt)
                            }
                            else {
                                handler(false,nil)
                            }
                            reachability.removeNotificationReceiver(for: "IPaStoreKit.validateReceipt")
                            
                        })
                        
                        
                    }
                })
            }
            
        }
        catch {
            handler(false,nil)
        }
    }
    open func requestProductID(_ productID:String, complete:@escaping IPaSKProductRequestHandler)
    {
        let request = SKProductsRequest(productIdentifiers: Set([productID]))
        let ipaSKRequest = IPaSKRequest(productRequest:request,handler:{
            _ipaSKRequest,response,error in
            complete(_ipaSKRequest.request as! SKProductsRequest,response,error)
            self.requestList.remove(_ipaSKRequest)
        })
        requestList.insert(ipaSKRequest)
        request.start()
        
    }
    /*!
    @abstract *Asynchronously* initiates the purchase for the product.
    
    @param productIdentifier the product identifier
    @param complete the completion block.
    */
    public func buyProduct(_ productIdentifier:String ,complete:@escaping IPaSKCompleteHandler) {
        if let _ = handlers[productIdentifier] {
            
            complete(nil,IPaStoreKitError.isPurchasing)
            return
        }
        handlers[productIdentifier] = complete
        _ = IPaStoreKit.shared.requestProductID(productIdentifier, complete: {
            request,response,error in
            if let response = response, let product = response.products.first {
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
            complete(nil,IPaStoreKitError.isRestoring)
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
                    handler(transaction,IPaStoreKitError.PurchaseFail)
                    handlers.removeValue(forKey: productIdentifier)
                case .deferred:
                    handler(transaction,nil)
                case .purchasing:
                    handler(transaction,nil)

                    break
                @unknown default:
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
        self.restoreHandler = nil
    }
    
    // Sent when all transactions from the user's purchase history have successfully been added back to the queue.

    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        
        restoreHandler?(queue.transactions,nil)
        self.restoreHandler = nil
    }
    
    // Sent when the download state has changed.

    public func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload])
    {
        
    }
        
}


