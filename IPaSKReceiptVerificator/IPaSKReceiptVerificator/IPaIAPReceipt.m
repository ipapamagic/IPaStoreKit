//
//  IPaIAPReceipt.m
//  IPaSKReceiptVerificator
//
//  Created by IPa Chen on 2015/2/19.
//  Copyright (c) 2015年 A Magic Studio. All rights reserved.
//

#import "IPaIAPReceipt.h"
#import "IPaSKReceiptVerificator.h"
#define IPaIAPReceiptASN1TypeQuantity 1701
#define IPaIAPReceiptASN1TypeProductIdentifier 1702
#define IPaIAPReceiptASN1TypeTransactionIdentifier 1703
#define IPaIAPReceiptASN1TypePurchaseDate 1704
#define IPaIAPReceiptASN1TypeOriginalTransactionIdentifier 1705
#define IPaIAPReceiptASN1TypeOriginalPurchaseDate 1706
#define IPaIAPReceiptASN1TypeSubscriptionExpirationDate 1708
#define IPaIAPReceiptASN1TypeWebOrderLineItemID 1711
#define IPaIAPReceiptASN1TypeCancellationDate 1712
@implementation IPaIAPReceipt

- (id)initWithASN1Data:(NSData*)asn1Data
{
    if (self = [super init])
    {
        self.transactionReceipt = asn1Data;
        // Explicit casting to avoid errors when compiling as Objective-C++
        [self enumerateASN1Attributes:(const uint8_t*)asn1Data.bytes length:asn1Data.length usingBlock:^(NSData *data, int type) {
            const uint8_t *p = (const uint8_t*)data.bytes;
            const NSUInteger length = data.length;
            switch (type)
            {
                case IPaIAPReceiptASN1TypeQuantity:
                    _quantity = IPaASN1ReadInteger(&p, length);
                    break;
                case IPaIAPReceiptASN1TypeProductIdentifier:
                    _productIdentifier = IPaASN1ReadUTF8String(&p, length);
                    break;
                case IPaIAPReceiptASN1TypeTransactionIdentifier:
                    _transactionIdentifier = IPaASN1ReadUTF8String(&p, length);
                    break;
                case IPaIAPReceiptASN1TypePurchaseDate:
                {
                    NSString *string = IPaASN1ReadIA5SString(&p, length);
                    _purchaseDate = [self formatRFC3339String:string];
                    break;
                }
                case IPaIAPReceiptASN1TypeOriginalTransactionIdentifier:
                    _originalTransactionIdentifier = IPaASN1ReadUTF8String(&p, length);
                    break;
                case IPaIAPReceiptASN1TypeOriginalPurchaseDate:
                {
                    NSString *string = IPaASN1ReadIA5SString(&p, length);
                    _originalPurchaseDate = [self formatRFC3339String:string];
                    break;
                }
                case IPaIAPReceiptASN1TypeSubscriptionExpirationDate:
                {
                    NSString *string = IPaASN1ReadIA5SString(&p, length);
                    _subscriptionExpirationDate = [self formatRFC3339String:string];
                    break;
                }
                case IPaIAPReceiptASN1TypeWebOrderLineItemID:
                    _webOrderLineItemID = IPaASN1ReadInteger(&p, length);
                    break;
                case IPaIAPReceiptASN1TypeCancellationDate:
                {
                    NSString *string = IPaASN1ReadIA5SString(&p, length);
                    _cancellationDate = [self formatRFC3339String:string];
                    break;
                }
            }
        }];
    }
    return self;
}

- (BOOL)isActiveAutoRenewableSubscriptionForDate:(NSDate*)date
{
    NSAssert(self.subscriptionExpirationDate != nil, @"The product %@ is not an auto-renewable subscription.", self.productIdentifier);
    
    if (self.cancellationDate) return NO;
    
    return [self.purchaseDate compare:date] != NSOrderedDescending && [date compare:self.subscriptionExpirationDate] != NSOrderedDescending;
}

- (void)verifyTransactionSuccess:(void (^)())successBlock
                  failure:(void (^)(NSError *error))failureBlock
{
    NSError *error;
    NSDictionary *requestContents = @{
                                      @"receipt-data": [self.transactionReceipt base64EncodedStringWithOptions:0]
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
    static NSString *requestMethod = @"POST";
    request.HTTPMethod = requestMethod;
    
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
