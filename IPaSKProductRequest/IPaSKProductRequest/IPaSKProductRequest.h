//
//  IPaSKProductRequest.h
//  IPaSKProductRequest
//
//  Created by IPa Chen on 2015/2/17.
//  Copyright (c) 2015年 A Magic Studio. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for IPaSKProductRequest.
FOUNDATION_EXPORT double IPaSKProductRequestVersionNumber;

//! Project version string for IPaSKProductRequest.
FOUNDATION_EXPORT const unsigned char IPaSKProductRequestVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <IPaSKProductRequest/PublicHeader.h>


@import StoreKit;

@interface IPaSKProductRequest : SKProductsRequest
+(id)requestProductID:(NSString*)productID callback:(void (^)(SKProductsRequest*,SKProductsResponse*))callback;
@end
