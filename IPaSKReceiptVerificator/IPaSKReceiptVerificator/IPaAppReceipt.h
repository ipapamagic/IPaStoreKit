//
//  IPaAppReceipt.m
//  IPaSKReceiptVerificator


//
//  RMAppReceipt.h
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

#import <Foundation/Foundation.h>
#import "IPaSKReceipt.h"
/** Represents the app receipt.
 */
@interface IPaAppReceipt : IPaSKReceipt

/** The app’s bundle identifier. 
 
 This corresponds to the value of CFBundleIdentifier in the Info.plist file.
 */
@property (nonatomic, strong, readonly) NSString *bundleIdentifier;

/** The bundle identifier as data, as contained in the receipt. Used to verifiy the receipt's hash.
 @see verifyReceiptHash
 */
@property (nonatomic, strong, readonly) NSData *bundleIdentifierData;

/** The app’s version number. This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist.
 */
@property (nonatomic, strong, readonly) NSString *appVersion;

/** An opaque value used as part of the SHA-1 hash.
 */
@property (nonatomic, strong, readonly) NSData *opaqueValue;

/** A SHA-1 hash, used to validate the receipt.
 */
@property (nonatomic, strong, readonly) NSData *receiptHash;

/** Array of in-app purchases contained in the receipt.
 @see IPaAppReceiptIAP
 */
@property (nonatomic, strong, readonly) NSArray *inAppPurchases;

/** The version of the app that was originally purchased. This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist file when the purchase was originally made. In the sandbox environment, the value of this field is always “1.0”.
 */
@property (nonatomic, strong, readonly) NSString *originalAppVersion;

/** The date that the app receipt expires. Only for apps purchased through the Volume Purchase Program. If nil, the receipt does not expire. When validating a receipt, compare this date to the current date to determine whether the receipt is expired. Do not try to use this date to calculate any other information, such as the time remaining before expiration.
 */
@property (nonatomic, strong, readonly) NSDate *expirationDate;

/** Returns an initialized app receipt from the given data.
 @param asn1Data ASN1 data
 @return An initialized app receipt from the given data.
 */
- (id)initWithASN1Data:(NSData*)asn1Data;

/** Returns whether there is an in-app purchase in the receipt for the given product.
 @param productIdentifier The identifier of the product.
 @return YES if there is an in-app purchase for the given product, NO otherwise.
 */
- (BOOL)containsInAppPurchaseOfProductIdentifier:(NSString*)productIdentifier;

/** Returns whether the receipt contains an active auto-renewable subscription for the given product identifier and for the given date.
 @param productIdentifier The identifier of the auto-renewable subscription.
 @param date The date in which the latest auto-renewable subscription should be active. If you are using the current date, you might not want to take it from the device in case the user has changed it.
 @return YES if the latest auto-renewable subscription is active for the given date, NO otherwise.
 @warning Auto-renewable subscription lapses are possible. If you are checking against the current date, you might want to deduct some time as tolerance.
 @warning If this method fails Apple recommends to refresh the receipt and try again once.
 */
- (BOOL)containsActiveAutoRenewableSubscriptionOfProductIdentifier:(NSString *)productIdentifier forDate:(NSDate *)date;

/** Returns wheter the receipt hash corresponds to the device's GUID by calcuting the expected hash using the GUID, bundleIdentifierData and opaqueValue.
 @return YES if the hash contained in the receipt corresponds to the device's GUID, NO otherwise.
 */
- (BOOL)verifyReceiptHash;




- (BOOL)verifyAppReceiptWithBundleID:(NSString*)bundleID;
/**
 Returns the app receipt contained in the bundle, if any and valid. Extracts the receipt in ASN1 from the PKCS #7 container, and then parses the ASN1 data into a IPaAppReceipt instance. If an Apple Root certificate is available, it will also verify that the signature of the receipt is valid.
 @return The app receipt contained in the bundle, or nil if there is no receipt or if it is invalid.
 @see refreshReceipt
 @see setAppleRootCertificateURL:
 */
+ (IPaAppReceipt*)bundleReceipt;


@end
