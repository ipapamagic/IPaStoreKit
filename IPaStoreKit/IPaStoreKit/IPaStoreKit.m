//
//  IPaStoreKit.m
//  IPaStoreKit
//
//  Created by IPa Chen on 2015/2/21.
//  Copyright 2015年 A Magic Studio. All rights reserved.
//

#import "IPaStoreKit.h"
@import StoreKit;
@interface IPaStoreKit()
@end
@implementation IPaStoreKit
static IPaStoreKit *instance;
+ (id)allocWithZone:(NSZone *)zone {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (instance == nil) {
            instance = [super allocWithZone:zone];
        }

    });
    return instance;
}
+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (instance == nil){
            instance = [[IPaStoreKit alloc] init];
        }
    });
    
    return instance;
}
- (id)copyWithZone:(NSZone *)zone
{
    return self;
}
-(id)init
{
    self = [super init];
    
    return self;
}
@end
