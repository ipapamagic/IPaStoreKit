//
//  IPaAppReceipt.m
//  IPaSKReceiptVerificator

//
//  RMAppReceipt.m
//  RMStore
//
//  Created by Hermes on 10/12/13.
//  Copyright (c) 2013 Robot Media. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "IPaAppReceipt.h"
#import <UIKit/UIKit.h>
#import "IPaIAPReceipt.h"
#import "IPaSKReceiptVerificator.h"
#import <openssl/sha.h>
#import <openssl/objects.h>
#import <openssl/x509.h>
#define IPaAppReceiptASN1TypeBundleIdentifier 2
#define IPaAppReceiptASN1TypeAppVersion 3
#define IPaAppReceiptASN1TypeOpaqueValue 4
#define IPaAppReceiptASN1TypeHash 5
#define IPaAppReceiptASN1TypeInAppPurchaseReceipt 17
#define IPaAppReceiptASN1TypeOriginalAppVersion 19
#define IPaAppReceiptASN1TypeExpirationDate 21


@implementation IPaAppReceipt
{
    NSData *transactionReceipt;
}
- (id)initWithASN1Data:(NSData*)asn1Data
{
    if (self = [super init])
    {
        transactionReceipt = asn1Data;
        NSMutableArray *purchases = [NSMutableArray array];
         // Explicit casting to avoid errors when compiling as Objective-C++
        [self enumerateASN1Attributes:(const uint8_t*)asn1Data.bytes length:asn1Data.length usingBlock:^(NSData *data, int type) {
            const uint8_t *s = (const uint8_t*)data.bytes;
            const NSUInteger length = data.length;
            switch (type)
            {
                case IPaAppReceiptASN1TypeBundleIdentifier:
                    _bundleIdentifierData = data;
                    _bundleIdentifier = IPaASN1ReadUTF8String(&s, length);
                    break;
                case IPaAppReceiptASN1TypeAppVersion:
                    _appVersion = IPaASN1ReadUTF8String(&s, length);
                    break;
                case IPaAppReceiptASN1TypeOpaqueValue:
                    _opaqueValue = data;
                    break;
                case IPaAppReceiptASN1TypeHash:
                    _receiptHash = data;
                    break;
                case IPaAppReceiptASN1TypeInAppPurchaseReceipt:
                {
                    IPaIAPReceipt *purchase = [[IPaIAPReceipt alloc] initWithASN1Data:data];
                    [purchases addObject:purchase];
                    break;
                }
                case IPaAppReceiptASN1TypeOriginalAppVersion:
                    _originalAppVersion = IPaASN1ReadUTF8String(&s, length);
                    break;
                case IPaAppReceiptASN1TypeExpirationDate:
                {
                    NSString *string = IPaASN1ReadIA5SString(&s, length);
                    _expirationDate = [self formatRFC3339String:string];
                    break;
                }
            }
        }];
        _inAppPurchases = purchases;
    }
    return self;
}

- (BOOL)containsInAppPurchaseOfProductIdentifier:(NSString*)productIdentifier
{
    for (IPaIAPReceipt *purchase in _inAppPurchases)
    {
        if ([purchase.productIdentifier isEqualToString:productIdentifier]) return YES;
    }
    return NO;
}

-(BOOL)containsActiveAutoRenewableSubscriptionOfProductIdentifier:(NSString *)productIdentifier forDate:(NSDate *)date
{
    IPaIAPReceipt *lastTransaction = nil;
    
    for (IPaIAPReceipt *iap in [self inAppPurchases])
    {
        if (![iap.productIdentifier isEqualToString:productIdentifier]) continue;
        
        if (!lastTransaction || [iap.subscriptionExpirationDate compare:lastTransaction.subscriptionExpirationDate] == NSOrderedDescending)
        {
            lastTransaction = iap;
        }
    }
    
    return [lastTransaction isActiveAutoRenewableSubscriptionForDate:date];
}

- (BOOL)verifyReceiptHash
{
    // TODO: Getting the uuid in Mac is different. See: https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateLocally.html#//apple_ref/doc/uid/TP40010573-CH1-SW5
    NSUUID *uuid = [[UIDevice currentDevice] identifierForVendor];
    unsigned char uuidBytes[16];
    [uuid getUUIDBytes:uuidBytes];
    
    // Order taken from: https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateLocally.html#//apple_ref/doc/uid/TP40010573-CH1-SW5
    NSMutableData *data = [NSMutableData data];
    [data appendBytes:uuidBytes length:sizeof(uuidBytes)];
    [data appendData:self.opaqueValue];
    [data appendData:self.bundleIdentifierData];
    
    NSMutableData *expectedHash = [NSMutableData dataWithLength:SHA_DIGEST_LENGTH];
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
@end
