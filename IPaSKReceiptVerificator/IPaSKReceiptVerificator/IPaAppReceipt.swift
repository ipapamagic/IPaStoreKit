//
//  IPaAppReceipt.swift
//  IPaSKReceiptVerificator
//
//  Created by IPa Chen on 2015/7/7.
//  Copyright (c) 2015年 A Magic Studio. All rights reserved.
//

import Foundation
import openssl
public class IPaAppReceipt:IPaSKReceipt {
    enum IPaAppReceiptASN1Type :Int32{
        case BundleIdentifier = 2
        case AppVersion = 3
        case OpaqueValue = 4
        case Hash = 5
        case InAppPurchaseReceipt = 17
        case OriginalAppVersion = 19
        case ExpirationDate = 21
    

    }
    var transactionReceipt:NSData

    /** The app’s bundle identifier.
    
    This corresponds to the value of CFBundleIdentifier in the Info.plist file.
    */
    private var _bundleIdentifier:String
    public var bundleIdentifier:String {
        get {
            return _bundleIdentifier
        }
    }
    
    /** The bundle identifier as data, as contained in the receipt. Used to verifiy the receipt's hash.
    @see verifyReceiptHash
    */
    private var _bundleIdentifierData:NSData
    public var bundleIdentifierData:NSData {
        get {
            return _bundleIdentifierData
        }
    }
    
    /** The app’s version number. This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist.
    */
    private var _appVersion:String
    public var appVersion:String {
        get {
            return _appVersion
        }
    }
    
    /** An opaque value used as part of the SHA-1 hash.
    */
    private var _opaqueValue:NSData
    public var opaqueValue:NSData {
        get {
            return _opaqueValue
        }
    }
    
    /** A SHA-1 hash, used to validate the receipt.
    */
    private var _receiptHash:NSData
    public var receiptHash:NSData {
        get {
            return _receiptHash
        }
    }
    
    /** Array of in-app purchases contained in the receipt.
    @see IPaAppReceiptIAP
    */
    private var _inAppPurchases:[IPaIAPReceipt]
    public var inAppPurchases:[IPaIAPReceipt] {
        get {
            return _inAppPurchases
        }
    }
    
    /** The version of the app that was originally purchased. This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist file when the purchase was originally made. In the sandbox environment, the value of this field is always “1.0”.
    */
    private var _originalAppVersion:String
    public var originalAppVersion:String {
        get {
            return _originalAppVersion
        }

    }
    
    /** The date that the app receipt expires. Only for apps purchased through the Volume Purchase Program. If nil, the receipt does not expire. When validating a receipt, compare this date to the current date to determine whether the receipt is expired. Do not try to use this date to calculate any other information, such as the time remaining before expiration.
    */
    private var _expirationDate:NSDate
    public var expirationDate:NSDate {
        get {
            return _expirationDate
        }
    }
    
    public init(ASN1Data:NSData) {
        transactionReceipt = ASN1Data;
        super.init()
        // Explicit casting to avoid errors when compiling as Objective-C++
        enumerateASN1Attributes(UnsafePointer<UInt8>(ASN1Data.bytes), length: ASN1Data.length, usingBlock: {
            (data , type) -> () in
            var p = UnsafePointer<UInt8>(data.bytes)
            let length:Int = data.length
            if let attributeType:IPaAppReceiptASN1Type = IPaAppReceiptASN1Type(rawValue: type) {
                switch (attributeType)
                {
                case .BundleIdentifier:
                    self._bundleIdentifierData = data
                    self._bundleIdentifier = self.ASN1ReadUTF8String(&p, omax: length)

                case .AppVersion:
                    self._appVersion = self.ASN1ReadUTF8String(&p,omax:length)
                case .OpaqueValue:
                    self._opaqueValue = data
                case .Hash:
                    self._receiptHash = data
                case .InAppPurchaseReceipt:
                    let purchase = IPaIAPReceipt(ASN1Data: data)
                    self._inAppPurchases.append(purchase)

                case .OriginalAppVersion:
                    self._originalAppVersion = self.ASN1ReadUTF8String(&p, omax:length)
                case .ExpirationDate:
                    let string = self.ASN1ReadIA5SString(&p, omax: length)
                    self._expirationDate = self.formatRFC3339String(string)
                }
            }
        })
    }
    public func containsInAppPurchase(productIdentifier:String) -> Bool
    {
        let result = _inAppPurchases.filter({
            purchase in
            return (purchase.productIdentifier == productIdentifier)
        })
        return result.count > 0
    }
    public func containsActiveAutoRenewableSubscription(productIdentifier:String, date:NSDate ) -> Bool
    {
        
        var result = _inAppPurchases.filter{
            return  $0.productIdentifier == productIdentifier
        }
            
        result.sort{
            (iap:IPaIAPReceipt,iap2:IPaIAPReceipt) -> Bool in
            return (iap.subscriptionExpirationDate.compare(iap2.subscriptionExpirationDate) == .OrderedAscending)
        }
        if let lastTransaction = result.last {
            return lastTransaction.isActiveAutoRenewableSubscription(date)
        }
        return false
    }
    public func verifyReceiptHash() -> Bool
    {
    // TODO: Getting the uuid in Mac is different. See: https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateLocally.html#//apple_ref/doc/uid/TP40010573-CH1-SW5
        let uuid = UIDevice.currentDevice().identifierForVendor
        let uuidBytes:NSMutableData! = NSMutableData(length: 16)
        uuid.getUUIDBytes(UnsafeMutablePointer(uuidBytes.mutableBytes))

    
    // Order taken from: https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateLocally.html#//apple_ref/doc/uid/TP40010573-CH1-SW5
        var data = NSMutableData()
        data.appendBytes(uuidBytes.bytes, length: uuidBytes.length)
        data.appendData(_opaqueValue)
        data.appendData(_bundleIdentifierData)
        expectedHash = NSMutableData(length: SHA_DIGEST_LENGTH)
    

    SHA1((const uint8_t*)data.bytes, data.length, (uint8_t*)expectedHash.mutableBytes); // Explicit casting to avoid errors when compiling as Objective-C++
    
    return [expectedHash isEqualToData:self.receiptHash];
    }
    - (BOOL)verifyAppReceiptWithBundleID:(NSString*)bundleID
    {
    if (![self.bundleIdentifier isEqualToString:bundleID]) {
    return NO;
    }
    
    if (![self verifyReceiptHash]) {
    return NO;
    }
    return YES;
    }
    + (IPaAppReceipt*)bundleReceipt
    {
    NSURL *URL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSString *path = URL.path;
    const BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:nil];
    if (!exists) return nil;
    
    NSData *data = [self dataFromPCKS7Path:path];
    if (!data) return nil;
    
    IPaAppReceipt *receipt = [[IPaAppReceipt alloc] initWithASN1Data:data];
    return receipt;
    }
    + (NSData*)dataFromPCKS7Path:(NSString*)path
    {
    const char *cpath = [[path stringByStandardizingPath] fileSystemRepresentation];
    FILE *fp = fopen(cpath, "rb");
    if (!fp) return nil;
    
    PKCS7 *p7 = d2i_PKCS7_fp(fp, NULL);
    fclose(fp);
    
    if (!p7) return nil;
    
    NSData *data;
    NSURL *certificateURL = [[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"];
    NSData *certificateData = [NSData dataWithContentsOfURL:certificateURL];
    if (!certificateData || [self verifyPCKS7:p7 withCertificateData:certificateData])
    {
    struct pkcs7_st *contents = p7->d.sign->contents;
    if (PKCS7_type_is_data(contents))
    {
    ASN1_OCTET_STRING *octets = contents->d.data;
    data = [NSData dataWithBytes:octets->data length:octets->length];
    }
    }
    PKCS7_free(p7);
    return data;
    }
    + (BOOL)verifyPCKS7:(PKCS7*)container withCertificateData:(NSData*)certificateData
    { // Based on: https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateLocally.html#//apple_ref/doc/uid/TP40010573-CH1-SW17
    static int verified = 1;
    int result = 0;
    OpenSSL_add_all_digests(); // Required for PKCS7_verify to work
    X509_STORE *store = X509_STORE_new();
    if (store)
    {
    const uint8_t *certificateBytes = (uint8_t *)(certificateData.bytes);
    X509 *certificate = d2i_X509(NULL, &certificateBytes, (long)certificateData.length);
    if (certificate)
    {
    X509_STORE_add_cert(store, certificate);
    
    BIO *payload = BIO_new(BIO_s_mem());
    result = PKCS7_verify(container, NULL, store, NULL, payload, 0);
    BIO_free(payload);
    
    X509_free(certificate);
    }
    }
    X509_STORE_free(store);
    EVP_cleanup(); // Balances OpenSSL_add_all_digests (), perhttp://www.openssl.org/docs/crypto/OpenSSL_add_all_algorithms.html
    
    return result == verified;
    }
    
    - (void)verifyTransactionSuccess:(void (^)())successBlock
    failure:(void (^)(NSError *error))failureBlock
    {
    NSError *error;
    
    NSDictionary *requestContents = @{
    @"receipt-data": [transactionReceipt base64EncodedStringWithOptions:0]
    };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
    options:0
    error:&error];
    
    
    if (!requestData)
    {
    IPaSKLog(@"Failed to serialize receipt into JSON");
    if (failureBlock != nil)
    {
    failureBlock(error);
    }
    return;
    }
    
    static NSString *productionURL = @"https://buy.itunes.apple.com/verifyReceipt";
    
    [self verifyRequestData:requestData url:productionURL success:successBlock failure:failureBlock];
    }
    - (void)verifyRequestData:(NSData*)requestData
    url:(NSString*)urlString
    success:(void (^)())successBlock
    failure:(void (^)(NSError *error))failureBlock
    {
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPBody = requestData;
    request.HTTPMethod = @"POST";
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSError *error;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
    dispatch_async(dispatch_get_main_queue(), ^{
    if (!data)
    {
    IPaSKLog(@"Server Connection Failed");
    NSError *wrapperError = [NSError errorWithDomain:IPaStoreKitErrorDomain code:IPaStoreKitErrorCodeUnableToCompleteVerification userInfo:@{NSUnderlyingErrorKey : error, NSLocalizedDescriptionKey : @"Connection to Apple failed. Check the underlying error for more info."}];
    if (failureBlock != nil)
    {
    failureBlock(wrapperError);
    }
    return;
    }
    NSError *jsonError;
    NSDictionary *responseJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (!responseJSON)
    {
    IPaSKLog(@"Failed To Parse Server Response");
    if (failureBlock != nil)
    {
    failureBlock(jsonError);
    }
    }
    
    static NSString *statusKey = @"status";
    NSInteger statusCode = [responseJSON[statusKey] integerValue];
    
    static NSInteger successCode = 0;
    static NSInteger sandboxCode = 21007;
    if (statusCode == successCode)
    {
    if (successBlock != nil)
    {
    successBlock();
    }
    }
    else if (statusCode == sandboxCode)
    {
    IPaSKLog(@"Verifying Sandbox Receipt");
    // From: https://developer.apple.com/library/ios/#technotes/tn2259/_index.html
    // See also: http://stackoverflow.com/questions/9677193/ios-storekit-can-i-detect-when-im-in-the-sandbox
    // Always verify your receipt first with the production URL; proceed to verify with the sandbox URL if you receive a 21007 status code. Following this approach ensures that you do not have to switch between URLs while your application is being tested or reviewed in the sandbox or is live in the App Store.
    
    static NSString *sandboxURL = @"https://sandbox.itunes.apple.com/verifyReceipt";
    [self verifyRequestData:requestData url:sandboxURL success:successBlock failure:failureBlock];
    }
    else
    {
    IPaSKLog(@"Verification Failed With Code %ld", (long)statusCode);
    NSError *serverError = [NSError errorWithDomain:IPaStoreKitErrorDomain code:statusCode userInfo:nil];
    if (failureBlock != nil)
    {
    failureBlock(serverError);
    }
    }
    });
    });
    }

}