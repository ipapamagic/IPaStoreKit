//
//  IPaReceiptValidator.swift
//  Pods
//
//  Created by IPa Chen on 2017/5/30.
//
//

import UIKit
public typealias IPaReceiptValidatorHandler = (Bool,[String:Any]?) -> ()
public typealias IPaReceiptIAPValidatorHandler = (String) -> ()
class IPaReceiptValidator: NSObject {
    private enum ValidateURL: String {
        case sandbox = "https://sandbox.itunes.apple.com/verifyReceipt"
        case production = "https://buy.itunes.apple.com/verifyReceipt"
    }
    private enum StatusCode: Int {
        case unknown = -2 // No decodable status
        case none = -1 // No status returned
        case valid = 0 // Valid status
        case jsonNotReadable = 21000 // The App Store could not read the JSON object you provided.
        case malformedOrMissingData = 21002 // The data in the receipt-data property was malformed or missing.
        case receiptCouldNotBeAuthenticated = 21003 // The receipt could not be authenticated.
        case sharedSecretNotMatching = 21004 // The shared secret you provided does not match the shared secret on file for your account.
        // Only returned for iOS 6 style transaction receipts for auto-renewable subscriptions.
        case receiptServerUnavailable = 21005 // The receipt server is currently not available.
        case subscriptionExpired = 21006 // This receipt is valid but the subscription has expired. When this status code is returned to your server, the receipt data is also decoded and returned as part of the response.
        // Only returned for iOS 6 style transaction receipts for auto-renewable subscriptions.
        case testReceipt = 21007 //  This receipt is from the test environment, but it was sent to the production environment for verification. Send it to the test environment instead.
        case productionEnvironment = 21008 // This receipt is from the production environment, but it was sent to the test environment for verification. Send it to the production environment instead.
    }
    
    fileprivate func checkAppBundleID(withReceipt receipt: [String:Any]) -> Bool {
        guard let receiptBundleID = receipt["bundle_id"] as? String,let appBundleID = Bundle.main.bundleIdentifier else {
            return false
        }
        return receiptBundleID == appBundleID
    }
    
    func validate(_ iapHandler:@escaping IPaReceiptIAPValidatorHandler, completion: @escaping IPaReceiptValidatorHandler)
    {
        self.validate(iapHandler,password: nil, completion: completion)
    }
        
    func validate(_ iapHandler:@escaping IPaReceiptIAPValidatorHandler,password:String?,completion: @escaping IPaReceiptValidatorHandler)
    {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            completion(false,nil)
            return
        }
        var data:Data?
        do {
            data = try Data(contentsOf: receiptURL)
        }
            
        catch _ {
            completion(false,nil)
            return
        }
        guard let receiptData = data else {
            completion(false,nil)
            return
        }
        let receiptDataString = receiptData.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
        var payload:[String:Any] = ["receipt-data": receiptDataString]
        if let password = password {
            payload["password"] = password
        }
        var payloadData: Data?
        
        do {
            payloadData = try JSONSerialization.data(withJSONObject: payload, options: JSONSerialization.WritingOptions(rawValue: 0))
        }
            
        catch let error as NSError {
            print(error.localizedDescription)
            completion(false,nil)
            return
        }
        guard let wPayloadData = payloadData else {
            completion(false,nil)
            return
        }
        validateRequest(ValidateURL.production.rawValue,data:wPayloadData,iapHandler:iapHandler,complete:{
            success,status,jsonData in
            if success {
                completion(true,jsonData)
                return
            }
            self.validateRequest(ValidateURL.sandbox.rawValue,data:wPayloadData,iapHandler:iapHandler,complete:{
                success,status,jsonData in
                completion(success,jsonData)
            })
            
            
            
        })
    }
    //MARk: handleRequest
    fileprivate func validateRequest(_ url: String, data: Data,iapHandler:@escaping IPaReceiptIAPValidatorHandler, complete: @escaping ( Bool, Int?, [String: Any]?) -> ()) {
        
        // Request url
        guard let requestURL = URL(string: url) else {
            complete(false,nil,nil)
            return
        }
        // Request
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.httpBody = data
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            /// URL request error
            if let _ = error {
                complete(false,nil,nil)
                return
            }
            guard let responseData = data else {
                complete(false,nil,nil)
                return
            }
            
            /// JSON
            var json: [String: Any]?
            
            do {
                json = try JSONSerialization.jsonObject(with: responseData, options: .mutableLeaves) as? [String : Any]
            }
            catch _ {
                complete(false,nil,nil)
                return
            }
            
            /// Parse json
            /// Check for receipt status in json
            guard let parseJSON = json,let status = parseJSON["status"] as? Int else {
                complete(false,nil,nil)
                return
            }
            
            
            /// Check receipt status is valid
            guard status == StatusCode.valid.rawValue else {
                complete(false, status, nil)
                return
            }
            
            /// Handle additional security checks
            
            /// Check receipt send for verification exists in json response
            guard let receipt = parseJSON["receipt"] as? [String:Any] else {
                complete(false,status,nil)
                return
            }
            
            /// Check receipt contains correct bundle and product id for app
            guard self.checkAppBundleID(withReceipt: receipt) else {
                complete(false,status,nil)
                return
            }
            if let inApp = receipt["in_app"] as? [[String:Any]] {
                for receiptInApp in inApp {
                    guard let receiptProductID = receiptInApp["product_id"] as? String else {
                        continue
                    }
                    iapHandler(receiptProductID)
                }
            }
            
            // standard Validation successfull
            complete(true, status, parseJSON)
            
        }.resume()
    }
}

