//
//  IPaIAPReceipt.swift
//  IPaStoreKit
//
//  Created by IPa Chen on 2017/10/12.
//

import UIKit

open class IPaIAPReceipt: NSObject {
    /// The product identifier which purchase related to
    public var productIdentifier: String = ""
    
    /// Transaction identifier
    public var transactionIdentifier: String = ""
    
    /// Original Transaction identifier
    public var originalTransactionIdentifier: String = ""
    
    /// Purchase Date in string format
    public var purchaseDateString: String = ""
    
    /// Original Purchase Date in string format
    public var originalPurchaseDateString: String = ""
    
    /// Subscription Expiration Date in string format. Returns `nil` if the purchase is not a renewable subscription
    public var subscriptionExpirationDateString: String? = nil
    
    /// Cancellation Date in string format. Returns `nil` if the purchase is not a renewable subscription
    public var cancellationDateString: String? = nil
    
    ///
    public var webOrderLineItemID: Int? = nil
    
    /// Quantity
    public var quantity: Int = 0
    
    init(asn1Data: Data)
    {
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
                case .quantity:
                    quantity = asn1ReadInteger(&ptr, bytes.count)
                    
                case .productIdentifier:
                    productIdentifier = asn1ReadUTF8String(&ptr, bytes.count)!
                    
                case .transactionIdentifier:
                    transactionIdentifier = asn1ReadUTF8String(&ptr, bytes.count)!
                    
                case .purchaseDate:
                    purchaseDateString = asn1ReadASCIIString(&ptr, bytes.count)!
                    
                case .originalTransactionIdentifier:
                    originalTransactionIdentifier = asn1ReadUTF8String(&ptr, bytes.count)!
                    
                case .originalPurchaseDate:
                    originalPurchaseDateString = asn1ReadASCIIString(&ptr, bytes.count)!
                    
                case .subscriptionExpirationDate:
                    subscriptionExpirationDateString = asn1ReadASCIIString(&ptr, bytes.count)
                    
                case .cancellationDate:
                    cancellationDateString = asn1ReadASCIIString(&ptr, bytes.count)
                    
                case .webOrderLineItemID:
                    webOrderLineItemID = asn1ReadInteger(&ptr, bytes.count)
                    
                default:
                    asn1ConsumeObject(&ptr, bytes.count)
                }
            }
        })
    }
}
