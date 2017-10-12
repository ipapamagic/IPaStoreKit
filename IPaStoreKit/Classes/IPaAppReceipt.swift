//
//  IPaAppReceipt.swift
//  IPaStoreKit
//
//  Created by IPa Chen on 2017/10/11.
//

import UIKit
import openssl
public typealias IPaAppReceiptValidatorHandler = (Bool,[String:Any]?) -> ()
public typealias IPaIAPReceiptValidatorHandler = (String) -> ()
public enum IPaAppReceiptError:Error {
    case noAppReceipt
    case verifyFail
    case parsePKCS7Fail
    case emptyReceiptContents
    case parseASN1Fail
    case receiptNotSigned
    case receiptSignedDataNotFound
    case invalidSignature
    case appleIncRootCertificateNotFound
    case unableToLoadAppleIncRootCertificate
    case hashValidationFail
}
public enum IPaAppReceiptField: Int
{
    case bundleIdentifier = 2
    case appVersion = 3
    case opaqueValue = 4
    case receiptHash = 5 // SHA-1 Hash
    case inAppPurchaseReceipt = 17 // The receipt for an in-app purchase.
    case originalAppVersion = 19
    case expirationDate = 21
    
    case quantity = 1701
    case productIdentifier = 1702
    case transactionIdentifier = 1703
    case purchaseDate = 1704
    case originalTransactionIdentifier = 1705
    case originalPurchaseDate = 1706
    case subscriptionExpirationDate = 1708
    case webOrderLineItemID = 1711
    case cancellationDate = 1712
    case unknown = -1
}
open class IPaAppReceipt: NSObject {
    var bundleIdentifier = ""
    var appVersion = ""
    var originalAppVersion = ""
    var purchases = [IPaIAPReceipt]()
    var bundleIdentifierData = Data()
    var opaqueValue = Data()
    var receiptHash = Data()
    var expirationDate: String? = ""
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
    
    static open func parseAppReceipt() throws -> IPaAppReceipt {
        guard let receiptUrl = Bundle.main.appStoreReceiptURL ,let receiptData = try? Data(contentsOf: receiptUrl) else {
            throw IPaAppReceiptError.noAppReceipt
        }
        let receiptBio = BIO_new(BIO_s_mem())
        
        defer
        {
            BIO_free(receiptBio)
        }
        
        var values = [UInt8](repeating:0, count:receiptData.count)
        receiptData.copyBytes(to: &values, count: receiptData.count)
        
        BIO_write(receiptBio, values, Int32(receiptData.count))
        
        guard let receiptPKCS7 = d2i_PKCS7_bio(receiptBio, nil) else
        {
            throw IPaAppReceiptError.parsePKCS7Fail
        }
        defer {
            PKCS7_free(receiptPKCS7)
        }
        //check signature existance
        if OBJ_obj2nid(receiptPKCS7.pointee.type) != NID_pkcs7_signed
        {
            throw IPaAppReceiptError.receiptNotSigned
        }
        
        if OBJ_obj2nid(receiptPKCS7.pointee.d.sign.pointee.contents.pointee.type) != NID_pkcs7_data
        {
            throw IPaAppReceiptError.receiptSignedDataNotFound
        }
        
        let certificateData = try appleCertificateData()
        let verified: Int32 = 1
        
        let appleRootBIO = BIO_new(BIO_s_mem())
        
        var appleRootBytes = [UInt8](repeating:0, count:certificateData.count)
        certificateData.copyBytes(to: &appleRootBytes, count: certificateData.count)
        BIO_write(appleRootBIO, appleRootBytes, Int32(certificateData.count))
        
        let appleRootX509 = d2i_X509_bio(appleRootBIO, nil)
        let store = X509_STORE_new()
        
        X509_STORE_add_cert(store, appleRootX509)
        OpenSSL_add_all_digests()
        
        let result = PKCS7_verify(receiptPKCS7, nil, store, nil, nil, 0)
        
        BIO_free(appleRootBIO)
        X509_STORE_free(store)
        EVP_cleanup()
        
        if verified != result
        {
            throw IPaAppReceiptError.invalidSignature
        }
    
        
        
        
        let contents: UnsafeMutablePointer<pkcs7_st> = receiptPKCS7.pointee.d.sign.pointee.contents
        let octets: UnsafeMutablePointer<ASN1_OCTET_STRING> = contents.pointee.d.data
        
        let asn1Data = Data(bytes: octets.pointee.data, count: Int(octets.pointee.length))

        let appReceipt = IPaAppReceipt(asn1Data:asn1Data)
        try appReceipt.verifyHash()
        return appReceipt
        
    }
    fileprivate static func appleCertificateData() throws -> Data
    {
        guard let appleRootURL = Bundle(for: IPaAppReceipt.self).url(forResource: "AppleIncRootCertificate", withExtension: "cer") else
        {
            throw IPaAppReceiptError.appleIncRootCertificateNotFound
        }
        
        let appleRootData = try Data(contentsOf: appleRootURL)
        
        if appleRootData.count == 0
        {
            throw IPaAppReceiptError.unableToLoadAppleIncRootCertificate
        }
        
        return appleRootData
    }
    init(asn1Data:Data) {
        super.init()
        asn1Data.enumerateASN1Attributes({
            attributes in
            if let field = IPaAppReceiptField(rawValue: attributes.type)
            {
                let length = attributes.data.count

                var bytes = [UInt8](repeating:0, count: length)
                attributes.data.copyBytes(to: &bytes, count: length)

                var ptr = UnsafePointer<UInt8>?(bytes)

                switch field
                {
                case .bundleIdentifier:
                    bundleIdentifierData = Data(bytes: bytes, count: length)
                    bundleIdentifier = asn1ReadUTF8String(&ptr, bytes.count)!
                case .appVersion:
                    appVersion = asn1ReadUTF8String(&ptr, bytes.count)!
                case .opaqueValue:
                    opaqueValue = Data(bytes: bytes, count: length)
                case .receiptHash:
                    receiptHash = Data(bytes: bytes, count: length)
                case .inAppPurchaseReceipt:
                    purchases.append(IPaIAPReceipt(asn1Data: attributes.data))
                case .originalAppVersion:
                    originalAppVersion = asn1ReadUTF8String(&ptr, bytes.count)!
                case .expirationDate:
                    let str = asn1ReadASCIIString(&ptr, bytes.count)
                    expirationDate = str
                default:
//                    print("attribute.type = \(attributes.type))")
                    break
                }
            }

        })
    }
    fileprivate func verifyHash() throws {
        var uuidBytes = UIDevice.current.identifierForVendor!.uuid
        let uuidData = Data(bytes: &uuidBytes, count: MemoryLayout.size(ofValue: uuidBytes))
        let opaqueData = opaqueValue
        let bundleIdData = bundleIdentifierData
        
        var hash = Array<CUnsignedChar>(repeating: 0, count: 20)
        var ctx = SHA_CTX()
        
        SHA1_Init(&ctx)
        var bytes = [UInt8](repeating:0, count: uuidData.count)
        uuidData.copyBytes(to: &bytes, count: uuidData.count)
        let uuidDataBytes = UnsafePointer<UInt8>(bytes)
        SHA1_Update(&ctx, uuidDataBytes, uuidData.count)
        
        bytes = [UInt8](repeating:0, count: opaqueData.count)
        opaqueData.copyBytes(to: &bytes, count: opaqueData.count)
        let opaqueDataBytes = UnsafePointer<UInt8>(bytes)
        SHA1_Update(&ctx, opaqueDataBytes, opaqueData.count)
        
        bytes = [UInt8](repeating:0, count: bundleIdData.count)
        bundleIdData.copyBytes(to: &bytes, count: bundleIdData.count)
        let bundleIdDataBytes = UnsafePointer<UInt8>(bytes)
        SHA1_Update(&ctx, bundleIdDataBytes, bundleIdData.count)
        SHA1_Final(&hash, &ctx);
        
        let computedHashData = Data(bytes: &hash, count: hash.count)
        
        if (computedHashData != receiptHash)
        {
            throw IPaAppReceiptError.hashValidationFail
        }
    }
    fileprivate func checkAppBundleID(withReceipt receipt: [String:Any]) -> Bool {
        guard let receiptBundleID = receipt["bundle_id"] as? String,let appBundleID = Bundle.main.bundleIdentifier else {
            return false
        }
        return receiptBundleID == appBundleID
    }
    
    open func validate(_ iapHandler:@escaping IPaIAPReceiptValidatorHandler, completion: @escaping IPaAppReceiptValidatorHandler)
    {
        self.validate(iapHandler,password: nil, completion: completion)
    }
    
    open func validate(_ iapHandler:@escaping IPaIAPReceiptValidatorHandler,password:String?,completion: @escaping IPaAppReceiptValidatorHandler)
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
    fileprivate func validateRequest(_ url: String, data: Data,iapHandler:@escaping IPaIAPReceiptValidatorHandler, complete: @escaping ( Bool, Int?, [String: Any]?) -> ()) {
        
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
