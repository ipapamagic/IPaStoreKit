//
//  IPaSKRequest.swift
//  IPaStoreKit
//
//  Created by IPa Chen on 2017/10/13.
//

import UIKit
import StoreKit
public typealias IPaSKRequestHandler = (SKRequest,Error?) -> ()
typealias _IPaSKRequestHandler = (IPaSKRequest,Error?) -> ()
typealias _IPaSKProductRequestHandler = (IPaSKRequest,SKProductsResponse?,Error?) -> ()
class IPaSKRequest: NSObject {
    var request:SKRequest
    var handler:Any
    init(request:SKRequest,handler:@escaping _IPaSKRequestHandler) {
        self.request = request
        self.handler = handler
        super.init()
        request.delegate = self
    }
    init(productRequest:SKProductsRequest,handler:@escaping _IPaSKProductRequestHandler) {
        self.request = productRequest as SKRequest
        self.handler = handler
        super.init()
        request.delegate = self
    }
}

extension IPaSKRequest:SKRequestDelegate,SKProductsRequestDelegate
{
    public func requestDidFinish(_ request: SKRequest) {
        
        if let handler = self.handler as? _IPaSKRequestHandler {
            handler(self,nil)
        }
        else if let handler = self.handler as? _IPaSKProductRequestHandler {
            handler(self,nil,nil)
        }
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error)
    {
        if let handler = self.handler as? _IPaSKRequestHandler {
            handler(self,error)
        }
        else if let handler = self.handler as? _IPaSKProductRequestHandler {
            handler(self,nil,error)
        }
    }
    
    //MARK: SKProductsRequestDelegate
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse)
    {
        let handler = self.handler as! _IPaSKProductRequestHandler
        handler(self,response,nil)
    }
}
