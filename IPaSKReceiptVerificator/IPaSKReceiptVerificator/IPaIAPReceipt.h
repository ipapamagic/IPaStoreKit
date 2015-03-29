//
//  IPaIAPReceipt.h
//  IPaSKReceiptVerificator
//
//  Created by IPa Chen on 2015/2/19.
//  Copyright (c) 2015年 A Magic Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IPaSKReceipt.h"
/** Represents an in-app purchase in the app receipt.
 */
@interface IPaIAPReceipt : IPaSKReceipt



/** The number of items purchased. This value corresponds to the quantity property of the SKPayment object stored in the transaction’s payment property.
 */
@property (nonatomic, readonly) NSInteger quantity;

/** The product identifier of the item that was purchased. This value corresponds to the productIdentifier property of the SKPayment object stored in the transaction’s payment property.
 */
@property (nonatomic, strong, readonly) NSString *productIdentifier;

/**
 The transaction identifier of the item that was purchased. This value corresponds to the transaction’s transactionIdentifier property.
 */
@property (nonatomic, strong, readonly) NSString *transactionIdentifier;

/** For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier.
 
 This value corresponds to the original transaction’s transactionIdentifier property.
 
 All receipts in a chain of renewals for an auto-renewable subscription have the same value for this field.
 */
@property (nonatomic, strong, readonly) NSString *originalTransactionIdentifier;

/** The date and time that the item was purchased. This value corresponds to the transaction’s transactionDate property.
 
 For a transaction that restores a previous transaction, the purchase date is the date of the restoration. Use `originalPurchaseDate` to get the date of the original transaction.
 
 In an auto-renewable subscription receipt, this is always the date when the subscription was purchased or renewed, regardles of whether the transaction has been restored
 */
@property (nonatomic, strong, readonly) NSDate *purchaseDate;

/** For a transaction that restores a previous transaction, the date of the original transaction.
 
 This value corresponds to the original transaction’s transactionDate property.
 
 In an auto-renewable subscription receipt, this indicates the beginning of the subscription period, even if the subscription has been renewed.
 */
@property (nonatomic, strong, readonly) NSDate *originalPurchaseDate;

/**
 The expiration date for the subscription.
 
 Only present for auto-renewable subscription receipts.
 */
@property (nonatomic, strong, readonly) NSDate *subscriptionExpirationDate;

/** For a transaction that was canceled by Apple customer support, the date of the cancellation.
 */
@property (nonatomic, strong, readonly) NSDate *cancellationDate;

/** The primary key for identifying subscription purchases.
 */
@property (nonatomic, readonly) NSInteger webOrderLineItemID;

/*
 original transaction receipt data
 */
@property (nonatomic,strong) NSData* transactionReceipt;
/** Returns an initialized in-app purchase from the given data.
 @param asn1Data ASN1 data
 @return An initialized in-app purchase from the given data.
 */
- (id)initWithASN1Data:(NSData*)asn1Data;

/** Returns whether the auto renewable subscription is active for the given date.
 @param date The date in which the auto-renewable subscription should be active. If you are using the current date, you might not want to take it from the device in case the user has changed it.
 @return YES if the auto-renewable subscription is active for the given date, NO otherwise.
 @warning Auto-renewable subscription lapses are possible. If you are checking against the current date, you might want to deduct some time as tolerance.
 @warning If this method fails Apple recommends to refresh the receipt and try again once.
 */
- (BOOL)isActiveAutoRenewableSubscriptionForDate:(NSDate*)date;


@end
