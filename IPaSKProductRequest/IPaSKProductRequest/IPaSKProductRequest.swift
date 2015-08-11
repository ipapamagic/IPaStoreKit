//
//  IPaSKProductRequest.swift
//  IPaSKProductRequest
//
//  Created by IPa Chen on 2015/6/25.
//  Copyright (c) 2015年 A Magic Studio. All rights reserved.
//

import Foundation
import StoreKit;
typealias IPaSKProductRequestHandler = (SKProductsRequest,SKProductsResponse) -> ();
class IPaSKProductRequest : SKProductsRequest,SKProductsRequestDelegate {
    var handler:IPaSKProductRequestHandler?
    
    static var SKRequestList = [IPaSKProductRequest]()
    static func requestProductID(productID:String, complete:IPaSKProductRequestHandler) -> IPaSKProductRequest!
    {
        let request = IPaSKProductRequest(productIdentifiers: Set([productID]))
        
        request.delegate = request
        request.handler = complete;
        self.retainRequest(request)
        request.start()
        return request
    }
    static func retainRequest(request:IPaSKProductRequest) {
        if find(self.SKRequestList,request) == nil {
            SKRequestList.append(request)
        }
    }
    static func releaseRequest(request:IPaSKProductRequest) {
        if let index = find(self.SKRequestList,request) {
            SKRequestList.removeAtIndex(index)
        }
    }
    
    
// MARK:SKProductsRequestDelegate
    func productsRequest(request: SKProductsRequest!, didReceiveResponse response: SKProductsResponse!)
    {
        self.handler?(request,response);
    
    
        IPaSKProductRequest.releaseRequest(self)
    }
}
