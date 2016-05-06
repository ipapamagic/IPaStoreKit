//
//  IPaIAPReceipt.m
//  IPaSKReceiptVerificator
//
//  Created by IPa Chen on 2015/2/19.
//  Copyright (c) 2015年 A Magic Studio. All rights reserved.
//

#import "IPaIAPReceipt.h"
//#import "IPaSKReceiptVerificator.h"
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
                    _quantity = [self ASN1ReadInteger:&p omax:length];
                    break;
                case IPaIAPReceiptASN1TypeProductIdentifier:
                    _productIdentifier = [self ASN1ReadUTF8String:&p omax:length];
                    break;
                case IPaIAPReceiptASN1TypeTransactionIdentifier:
                    _transactionIdentifier = [self ASN1ReadUTF8String:&p omax:length];
                    break;
                case IPaIAPReceiptASN1TypePurchaseDate:
                {
                    NSString *string = [self ASN1ReadIA5SString:&p omax:length];
                    _purchaseDate = [self formatRFC3339String:string];
                    break;
                }
                case IPaIAPReceiptASN1TypeOriginalTransactionIdentifier:
                    _originalTransactionIdentifier = [self ASN1ReadUTF8String:&p omax:length];
                    break;
                case IPaIAPReceiptASN1TypeOriginalPurchaseDate:
                {
                    NSString *string = [self ASN1ReadIA5SString:&p omax:length];
                    _originalPurchaseDate = [self formatRFC3339String:string];
                    break;
                }
                case IPaIAPReceiptASN1TypeSubscriptionExpirationDate:
                {
                    NSString *string = [self ASN1ReadIA5SString:&p omax:length];
                    _subscriptionExpirationDate = [self formatRFC3339String:string];
                    break;
                }
                case IPaIAPReceiptASN1TypeWebOrderLineItemID:
                    _webOrderLineItemID = [self ASN1ReadInteger:&p omax:length];
                    break;
                case IPaIAPReceiptASN1TypeCancellationDate:
                {
                    NSString *string = [self ASN1ReadIA5SString:&p omax:length];
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


@end
