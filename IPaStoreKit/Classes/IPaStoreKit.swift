//
//  IPaStoreKit.swift
//  IPaStoreKit
//
//  Created by IPa Chen on 2015/8/11.
//  Copyright 2015年 A Magic Studio. All rights reserved.
//

import StoreKit
import IPaReachability
import IPaLog
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
    open var appReceiptString:String? {
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
            FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {

            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)

                return receiptData.base64EncodedString(options: [])

                // Read receiptData
            }
            catch {
                IPaLog(error.localizedDescription)
                
            }
        }
        return nil
    }
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
        
    }
    open func getIAPReceipts(from responseBody:[String:Any]) -> [[String:Any]] {
        let receipt = responseBody["receipt"] as? [String:Any] ?? [String:Any]()
        return receipt["in_app"] as? [[String:Any]] ?? [[String:Any]]()
        
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
        ipaSKRequest.start()
        
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
                if let response = response,let product = response.products.first,product.productIdentifier == productIdentifier {
                    SKPaymentQueue.default().add(SKPayment(product: product))
                }
                else {
                    guard let _ = response else {
                        return
                    }
                    self.handlers.removeValue(forKey: productIdentifier)
                    complete(.failure(IPaStoreKitError.PurchaseFail))
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
    public func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        return true
    }
}


