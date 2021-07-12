//
//  IPaStoreKit.swift
//  IPaStoreKit
//
//  Created by IPa Chen on 2015/8/11.
//  Copyright 2015年 A Magic Studio. All rights reserved.
//

import StoreKit
import IPaReachability
public typealias IPaSKCompleteHandler = (Result<SKPaymentTransaction,Error>) -> ()
public typealias IPaSKRestoreCompleteHandler = (Result<[SKPaymentTransaction],Error>) -> ()
public typealias IPaSKProductRequestHandler = (Result<(SKProductsRequest,SKProductsResponse?),Error>) -> ()
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
    let reachability:IPaReachability = IPaReachability.forInternetConnection()!
    var iapVerifiedObserver:NSObjectProtocol?
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
            _ipaSKRequest,result in
            let newResult = result.flatMap { _ in
                return Result<SKRequest,Error>.success(_ipaSKRequest.request)
            }
            complete(newResult)
            self.requestList.remove(_ipaSKRequest)
        })
        requestList.insert(ipaSKRequest)
        request.start()
    }
    open func getVerifiedReceipts(_ handler:@escaping ([IPaIAPReceipt]) -> ()) {
        let status = self.reachability.currentStatus
        if status != .notReachable {
            self.doVerifyIap(handler)
        }
        else {
            iapVerifiedObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: IPaReachability.kIPaReachabilityChangedNotification), object: nil, queue: OperationQueue.main, using: {
                    noti in
                    self.doVerifyIap(handler)
                })
            _ = reachability.startNotifier()
        }
        
    }
    fileprivate func doVerifyIap(_ handler:@escaping ([IPaIAPReceipt]) -> ()) {
        self.getAppReceipt({
            validated,receipt in
            guard let appReceipt = receipt,let validated = validated,validated else {
                return
            }
            handler(appReceipt.purchases)
            self.reachability.stopNotifier()
            if let iapVerifiedObserver = self.iapVerifiedObserver {
                NotificationCenter.default.removeObserver(iapVerifiedObserver)
                self.iapVerifiedObserver = nil
            }
        })
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
            
            if !reachability.isNotReachable {
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
                    if !reachability.isNotReachable {
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
            _ipaSKRequest,result in
            let newResult = result.flatMap { response in
                return Result<(SKProductsRequest,SKProductsResponse?),Error>.success((_ipaSKRequest.request as! SKProductsRequest,response))
            }
            complete(newResult)
            
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
    public func purchaseProduct(_ productIdentifier:String ,complete:@escaping IPaSKCompleteHandler) {
        if let _ = handlers[productIdentifier] {
            
            complete(.failure(IPaStoreKitError.isPurchasing))
            return
        }
        handlers[productIdentifier] = complete
        IPaStoreKit.shared.requestProductID(productIdentifier, complete: {
            result in
            
            switch result {
            case .success(let (_,response)):
                if let response = response,let product = response.products.first  {
                    SKPaymentQueue.default().add(SKPayment(product: product))
                }
            case .failure(let error):
                self.handlers.removeValue(forKey: productIdentifier)
                complete(.failure(error))
            }
        })
    }
    /*!
    @abstract *Asynchronously* restore the purchases for the product.
    @param complete the completion block.
    */
    public func restorePurcheses(complete:@escaping IPaSKRestoreCompleteHandler) {
        if restoreHandler != nil {
            complete(.failure(IPaStoreKitError.isRestoring))
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
                    handler(.success(transaction))
                    handlers.removeValue(forKey: productIdentifier)
                case .failed:
                    queue.finishTransaction(transaction)
                    handler(.failure(IPaStoreKitError.PurchaseFail))
                    
                    handlers.removeValue(forKey: productIdentifier)
                case .deferred:
                    break
                case .purchasing:
                    

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

        self.restoreHandler?(.failure(error))
        self.restoreHandler = nil
    }
    
    // Sent when all transactions from the user's purchase history have successfully been added back to the queue.

    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        
        self.restoreHandler?(.success(queue.transactions))
        self.restoreHandler = nil
    }
    
    // Sent when the download state has changed.

    public func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload])
    {
        
    }
        
}


