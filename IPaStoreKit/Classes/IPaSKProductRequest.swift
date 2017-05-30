//
//  IPaSKProductRequest.swift
//  IPaSKProductRequest
//
//  Created by IPa Chen on 2015/6/25.
//  Copyright (c) 2015年 A Magic Studio. All rights reserved.
//

import Foundation
import StoreKit
public typealias IPaSKProductRequestHandler = (SKProductsRequest,SKProductsResponse) -> ()
class IPaSKProductRequest : SKProductsRequest {
    var handler:IPaSKProductRequestHandler?
    
    convenience init(productIdentifiers: Set<String>,handler:@escaping IPaSKProductRequestHandler) {
        self.init(productIdentifiers: productIdentifiers)
        self.handler = handler
        
    }
    
}
