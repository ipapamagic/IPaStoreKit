//
//  IPaIAPReceipt.swift
//  IPaSKReceiptVerificator
//
//  Created by IPa Chen on 2015/7/6.
//  Copyright (c) 2015年 A Magic Studio. All rights reserved.
//

import Foundation
public class IPaIAPReceipt : IPaSKReceipt {
    enum IPaIAPReceiptASN1Type:Int32 {
        case Quantity = 1701
        case ProductIdentifier = 1702
        case TransactionIdentifier = 1703
        case PurchaseDate = 1704
        case OriginalTransactionIdentifier = 1705
        case OriginalPurchaseDate = 1706
        case SubscriptionExpirationDate = 1708
        case WebOrderLineItemID = 1711
        case CancellationDate = 1712
    }
    /** The number of items purchased. This value corresponds to the quantity property of the SKPayment object stored in the transaction’s payment property.
    */
    private var _quantity:Int32 = 0
    public var quantity:Int32 {
        get {
           return _quantity
        }
    }
    /** The product identifier of the item that was purchased. This value corresponds to the productIdentifier property of the SKPayment object stored in the transaction’s payment property.
    */
    private var _productIdentifier = ""
    public var productIdentifier:String {
        get {
            return _productIdentifier
        }
    }
    
    /**
    The transaction identifier of the item that was purchased. This value corresponds to the transaction’s transactionIdentifier property.
    */
    private var _transactionIdentifier = ""
    public var transactionIdentifier:String {
        get {
            return _transactionIdentifier
        }
    }
    
    
    /** For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier.
    
    This value corresponds to the original transaction’s transactionIdentifier property.
    
    All receipts in a chain of renewals for an auto-renewable subscription have the same value for this field.
    */
    private var _originalTransactionIdentifier = ""
    public var originalTransactionIdentifier:String {
        get {
            return _originalTransactionIdentifier
        }
    }
    /** The date and time that the item was purchased. This value corresponds to the transaction’s transactionDate property.
    
    For a transaction that restores a previous transaction, the purchase date is the date of the restoration. Use `originalPurchaseDate` to get the date of the original transaction.
    
    In an auto-renewable subscription receipt, this is always the date when the subscription was purchased or renewed, regardles of whether the transaction has been restored
    */
    lazy private var _purchaseDate = NSDate()
    public var purchaseDate:NSDate {
        get {
            return _purchaseDate
        }
    }
    /** For a transaction that restores a previous transaction, the date of the original transaction.
    
    This value corresponds to the original transaction’s transactionDate property.
    
    In an auto-renewable subscription receipt, this indicates the beginning of the subscription period, even if the subscription has been renewed.
    */
    lazy private var _originalPurchaseDate = NSDate()
    public var originalPurchaseDate:NSDate {
        get {
            return _originalPurchaseDate
        }
    }
    /**
    The expiration date for the subscription.
    
    Only present for auto-renewable subscription receipts.
    */
    lazy private var _subscriptionExpirationDate = NSDate()
    public var subscriptionExpirationDate:NSDate {
        get {
            return _subscriptionExpirationDate
        }
    }
    
    /** For a transaction that was canceled by Apple customer support, the date of the cancellation.
    */
    private var _cancellationDate:NSDate?
    public var cancellationDate:NSDate? {
        get {
            return _cancellationDate
        }
    }
    
    /** The primary key for identifying subscription purchases.
    */
    private var _webOrderLineItemID:Int32 = 0
    public var webOrderLineItemID:Int32 {
        get {
            return _webOrderLineItemID
        }
    }
    
    /*
    original transaction receipt data
    */
    var transactionReceipt:NSData
    /** Returns an initialized in-app purchase from the given data.
    @param asn1Data ASN1 data
    @return An initialized in-app purchase from the given data.
    */
    public init(ASN1Data:NSData) {
        transactionReceipt = ASN1Data;
        super.init()
        
        // Explicit casting to avoid errors when compiling as Objective-C++
        
        enumerateASN1Attributes(UnsafePointer<UInt8>(ASN1Data.bytes), length: ASN1Data.length, usingBlock: {
            (data , type) -> () in
            var p = UnsafePointer<UInt8>(data.bytes)
            let length:Int = data.length
            if let attributeType:IPaIAPReceiptASN1Type = IPaIAPReceiptASN1Type(rawValue: type) {
                switch (attributeType)
                {
                case .Quantity:

                    self._quantity = self.ASN1ReadInteger(&p, omax: length)
                case .ProductIdentifier:
                    self._productIdentifier = self.ASN1ReadUTF8String(&p,omax:length)
                case .TransactionIdentifier:
                    self._transactionIdentifier = self.ASN1ReadUTF8String(&p, omax:length)
                case .PurchaseDate:
                    let string = self.ASN1ReadIA5SString(&p,omax:length)
                    self._purchaseDate = self.formatRFC3339String(string)
                
                case .OriginalTransactionIdentifier:
                    self._originalTransactionIdentifier = self.ASN1ReadUTF8String(&p,omax:length)
                case .OriginalPurchaseDate:
                    let string = self.ASN1ReadIA5SString(&p,omax:length)
                    self._originalPurchaseDate = self.formatRFC3339String(string)


                case .SubscriptionExpirationDate:

                    let string = self.ASN1ReadIA5SString(&p, omax:length)
                    self._subscriptionExpirationDate = self.formatRFC3339String(string)
                case .WebOrderLineItemID:
                    self._webOrderLineItemID = self.ASN1ReadInteger(&p,omax:length)

                case .CancellationDate:

                    let string = self.ASN1ReadIA5SString(&p, omax:length)
                    self._cancellationDate = self.formatRFC3339String(string)

                }
            }
        })
    

    }

    
    /** Returns whether the auto renewable subscription is active for the given date.
    @param date The date in which the auto-renewable subscription should be active. If you are using the current date, you might not want to take it from the device in case the user has changed it.
    @return YES if the auto-renewable subscription is active for the given date, NO otherwise.
    @warning Auto-renewable subscription lapses are possible. If you are checking against the current date, you might want to deduct some time as tolerance.
    @warning If this method fails Apple recommends to refresh the receipt and try again once.
    */
    public func isActiveAutoRenewableSubscription(date:NSDate) -> Bool {
        
//        NSAssert(self.subscriptionExpirationDate != nil, @"The product %@ is not an auto-renewable subscription.", self.productIdentifier);
        
        if self.cancellationDate != nil {
            return false
        }
        return (self.purchaseDate.compare(date) != .OrderedDescending && date.compare(self.subscriptionExpirationDate) != .OrderedDescending)
    }
    




    
}

