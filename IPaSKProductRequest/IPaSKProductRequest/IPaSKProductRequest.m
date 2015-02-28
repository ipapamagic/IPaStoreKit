//
//  IPaSKProductRequest.m
//  IPaStoreKitManager
//
//  Created by IPa Chen on 2013/11/14.
//  Copyright (c) 2013年 AMagicStudio. All rights reserved.
//

#import "IPaSKProductRequest.h"
@interface IPaSKProductRequest () <SKProductsRequestDelegate>
@property (nonatomic,copy) void (^requestCallback)(SKProductsRequest*,SKProductsResponse*);
@end
@implementation IPaSKProductRequest
static NSMutableArray *SKRequestList;
+(void)retainRequest:(IPaSKProductRequest*)request
{
    if (SKRequestList == nil) {
        SKRequestList = [@[] mutableCopy];
    }
    if ([SKRequestList indexOfObject:request] == NSNotFound)
    {
        [SKRequestList addObject:request];
    }
    
}
+(void)releaseRequest:(IPaSKProductRequest*)request
{
    [SKRequestList removeObject:request];
}

+(id)requestProductID:(NSString*)productID callback:(void (^)(SKProductsRequest*,SKProductsResponse*))callback
{
    IPaSKProductRequest *request = [[IPaSKProductRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:productID]];
    request.delegate = request;
    request.requestCallback = callback;
    
    [self retainRequest:request];
    [request start];
    return request;
}

#pragma mark - SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response
{
    self.requestCallback(request,response);
    
    
    [IPaSKProductRequest releaseRequest:self];
}
@end
